import AppKit
import SwiftUI

// Real, never-shown controls: this is not physical pointer, IME or cross-app evidence.
@MainActor func todoControlsTests(directory: URL) throws {
    _ = NSApplication.shared
    let s = try Store(directory: directory), m = AppModel(store: s), windows = NoteWindows(model: m)
    let evidence = directory.appendingPathComponent("content")
    try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap { descendants($0) } }
    func settle(_ view: NSView) {
        for _ in 0..<8 { view.layoutSubtreeIfNeeded(); view.displayIfNeeded(); RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.04)) }
    }
    func capture(_ view: NSView, _ name: String) throws {
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])!.write(to: evidence.appendingPathComponent(name + ".png"))
    }
    func fullyVisible(_ control: NSView, in root: NSView) -> Bool {
        guard root.bounds.contains(control.convert(control.bounds, to: root)) else { return false }
        var ancestor = control.superview
        while let view = ancestor, view !== root {
            if view is NSClipView, !view.bounds.contains(control.convert(control.bounds, to: view)) { return false }
            ancestor = view.superview
        }
        return true
    }
    func addButton(_ root: NSView) throws -> NSButton {
        let matches = descendants(root).compactMap { $0 as? NSButton }.filter { $0.frame.width > 50 && $0.frame.width < 120 }
        guard matches.count == 1 else { throw TestFailure(description: "unique real add control: \(matches.count)") }
        return matches[0]
    }
    for height in [190.0, 175.0] {
        try expect(s.setDefaultHeight(height), "set sequential height")
        let id = s.create(); windows.show(id, orderFront: false)
        let panel = windows.panels[id]!, root = panel.contentView!
        defer { panel.orderOut(nil) }
        settle(root)
        let initialButton = try addButton(root), initial = initialButton.convert(initialButton.bounds, to: root)
        try expect(s.note(id)!.todos.isEmpty && fullyVisible(initialButton, in: root), "empty add fully visible")
        try capture(root, "\(height)-0")
        for count in 1...3 {
            try addButton(root).performClick(nil); settle(root)
            let button = try addButton(root)
            try capture(root, "\(height)-\(count)")
            try expect(s.note(id)!.todos.count == count, "actual sequential count \(height)/\(count)")
            try expect(fullyVisible(button, in: root), "add fully visible after \(height)/\(count)")
            try expect(button.convert(button.bounds, to: root) == initial, "add stays fixed after \(height)/\(count)")
            let fields = descendants(root).compactMap { $0 as? NSTextField }.filter { $0.placeholderString == "待办文字" }
            guard let newest = fields.last else { throw TestFailure(description: "new todo field missing") }
            try expect(fullyVisible(newest, in: root), "new row visible after \(height)/\(count)")
            try expect(newest.currentEditor() === panel.firstResponder && newest.currentEditor() != nil, "new row input focused after \(height)/\(count)")
            print("SEQUENTIAL height=\(height) count=\(count) fixedAdd=true newRowVisible=true focused=true hidden=\(!panel.isVisible)")
        }
        guard let text = descendants(root).compactMap({ $0 as? NSTextView }).first(where: { $0.accessibilityLabel() == "便签正文" }) else { throw TestFailure(description: "body missing") }
        s.edit(id) { $0.body = (1...100).map { "采购记录\($0)" }.joined(separator: "\n") }; settle(root)
        text.scrollRangeToVisible(NSRange(location: (text.string as NSString).length, length: 0))
        text.insertText("末尾续写", replacementRange: NSRange(location: (text.string as NSString).length, length: 0)); settle(root)
        try expect(s.note(id)!.body.hasSuffix("末尾续写") && text.font?.pointSize == 12.5, "long body delegate and original font")
        s.beforeSave = { throw TestFailure(description: "injected add failure") }
        try addButton(root).performClick(nil); settle(root)
        try expect(s.note(id)!.todos.count == 4 && s.dirty && s.error != nil, "failed save retains added item and error")
        guard let outer = descendants(root).compactMap({ $0 as? NSScrollView }).first(where: { $0 !== text.enclosingScrollView }), let doc = outer.documentView else { throw TestFailure(description: "outer scroll missing") }
        doc.scroll(NSPoint(x: 0, y: max(0, doc.bounds.height - outer.contentView.bounds.height))); settle(root)
        let failedAdd = try addButton(root)
        try expect(outer.contentView.bounds.maxY >= doc.bounds.maxY - 2 && fullyVisible(failedAdd, in: root), "error region and fixed add reachable")
        try capture(root, "\(height)-failure")
        s.beforeSave = nil
        try expect(s.save() && !s.dirty && s.error == nil, "formal save retry retains content")
        try expect(m.toggleLock(id), "lock compact")
        settle(root)
        try expect(!descendants(root).compactMap { $0 as? NSTextField }.filter { $0.placeholderString == "待办文字" }.contains { $0.isEnabled }, "locked todo inputs disabled")
        try expect(!descendants(root).compactMap { $0 as? NSButton }.contains { $0.frame.width > 50 && $0.frame.width < 120 }, "locked add hidden")
        let old = s.note(id)!.todos
        s.edit(id) { $0.todos.append(Todo(text: "blocked")) }
        try expect(s.note(id)!.todos == old, "final store lock blocks append")
        try capture(root, "\(height)-locked")
        try expect(m.toggleLock(id), "unlock compact"); settle(root)
        panel.makeFirstResponder(text)
        text.setMarkedText("zhong", selectedRange: NSRange(location: 5, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        let markedCount = s.note(id)!.todos.count
        try addButton(root).performClick(nil); settle(root)
        try expect(text.hasMarkedText() && s.note(id)!.todos.count == markedCount && s.error != nil, "add preserves marked body and does not move focus")
        text.unmarkText(); try expect(s.save(), "clear simulated candidate error")
    }
    m.selected = s.notes.first?.id
    let manager = NSHostingView(rootView: ManagerView(model: m)); manager.frame = NSRect(x: 0, y: 0, width: 1060, height: 700); settle(manager)
    try expect(!descendants(manager).compactMap { $0 as? NSTextField }.contains { $0.placeholderString == "190" }, "manager list has no height control")
    try capture(manager, "manager")
    let settings = NSHostingView(rootView: SettingsView(model: m)); settings.frame = NSRect(x: 0, y: 0, width: 588, height: 560)
    let window = NSWindow(contentRect: settings.frame, styleMask: [.borderless], backing: .buffered, defer: false); window.contentView = settings
    defer { window.orderOut(nil) }
    settle(settings)
    guard let field = descendants(settings).compactMap({ $0 as? NSTextField }).first(where: { $0.placeholderString == "190" }) else { throw TestFailure(description: "height input missing from settings") }
    try expect(fullyVisible(field, in: settings), "settings height input visible")
    m.heightDraft = "500"; s.beforeLayoutSave = { throw TestFailure(description: "injected settings failure") }; settle(settings)
    try expect(!m.saveHeight(), "settings model save fails"); settle(settings)
    try expect(s.defaultHeight == 175 && m.heightDraft == "500" && m.heightSaveFailed && m.heightFeedback != nil, "settings failed save retains value/draft/feedback")
    try capture(settings, "settings-failure")
    s.beforeLayoutSave = nil; try expect(m.saveHeight(), "settings model retry"); settle(settings)
    try expect(s.defaultHeight == 500 && !m.heightSaveFailed, "settings model saves and redraws")
    try capture(settings, "settings-saved")
    try expect(s.save(), "save before normal controls return")
    print("PASS note-settings-todo-controls")
}
