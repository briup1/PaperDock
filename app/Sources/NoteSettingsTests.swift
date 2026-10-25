import AppKit
import SwiftUI

@MainActor func noteSettingsTests(_ suite: String, directory: URL) throws {
    if suite == "note-settings-todo-controls" { try todoControlsTests(directory: directory); return }
    if suite == "note-settings-compat" {
        let id: UUID
        do { let s = try Store(directory: directory); id = s.create() }
        let layoutURL = directory.appendingPathComponent("NoteLayout.json")
        let old = "{\"version\":1,\"notes\":{\"\(id)\":{\"locked\":true,\"x\":150,\"y\":160,\"width\":390,\"height\":600}}}"
        try Data(old.utf8).write(to: layoutURL)
        do {
            let s = try Store(directory: directory)
            try expect(s.defaultHeight == 190 && s.layer(id) == .floating && s.isLocked(id) && !s.isCollapsed(id), "missing fields only use legacy defaults")
            try expect((try? Data(contentsOf: layoutURL)) == Data(old.utf8), "load does not rewrite legacy layout")
        }
        let saved = old.replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"defaultHeight\":177.5")
        try Data(saved.utf8).write(to: layoutURL)
        do {
            let s = try Store(directory: directory)
            try expect(s.defaultHeight == 177.5 && (try? Data(contentsOf: layoutURL)) == Data(saved.utf8), "existing saved height retained without rewrite")
        }
        let invalidHeights = ["null", "\"500\"", "174.9", "1000.1", "1e999"]
        let invalidLayers = ["null", "3", "\"invalid\""]
        var samples = invalidHeights.map { old.replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"defaultHeight\":\($0)") }
        samples += invalidLayers.map { old.replacingOccurrences(of: "\"locked\":true", with: "\"locked\":true,\"layer\":\($0)") }
        samples += [old.replacingOccurrences(of: "\"version\":1", with: "\"version\":2"), String(old.dropLast()), old.replacingOccurrences(of: "\"height\":600", with: "\"height\":174")]
        for sample in samples {
            let data = Data(sample.utf8); try data.write(to: layoutURL)
            var rejected = false
            do { _ = try Store(directory: directory) } catch { rejected = true }
            try expect(rejected && (try? Data(contentsOf: layoutURL)) == data, "bad field/version preserved rather than defaulted")
        }
        print("PASS \(suite)"); return
    }
    let s = try Store(directory: directory)
    if suite == "note-settings-write" {
        let a = s.create(), b = s.create()
        s.edit(a) { $0.body = "稍后采购"; $0.todos = [Todo(text: "核对数量"), Todo(text: "联系供应商", done: true)] }
        try expect(s.updateFrame(a, NSRect(x: 150, y: 160, width: 390, height: 600)), "write frame")
        try expect(s.setLayer(a, .desktop), "write desktop")
        try expect(s.setLocked(b, true, frame: NSRect(x: 200, y: 250, width: 270, height: 500)), "write other locked floating")
        try expect(s.setDefaultHeight(177.5) && s.setDefaultHeight(500), "write precise global setting")
        s.updateSettings(ColorSettings(fixed: true, fixedColor: "#ABCDEF", added: ["#2468AC"], saved: ["#123456"]))
        try JSONEncoder().encode(s.notes).write(to: directory.appendingPathComponent("expected-notes.json"))
    } else if suite == "note-settings-read" {
        let expected = try JSONDecoder().decode([Note].self, from: Data(contentsOf: directory.appendingPathComponent("expected-notes.json")))
        try expect(s.notes.sorted { $0.id.uuidString < $1.id.uuidString } == expected.sorted { $0.id.uuidString < $1.id.uuidString }, "cross process complete content/time/identity")
        let a = expected[0].id, b = expected[1].id
        try expect(s.defaultHeight == 500 && s.layer(a) == .desktop && s.layer(b) == .floating && s.isLocked(b), "cross process global height and per-note layer/lock")
        try expect(s.settings.fixed && s.settings.fixedColor == "#ABCDEF" && s.settings.pool.count == 7 && s.settings.saved == ["#123456"], "old custom settings retained")
        _ = NSApplication.shared
        let m = AppModel(store: s), windows = NoteWindows(model: m)
        for id in [a, b] { windows.show(id, orderFront: false) }
        try expect(abs(windows.panels[a]!.frame.height - 500) <= 1 && abs(windows.panels[b]!.frame.height - 500) <= 1 && !windows.panels[b]!.isMovable, "startup restores uniform height even for old locked note")
        try expect(windows.panels[a]!.level == NoteWindows.level(.desktop) && windows.panels[b]!.level == .floating, "startup applies mixed native window levels")
        windows.panels.values.forEach { $0.orderOut(nil) }
        try expect(s.note(s.create())?.color == "#ABCDEF", "new fixed color still used")
    } else if suite == "note-settings-rules" {
        let m = AppModel(store: s), a = m.newNote(), b = m.newNote()
        let frame = NSRect(x: 150, y: 160, width: 390, height: 600)
        m.floatingFrame = { _ in frame }
        try expect(s.updateFrame(a, frame), "valid placement")
        let oldDate = s.note(a)!.modified
        for invalid in ["", "abc", "NaN", "Infinity", "-Infinity", "174.9", "1000.1"] {
            m.heightDraft = invalid
            try expect(!m.saveHeight() && s.defaultHeight == 190 && m.heightDraft == invalid && m.heightFeedback != nil, "invalid draft rejected and retained: \(invalid)")
        }
        try expect(!s.setDefaultHeight(.nan) && !s.setDefaultHeight(.infinity) && !s.setDefaultHeight(174.9), "store final height validation")
        for value in [175.0, 177.5, 1000.0, 177.5] { m.heightDraft = String(value); try expect(m.saveHeight() && s.defaultHeight == value, "valid precise height") }
        let layoutURL = directory.appendingPathComponent("NoteLayout.json"), before = try Data(contentsOf: layoutURL)
        s.beforeLayoutSave = { throw TestFailure(description: "injected layout write failure") }
        m.heightDraft = "500"
        try expect(!m.saveHeight() && s.defaultHeight == 177.5 && m.heightDraft == "500" && m.heightSaveFailed, "failed global save preserves old effective value and draft")
        try expect((try? Data(contentsOf: layoutURL)) == before, "failed global save leaves exact persisted bytes")
        try expect(!m.setLayer(a, .desktop) && s.layer(a) == .floating, "layout failure does not publish layer")
        s.beforeLayoutSave = nil
        try expect(m.saveHeight() && s.defaultHeight == 500, "explicit height retry succeeds")
        s.beforeSave = { throw TestFailure(description: "injected content save failure") }
        try expect(!m.setLayer(a, .desktop) && s.layer(a) == .floating, "content failure prevents layer")
        s.beforeSave = nil
        try expect(m.setLayer(a, .desktop) && s.layer(b) == .floating, "only selected note changes layer")
        try expect(m.toggleLock(a), "lock desktop note")
        try expect(!m.setLayer(a, .floating) && !s.setLayer(a, .floating, frame: frame) && !s.setCollapsed(a, true), "model/store final lock blocks bypass")
        s.edit(a) { $0.body = "blocked" }; try expect(s.note(a)?.body == "", "locked body unchanged")
        try expect(m.toggleLock(a) && m.toggleCollapsed(a), "unlock collapse")
        m.heightDraft = "175"; try expect(m.saveHeight(), "height while collapsed")
        let collapsedPlacement = s.placements[a]
        s.beforeLayoutSave = { throw TestFailure(description: "injected expand failure") }
        try expect(!m.toggleCollapsed(a) && s.isCollapsed(a) && s.placements[a] == collapsedPlacement, "expand failure preserves collapsed metadata")
        s.beforeLayoutSave = nil
        try expect(m.toggleCollapsed(a), "expand after changed setting")
        try expect(s.placements[a]?.height == 175 && s.placements[a]?.frame.maxY == frame.maxY && s.layer(a) == .desktop, "expand uses current height preserving top/width/layer")
        try expect(s.note(a)?.modified == oldDate, "settings/layer/lock/collapse do not change content time")
    } else if suite == "note-settings-controls" {
        _ = NSApplication.shared
        let m = AppModel(store: s), windows = NoteWindows(model: m)
        m.showFloating = { windows.show($0, orderFront: false) }; m.hideFloating = { windows.hide($0) }
        let a = m.newNote(), b = m.newNote(), panel = windows.panels[a]!
        let evidence = directory.appendingPathComponent("content", isDirectory: true)
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        func near(_ height: Double, _ target: Double) -> Bool { abs(height - target) <= 1 }
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap { descendants($0) } }
        func settle(_ view: NSView) {
            for _ in 0..<4 { view.layoutSubtreeIfNeeded(); view.displayIfNeeded(); RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.04)) }
        }
        func capture(_ view: NSView, _ name: String) throws {
            settle(view)
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!; view.cacheDisplay(in: view.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])!.write(to: evidence.appendingPathComponent(name + ".png"))
        }
        try expect(near(panel.frame.height, 190), "new panel height permits AppKit <=1pt alignment")
        let before = panel.frame
        m.heightDraft = "500"; try expect(m.saveHeight() && panel.frame == before, "global save does not resize open panel")
        panel.setFrame(NSRect(x: 150, y: 160, width: 390, height: 600), display: false)
        windows.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification, object: panel))
        let temporary = panel.frame
        try expect(m.toggleLock(b) && m.toggleLock(b), "arrange other panel")
        windows.synchronizeLock(a); windows.show(a, orderFront: false)
        try expect(panel.frame == temporary, "other placement notification and showing already-open ID do not reset height")
        let layoutURL = directory.appendingPathComponent("NoteLayout.json"), bytes = try Data(contentsOf: layoutURL)
        s.beforeLayoutSave = { throw TestFailure(description: "injected global failure") }
        m.heightDraft = "175"; try expect(!m.saveHeight(), "fail new global value")
        let failedOpen = m.newNote()
        try expect(near(windows.panels[failedOpen]!.frame.height, 500) && (try? Data(contentsOf: layoutURL)) == bytes, "before retry new window reads old saved value and bytes unchanged")
        s.beforeLayoutSave = nil
        m.stash(a); m.show(a)
        try expect(near(panel.frame.height, 500) && panel.frame.width == temporary.width && abs(panel.frame.maxY - temporary.maxY) <= 1, "real reopen uses setting but keeps width/top")
        try expect(m.toggleLock(a), "lock for reopen")
        windows.hide(a); windows.show(a, orderFront: false)
        try expect(s.isLocked(a) && near(panel.frame.height, 500) && !panel.isMovable, "locked reopen applies global height without unlocking")
        try expect(m.toggleLock(a), "unlock for compact data")
        s.edit(a) { $0.manualTitle = "稍后采购"; $0.body = (1...100).map { "采购记录\($0)" }.joined(separator: "\n"); $0.todos = (1...12).map { Todo(text: "核对数量\($0)") } }
        panel.setFrame(NSRect(x: panel.frame.minX, y: panel.frame.minY, width: 270, height: panel.frame.height), display: false)
        windows.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification, object: panel))
        for height in [175.0, 177.5] {
            try expect(s.setDefaultHeight(height), "set short height")
            windows.hide(a); windows.show(a, orderFront: false)
            let view = panel.contentView!; settle(view)
            try capture(view, "height-\(height)")
            try expect(near(panel.frame.height, height), "short physical height")
            guard let text = descendants(view).compactMap({ $0 as? NSTextView }).first(where: { $0.accessibilityLabel() == "便签正文" }),
                  let bodyScroll = text.enclosingScrollView,
                  let outer = descendants(view).compactMap({ $0 as? NSScrollView }).first(where: { $0 !== bodyScroll && ($0.documentView?.bounds.height ?? 0) > $0.contentView.bounds.height }) else {
                throw TestFailure(description: "short editor needs real body and outer scrolling")
            }
            try expect(bodyScroll.bounds.height >= 60 && text.font?.pointSize == 12.5, "body stays bounded at unchanged font")
            text.scrollRangeToVisible(NSRange(location: (text.string as NSString).length, length: 0)); settle(view)
            text.insertText("末尾续写", replacementRange: NSRange(location: (text.string as NSString).length, length: 0))
            try expect(s.note(a)?.body.hasSuffix("末尾续写") == true, "real body delegate saves tail at short height")
            s.edit(a) { $0.todos[11].done = true; $0.todos.append(Todo(text: "新增")); $0.todos.removeLast() }
            try expect(s.note(a)?.todos.count == 12 && s.note(a)?.todos[11].done == true, "last todo and add/remove keep same content ID")
            s.beforeSave = { throw TestFailure(description: "injected short editor failure") }
            s.edit(a) { $0.body += "保留已确认文字" }; settle(view)
            let doc = outer.documentView!
            doc.scroll(NSPoint(x: 0, y: max(0, doc.bounds.height - outer.contentView.bounds.height))); settle(view)
            try expect(outer.contentView.bounds.maxY >= doc.bounds.maxY - 2 && s.error != nil && s.note(a)?.body.hasSuffix("保留已确认文字") == true, "outer reaches bottom including save error without losing edits")
            try capture(view, "height-\(height)-bottom-error")
            s.beforeSave = nil; try expect(s.save(), "short error content retry")
        }
        let manager = NSHostingView(rootView: ManagerView(model: m)); manager.frame = NSRect(x: 0, y: 0, width: 1060, height: 700)
        manager.layoutSubtreeIfNeeded(); manager.displayIfNeeded()
        let managerRep = manager.bitmapImageRepForCachingDisplay(in: manager.bounds)!; manager.cacheDisplay(in: manager.bounds, to: managerRep)
        try managerRep.representation(using: .png, properties: [:])!.write(to: evidence.appendingPathComponent("manager.png"))
        try expect(m.setLayer(a, .desktop) && panel.level == NoteWindows.level(.desktop), "native layer follows saved state")
        let priorPlacement = s.placements[a]
        s.beforeLayoutSave = { throw TestFailure(description: "injected native layer failure") }
        try expect(!m.setLayer(a, .floating) && panel.level == NoteWindows.level(.desktop) && s.placements[a] == priorPlacement, "failed layer save keeps real window and authoritative state")
        s.beforeLayoutSave = nil
        try expect(m.toggleLock(a) && !m.setLayer(a, .floating) && !s.setLayer(a, .floating, frame: panel.frame) && panel.level == NoteWindows.level(.desktop), "locked native layer cannot be bypassed")
        try expect(m.toggleLock(a), "unlock before marked candidate")
        let text = NSTextView(); panel.contentView?.addSubview(text); panel.makeFirstResponder(text)
        text.setMarkedText("zhong", selectedRange: NSRange(location: 5, length: 0), replacementRange: NSRange(location: 0, length: 0))
        try expect(!m.setLayer(a, .floating) && text.hasMarkedText() && s.layer(a) == .desktop, "target marked text blocks layer without cancelling")
        text.unmarkText(); text.removeFromSuperview()
        try expect(m.toggleCollapsed(a) && near(panel.frame.height, 27), "collapse keeps 27")
        try expect(m.toggleLock(a), "lock collapsed for content evidence")
        s.error = "未保存：合成故障"
        try capture(panel.contentView!, "collapsed-locked-error")
        try expect(m.toggleLock(a), "unlock collapsed")
        try expect(s.setDefaultHeight(500) && m.toggleCollapsed(a) && near(panel.frame.height, 500), "next expand current setting")
        try expect(s.setDefaultHeight(1000), "maximum legal setting")
        windows.hide(a); windows.show(a, orderFront: false)
        try expect(s.defaultHeight == 1000 && panel.frame.height <= NSScreen.main!.visibleFrame.height && NSScreen.main!.visibleFrame.contains(panel.frame), "overscreen display stays accessible without changing saved value")
        windows.panels.values.forEach { $0.orderOut(nil) }
        try expect(s.save(), "controls save on normal return")
    } else { throw TestFailure(description: "Unknown settings suite: \(suite)") }
    print("PASS \(suite)")
}
