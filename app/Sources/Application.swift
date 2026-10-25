import AppKit
import SwiftUI

@MainActor final class ApplicationController: NSObject, NSApplicationDelegate {
    let model: AppModel
    let windows: NoteWindows
    var edge: EdgeWindow?
    var manager: NSWindow!
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    let quitAfter: Double?
    let evidenceDirectory: URL?
    let guiTest: Bool
    private(set) var testFailure: String?
    private var guiProbeCompleted = false
    var activePalette: NSWindow?
    init(store: Store, quitAfter: Double?, evidenceDirectory: URL?, guiTest: Bool) {
        model = AppModel(store: store); windows = NoteWindows(model: model)
        self.quitAfter = quitAfter; self.evidenceDirectory = evidenceDirectory; self.guiTest = guiTest
        super.init()
        model.showFloating = { [weak self] in self?.windows.show($0) }
        model.hideFloating = { [weak self] in self?.windows.hide($0) }
        model.showManager = { [weak self] in self?.openManager() }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Bundle.main.url(forResource: "PaperDock", withExtension: "icns"), let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        manager = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1060, height: 700), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        manager.title = "PaperDock · 全部便签"; manager.minSize = NSSize(width: 880, height: 580); manager.isReleasedWhenClosed = false
        manager.contentView = NSHostingView(rootView: ManagerView(model: model)); manager.center()
        installMenus()
        edge = EdgeWindow { [weak self] point in
            guard let self else { return }
            let id = self.model.newNote(); self.windows.show(id, point: point)
        }
        for n in model.store.notes where n.visible && !n.deleted { windows.show(n.id) }
        openManager()
        if let dir = evidenceDirectory {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try writeObservation(dir.appendingPathComponent("launch.json"))
            } catch { report(error) }
        }
        if guiTest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.runGUIProbe() }
        } else if let dir = evidenceDirectory {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                do { try self.capture(self.manager, to: dir.appendingPathComponent("manager-content.png")); try self.writeObservation(dir.appendingPathComponent("observed.json")) }
                catch { self.report(error) }
            }
        }
        if let quitAfter { DispatchQueue.main.asyncAfter(deadline: .now() + quitAfter) { NSApp.terminate(nil) } }
    }
    func installMenus() {
        let bar = NSMenu()
        let appRoot = NSMenuItem(); bar.addItem(appRoot)
        let app = NSMenu(); appRoot.submenu = app
        app.addItem(menuItem("关于 PaperDock", #selector(about), "")); app.addItem(.separator())
        app.addItem(menuItem("设置与默认纸色…", #selector(openSettings), ",")); app.addItem(.separator())
        app.addItem(menuItem("退出 PaperDock", #selector(quit), "q"))
        let fileRoot = NSMenuItem(); fileRoot.title = "文件"; bar.addItem(fileRoot)
        let file = NSMenu(title: "文件"); fileRoot.submenu = file
        file.addItem(menuItem("新建便签", #selector(newNote), "n")); file.addItem(menuItem("管理全部便签", #selector(openManager), "0"))
        let editRoot = NSMenuItem(); editRoot.title = "编辑"; bar.addItem(editRoot)
        let edit = NSMenu(title: "编辑"); editRoot.submenu = edit
        for (title, action, key) in [("撤销", Selector(("undo:")), "z"), ("剪切", #selector(NSText.cut(_:)), "x"), ("复制", #selector(NSText.copy(_:)), "c"), ("粘贴", #selector(NSText.paste(_:)), "v"), ("全选", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(NSMenuItem(title: title, action: action, keyEquivalent: key))
        }
        NSApp.mainMenu = bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "▱"
        statusItem?.button?.toolTip = "PaperDock"
        let status = NSMenu()
        status.addItem(menuItem("新建便签", #selector(newNote), "")); status.addItem(menuItem("管理全部便签", #selector(openManager), ""))
        status.addItem(menuItem("设置与默认纸色…", #selector(openSettings), "")); status.addItem(.separator()); status.addItem(menuItem("退出 PaperDock", #selector(quit), ""))
        statusItem?.menu = status
    }
    func menuItem(_ title: String, _ selector: Selector, _ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key); item.target = self; return item
    }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "PaperDock", .applicationVersion: "0.1.1-local", .credits: NSAttributedString(string: "本机单屏普通窗口开发版 · 无云同步")]) }
    @objc func newNote() { model.newNote() }
    @objc func openManager() { manager.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 590, height: 340), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "PaperDock · 设置"; w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(model: model, closeWindow: { [weak w] in w?.orderOut(nil) })); w.center(); settingsWindow = w
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Ending the field editor commits valid title/todo edits; unconfirmed IME text is not fabricated.
        for w in NSApp.windows { w.endEditing(for: nil) }
        if model.canTerminate() {
            // NSApplication.terminate exits with 0 without returning from run(). Stop only after saving,
            // then let main finalize evidence and own the real process exit status.
            sender.stop(nil)
            if let wake = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0) {
                sender.postEvent(wake, atStart: true)
            }
            return .terminateCancel
        }
        let alert = NSAlert(); alert.messageText = "尚未保存，PaperDock 未退出"; alert.informativeText = model.store.error ?? "请重试保存后再退出。内存中的编辑仍保留。"; alert.addButton(withTitle: "返回编辑")
        alert.runModal(); return .terminateCancel
    }
    func finishTermination() -> Int32 {
        if guiTest && !guiProbeCompleted { report(TestFailure(description: "GUI probe did not complete")) }
        if let dir = evidenceDirectory {
            do {
                try writeObservation(dir.appendingPathComponent("exit.json"))
                try Data("normal termination\n".utf8).write(to: dir.appendingPathComponent("normal-exit.txt"))
            } catch { report(error) }
            if guiTest {
                do {
                    let result = GUIResult(pid: ProcessInfo.processInfo.processIdentifier, status: testFailure == nil ? "passed" : "failed", completed: guiProbeCompleted, failure: testFailure)
                    try JSONEncoder().encode(result).write(to: dir.appendingPathComponent("gui-result.json"), options: .atomic)
                } catch { report(error) }
            }
        }
        return testFailure == nil ? 0 : 1
    }
    func report(_ error: Error) {
        if testFailure == nil { testFailure = String(describing: error) }
        fputs("FAIL \(error)\n", stderr)
    }
    func capture(_ window: NSWindow, to url: URL) throws {
        guard let view = window.contentView else { throw TestFailure(description: "No content view") }
        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw TestFailure(description: "No bitmap") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw TestFailure(description: "No PNG") }
        try png.write(to: url)
    }
    func writeObservation(_ url: URL) throws {
        let snapshot = Observation(pid: ProcessInfo.processInfo.processIdentifier, version: "0.1.1-local", directory: model.store.directory.path, notes: model.store.notes, settings: model.store.settings, selected: model.selected, filter: model.filter.rawValue, query: model.query, dirty: model.store.dirty, error: model.store.error, windows: windows.panels.map { id, w in WindowObservation(id: id, visible: w.isVisible, key: w.isKeyWindow, level: w.level.rawValue, x: w.frame.origin.x, y: w.frame.origin.y, width: w.frame.width, height: w.frame.height) }, screen: NSScreen.main.map { "\($0.frame) visible=\($0.visibleFrame) scale=\($0.backingScaleFactor)" } ?? "none")
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; e.dateEncodingStrategy = .iso8601
        try e.encode(snapshot).write(to: url)
    }
    func runGUIProbe() {
        do {
            guard let dir = evidenceDirectory else { throw TestFailure(description: "GUI test requires --evidence-dir") }
            try capture(manager, to: dir.appendingPathComponent("00-first-state-content.png"))
            let file = NSApp.mainMenu!.items[1].submenu!
            let count = model.store.notes.count
            file.performActionForItem(at: 0)
            guard let id = model.selected else { throw TestFailure(description: "menu new did not select") }
            try expect(model.store.notes.count == count + 1, "real menu creates one")
            model.store.edit(id) { $0.body = "明天联系客户确认报价\n上海 → 德班，核对 40HQ 价格后再回复。"; $0.todos = [Todo(text: "完成核对", done: true), Todo(text: "退出后复核")] }
            try expect(windows.panels[id]?.isVisible == true, "real menu floating window")
            windows.show(id); try expect(windows.panels[id] != nil, "window unique")
            model.store.arrange(id) { $0.color = "#303731" }
            model.query = "40HQ"; model.select(id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.captureGUIStage(id, dir: dir) }
        } catch { report(error); NSApp.terminate(nil) }
    }
    func captureGUIStage(_ id: UUID, dir: URL) {
        do {
            try capture(manager, to: dir.appendingPathComponent("01-three-column-content.png"))
            if let window = windows.panels[id] { try capture(window, to: dir.appendingPathComponent("02-floating-content.png")) }
            model.store.edit(id) { $0.body = "继续记录甲" }
            try expect(model.editingOutsideResults && model.selected == id, "stable editor selection")
            model.store.edit(id) { $0.body += "继续记录乙" }
            let draft = PaletteDraft(store: model.store, noteID: id)
            draft.hex = "#2468AC"; draft.syncHSV()
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 610, height: 650), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false; w.title = "PaperDock · 配色证据"; w.contentView = NSHostingView(rootView: PaletteView(draft: draft) { w.orderOut(nil) }); w.center(); w.makeKeyAndOrderFront(nil); activePalette = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                do {
                    try self.capture(self.manager, to: dir.appendingPathComponent("03-pinned-editor-content.png"))
                    try self.capture(w, to: dir.appendingPathComponent("04-palette-content.png"))
                    draft.hex = "#12ZZZZ"
                    self.manager.setContentSize(NSSize(width: 880, height: 600))
                    self.model.store.arrange(id) { $0.color = "#FFFEFA" }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        do {
                            try self.capture(w, to: dir.appendingPathComponent("05-invalid-palette-content.png"))
                            try self.capture(self.manager, to: dir.appendingPathComponent("06-narrow-light-content.png"))
                            w.orderOut(nil); self.windows.panels[id]?.performClose(nil)
                            try expect(self.model.store.note(id)?.visible == false, "real close stashes")
                            self.model.changeFilter(.trash); self.model.query = ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                do {
                                    try self.capture(self.manager, to: dir.appendingPathComponent("07-empty-trash-content.png"))
                                    try self.writeObservation(dir.appendingPathComponent("gui-final.json"))
                                    self.guiProbeCompleted = true
                                    print("GUI probe completed formal menu/window/SwiftUI content-view checks (not human interaction); final result follows saved termination")
                                } catch { self.report(error) }
                                NSApp.terminate(nil)
                            }
                        } catch { self.report(error); NSApp.terminate(nil) }
                    }
                } catch { self.report(error); NSApp.terminate(nil) }
            }
        } catch { report(error); NSApp.terminate(nil) }
    }
}
struct GUIResult: Codable { let pid: Int32; let status: String; let completed: Bool; let failure: String? }
struct WindowObservation: Codable { let id: UUID; let visible: Bool; let key: Bool; let level: Int; let x: Double; let y: Double; let width: Double; let height: Double }
struct Observation: Codable {
    let pid: Int32; let version: String; let directory: String; let notes: [Note]; let settings: ColorSettings; let selected: UUID?; let filter: String; let query: String; let dirty: Bool; let error: String?; let windows: [WindowObservation]; let screen: String
}
