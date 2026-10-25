import AppKit
import CoreData
import SwiftUI
import Darwin

struct Todo: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var done = false
}
struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var manualTitle = ""
    var body = ""
    var todos: [Todo] = []
    var modified = Date()
    var visible = true
    var deleted = false
    var color = "#FFFEFA"
    var title: String {
        if !manualTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return manualTitle }
        let content = ([body] + todos.map(\.text)).joined(separator: "\n")
        let unmarked = content.components(separatedBy: .newlines).map {
            $0.replacingOccurrences(of: #"^\s*(?:[-*•]\s*(?:\[[ xX]\]\s*)?|\d+[.)]\s*)"#, with: "", options: .regularExpression)
        }.joined().filter { !$0.isWhitespace }
        return unmarked.isEmpty ? "空白便签" : String(unmarked.prefix(5))
    }
    var summary: String { ([body] + todos.map(\.text)).joined(separator: " ") }
}
enum NoteFilter: String, CaseIterable { case all = "全部便签", visible = "桌面可见", stored = "已收纳", trash = "回收站" }
struct ColorSettings: Codable, Equatable {
    static let builtins = ["#FFFEFA", "#F5EEDC", "#E9DDC6", "#EDF0ED", "#E5EEDC", "#303731"]
    var fixed = false
    var fixedColor = "#FFFEFA"
    var added: [String] = []
    var saved: [String] = []
    var pool: [String] { Array(Set(Self.builtins + added)).sorted() }
}

struct NotePlacement: Codable, Equatable {
    static let collapsedHeight: CGFloat = 27
    var locked: Bool
    var collapsed: Bool
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    init(locked: Bool, frame: NSRect, collapsed: Bool = false) {
        self.locked = locked; self.collapsed = collapsed; x = frame.origin.x; y = frame.origin.y
        width = frame.width; height = frame.height
    }
    private enum CodingKeys: String, CodingKey { case locked, collapsed, x, y, width, height }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        locked = try c.decode(Bool.self, forKey: .locked)
        // Only a missing field is legacy data; null or the wrong type must still fail.
        collapsed = c.contains(.collapsed) ? try c.decode(Bool.self, forKey: .collapsed) : false
        x = try c.decode(Double.self, forKey: .x); y = try c.decode(Double.self, forKey: .y)
        width = try c.decode(Double.self, forKey: .width); height = try c.decode(Double.self, forKey: .height)
    }
    var valid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && abs(x) <= 100_000 && abs(y) <= 100_000
            && width >= 270 && height >= 350 && width <= 100_000 && height <= 100_000
    }
    // Stored frame always describes the expanded size anchored below the current top edge.
    var frame: NSRect { NSRect(x: x, y: y, width: width, height: height) }
    var displayedFrame: NSRect {
        collapsed ? NSRect(x: x, y: y + height - Self.collapsedHeight, width: width, height: Self.collapsedHeight) : frame
    }
    func moved(to displayed: NSRect) -> NotePlacement {
        let expanded = collapsed ? NSRect(x: displayed.minX, y: displayed.maxY - height, width: displayed.width, height: height) : displayed
        return NotePlacement(locked: locked, frame: expanded, collapsed: collapsed)
    }
}
private struct NoteLayout: Codable { var version = 1; var notes: [String: NotePlacement] = [:] }

@MainActor final class Store: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published private(set) var settings = ColorSettings()
    @Published var error: String?
    @Published private(set) var dirty = false
    let directory: URL
    var clock: () -> Date = Date.init
    // A real save boundary fault seam: UI and tests use this same save operation.
    var beforeSave: (() throws -> Void)?
    var beforeLayoutSave: (() throws -> Void)?
    @Published private(set) var placements: [UUID: NotePlacement] = [:]
    private var layoutURL: URL { directory.appendingPathComponent("NoteLayout.json") }
    private let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    private var lockFD: Int32 = -1

    init(directory: URL) throws {
        guard directory.path.hasPrefix("/") else { throw TestFailure(description: "数据目录必须为绝对路径") }
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fd = Darwin.open(directory.appendingPathComponent(".paperdock.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw TestFailure(description: "无法锁定数据目录") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { Darwin.close(fd); throw TestFailure(description: "此数据目录已由另一 PaperDock 进程使用") }
        lockFD = fd
        do {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: Self.model())
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: directory.appendingPathComponent("PaperDock.sqlite"), options: [NSMigratePersistentStoresAutomaticallyOption: false])
            context.persistentStoreCoordinator = coordinator
            try load()
            try loadLayout()
        } catch { Darwin.close(fd); lockFD = -1; throw error }
    }
    deinit { if lockFD >= 0 { Darwin.close(lockFD) } }
    private static func model() -> NSManagedObjectModel {
        func entity(_ name: String, _ attributes: [(String, NSAttributeType)]) -> NSEntityDescription {
            let e = NSEntityDescription(); e.name = name; e.managedObjectClassName = "NSManagedObject"
            e.properties = attributes.map { name, type in
                let a = NSAttributeDescription(); a.name = name; a.attributeType = type; a.isOptional = false; return a
            }
            return e
        }
        let m = NSManagedObjectModel(); m.versionIdentifiers = ["PaperDock.1"]
        let note = entity("Note", [("id", .UUIDAttributeType), ("manualTitle", .stringAttributeType), ("body", .stringAttributeType), ("modified", .dateAttributeType), ("visible", .booleanAttributeType), ("deleted", .booleanAttributeType), ("color", .stringAttributeType)])
        let todo = entity("Todo", [("id", .UUIDAttributeType), ("noteID", .UUIDAttributeType), ("text", .stringAttributeType), ("done", .booleanAttributeType), ("position", .integer64AttributeType)])
        let settings = entity("Settings", [("id", .stringAttributeType), ("fixed", .booleanAttributeType), ("fixedColor", .stringAttributeType), ("added", .stringAttributeType), ("saved", .stringAttributeType)])
        for e in [note, todo, settings] { e.uniquenessConstraints = [["id"]] }
        m.entities = [note, todo, settings]; return m
    }
    private func rows(_ name: String) throws -> [NSManagedObject] { try context.fetch(NSFetchRequest<NSManagedObject>(entityName: name)) }
    private func load() throws {
        let todos = try rows("Todo")
        notes = try rows("Note").map { r in
            guard let id = r.value(forKey: "id") as? UUID, let title = r.value(forKey: "manualTitle") as? String, let body = r.value(forKey: "body") as? String, let modified = r.value(forKey: "modified") as? Date, let color = r.value(forKey: "color") as? String, ColorValue.normalize(color) != nil else { throw TestFailure(description: "便签数据无效，原库已保留") }
            let items = try todos.filter { $0.value(forKey: "noteID") as? UUID == id }.sorted { ($0.value(forKey: "position") as! Int64) < ($1.value(forKey: "position") as! Int64) }.map { t -> Todo in
                guard let tid = t.value(forKey: "id") as? UUID, let text = t.value(forKey: "text") as? String else { throw TestFailure(description: "待办数据无效") }
                return Todo(id: tid, text: text, done: t.value(forKey: "done") as! Bool)
            }
            return Note(id: id, manualTitle: title, body: body, todos: items, modified: modified, visible: r.value(forKey: "visible") as! Bool, deleted: r.value(forKey: "deleted") as! Bool, color: color)
        }
        let noteIDs = Set(notes.map(\.id))
        guard noteIDs.count == notes.count, Set(todos.compactMap { $0.value(forKey: "id") as? UUID }).count == todos.count,
              todos.allSatisfy({ row in (row.value(forKey: "noteID") as? UUID).map { noteIDs.contains($0) } == true }) else {
            throw TestFailure(description: "记录身份或待办关联无效，原库已保留")
        }
        let records = try rows("Settings")
        if let r = records.first {
            guard records.count == 1, let fixed = r.value(forKey: "fixedColor") as? String, ColorValue.normalize(fixed) != nil, let added = r.value(forKey: "added") as? String, let saved = r.value(forKey: "saved") as? String else { throw TestFailure(description: "配色设置无效，未覆盖") }
            let decoder = JSONDecoder()
            settings = ColorSettings(fixed: r.value(forKey: "fixed") as! Bool, fixedColor: fixed, added: try decoder.decode([String].self, from: Data(added.utf8)), saved: try decoder.decode([String].self, from: Data(saved.utf8)))
            guard (settings.added + settings.saved).allSatisfy({ ColorValue.normalize($0) != nil }) else { throw TestFailure(description: "设置含无效颜色") }
        }
    }
    private func loadLayout() throws {
        guard FileManager.default.fileExists(atPath: layoutURL.path) else { return }
        do {
            let layout = try JSONDecoder().decode(NoteLayout.self, from: Data(contentsOf: layoutURL))
            guard layout.version == 1 else { throw TestFailure(description: "不支持的锁定文件版本") }
            var decoded: [UUID: NotePlacement] = [:]
            for (key, value) in layout.notes {
                guard let id = UUID(uuidString: key), decoded[id] == nil, value.valid,
                      let note = note(id), !value.locked || (!note.deleted && note.visible) else {
                    throw TestFailure(description: "锁定文件身份或位置无效")
                }
                decoded[id] = value
            }
            placements = decoded
        } catch { throw TestFailure(description: "无法读取锁定/位置文件，原文件已保留：\(error.localizedDescription)") }
    }
    func isLocked(_ id: UUID) -> Bool { placements[id]?.locked == true }
    @discardableResult func setLocked(_ id: UUID, _ locked: Bool, frame: NSRect? = nil) -> Bool {
        guard let n = note(id), !n.deleted, !locked || n.visible else { return false }
        if isLocked(id) == locked { return true }
        guard var placement = placement(id, displayedFrame: frame) else { return false }
        placement.locked = locked
        // Persist content before associating the metadata with its stable ID.
        guard save() else { return false }
        return persistPlacement(id, placement)
    }
    func isCollapsed(_ id: UUID) -> Bool { placements[id]?.collapsed == true }
    @discardableResult func setCollapsed(_ id: UUID, _ collapsed: Bool, frame: NSRect? = nil) -> Bool {
        guard !isLocked(id), let n = note(id), !n.deleted else { return false }
        if isCollapsed(id) == collapsed { return true }
        guard var placement = placement(id, displayedFrame: frame) else { return false }
        placement.collapsed = collapsed
        guard save() else { return false }
        return persistPlacement(id, placement)
    }
    @discardableResult func updateFrame(_ id: UUID, _ frame: NSRect) -> Bool {
        guard !isLocked(id), note(id)?.deleted == false,
              let placement = placement(id, displayedFrame: frame) else { return false }
        // Moving a panel only writes layout, never all content rows or the modification date.
        return persistPlacement(id, placement)
    }
    private func placement(_ id: UUID, displayedFrame: NSRect?) -> NotePlacement? {
        let value: NotePlacement?
        if let rect = displayedFrame {
            value = placements[id]?.moved(to: rect) ?? NotePlacement(locked: false, frame: rect)
        } else { value = placements[id] }
        guard let value, value.valid else { error = "未保存：便签位置或尺寸无效"; return nil }
        return value
    }
    private func persistPlacement(_ id: UUID, _ placement: NotePlacement) -> Bool {
        guard placement.valid else { error = "未保存：便签位置或尺寸无效"; return false }
        if placements[id] == placement { return true }
        var next = placements; next[id] = placement
        do {
            try beforeLayoutSave?()
            let layout = NoteLayout(notes: Dictionary(uniqueKeysWithValues: next.map { ($0.key.uuidString, $0.value) }))
            try JSONEncoder().encode(layout).write(to: layoutURL, options: .atomic)
            placements = next
            if !dirty { error = nil }
            return true
        } catch { self.error = "未保存便签整理状态：\(error.localizedDescription)"; return false }
    }
    func note(_ id: UUID) -> Note? { notes.first { $0.id == id } }
    @discardableResult func create() -> UUID {
        var n = Note(); n.modified = clock(); n.color = settings.fixed ? settings.fixedColor : settings.pool.randomElement()!
        notes.append(n); dirty = true; save(); return n.id
    }
    func edit(_ id: UUID, _ change: (inout Note) -> Void) { mutate(id, content: true, change) }
    func arrange(_ id: UUID, _ change: (inout Note) -> Void) { mutate(id, content: false, change) }
    private func mutate(_ id: UUID, content: Bool, _ change: (inout Note) -> Void) {
        guard !isLocked(id), let index = notes.firstIndex(where: { $0.id == id }) else { return }
        var n = notes[index]; change(&n)
        guard n != notes[index] else { return }
        if content { n.modified = clock() }
        notes[index] = n; dirty = true; save()
    }
    func updateSettings(_ settings: ColorSettings) { self.settings = settings; dirty = true; save() }
    @discardableResult func applyPalette(_ settings: ColorSettings, noteID: UUID?, color: String, sourceNoteID: UUID? = nil) -> Bool {
        guard sourceNoteID.map({ !isLocked($0) && note($0)?.deleted == false }) ?? true,
              noteID.map({ !isLocked($0) }) ?? true else { return false }
        if let id = noteID {
            guard let index = notes.firstIndex(where: { $0.id == id && !$0.deleted }) else { return false }
            notes[index].color = color
        }
        self.settings = settings; dirty = true; return save()
    }
    func results(_ filter: NoteFilter, _ query: String) -> [Note] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.filter { n in
            let within: Bool
            switch filter { case .all: within = !n.deleted; case .visible: within = !n.deleted && n.visible; case .stored: within = !n.deleted && !n.visible; case .trash: within = n.deleted }
            return within && (q.isEmpty || (n.title + "\n" + n.summary).range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
        }.sorted { $0.modified == $1.modified ? $0.id.uuidString < $1.id.uuidString : $0.modified > $1.modified }
    }
    @discardableResult func save() -> Bool {
        do {
            try beforeSave?()
            let existingNotes = Dictionary(uniqueKeysWithValues: try rows("Note").map { ($0.value(forKey: "id") as! UUID, $0) })
            let existingTodos = Dictionary(uniqueKeysWithValues: try rows("Todo").map { ($0.value(forKey: "id") as! UUID, $0) })
            var retained = Set<UUID>()
            for n in notes {
                let r = existingNotes[n.id] ?? NSEntityDescription.insertNewObject(forEntityName: "Note", into: context)
                for (key, value): (String, Any) in [("id", n.id), ("manualTitle", n.manualTitle), ("body", n.body), ("modified", n.modified), ("visible", n.visible), ("deleted", n.deleted), ("color", n.color)] { r.setValue(value, forKey: key) }
                for (i, t) in n.todos.enumerated() {
                    retained.insert(t.id)
                    let row = existingTodos[t.id] ?? NSEntityDescription.insertNewObject(forEntityName: "Todo", into: context)
                    for (key, value): (String, Any) in [("id", t.id), ("noteID", n.id), ("text", t.text), ("done", t.done), ("position", Int64(i))] { row.setValue(value, forKey: key) }
                }
            }
            for (id, row) in existingTodos where !retained.contains(id) { context.delete(row) }
            let r = try rows("Settings").first ?? NSEntityDescription.insertNewObject(forEntityName: "Settings", into: context)
            let encoder = JSONEncoder()
            r.setValue("default", forKey: "id"); r.setValue(settings.fixed, forKey: "fixed"); r.setValue(settings.fixedColor, forKey: "fixedColor")
            r.setValue(String(decoding: try encoder.encode(settings.added), as: UTF8.self), forKey: "added")
            r.setValue(String(decoding: try encoder.encode(settings.saved), as: UTF8.self), forKey: "saved")
            try context.save(); dirty = false; error = nil; return true
        } catch {
            context.rollback(); dirty = true; self.error = "未保存：\(error.localizedDescription)"; return false
        }
    }
}
