import AppKit

struct TestFailure: Error, LocalizedError, CustomStringConvertible {
    let description: String
    var errorDescription: String? { description }
}
@MainActor func expect(_ ok: @autoclosure () -> Bool, _ message: String) throws {
    if !ok() { throw TestFailure(description: message) }
}
@MainActor func coreTests(_ suite: String, directory: URL) throws {
    if suite.hasPrefix("compact-") && suite != "compact-red" { try compactTests(suite, directory: directory); return }
    if suite == "compact-red" {
        _ = NSApplication.shared
        let s = try Store(directory: directory), model = AppModel(store: s), windows = NoteWindows(model: model)
        let id = s.create(); windows.show(id, orderFront: false)
        let panel = windows.panels[id]!
        try expect(panel.frame.size == NSSize(width: 270, height: 355), "new note frame must be 270x355pt, not contentRect")
        panel.orderOut(nil); print("PASS compact-red"); return
    }
    if suite.hasPrefix("pin-") && suite != "pin-red" { try pinTests(suite, directory: directory); return }
    if suite == "pin-red" {
        let id: UUID
        do { let s = try Store(directory: directory); id = s.create(); s.edit(id) { $0.body = "锁前正文" } }
        let json = "{\"version\":1,\"notes\":{\"\(id.uuidString)\":{\"locked\":true,\"x\":150,\"y\":160,\"width\":390,\"height\":500}}}"
        try Data(json.utf8).write(to: directory.appendingPathComponent("NoteLayout.json"), options: .atomic)
        let s = try Store(directory: directory)
        s.edit(id) { $0.body = "不该写入" }
        try expect(s.note(id)?.body == "锁前正文", "persisted pin rejects content changes")
        print("PASS pin-red"); return
    }
    if suite == "bad-store" {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("PaperDock.sqlite"), marker = Data("not-a-sqlite-database\n".utf8)
        try marker.write(to: path)
        var failed = false
        do { _ = try Store(directory: directory) } catch { failed = true }
        try expect(failed && (try? Data(contentsOf: path)) == marker, "bad store refused and untouched")
        print("PASS bad-store"); return
    }
    let s = try Store(directory: directory)
    if suite == "title" {
        let id = s.create()
        for (body, title) in [("买牛奶", "买牛奶"), ("明天联系客", "明天联系客"), ("明天联系客户确认报价", "明天联系客"), ("  明天\n联系客户", "明天联系客"), ("👨‍👩‍👧‍👦甲乙丙丁戊", "👨‍👩‍👧‍👦甲乙丙丁"), ("- [ ] 发送报价", "发送报价")] {
            s.edit(id) { $0.body = body }; try expect(s.note(id)?.title == title, "title \(body)")
        }
        s.edit(id) { $0.body = ""; $0.todos = [Todo(text: "发送报价")] }
        try expect(s.note(id)?.title == "发送报价", "todo title")
        s.edit(id) { $0.manualTitle = "报价跟进"; $0.body = "下周确认新方案" }
        try expect(s.note(id)?.title == "报价跟进", "manual protection")
        s.edit(id) { $0.manualTitle = "" }
        try expect(s.note(id)?.title == "下周确认新", "clear manual")
    } else if suite == "dates" {
        let id = s.create(), old = Date(timeIntervalSince1970: 100), next = Date(timeIntervalSince1970: 90000)
        s.arrange(id) { $0.modified = old }
        s.clock = { next }
        for change: (inout Note) -> Void in [{ $0.body = "正文" }, { $0.manualTitle = "标题" }, { $0.todos.append(Todo(text: "明日复核")) }, { $0.todos[0].text = "今天复核" }, { $0.todos[0].done = true }, { $0.todos[0].done = false }, { $0.todos.removeLast() }] {
            s.arrange(id) { $0.modified = old }; s.edit(id, change)
            try expect(s.note(id)?.modified == next, "content date")
        }
        s.arrange(id) { $0.modified = old; $0.visible = false; $0.color = "#303731"; $0.deleted = true }
        s.arrange(id) { $0.deleted = false }
        try expect(s.note(id)?.modified == old, "noncontent date")
        s.edit(id) { $0.body = "正文" }
        try expect(s.note(id)?.modified == old, "no-op date")
        let calendar = Calendar.current, today = Date(), yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        try expect(ManagerView.dayLabel(today, now: today, calendar: calendar) == "今天" && ManagerView.dayLabel(yesterday, now: today, calendar: calendar) == "昨天", "local natural day groups")
        let b = s.create(); s.arrange(b) { $0.modified = old }
        let results = s.results(.all, "")
        try expect(results.map(\.id) == [id, b].sorted { $0.uuidString < $1.uuidString }, "stable equal date order")
    } else if suite == "query" {
        let a = s.create(), b = s.create()
        s.edit(a) { $0.manualTitle = "客户报价跟进"; $0.body = String(repeating: "甲", count: 120) + "40HQ 独有标记Z731"; $0.todos = [Todo(text: "核对最新报价")] }
        s.arrange(a) { $0.visible = false }
        for q in ["客户报价跟进", "z731", "40hq", "核对最新报价"] {
            try expect(s.results(.all, q).map(\.id) == [a], "full search \(q)")
        }
        try expect(s.results(.visible, "Z731").isEmpty, "filter isolation")
        s.arrange(b) { $0.deleted = true; $0.body = "独有标记Z731"; $0.visible = false }
        try expect(s.results(.all, "Z731").map(\.id) == [a], "trash isolation")
        try expect(s.results(.trash, "Z731").map(\.id) == [b], "trash search")
        s.edit(a) { $0.body = "继续记录甲" }
        try expect(s.results(.all, "40hq").isEmpty, "leave match")
        s.edit(a) { $0.body += "继续记录乙" }
        try expect(s.note(a)?.body == "继续记录甲继续记录乙" && s.note(b)?.body == "独有标记Z731", "stable identity")
    } else if suite == "windows" {
        _ = NSApplication.shared
        let m = AppModel(store: s), windows = NoteWindows(model: m)
        let id = s.create(); windows.show(id); windows.show(id)
        try expect(windows.panels.count == 1 && windows.panels[id]?.isVisible == true, "one window per ID")
        try expect(windows.panels[id]?.level == .floating, "ordinary floating level")
        windows.panels[id]?.performClose(nil)
        try expect(s.note(id)?.visible == false && windows.panels[id]?.isVisible == false, "close stash")
        windows.show(id)
        try expect(windows.panels.count == 1 && windows.panels[id]?.isVisible == true, "reuse same window")
        windows.hide(id)
        let date = s.note(id)!.modified
        windows.panels[id]?.setFrame(NSRect(x: 150, y: 160, width: 390, height: 500), display: true)
        try expect(s.note(id)?.modified == date, "move resize noncontent")
        let edge = EdgeWindow { _ in }
        try expect(edge.panel.frame.width == 2 && edge.panel.frame.height == 130, "edge hidden geometry")
        edge.view.gesture.enter(); edge.layout(); try expect(edge.panel.frame.width == 24, "edge expanded geometry")
        edge.panel.orderOut(nil)
        let g = EdgeGesture(); g.enter(); try expect(g.expanded, "hover expand")
        g.leave(); try expect(!g.expanded, "leave collapse")
        g.enter(); g.begin(NSPoint(x: 1000, y: 300)); g.leave()
        try expect(g.expanded, "hold during drag")
        try expect(!g.finish(NSPoint(x: 980, y: 300)) && !g.expanded, "under40 cancels")
        g.enter(); g.begin(NSPoint(x: 1000, y: 300))
        try expect(g.finish(NSPoint(x: 950, y: 300)) && !g.expanded, "40pt one creation")
        try expect(!g.finish(NSPoint(x: 940, y: 300)), "no second release")
    } else if suite == "hsv" {
        _ = NSApplication.shared
        let id = s.create(), d = PaletteDraft(store: s, noteID: id)
        let control = HSVControl(draft: d, hueOnly: false); control.frame = NSRect(x: 0, y: 0, width: 320, height: 210)
        d.hex = "#123456"; d.syncHSV(); let h = d.hue
        control.choose(NSPoint(x: 250, y: 50))
        try expect(d.hex != "#123456" && abs(d.hue - h) < 0.001, "point updates hex preserving hue")
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 123)!
        let sat = d.saturation; control.keyDown(with: event)
        try expect(d.saturation < sat && ColorValue.normalize(d.hex) != nil, "keyboard changes color")
        d.pick(s: 0); let achromaticHue = d.hue; d.pick(s: 0.5)
        try expect(d.hue == achromaticHue, "retain hue through white")
        let hue = HSVControl(draft: d, hueOnly: true); hue.frame = NSRect(x: 0, y: 0, width: 320, height: 24); hue.choose(NSPoint(x: 180, y: 10))
        try expect(abs(d.hue - 0.5625) < 0.001, "hue control")
    } else if suite == "editor" {
        _ = NSApplication.shared
        let id = s.create(); s.edit(id) { $0.body = "已确认" }
        let delegate = BodyCoordinator(store: s, id: id), text = NSTextView()
        text.delegate = delegate; delegate.synchronize(text)
        try expect(text.string == "已确认", "editor initial value")
        text.setMarkedText("zhong", selectedRange: NSRange(location: 5, length: 0), replacementRange: NSRange(location: 0, length: 0))
        delegate.textDidChange(Notification(name: NSText.didChangeNotification, object: text))
        try expect(text.hasMarkedText() && s.note(id)?.body == "已确认", "marked text not committed")
        s.edit(id) { $0.manualTitle = "别的界面更新" }; let marked = text.string
        delegate.synchronize(text)
        try expect(text.string == marked && text.hasMarkedText(), "marked editor not replaced")
        text.unmarkText(); text.string = "中文已确认"; delegate.textDidChange(Notification(name: NSText.didChangeNotification, object: text))
        try expect(s.note(id)?.body == "中文已确认", "confirmed text save")
    } else if suite == "controller" {
        let m = AppModel(store: s), a = m.newNote(), b = m.newNote()
        s.edit(a) { $0.body = "40HQ" }; s.edit(b) { $0.body = "其他" }
        m.query = "40hq"; m.select(a); s.edit(a) { $0.body = "继续记录甲" }
        try expect(m.selected == a && m.editingOutsideResults, "pinned editor")
        s.edit(m.selected!) { $0.body += "继续记录乙" }
        try expect(s.note(b)?.body == "其他", "no cross-write")
        m.requestDelete(a); m.confirmDelete(false)
        try expect(s.note(a)?.deleted == false, "cancel delete")
        let date = s.note(a)!.modified
        m.requestDelete(a); m.confirmDelete(true)
        try expect(s.note(a)?.deleted == true && s.note(a)?.visible == false, "soft delete")
        m.restore(a)
        try expect(s.note(a)?.deleted == false && s.note(a)?.visible == false && s.note(a)?.modified == date, "restore stored")
        s.beforeSave = { throw TestFailure(description: "injected write failure") }
        s.edit(a) { $0.body = "保留未保存文字" }
        try expect(!m.canTerminate() && s.error != nil && s.dirty && s.note(a)?.body == "保留未保存文字", "visible save failure blocks exit")
        s.beforeSave = nil
        try expect(m.canTerminate() && !s.dirty && s.error == nil, "retry save")
        var locked = false
        do { _ = try Store(directory: directory) } catch { locked = true }
        try expect(locked, "same-directory second writer refused")
    } else if suite == "palette" {
        let a = s.create(), old = s.note(a)!, initial = s.settings
        do { let d = PaletteDraft(store: s, noteID: a); d.hex = "#2468AC"; d.scope = .fixed; d.stage() }
        try expect(s.settings == initial && s.note(a) == old, "cancel draft")
        let invalid = PaletteDraft(store: s, noteID: a); invalid.hex = "#12ZZZZ"
        try expect(!invalid.apply() && s.note(a) == old, "invalid rejected")
        let d = PaletteDraft(store: s, noteID: a); d.hex = "#ABCDEF"; d.scope = .fixed; d.stage()
        try expect(d.apply(), "fixed apply")
        try expect(s.note(a) == old && s.settings.fixed && s.settings.fixedColor == "#ABCDEF", "fixed doesn't recolor old")
        let b = s.create(); try expect(s.note(b)?.color == "#ABCDEF", "new fixed")
        let single = PaletteDraft(store: s, noteID: b); single.hex = "#2468ac"; try expect(single.apply(), "single apply")
        try expect(s.note(b)?.color == "#2468AC" && !s.settings.pool.contains("#2468AC"), "single not in pool")
        for _ in 0..<2 { let r = PaletteDraft(store: s, noteID: a); r.hex = "#2468AC"; r.scope = .random; try expect(r.apply(), "random apply") }
        try expect(!s.settings.fixed && s.settings.pool.count == 7 && s.note(a) == old, "dedup no recolor")
        let r = PaletteDraft(store: s, noteID: nil); r.scope = .random; r.addToPool = false; r.hex = "#123456"; try expect(r.apply(), "existing pool")
        try expect(s.settings.pool.count == 7 && !s.settings.pool.contains("#123456"), "random without add")
        for _ in 0..<8 { let id = s.create(); try expect(s.settings.pool.contains(s.note(id)!.color), "random membership") }
        s.beforeSave = { throw TestFailure(description: "palette save failure") }
        let failed = PaletteDraft(store: s, noteID: a); failed.hex = "#112233"
        try expect(!failed.apply() && s.error != nil && s.dirty, "palette doesn't claim saved on failure")
        s.beforeSave = nil; try expect(s.save(), "palette retry")
    } else if suite == "write" {
        let id = s.create(); s.edit(id) { $0.manualTitle = "本地样本"; $0.body = "本地保存样本Z731"; $0.todos = [Todo(text: "完成核对", done: true), Todo(text: "退出后复核")] }
        s.arrange(id) { $0.color = "#2468AC"; $0.visible = false }
        s.updateSettings(ColorSettings(fixed: true, fixedColor: "#ABCDEF", added: ["#2468AC"]))
        try expect(s.save(), "save")
        try id.uuidString.write(to: directory.appendingPathComponent("expected-id.txt"), atomically: true, encoding: .utf8)
        try JSONEncoder().encode(s.note(id)!).write(to: directory.appendingPathComponent("expected-note.json"))
    } else if suite == "read" || suite == "read-random" {
        let id = UUID(uuidString: try String(contentsOf: directory.appendingPathComponent("expected-id.txt"), encoding: .utf8))!
        let n = s.note(id)
        let expected = try JSONDecoder().decode(Note.self, from: Data(contentsOf: directory.appendingPathComponent("expected-note.json")))
        try expect(n == expected, "complete note including IDs/order/date readback")
        try expect(n?.manualTitle == "本地样本" && n?.body == "本地保存样本Z731" && n?.todos.count == 2 && n?.todos[0].done == true && n?.todos[1].done == false && n?.visible == false && n?.color == "#2468AC", "readback")
        try expect(s.settings.fixed == (suite == "read") && s.settings.pool.count == 7, "settings readback")
        if suite == "read" {
            let new = s.create(); try expect(s.note(new)?.color == "#ABCDEF", "fixed new")
            var settings = s.settings; settings.fixed = false; s.updateSettings(settings)
        } else {
            let new = s.create(); try expect(s.settings.pool.contains(s.note(new)!.color), "random after second restart")
        }
    } else { throw TestFailure(description: "Unknown suite: \(suite)") }
    print("PASS \(suite)")
}
