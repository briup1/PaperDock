import Foundation
import CoreData
import Darwin

let builtInPapers = ["#FFFEFA", "#F4ECD8", "#E8D5B5", "#E8E9E6", "#DDE8D5", "#343A36"]

enum SpikeError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String { if case let .invalid(message) = self { return message }; return "Unknown error" }
}

struct NoteState: Codable, Equatable {
    var body = ""
    var manualTitle = ""
    var todo = ""
    var done = false
    var paper = builtInPapers[0]
    var visible = false
    var created = false
    var x = 120.0, y = 160.0, width = 380.0, height = 420.0
    var modified = Date().timeIntervalSince1970
    var mode = "random"
    var fixed = builtInPapers[0]
    var pool = builtInPapers

    var title: String {
        if !manualTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return manualTitle }
        let visible = body.filter { !$0.isWhitespace }
        return visible.isEmpty ? "空白便签" : String(visible.prefix(5))
    }
    func nextPaper() -> String { mode == "fixed" ? fixed : pool.randomElement()! }
    static func validHex(_ value: String) -> Bool {
        value.range(of: "^#[0-9A-F]{6}$", options: .regularExpression) != nil
    }
    func validate() throws {
        guard [paper, fixed].allSatisfy(Self.validHex), !pool.isEmpty,
              pool.count <= 256, pool.allSatisfy(Self.validHex), Set(pool).count == pool.count,
              ["random", "fixed"].contains(mode), [x,y,width,height,modified].allSatisfy({ $0.isFinite }),
              width >= 320, height >= 340, width <= 10000, height <= 10000,
              body.utf8.count <= 1_000_000, todo.utf8.count <= 10000, manualTitle.utf8.count <= 10000
        else { throw SpikeError.invalid("Invalid persisted state; refusing replacement") }
    }
}

// One disposable record containing the complete note/settings transaction, not the final product schema.
final class SpikeStore {
    let coordinator: NSPersistentStoreCoordinator
    let context: NSManagedObjectContext
    let directory: URL
    private var lockFD: Int32 = -1

    init(directory: URL) throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().resolvingSymlinksInPath()
        let target = directory.standardizedFileURL.resolvingSymlinksInPath()
        guard target.path.hasPrefix(root.path + "/"), target.path != root.path + "/review-evidence" else {
            throw SpikeError.invalid("Data must be below native-spike (review-evidence requires a child directory)")
        }
        self.directory = target
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        lockFD = Darwin.open(target.appendingPathComponent("instance.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
            if lockFD >= 0 { Darwin.close(lockFD) }
            throw SpikeError.invalid("Data directory busy or inaccessible; use a new directory")
        }
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "Snapshot"
        entity.managedObjectClassName = "NSManagedObject"
        let attribute = NSAttributeDescription()
        attribute.name = "payload"
        attribute.attributeType = .binaryDataAttributeType
        attribute.isOptional = false
        entity.properties = [attribute]
        model.entities = [entity]
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                at: target.appendingPathComponent("notes.sqlite"), options: [
                    NSMigratePersistentStoresAutomaticallyOption: false,
                    NSInferMappingModelAutomaticallyOption: false,
                    NSSQLitePragmasOption: ["journal_mode": "DELETE"]])
        } catch {
            flock(lockFD, LOCK_UN); Darwin.close(lockFD); lockFD = -1
            throw error
        }
    }
    deinit { if lockFD >= 0 { flock(lockFD, LOCK_UN); Darwin.close(lockFD) } }
    func load() throws -> NoteState? {
        let rows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Snapshot"))
        guard rows.count <= 1 else { throw SpikeError.invalid("Unexpected duplicate snapshots; refusing replacement") }
        guard let row = rows.first else { return nil }
        guard let data = row.value(forKey: "payload") as? Data else { throw SpikeError.invalid("Missing payload") }
        let value = try JSONDecoder().decode(NoteState.self, from: data)
        try value.validate()
        return value
    }
    func save(_ state: NoteState) throws {
        try state.validate()
        let data = try JSONEncoder().encode(state)
        let rows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Snapshot"))
        guard rows.count <= 1 else { throw SpikeError.invalid("Unexpected duplicate snapshots") }
        let row = rows.first ?? NSEntityDescription.insertNewObject(forEntityName: "Snapshot", into: context)
        row.setValue(data, forKey: "payload")
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

func runModelChecks(directory: URL) throws {
    let store = try SpikeStore(directory: directory)
    guard try store.load() == nil else { throw SpikeError.invalid("--check requires a fresh data directory") }
    var state = NoteState()
    state.body = " 明天联系客户确认报价🇨🇳👩🏽‍💻"
    guard state.title == "明天联系客" else { throw SpikeError.invalid("Chinese title check") }
    state.body = "👩🏽‍💻🇨🇳甲乙丙丁"
    guard state.title == "👩🏽‍💻🇨🇳甲乙丙" else { throw SpikeError.invalid("Grapheme check") }
    state.manualTitle = "手动标题"; state.body = "后续正文"
    guard state.title == "手动标题" else { throw SpikeError.invalid("Manual title check") }
    state.todo = "核对报价"; state.done = true; state.visible = true
    state.fixed = "#ABCDEF"; state.mode = "fixed"
    guard (0..<20).allSatisfy({ _ in state.nextPaper() == "#ABCDEF" }) else { throw SpikeError.invalid("Fixed paper check") }
    state.pool.append("#ABCDEF"); state.mode = "random"
    guard (0..<100).allSatisfy({ _ in state.pool.contains(state.nextPaper()) }) else { throw SpikeError.invalid("Random membership check") }
    try store.save(state)
    guard try store.load() == state else { throw SpikeError.invalid("CoreData roundtrip") }
    var invalid = state; invalid.paper = "broken"
    do { try store.save(invalid); throw SpikeError.invalid("Invalid save unexpectedly succeeded") }
    catch let error as SpikeError where error.description.hasPrefix("Invalid persisted") { }
    guard try store.load() == state else { throw SpikeError.invalid("Invalid save changed old values") }
    do { _ = try SpikeStore(directory: directory); throw SpikeError.invalid("Duplicate writer allowed") }
    catch let error as SpikeError where error.description.hasPrefix("Data directory busy") { }
    print("PASS model: Chinese/grapheme/manual titles; todo; fixed/random membership; CoreData roundtrip; invalid-save preserves old value; duplicate writer refused")
}
