import AppKit
import Foundation

let arguments = CommandLine.arguments
func argument(_ name: String) -> String? {
    guard let i = arguments.firstIndex(of: name), arguments.indices.contains(i + 1) else { return nil }
    return arguments[i + 1]
}
let dataURL = URL(fileURLWithPath: argument("--data-dir") ?? "", isDirectory: true)
guard argument("--data-dir") != nil else {
    fputs("Required: --data-dir /absolute/path/below/experiments/native-spike\n", stderr); exit(2)
}
if arguments.contains("--check") {
    do { try runModelChecks(directory: dataURL); exit(0) }
    catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
}

final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// A nonactivating panel receives only its own narrow hit region, not global mouse events.
final class EdgePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class EdgeView: NSView {
    enum Phase: String { case hidden, revealed, dragging, triggered }
    weak var owner: SpikeApp?
    private(set) var phase = Phase.hidden
    private(set) var triggerCount = 0
    private var anchor: NSPoint?
    private var tracking: NSTrackingArea?
    private var waitForExit = false
    var collapsedFrame = NSRect.zero

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area); tracking = area
    }
    override func draw(_ dirtyRect: NSRect) {
        // Not zero occupation: a 2pt x 130pt, 1%-opacity hit surface stays ordered for hover delivery.
        (phase == .hidden ? NSColor.systemTeal.withAlphaComponent(0.01) : NSColor.systemTeal).setFill()
        bounds.fill()
        if phase != .hidden {
            ("拖\n出\n＋" as NSString).draw(in: bounds.insetBy(dx: 3, dy: 20), withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 14)])
        }
    }
    func screenPoint(_ event: NSEvent) -> NSPoint { window!.convertPoint(toScreen: event.locationInWindow) }
    private func transition(_ next: Phase, reason: String) {
        phase = next
        var frame = collapsedFrame
        if next != .hidden { frame.origin.x = frame.maxX - 24; frame.size.width = 24 }
        window?.setFrame(frame, display: true)
        needsDisplay = true
        owner?.log("edge-phase", ["phase": phase.rawValue, "reason": reason, "frame": NSStringFromRect(frame),
                                  "key": window?.isKeyWindow ?? false, "appActive": NSApp.isActive])
    }
    override func mouseEntered(with event: NSEvent) {
        // Ignore a stale tracking event from before a frame change, or a cancelled click still at the edge.
        guard phase == .hidden, !waitForExit, window?.frame.contains(screenPoint(event)) == true else { return }
        transition(.revealed, reason: "mouse-entered")
    }
    override func mouseExited(with event: NSEvent) {
        guard window?.frame.contains(screenPoint(event)) == false else { return }
        if phase == .dragging || phase == .triggered { return }
        waitForExit = false
        if phase == .revealed { transition(.hidden, reason: "mouse-exited") }
    }
    override func mouseDown(with event: NSEvent) {
        guard phase == .revealed else { return }
        anchor = screenPoint(event)
        transition(.dragging, reason: "mouse-down")
        owner?.log("edge-down", ["screenPoint": NSStringFromPoint(anchor!)])
    }
    override func mouseDragged(with event: NSEvent) {
        guard phase == .dragging, let anchor else { return }
        let p = screenPoint(event)
        guard anchor.x - p.x >= 40 else { return }
        triggerCount += 1
        transition(.triggered, reason: "drag-threshold")
        owner?.showNote(at: p)
        owner?.log("edge-drag-created", ["screenPoint": NSStringFromPoint(p), "threshold": 40, "triggerCount": triggerCount])
    }
    override func mouseUp(with event: NSEvent) {
        guard phase == .dragging || phase == .triggered else { return }
        let point = screenPoint(event)
        let completed = phase == .triggered
        anchor = nil
        waitForExit = collapsedFrame.contains(point)
        transition(.hidden, reason: completed ? "drag-completed" : "drag-cancelled")
    }
}

final class SpikeApp: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextViewDelegate, NSTextFieldDelegate {
    let store: SpikeStore
    var state: NoteState
    var statusItem: NSStatusItem!
    var note: KeyWindow!
    var demo: NSWindow!
    var edge: EdgePanel!
    let edgeView = EdgeView()
    let titleField = NSTextField()
    let body = NSTextView()
    let todo = NSTextField()
    let done = NSButton(checkboxWithTitle: "完成待办", target: nil, action: nil)
    let color = NSColorWell()
    let scope = NSPopUpButton()
    let status = NSTextField(labelWithString: "")
    var loaded = false
    var testing = false
    var failed = false
    let auto = argument("--auto")
    let logURL: URL

    init(store: SpikeStore) throws {
        self.store = store
        state = try store.load() ?? NoteState()
        logURL = store.directory.appendingPathComponent("events.jsonl")
        super.init()
    }
    func log(_ event: String, _ details: [String: Any] = [:]) {
        var row = details
        row["event"] = event; row["pid"] = ProcessInfo.processInfo.processIdentifier
        row["time"] = ISO8601DateFormatter().string(from: Date())
        row["category"] = testing ? "programmatic" : "app-callback-not-human-attested"
        do {
            let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) + Data([10])
            if !FileManager.default.fileExists(atPath: logURL.path) { try Data().write(to: logURL, options: .withoutOverwriting) }
            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            try handle.seekToEnd(); try handle.write(contentsOf: data)
            print(String(decoding: data, as: UTF8.self), terminator: ""); fflush(stdout)
        } catch { fputs("Evidence write failed: \(error)\n", stderr); failed = true }
    }
    func require(_ condition: @autoclosure () -> Bool, _ label: String) throws {
        guard condition() else { throw SpikeError.invalid(label) }
        log("assert-pass", ["check": label])
    }
    func save() -> Bool {
        do { try store.save(state); status.stringValue = "CoreData 已保存"; return true }
        catch { status.stringValue = "保存失败，旧数据未替换：\(error)"; log("save-failed", ["error": String(describing: error)]); failed = true; return false }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        testing = auto != nil
        log("launch", ["os": ProcessInfo.processInfo.operatingSystemVersionString, "dataDirectory": store.directory.path,
                       "auto": auto ?? "manual", "permissionRequests": "none", "globalMonitor": "not installed"])
        let appMenu = NSMenu()
        let rootItem = NSMenuItem(); appMenu.addItem(rootItem)
        let submenu = NSMenu(); rootItem.submenu = submenu
        submenu.addItem(withTitle: "退出原生实验", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = appMenu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "纸·实验"
        let menu = NSMenu()
        menu.addItem(withTitle: "新建/找回这一张", action: #selector(restore), keyEquivalent: "n").target = self
        menu.addItem(withTitle: "退出实验", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        buildWindows()
        loaded = true
        NSApp.activate(ignoringOtherApps: true)
        if state.visible { restore() }
        if auto != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.runAutomation() }
        }
    }
    func buildWindows() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        for (i, s) in NSScreen.screens.enumerated() {
            log("screen", ["index": i, "frame": NSStringFromRect(s.frame), "visibleFrame": NSStringFromRect(s.visibleFrame), "scale": s.backingScaleFactor])
        }
        demo = NSWindow(contentRect: NSRect(x: screen.visibleFrame.midX - 280, y: screen.visibleFrame.midY - 180, width: 560, height: 360), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        demo.title = "PaperDock 普通演示窗口（仅本任务）"; demo.isReleasedWhenClosed = false
        let help = NSTextField(wrappingLabelWithString: "这是本任务的普通窗口，level = normal。\n\n靠近右侧边缘中段2pt感应区会探出青色‘拖出＋’；离开收回，向左拖超过40pt。\n便签浮动窗口可以编辑中文、完成待办、关闭收纳。\n菜单栏‘纸·实验’→找回。\n\n本实验不注册全局键盘监听，不要求辅助功能/屏幕录制权限。\n退出请用 ⌘Q 或菜单栏。")
        help.frame = NSRect(x: 24, y: 30, width: 510, height: 290); demo.contentView!.addSubview(help)
        demo.makeKeyAndOrderFront(nil)
        let edgeRect = NSRect(x: screen.frame.maxX - 2, y: screen.visibleFrame.midY - 65, width: 2, height: 130)
        edge = EdgePanel(contentRect: edgeRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        edge.level = .floating; edge.isReleasedWhenClosed = false; edge.hidesOnDeactivate = false
        edge.isOpaque = false; edge.backgroundColor = .clear; edge.hasShadow = false
        edge.isFloatingPanel = true; edge.becomesKeyOnlyIfNeeded = true; edge.contentView = edgeView
        edgeView.owner = self; edgeView.collapsedFrame = edgeRect; edge.setFrame(edgeRect, display: true); edge.orderFrontRegardless()
        log("edge-window", ["frame": NSStringFromRect(edge.frame), "screenRight": screen.frame.maxX,
                            "strategy": "2pt own nonactivating hit strip; NSTrackingArea activeAlways; revealed width 24pt; no global monitor"])
        note = KeyWindow(contentRect: NSRect(x: state.x, y: state.y, width: state.width, height: state.height), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        note.level = .floating; note.hidesOnDeactivate = false; note.isReleasedWhenClosed = false
        note.contentMinSize = NSSize(width: 320, height: 340); note.delegate = self
        note.appearance = NSAppearance(named: .aqua)
        let content = note.contentView!
        content.wantsLayer = true
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16), stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 12), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12)])
        titleField.placeholderString = "手动标题（留空自动）"; titleField.delegate = self
        titleField.stringValue = state.manualTitle
        stack.addArrangedSubview(titleField)
        titleField.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        body.isRichText = false; body.isAutomaticQuoteSubstitutionEnabled = false
        body.font = .systemFont(ofSize: 17); body.string = state.body; body.delegate = self
        body.isVerticallyResizable = true; body.isHorizontallyResizable = false
        body.autoresizingMask = [.width]; body.textContainer?.widthTracksTextView = true
        scroll.documentView = body; stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        todo.placeholderString = "一条实验待办"; todo.stringValue = state.todo; todo.delegate = self
        stack.addArrangedSubview(todo); todo.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        done.target = self; done.action = #selector(toggleDone); done.state = state.done ? .on : .off
        stack.addArrangedSubview(done)
        color.color = nsColor(state.paper); color.supportsAlpha = false
        scope.addItems(withTitles: ["只改当前", "以后固定", "加入随机", "切回原随机池"])
        let apply = NSButton(title: "应用", target: self, action: #selector(applyColor))
        let palette = NSStackView(views: [color, scope, apply]); palette.spacing = 8
        stack.addArrangedSubview(palette)
        stack.addArrangedSubview(status)
        status.font = .systemFont(ofSize: 11)
        updateAppearance()
    }
    func nsColor(_ hex: String) -> NSColor {
        let value = UInt32(hex.dropFirst(), radix: 16)!
        return NSColor(srgbRed: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, alpha: 1)
    }
    func hexColor(_ color: NSColor) -> String? {
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        return String(format: "#%02X%02X%02X", Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
    }
    func updateAppearance() {
        let c = nsColor(state.paper)
        note.backgroundColor = c; body.backgroundColor = c
        note.contentView?.layer?.backgroundColor = c.cgColor
        let rgb = c.usingColorSpace(.sRGB)!
        body.textColor = (rgb.redComponent * 0.299 + rgb.greenComponent * 0.587 + rgb.blueComponent * 0.114) < 0.5 ? .white : .black
        note.title = state.title
    }
    func showNote(at point: NSPoint) {
        let s = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main!
        let f = s.visibleFrame
        note.setFrameOrigin(NSPoint(x: max(f.minX, min(point.x - note.frame.width, f.maxX - note.frame.width)), y: max(f.minY, min(point.y - note.frame.height / 2, f.maxY - note.frame.height))))
        restore()
    }
    @objc func restore() {
        if !state.created { state.paper = state.nextPaper(); state.created = true }
        state.visible = true; note.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        note.makeFirstResponder(body); updateAppearance(); recordGeometry(); _ = save()
        log("restore", ["visible": note.isVisible])
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === note else { return true }
        state.visible = false
        guard save() else { return false }
        note.orderOut(nil); log("store-note", ["visible": note.isVisible]); return false
    }
    func recordGeometry() {
        state.x = note.frame.origin.x; state.y = note.frame.origin.y
        // contentRect is used for construction; avoid accumulating title-bar height across launches.
        let size = note.contentRect(forFrameRect: note.frame).size
        state.width = size.width; state.height = size.height
    }
    func windowDidMove(_ notification: Notification) { geometryChanged() }
    func windowDidResize(_ notification: Notification) { geometryChanged() }
    func geometryChanged() { guard loaded else { return }; recordGeometry(); _ = save() }
    func textDidChange(_ notification: Notification) {
        state.body = body.string; state.modified = Date().timeIntervalSince1970; updateAppearance(); _ = save()
    }
    func controlTextDidChange(_ notification: Notification) {
        state.manualTitle = titleField.stringValue; state.todo = todo.stringValue
        state.modified = Date().timeIntervalSince1970; updateAppearance(); _ = save()
    }
    @objc func toggleDone() { state.done = done.state == .on; state.modified = Date().timeIntervalSince1970; _ = save() }
    @objc func applyColor() {
        guard let hex = hexColor(color.color) else { status.stringValue = "不支持的色彩空间，未应用"; return }
        switch scope.indexOfSelectedItem {
        case 0: state.paper = hex
        case 1: state.fixed = hex; state.mode = "fixed"
        case 2: if !state.pool.contains(hex) { state.pool.append(hex) }; state.mode = "random"
        default: state.mode = "random"
        }
        updateAppearance(); _ = save(); log("palette-applied", ["scope": scope.indexOfSelectedItem, "paper": state.paper, "mode": state.mode, "pool": state.pool])
    }
    func renderOwnView(_ name: String) throws {
        let view = note.contentView!
        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw SpikeError.invalid("Own-view bitmap unavailable") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw SpikeError.invalid("PNG unavailable") }
        try png.write(to: store.directory.appendingPathComponent(name))
        log("own-view-render", ["file": name, "categoryDetail": "NSView cacheDisplay, not screen capture or visual occlusion proof"])
    }
    func runAutomation() {
        do {
            switch auto {
            case "hover": try checkHover()
            case "seed": try seed()
            case "read-fixed": try readFixed()
            case "read-random": try readRandom()
            default: throw SpikeError.invalid("--auto must be hover, seed, read-fixed, or read-random")
            }
        } catch { failed = true; log("FAIL", ["error": String(describing: error)]) }
        NSApp.terminate(nil)
    }
    func edgeEvent(_ action: String, at screenPoint: NSPoint) {
        let point = edge.convertPoint(fromScreen: screenPoint)
        let type: NSEvent.EventType = action == "down" ? .leftMouseDown : action == "drag" ? .leftMouseDragged : action == "up" ? .leftMouseUp : .mouseMoved
        let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: edge.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        switch action {
        case "enter": edgeView.mouseEntered(with: event)
        case "exit": edgeView.mouseExited(with: event)
        case "down": edgeView.mouseDown(with: event)
        case "drag": edgeView.mouseDragged(with: event)
        default: edgeView.mouseUp(with: event)
        }
    }
    func checkHover() throws {
        let strip = edgeView.collapsedFrame
        let near = NSPoint(x: strip.maxX - 1, y: strip.midY)
        let insideLabel = NSPoint(x: strip.maxX - 12, y: strip.midY)
        let outside = NSPoint(x: strip.maxX - 100, y: strip.midY)
        let initialKey = NSApp.keyWindow
        let initialActive = NSApp.isActive
        let originalState = state
        try require(edgeView.phase == .hidden && edge.frame.width == 2 && edge.isVisible && edge.alphaValue == 1, "hidden edge retains only ordered 2pt hit strip, not alphaValue zero")
        edgeView.updateTrackingAreas()
        try require(edgeView.trackingAreas.count == 1 && edgeView.trackingAreas[0].options.contains(.activeAlways), "one activeAlways self-window tracking area")
        edgeEvent("enter", at: near)
        try require(edgeView.phase == .revealed && edge.frame.width == 24, "proximity reveals 24pt label")
        // A stale exit from the former 2pt area must not collapse the newly expanded label.
        edgeEvent("exit", at: insideLabel)
        try require(edgeView.phase == .revealed, "stale strip exit inside expanded label ignored")
        edgeEvent("exit", at: outside)
        try require(edgeView.phase == .hidden && edge.frame.width == 2, "leaving label retracts to 2pt without broad hidden interception")
        try require(NSApp.keyWindow === initialKey && NSApp.isActive == initialActive && !edge.canBecomeKey && !edge.canBecomeMain, "hover reveal/retract does not change own key/active state")
        edgeEvent("enter", at: near); edgeEvent("down", at: near)
        edgeEvent("exit", at: outside)
        try require(edgeView.phase == .dragging && edge.frame.width == 24, "tracking exit during held drag does not retract")
        edgeEvent("drag", at: NSPoint(x: near.x - 20, y: near.y))
        edgeEvent("up", at: outside)
        try require(edgeView.phase == .hidden && edgeView.triggerCount == 0 && state == originalState, "cancel below threshold retracts without changing note data")
        // Cancel a click without moving off the narrow strip, then leave and approach again.
        edgeEvent("enter", at: near); edgeEvent("down", at: near); edgeEvent("up", at: near)
        edgeEvent("enter", at: near)
        try require(edgeView.phase == .hidden, "cancel under pointer does not instantly re-open")
        edgeEvent("exit", at: outside); edgeEvent("enter", at: near)
        try require(edgeView.phase == .revealed, "can reveal again after cancelled click leaves")
        for i in 1...2 {
            if i == 2 { edgeEvent("enter", at: near) }
            edgeEvent("down", at: insideLabel); edgeEvent("exit", at: outside)
            edgeEvent("drag", at: outside); edgeEvent("drag", at: NSPoint(x: outside.x - 20, y: outside.y))
            try require(edgeView.phase == .triggered && edgeView.triggerCount == i, "one trigger per held drag \(i), duplicate drag ignored")
            edgeEvent("exit", at: outside)
            try require(edgeView.phase == .triggered, "triggered drag not interrupted by exit")
            edgeEvent("up", at: outside)
            try require(edgeView.phase == .hidden && edge.frame.width == 2, "completed drag \(i) retracts and rearms")
        }
        try require(note.isVisible && !edge.isKeyWindow, "completed drag shows note, never keys edge panel")
        log("PASS-hover", ["triggerCount": edgeView.triggerCount, "hiddenFrame": NSStringFromRect(edge.frame),
                           "evidence": "direct self-view callbacks, not human hover or OS-delivered mouse events"])
    }
    func seed() throws {
        try require(state.body.isEmpty && state.todo.isEmpty, "seed uses fresh isolated state")
        try require(statusItem.button != nil && edge.isVisible && demo.isVisible, "status item and real edge/demo windows visible")
        try require(abs(edge.frame.maxX - (NSScreen.main?.frame.maxX ?? -1)) < 1, "edge uses NSScreen real right coordinate")
        // New hover entry plus the existing note/persistence regression, only self-view callbacks.
        try checkHover()
        // Activation crosses the window server asynchronously; service the real run loop, bounded.
        let deadline = Date().addingTimeInterval(2)
        while (!NSApp.isActive || !note.isKeyWindow) && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        log("focus-observed", ["active": NSApp.isActive, "visible": note.isVisible, "key": note.isKeyWindow,
                               "firstResponderIsBody": note.firstResponder === body])
        try require(note.isVisible && note.isKeyWindow && note.firstResponder === body, "edge callback made key editable window after bounded activation wait")
        try require(state.created && builtInPapers.contains(state.paper), "first creation uses built-in random paper pool")
        demo.orderFrontRegardless()
        let order = NSApp.orderedWindows
        try require(note.level.rawValue > demo.level.rawValue && order.firstIndex(of: note)! < order.firstIndex(of: demo)!, "floating note above own normal demo window in AppKit order")
        log("window-order", ["noteNumber": note.windowNumber, "demoNumber": demo.windowNumber, "noteLevel": note.level.rawValue, "demoLevel": demo.level.rawValue, "orderedWindowNumbers": order.map(\.windowNumber)])
        body.insertText("明天联系客户确认报价🇨🇳👩🏽‍💻", replacementRange: NSRange(location: 0, length: body.string.utf16.count))
        try require(state.body == body.string && state.title == "明天联系客", "NSTextView insertText Chinese string and delegate autosave (not IME)")
        titleField.stringValue = "实验便签"; todo.stringValue = "核对报价"
        controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: titleField))
        done.performClick(nil)
        try require(state.done && state.todo == "核对报价", "checkbox target/action completed todo persisted")
        let modified = state.modified
        note.setFrameOrigin(NSPoint(x: note.frame.minX - 12, y: note.frame.minY + 10))
        note.setContentSize(NSSize(width: 400, height: 440)); recordGeometry()
        try require(abs(state.width - 400) < 1 && abs(state.height - 440) < 1, "window move/resize recorded in content coordinates")
        note.performClose(nil)
        try require(!note.isVisible && !state.visible, "close stores rather than destroys")
        restore()
        try require(note.isVisible && state.body == body.string, "restore keeps editable content")
        color.color = nsColor("#DDE8D5"); scope.selectItem(at: 0); applyColor()
        let notePaper = state.paper
        color.color = nsColor("#ABCDEF"); scope.selectItem(at: 2); applyColor(); applyColor()
        try require(state.pool.filter { $0 == "#ABCDEF" }.count == 1 && state.mode == "random", "custom paper deduplicated and switches random")
        scope.selectItem(at: 1); applyColor()
        try require(state.mode == "fixed" && state.nextPaper() == "#ABCDEF" && state.paper == notePaper, "fixed config affects future selection not existing paper")
        try require(state.modified == modified, "geometry/store/restore/color do not modify content timestamp")
        try require(save(), "final CoreData transaction saved")
        try renderOwnView("note-programmatic.png")
        try JSONEncoder().encode(state).write(to: store.directory.appendingPathComponent("expected.json"), options: .withoutOverwriting)
        log("PASS-seed", ["title": state.title, "body": state.body, "todo": state.todo, "done": state.done, "paper": state.paper, "mode": state.mode])
    }
    func expected() throws -> NoteState { try JSONDecoder().decode(NoteState.self, from: Data(contentsOf: store.directory.appendingPathComponent("expected.json"))) }
    func readFixed() throws {
        // Window creation may normalize geometry; compare the persistent payload before startup restore.
        let expected = try expected()
        try require(state.body == expected.body && state.manualTitle == expected.manualTitle && state.todo == expected.todo && state.done == expected.done && state.paper == expected.paper && state.mode == "fixed" && state.fixed == "#ABCDEF" && state.pool == expected.pool && state.modified == expected.modified, "new process read back title/body/todo/paper/fixed/pool/content time")
        try require(note.isVisible && body.string == expected.body, "new process renders restored editable window")
        scope.selectItem(at: 3); applyColor()
        try require(state.mode == "random" && state.pool.contains("#ABCDEF"), "switch back random retains custom pool")
        try renderOwnView("restart-programmatic.png")
        done.performClick(nil)
        try require(!state.done && state.todo == expected.todo, "completed todo can become incomplete via target/action")
        note.performClose(nil)
        try require(!state.visible && !note.isVisible, "quit next with note stored and incomplete todo")
        log("PASS-read-fixed")
    }
    func readRandom() throws {
        let expected = try expected()
        try require(state.mode == "random" && state.pool == expected.pool && state.title == "实验便签", "third process read back random mode and deduplicated custom pool")
        try require(!state.visible && !note.isVisible, "stored note does not reappear after process restart")
        try require(!state.done && state.todo == expected.todo && state.body == expected.body && state.paper == expected.paper, "new process read back incomplete todo/body/paper")
        try require(state.pool.contains(state.nextPaper()), "random future paper drawn from persisted pool")
        restore()
        try require(note.isVisible && body.string == expected.body, "stored note can be explicitly restored after restart")
        note.performClose(nil)
        log("PASS-read-random")
    }
    func applicationWillTerminate(_ notification: Notification) {
        // NSApplication.terminate exits internally; code after app.run is not its error channel.
        fflush(stdout); fflush(stderr)
        exit(failed ? 1 : 0)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if loaded { recordGeometry(); if !save() && auto == nil { return .terminateCancel } }
        edge?.orderOut(nil); note?.orderOut(nil); demo?.orderOut(nil)
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        log("exit", ["failed": failed, "ownWindowsClosed": true])
        return .terminateNow
    }
}

do {
    let store = try SpikeStore(directory: dataURL)
    let delegate = try SpikeApp(store: store)
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
    exit(delegate.failed ? 1 : 0)
} catch { fputs("FAIL startup (old values not replaced): \(error)\n", stderr); exit(1) }
