import SwiftUI
import Combine
import AppKit

@MainActor final class AppModel: ObservableObject {
    let store: Store
    @Published var selected: UUID?
    @Published var filter: NoteFilter = .all
    @Published var query = ""
    @Published var pendingDelete: UUID?
    @Published var heightDraft: String
    @Published var heightFeedback: String?
    @Published var heightSaveFailed = false
    var showFloating: ((UUID) -> Void)?
    var hideFloating: ((UUID) -> Void)?
    var showManager: (() -> Void)?
    var floatingFrame: ((UUID) -> NSRect?)?
    var lockChanged: ((UUID) -> Void)?
    var prepareCollapse: ((UUID) -> Bool)?
    var prepareLayerChange: ((UUID) -> Bool)?
    var prepareTodoAddition: ((UUID) -> Bool)?
    private var observation: AnyCancellable?
    init(store: Store) {
        self.store = store
        heightDraft = String(store.defaultHeight)
        observation = store.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }
    var results: [Note] { store.results(filter, query) }
    var editingOutsideResults: Bool { selected != nil && !results.contains { $0.id == selected } }
    @discardableResult func newNote() -> UUID {
        let id = store.create(); filter = .all; query = ""; selected = id; showFloating?(id); return id
    }
    func select(_ id: UUID) { selected = id }
    func changeFilter(_ value: NoteFilter) { filter = value; selected = nil }
    func show(_ id: UUID) {
        guard let n = store.note(id), !n.deleted else { return }
        store.arrange(id) { $0.visible = true }; showFloating?(id)
    }
    @discardableResult func toggleLock(_ id: UUID) -> Bool {
        let locked = !store.isLocked(id)
        if locked, let window = NSApp?.keyWindow, let editor = window.firstResponder as? NSTextView, !editor.hasMarkedText() {
            window.endEditing(for: nil)
        }
        guard store.setLocked(id, locked, frame: floatingFrame?(id)) else { return false }
        lockChanged?(id); return true
    }
    @discardableResult func toggleCollapsed(_ id: UUID) -> Bool {
        guard !store.isLocked(id), store.note(id)?.deleted == false else { return false }
        if !store.isCollapsed(id), prepareCollapse?(id) == false { return false }
        guard store.setCollapsed(id, !store.isCollapsed(id), frame: floatingFrame?(id)) else { return false }
        lockChanged?(id); return true
    }
    @discardableResult func saveHeight() -> Bool {
        guard let value = Double(heightDraft.trimmingCharacters(in: .whitespacesAndNewlines)), NoteHeight.valid(value) else {
            heightSaveFailed = true; heightFeedback = "请输入175…1000pt的有限数字（可含小数）"; return false
        }
        guard store.setDefaultHeight(value) else {
            heightSaveFailed = true; heightFeedback = store.error; return false
        }
        heightDraft = String(value); heightSaveFailed = false
        heightFeedback = "已保存；下次打开或展开生效，当前窗口不变"; return true
    }
    @discardableResult func toggleLayer(_ id: UUID) -> Bool {
        setLayer(id, store.layer(id) == .floating ? .desktop : .floating)
    }
    @discardableResult func setLayer(_ id: UUID, _ layer: NoteLayer) -> Bool {
        guard !store.isLocked(id), let n = store.note(id), !n.deleted, n.visible else { return false }
        if store.layer(id) == layer { return true }
        if prepareLayerChange?(id) == false { return false }
        guard store.setLayer(id, layer, frame: floatingFrame?(id)) else { return false }
        lockChanged?(id); return true
    }
    func stash(_ id: UUID) {
        guard !store.isLocked(id) else { return }
        store.arrange(id) { $0.visible = false }; hideFloating?(id)
    }
    var deletionTarget: Note? { pendingDelete.flatMap { store.note($0) } }
    func requestDelete(_ id: UUID) {
        guard !store.isLocked(id), store.note(id)?.deleted == false else { return }
        pendingDelete = id
    }
    func confirmDelete(_ confirmed: Bool) {
        defer { pendingDelete = nil }
        guard confirmed, let id = pendingDelete, !store.isLocked(id), store.note(id)?.deleted == false else { return }
        store.arrange(id) { $0.deleted = true; $0.visible = false }
        hideFloating?(id); if selected == id { selected = nil }
    }
    func restore(_ id: UUID) { store.arrange(id) { $0.deleted = false; $0.visible = false } }
    func canTerminate() -> Bool { store.save() }
}

enum PaletteScope: String, CaseIterable { case current = "只改当前便签", fixed = "以后固定使用此颜色", random = "加入随机配色 / 切回随机" }
@MainActor final class PaletteDraft: ObservableObject, Identifiable {
    let id = UUID()
    @Published var hex: String
    @Published var hue: Double = 0
    @Published var saturation: Double = 0
    @Published var brightness: Double = 1
    @Published var scope: PaletteScope = .current
    @Published var addToPool = true
    @Published var saved: [String]
    let store: Store
    let noteID: UUID?
    init(store: Store, noteID: UUID?) {
        self.store = store; self.noteID = noteID
        hex = store.note(noteID ?? UUID())?.color ?? store.settings.fixedColor; saved = store.settings.saved
        if noteID == nil { scope = store.settings.fixed ? .fixed : .random; addToPool = false }
        syncHSV()
    }
    var valid: Bool { hex.isEmpty || ColorValue.normalize(hex) != nil }
    var preview: String { ColorValue.normalize(hex) ?? hsvHex }
    var hsvHex: String {
        let c = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1).usingColorSpace(.sRGB)!
        return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
    func syncHSV() {
        guard let h = ColorValue.normalize(hex) else { return }
        let c = ColorValue.ns(h).usingColorSpace(.sRGB)!
        hue = c.hueComponent; saturation = c.saturationComponent; brightness = c.brightnessComponent
    }
    func pick(h: Double? = nil, s: Double? = nil, b: Double? = nil) {
        if let h { hue = min(1, max(0, h)) }; if let s { saturation = min(1, max(0, s)) }; if let b { brightness = min(1, max(0, b)) }
        hex = hsvHex
    }
    func stage() { guard valid else { return }; if !saved.contains(preview) { saved.append(preview) } }
    @discardableResult func apply() -> Bool {
        guard valid, noteID.map({ !store.isLocked($0) && store.note($0)?.deleted == false }) ?? true else { return false }
        let color = preview
        var settings = store.settings; settings.saved = Array(Set(saved)).sorted()
        switch scope {
        case .current:
            guard let id = noteID, store.note(id)?.deleted == false else { return false }
            break
        case .fixed: settings.fixed = true; settings.fixedColor = color
        case .random:
            settings.fixed = false
            if addToPool && !settings.pool.contains(color) { settings.added.append(color) }
        }
        return store.applyPalette(settings, noteID: scope == .current ? noteID : nil, color: color, sourceNoteID: noteID)
    }
}
