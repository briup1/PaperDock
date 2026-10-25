import AppKit
import SwiftUI
import Combine

@MainActor final class EdgeGesture {
    var expanded = false
    var dragging = false
    var origin = NSPoint.zero
    func enter() { expanded = true }
    func leave() { if !dragging { expanded = false } }
    func begin(_ point: NSPoint) { dragging = true; origin = point }
    func finish(_ point: NSPoint) -> Bool {
        let create = dragging && origin.x - point.x >= 40
        dragging = false; expanded = false; return create
    }
}
final class NotePanel: NSPanel {
    var movementFinished: (() -> Void)?
    var savedFrame: NSRect?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
@MainActor final class NoteWindows: NSObject, NSWindowDelegate {
    let model: AppModel
    private(set) var panels: [UUID: NSPanel] = [:]
    private var observation: AnyCancellable?
    init(model: AppModel) {
        self.model = model
        super.init()
        model.floatingFrame = { [weak self] in self?.panels[$0]?.frame }
        model.lockChanged = { [weak self] in self?.synchronizeLock($0) }
        model.prepareCollapse = { [weak self] id in
            guard let self, let panel = self.panels[id] else { return true }
            if let editor = panel.firstResponder as? NSTextView, editor.hasMarkedText() {
                self.model.store.error = "请先确认或取消输入法候选，再折叠便签"
                return false
            }
            panel.endEditing(for: nil)
            return true
        }
        observation = model.store.$placements.sink { [weak self] _ in
            // Published emits before assignment; apply the authoritative state on the next turn.
            DispatchQueue.main.async { [weak self] in self?.panels.keys.forEach { self?.synchronizeLock($0) } }
        }
    }
    func synchronizeLock(_ id: UUID) {
        guard let panel = panels[id] else { return }
        let locked = model.store.isLocked(id)
        let collapsed = model.store.isCollapsed(id)
        panel.minSize = NSSize(width: 270, height: collapsed ? NotePlacement.collapsedHeight : 350)
        panel.isMovable = !locked; panel.isMovableByWindowBackground = false
        if locked || collapsed { panel.styleMask.remove(.resizable) } else { panel.styleMask.insert(.resizable) }
        if let placement = model.store.placements[id], panel.frame != placement.displayedFrame {
            panel.setFrame(placement.displayedFrame, display: true)
        }
        (panel as? NotePanel)?.savedFrame = panel.frame
        panel.standardWindowButton(.closeButton)?.isEnabled = !locked
        panel.standardWindowButton(.miniaturizeButton)?.isEnabled = !locked
        panel.standardWindowButton(.zoomButton)?.isEnabled = !locked
    }
    func show(_ id: UUID, point: NSPoint? = nil, orderFront: Bool = true) {
        guard let n = model.store.note(id), !n.deleted else { return }
        let panel: NSPanel
        if let existing = panels[id] { panel = existing }
        else {
            let style: NSWindow.StyleMask = [.borderless, .resizable, .nonactivatingPanel]
            let content = NSWindow.contentRect(forFrameRect: NSRect(x: 0, y: 0, width: 270, height: 355), styleMask: style)
            panel = NotePanel(contentRect: content, styleMask: style, backing: .buffered, defer: false)
            panel.title = "PaperDock · 便签"; panel.titleVisibility = .hidden
            panel.level = .floating; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.minSize = NSSize(width: 270, height: 350); panel.delegate = self
            panel.contentView = NSHostingView(rootView: NoteEditor(model: model, id: id, compact: true))
            if let placement = model.store.placements[id] {
                panel.minSize = NSSize(width: 270, height: placement.collapsed ? NotePlacement.collapsedHeight : 350)
                panel.setFrame(placement.displayedFrame, display: false)
            } else { panel.center() }
            (panel as? NotePanel)?.movementFinished = { [weak self] in self?.saveFrame(id) }
            panels[id] = panel
        }
        synchronizeLock(id)
        if !model.store.isLocked(id), let p = point, let frame = NSScreen.main?.visibleFrame {
            let x = min(frame.maxX - panel.frame.width, max(frame.minX, p.x - panel.frame.width / 2))
            let y = min(frame.maxY - panel.frame.height, max(frame.minY, p.y - panel.frame.height / 2))
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            saveFrame(id)
        }
        model.store.arrange(id) { $0.visible = true }
        // Ordering is deliberately separate from key focus: clicking the editor grants input.
        if orderFront { panel.orderFrontRegardless() }
    }
    private func saveFrame(_ id: UUID) {
        guard let panel = panels[id] as? NotePanel, !model.store.isLocked(id) else { return }
        if model.store.updateFrame(id, panel.frame) { panel.savedFrame = panel.frame }
        else if let old = panel.savedFrame { panel.setFrame(old, display: true) }
    }
    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let id = panels.first(where: { $0.value === window })?.key else { return }
        saveFrame(id)
    }
    func hide(_ id: UUID) { panels[id]?.orderOut(nil) }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let id = panels.first(where: { $0.value === sender })?.key {
            guard !model.store.isLocked(id) else { return false }
            model.stash(id)
        }
        return false
    }
}
@MainActor final class EdgeView: NSView {
    let gesture = EdgeGesture()
    var changed: (() -> Void)?
    var created: ((NSPoint) -> Void)?
    private var tracking: NSTrackingArea?
    override var isFlipped: Bool { true }
    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        tracking = area; addTrackingArea(area); super.updateTrackingAreas()
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.38, green: 0.45, blue: 0.37, alpha: gesture.expanded ? 0.95 : 0.55).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: gesture.expanded ? 6 : 0, yRadius: 6).fill()
        if gesture.expanded {
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15, weight: .medium), .foregroundColor: NSColor.white]
            ("＋\n拖\n出" as NSString).draw(in: NSRect(x: 4, y: 30, width: 20, height: 80), withAttributes: attrs)
        }
    }
    override func mouseEntered(with event: NSEvent) { gesture.enter(); changed?() }
    override func mouseExited(with event: NSEvent) { gesture.leave(); changed?() }
    override func mouseDown(with event: NSEvent) {
        gesture.begin(NSEvent.mouseLocation)
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp], until: .distantFuture, inMode: .eventTracking, dequeue: true) {
            if next.type == .leftMouseUp {
                let point = NSEvent.mouseLocation
                let valid = gesture.finish(point); changed?()
                if valid && NSScreen.main?.frame.contains(point) == true { created?(point) }
                return
            }
        }
        _ = gesture.finish(gesture.origin); changed?()
    }
}
@MainActor final class EdgeWindow {
    let panel: NSPanel
    let view = EdgeView()
    init(create: @escaping (NSPoint) -> Void) {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.contentView = view; view.created = create
        view.changed = { [weak self] in self?.layout() }
        layout(); panel.orderFrontRegardless()
    }
    func layout() {
        guard let screen = NSScreen.main else { return }
        let width: CGFloat = view.gesture.expanded ? 24 : 2
        panel.setFrame(NSRect(x: screen.frame.maxX - width, y: screen.visibleFrame.midY - 65, width: width, height: 130), display: true)
        view.needsDisplay = true
    }
}
