import AppKit
import SwiftUI

@MainActor func pinTests(_ suite: String, directory: URL) throws {
    let frame = NSRect(x: 150, y: 160, width: 390, height: 500)
    if suite == "pin-metadata" {
        let id: UUID
        do { let s = try Store(directory: directory); id = s.create() }
        let url = directory.appendingPathComponent("NoteLayout.json")
        let prefix = "{\"version\":1,\"notes\":{\"\(id.uuidString)\":"
        let variants = ["broken", "{\"version\":2,\"notes\":{}}", prefix + "{\"locked\":true,\"x\":0,\"y\":0,\"width\":0,\"height\":500}}}", prefix + "{\"locked\":true,\"x\":1e99,\"y\":0,\"width\":390,\"height\":500}}}", "{\"version\":1,\"notes\":{\"not-an-id\":{\"locked\":true,\"x\":0,\"y\":0,\"width\":390,\"height\":500}}}"]
        for json in variants {
            let data = Data(json.utf8); try data.write(to: url, options: .atomic)
            var failed = false
            do { _ = try Store(directory: directory) } catch { failed = true }
            try expect(failed && (try? Data(contentsOf: url)) == data, "invalid metadata fails closed and preserves file")
        }
    } else if suite == "pin-io" {
        let s = try Store(directory: directory), id = s.create()
        let url = directory.appendingPathComponent("NoteLayout.json")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        try expect(!s.setLocked(id, true, frame: frame) && !s.isLocked(id) && s.error != nil, "real atomic-write failure does not publish lock")
        var isDirectory: ObjCBool = false
        try expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue, "write failure preserves conflicting original")
    } else if suite == "pin-rules" {
        let s = try Store(directory: directory), m = AppModel(store: s)
        let a = m.newNote(), b = m.newNote()
        s.edit(a) { $0.manualTitle = "报价跟进"; $0.body = "明天确认报价"; $0.todos = [Todo(text: "完成", done: true), Todo(text: "未完成")] }
        let old = s.note(a)!, settings = s.settings
        m.floatingFrame = { _ in frame }
        var hidden: [UUID] = []; m.hideFloating = { hidden.append($0) }
        m.requestDelete(a)
        let drafts = PaletteScope.allCases.map { scope -> PaletteDraft in let d = PaletteDraft(store: s, noteID: a); d.hex = "#2468AC"; d.scope = scope; d.stage(); return d }
        try expect(m.toggleLock(a) && s.isLocked(a), "pin saved")
        s.edit(a) { $0.manualTitle = "不该改"; $0.body = "不该改"; $0.todos.removeAll() }
        s.arrange(a) { $0.color = "#303731"; $0.visible = false; $0.deleted = true }
        m.stash(a); m.confirmDelete(true); m.requestDelete(a)
        try expect(s.note(a) == old && hidden.isEmpty && m.pendingDelete == nil, "locked writes/stash/stale delete/request refused")
        for d in drafts { try expect(!d.apply(), "stale draft refused in every scope") }
        var next = settings; next.fixed = true
        try expect(!s.applyPalette(next, noteID: a, color: "#303731"), "direct palette refused")
        try expect(!s.applyPalette(next, noteID: nil, color: "#303731", sourceNoteID: a), "source identity preserved for global palette")
        try expect(s.note(a) == old && s.settings == settings, "all locked data and settings unchanged")
        s.edit(b) { $0.body = "B可编辑" }; try expect(s.note(b)?.body == "B可编辑" && !s.isLocked(b), "B unaffected")
        s.beforeLayoutSave = { throw TestFailure(description: "injected metadata failure") }
        try expect(!m.toggleLock(a) && s.isLocked(a) && s.error != nil, "failed unlock keeps old lock")
        s.beforeLayoutSave = nil
        try expect(m.toggleLock(a) && !s.isLocked(a) && s.note(a) == old, "unlock does not change content/date")
        s.beforeSave = { throw TestFailure(description: "injected content save failure") }
        try expect(!m.toggleLock(a) && !s.isLocked(a) && s.error != nil, "failed prerequisite content save cannot claim pin")
        s.beforeSave = nil
        s.beforeLayoutSave = { throw TestFailure(description: "injected metadata failure") }
        try expect(!m.toggleLock(a) && !s.isLocked(a) && s.error != nil, "failed pin keeps unlocked")
        s.beforeLayoutSave = nil
        try expect(!s.setLocked(a, true, frame: NSRect(x: 0, y: 0, width: 0, height: 0)), "invalid live frame refused")
        s.edit(a) { $0.body += "解锁续写" }; try expect(s.note(a)?.body == "明天确认报价解锁续写", "unlocked editor resumes")
        try expect(m.toggleLock(a) && m.toggleLock(a), "retry pin and unlock")
        m.select(a); m.requestDelete(b); m.confirmDelete(false)
        try expect(s.note(b)?.deleted == false && m.selected == a, "B delete cancel keeps A selected")
        m.requestDelete(b); m.confirmDelete(true)
        try expect(s.note(b)?.deleted == true && s.note(a)?.deleted == false && m.selected == a && hidden == [b], "B stable ID deleted not selected A")
        m.restore(b); try expect(s.note(b)?.visible == false && s.note(b)?.deleted == false, "restore stored")
        let global = PaletteDraft(store: s, noteID: nil); global.scope = .fixed; global.hex = "#ABCDEF"
        try expect(global.apply(), "independent global settings still usable")
        try expect(m.canTerminate(), "normal save remains available")
    } else if suite == "pin-write" {
        let s = try Store(directory: directory), id = s.create()
        s.edit(id) { $0.body = "锁定重启样本"; $0.todos = [Todo(text: "完成", done: true), Todo(text: "未完成")] }
        try expect(s.setLocked(id, true, frame: frame), "write locked frame")
        try JSONEncoder().encode(s.note(id)!).write(to: directory.appendingPathComponent("pin-expected.json"))
    } else if suite == "pin-read" || suite == "pin-read-unlocked" || suite == "pin-window-read" {
        let s = try Store(directory: directory)
        let expected = try JSONDecoder().decode(Note.self, from: Data(contentsOf: directory.appendingPathComponent("pin-expected.json")))
        try expect(s.note(expected.id) == expected && s.placements[expected.id]?.frame == frame, "second process same ID/data/date/frame")
        if suite == "pin-window-read" {
            _ = NSApplication.shared
            let m = AppModel(store: s), windows = NoteWindows(model: m)
            windows.show(expected.id, orderFront: false)
            let panel = windows.panels[expected.id]!
            try expect(panel.frame == frame && !panel.isVisible && !panel.isMovable && !panel.styleMask.contains(.resizable), "restored frame and native lock applied before first display")
            panel.orderOut(nil)
        } else if suite == "pin-read" {
            try expect(s.isLocked(expected.id), "second process remains locked")
            s.edit(expected.id) { $0.body = "迟到写入" }; try expect(s.note(expected.id) == expected, "reloaded lock protects")
            try expect(s.setLocked(expected.id, false), "unlock persists")
        } else { try expect(!s.isLocked(expected.id), "third process remains unlocked") }
    } else if suite == "pin-controls" {
        _ = NSApplication.shared
        let s = try Store(directory: directory), m = AppModel(store: s), windows = NoteWindows(model: m)
        let id = s.create(); s.edit(id) { $0.body = "已确认" }
        // Create our panel offscreen without ordering it or installing an edge entrance.
        windows.show(id, orderFront: false)
        let panel = windows.panels[id]!
        panel.setFrame(frame, display: false)
        func capture(_ view: NSView, _ name: String) throws {
            view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw TestFailure(description: "No control bitmap") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw TestFailure(description: "No control PNG") }
            try png.write(to: directory.appendingPathComponent(name))
        }
        try capture(panel.contentView!, "unlocked-content.png")
        let delegate = BodyCoordinator(store: s, id: id), text = NSTextView()
        delegate.synchronize(text)
        text.setMarkedText("zhong", selectedRange: NSRange(location: 5, length: 0), replacementRange: NSRange(location: 0, length: 0))
        try expect(m.toggleLock(id), "control pin")
        try expect(!panel.isMovable && !panel.styleMask.contains(.resizable) && panel.standardWindowButton(.closeButton)?.isEnabled == false && panel.frame == frame, "native move/resize/close flags; frame stable")
        try capture(panel.contentView!, "locked-content.png")
        let manager = NSHostingView(rootView: ManagerView(model: m)); manager.frame = NSRect(x: 0, y: 0, width: 1060, height: 700)
        m.select(id); try capture(manager, "manager-locked-content.png")
        delegate.synchronize(text)
        try expect(!text.hasMarkedText() && text.string == "已确认", "lock discards unconfirmed candidate without saving")
        text.string = "迟到候选"; delegate.textDidChange(Notification(name: NSText.didChangeNotification, object: text))
        try expect(s.note(id)?.body == "已确认" && text.string == "已确认" && !delegate.textView(text, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementString: "x"), "delegate refuses locked edits")
        _ = windows.windowShouldClose(panel)
        try expect(s.note(id)?.visible == true, "window close cannot stash locked note")
        try expect(m.toggleLock(id) && panel.isMovable && panel.styleMask.contains(.resizable), "native flags restored")
        text.string = "解锁续写"; delegate.textDidChange(Notification(name: NSText.didChangeNotification, object: text))
        try expect(s.note(id)?.body == "解锁续写", "delegate editable after unlock")
        panel.orderOut(nil)
    } else { throw TestFailure(description: "Unknown pin suite: \(suite)") }
    print("PASS \(suite)")
}
