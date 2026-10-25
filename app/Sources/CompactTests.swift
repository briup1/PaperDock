import AppKit
import SwiftUI

@MainActor func compactTests(_ suite: String, directory: URL) throws {
    _ = NSApplication.shared
    let s = try Store(directory: directory), m = AppModel(store: s), windows = NoteWindows(model: m)
    let target = NSSize(width: 270, height: 355)
    if suite == "compact-write" {
        let id = s.create(); windows.show(id, orderFront: false)
        try expect(s.setLocked(id, true, frame: windows.panels[id]!.frame), "small frame can pin")
        try JSONEncoder().encode(s.note(id)!).write(to: directory.appendingPathComponent("expected.json"))
    } else if suite == "compact-read" {
        let expected = try JSONDecoder().decode(Note.self, from: Data(contentsOf: directory.appendingPathComponent("expected.json")))
        windows.show(expected.id, orderFront: false)
        let panel = windows.panels[expected.id]!
        try expect(panel.frame.size == target && !panel.isMovable && !panel.styleMask.contains(.resizable) && s.note(expected.id) == expected, "small frame reload and lock/data preserved")
        let layout = try Data(contentsOf: directory.appendingPathComponent("NoteLayout.json"))
        try expect(!s.setLocked(expected.id, false, frame: NSRect(x: 0, y: 0, width: 269, height: 355)) && s.isLocked(expected.id), "too narrow frame rejected")
        try expect(!s.setLocked(expected.id, false, frame: NSRect(x: 0, y: 0, width: 270, height: 349)) && s.isLocked(expected.id), "too short frame rejected")
        try expect(!s.setLocked(expected.id, false, frame: NSRect(x: CGFloat.infinity, y: 0, width: 270, height: 355)) && s.isLocked(expected.id), "infinite frame rejected")
        try expect((try? Data(contentsOf: directory.appendingPathComponent("NoteLayout.json"))) == layout, "invalid frame does not replace metadata")
        try expect(m.toggleLock(expected.id), "small frame unlock")
        s.edit(expected.id) { $0.body = "解锁续写" }
        try expect(s.note(expected.id)?.body == "解锁续写", "small frame edit resumes")
        panel.orderOut(nil)
    } else if suite == "compact-controls" {
        var observations: [[String: Any]] = []
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap { descendants($0) } }
        func settle(_ view: NSView) {
            for _ in 0..<4 {
                view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.04))
            }
        }
        func capture(_ view: NSView, name: String) throws {
            settle(view)
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw TestFailure(description: "No content bitmap") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw TestFailure(description: "No content PNG") }
            try png.write(to: directory.appendingPathComponent(name + ".png"))
        }
        for (name, color, count, locked) in [("empty-light", "#FFFEFA", 0, false), ("light", "#FFFEFA", 2, false), ("dark", "#303731", 2, false), ("long", "#FFFEFA", 8, false), ("locked-dark", "#303731", 8, true)] {
            let id = s.create()
            if count > 0 {
                s.edit(id) {
                    $0.manualTitle = "报价跟进"
                    $0.body = String(repeating: "明天联系客户确认报价。上海到德班，核对40HQ价格后回复。\n", count: count == 8 ? 20 : 1)
                    $0.todos = (1...count).map { Todo(text: "核对项目\($0)", done: $0 == 1) }
                }
            }
            s.arrange(id) { $0.color = color }
            windows.show(id, orderFront: false)
            let panel = windows.panels[id]!, view = panel.contentView!
            settle(view)
            try expect(panel.frame.size == target && !panel.isVisible, "new frame is 270x355 including system titlebar and stays undisplayed")
            try expect(panel.contentRect(forFrameRect: panel.frame).height < 355 && panel.minSize.width <= 270 && panel.minSize.height <= 355, "content differs from outer frame; minimum allows target")
            if locked { try expect(m.toggleLock(id), "small locked state") }
            try capture(view, name: name)
            let allViews = descendants(view)
            guard let text = allViews.compactMap({ $0 as? NSTextView }).first(where: { !$0.isFieldEditor && $0.accessibilityLabel() == "便签正文" }), let scroll = text.enclosingScrollView else { throw TestFailure(description: "Missing real body editor") }
            try expect(text.font?.pointSize == 12.5 && text.textContainerInset == NSSize(width: 8, height: 8), "compact body style")
            try expect(scroll.bounds.height >= 60 && scroll.bounds.width > 200, "useful body viewport")
            var row: [String: Any] = ["name": name, "frame": NSStringFromRect(panel.frame), "content": NSStringFromRect(view.bounds), "bodyViewport": NSStringFromRect(scroll.bounds), "font": text.font!.pointSize, "scrolls": allViews.compactMap { $0 as? NSScrollView }.map { ["class": String(describing: type(of: $0)), "viewport": NSStringFromRect($0.contentView.bounds), "document": NSStringFromRect($0.documentView?.bounds ?? .zero)] }]
            if name == "long" {
                try expect(text.string.components(separatedBy: "核对40HQ").count == 21 && text.string == s.note(id)?.body, "twenty complete sentences preserved")
                text.scrollRangeToVisible(NSRange(location: (text.string as NSString).length, length: 0))
                settle(view)
                try expect(text.visibleRect.maxY >= text.bounds.maxY - 20, "body scroll reaches final sentence")
                let tail = "末尾可编辑"
                text.insertText(tail, replacementRange: NSRange(location: (text.string as NSString).length, length: 0))
                try expect(s.note(id)?.body.hasSuffix(tail) == true, "long body tail edits same ID")
                settle(view)
                text.scrollRangeToVisible(NSRange(location: (text.string as NSString).length, length: 0))
                if let layout = text.layoutManager, let container = text.textContainer {
                    layout.ensureLayout(for: container)
                    let visibleGlyphs = layout.glyphRange(forBoundingRect: text.visibleRect, in: container)
                    let visibleCharacters = layout.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)
                    row["visibleCharactersAtEnd"] = NSStringFromRange(visibleCharacters)
                    row["bodyUsedRect"] = NSStringFromRect(layout.usedRect(for: container))
                    try expect(NSMaxRange(visibleCharacters) >= (text.string as NSString).length - 1, "final editable characters are actually in body viewport")
                }
                row["bodyVisibleAtEnd"] = NSStringFromRect(text.visibleRect)
                row["bodyCharacters"] = text.string.count
                if let todos = allViews.compactMap({ $0 as? NSScrollView }).first(where: { $0 !== scroll && ($0.documentView?.bounds.height ?? 0) > $0.contentView.bounds.height }) {
                    let doc = todos.documentView!
                    doc.scroll(NSPoint(x: 0, y: max(0, doc.bounds.height - todos.contentView.bounds.height)))
                    settle(view)
                    try expect(todos.contentView.bounds.maxY >= doc.bounds.maxY - 2, "todo scroll reaches eighth item")
                    s.edit(id) { $0.todos[7].text += "末尾续写" }
                    try expect(s.note(id)?.todos[7].text == "核对项目8末尾续写", "eighth todo remains editable on same ID")
                    row["todoScrollToEnd"] = true
                } else { throw TestFailure(description: "Eight todos must have a scrollable viewport") }
                try capture(view, name: "long-scrolled")
            }
            if locked {
                try expect(!text.isEditable && !panel.isMovable && !panel.styleMask.contains(.resizable), "small locked controls remain protected")
                try expect(m.toggleLock(id), "small unlock remains reachable through same model")
            }
            observations.append(row)
            panel.orderOut(nil)
        }
        let id = s.create(); windows.show(id, orderFront: false)
        let oldFrame = NSRect(x: 150, y: 160, width: 390, height: 500)
        try expect(s.setLocked(id, true, frame: oldFrame), "legacy frame accepted")
        let other = NoteWindows(model: m); other.show(id, orderFront: false)
        try expect(other.panels[id]?.frame == oldFrame, "recorded 390x500 remains unchanged")
        let manager = NSHostingView(rootView: NoteEditor(model: m, id: id, compact: false)); manager.frame = NSRect(x: 0, y: 0, width: 500, height: 650)
        try capture(manager, name: "manager-unchanged")
        guard let managerText = descendants(manager).compactMap({ $0 as? NSTextView }).first(where: { !$0.isFieldEditor && $0.accessibilityLabel() == "便签正文" }) else { throw TestFailure(description: "Missing manager body") }
        try expect(managerText.font?.pointSize == 17 && managerText.textContainerInset == NSSize(width: 12, height: 16), "manager body font and inset unchanged")
        try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("geometry.json"))
        windows.panels.values.forEach { $0.orderOut(nil) }; other.panels.values.forEach { $0.orderOut(nil) }
    } else { throw TestFailure(description: "Unknown compact suite: \(suite)") }
    print("PASS \(suite)")
}
