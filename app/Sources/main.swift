import AppKit

struct Options {
    var directory: URL?
    var test: String?
    var fixture: String?
    var export: URL?
    var evidence: URL?
    var quitAfter: Double?
    var guiTest = false
    init(_ args: [String]) throws {
        var i = 1
        while i < args.count {
            let option = args[i]
            if option == "--gui-test" { guiTest = true; i += 1; continue }
            guard i + 1 < args.count else { throw TestFailure(description: "Missing value for \(option)") }
            let value = args[i+1]
            func path() throws -> URL {
                guard value.hasPrefix("/") else { throw TestFailure(description: "\(option) requires an absolute path") }
                return URL(fileURLWithPath: value).standardizedFileURL
            }
            switch option {
            case "--data-dir": directory = try path()
            case "--test": test = value
            case "--seed-fixture": fixture = value
            case "--export": export = try path()
            case "--evidence-dir": evidence = try path()
            case "--quit-after": guard let seconds = Double(value), seconds.isFinite, seconds > 0 else { throw TestFailure(description: "Invalid quit interval") }; quitAfter = seconds
            default: throw TestFailure(description: "Unknown option: \(option)")
            }
            i += 2
        }
        if test != nil || fixture != nil || export != nil || evidence != nil || guiTest || quitAfter != nil {
            guard directory != nil else { throw TestFailure(description: "Development actions require explicit --data-dir /absolute/path") }
        }
        if guiTest && evidence == nil { throw TestFailure(description: "--gui-test requires --evidence-dir") }
    }
}

func main() -> Int32 {
    do {
        let options = try Options(CommandLine.arguments)
        return try MainActor.assumeIsolated {
            if let suite = options.test {
                try coreTests(suite, directory: options.directory!); return 0
            }
            let data = options.directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PaperDock", isDirectory: true)
            let store: Store
            do { store = try Store(directory: data) }
            catch {
                if options.directory == nil || (options.fixture == nil && options.export == nil) {
                    _ = NSApplication.shared
                    let alert = NSAlert(); alert.messageText = "PaperDock 无法打开本地数据"; alert.informativeText = "\(error.localizedDescription)\n原数据未清空，请检查数据目录：\(data.path)"; alert.addButton(withTitle: "退出"); alert.runModal()
                }
                throw error
            }
            if let fixture = options.fixture { try seedFixture(fixture, store: store) }
            if let output = options.export {
                let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; e.dateEncodingStrategy = .iso8601
                try e.encode(ExportedState(notes: store.notes, settings: store.settings, placements: Dictionary(uniqueKeysWithValues: store.placements.map { ($0.key.uuidString, $0.value) }))).write(to: output)
                if !options.guiTest { return 0 }
            }
            if options.fixture != nil && !options.guiTest && options.evidence == nil && options.quitAfter == nil { return 0 }
            let app = NSApplication.shared; app.setActivationPolicy(.regular)
            let controller = ApplicationController(store: store, quitAfter: options.quitAfter, evidenceDirectory: options.evidence, guiTest: options.guiTest)
            app.delegate = controller
            withExtendedLifetime(controller) { app.run() }
            return controller.finishTermination()
        }
    } catch { fputs("PaperDock: \(error)\n", stderr); return 1 }
}
exit(main())

struct ExportedState: Codable { let notes: [Note]; let settings: ColorSettings; let placements: [String: NotePlacement] }
@MainActor func seedFixture(_ name: String, store: Store) throws {
    guard store.notes.isEmpty else { throw TestFailure(description: "Fixture refuses nonempty store") }
    guard ["standard", "history", "empty-fixed"].contains(name) else { throw TestFailure(description: "Unknown fixture") }
    if name == "empty-fixed" {
        store.updateSettings(ColorSettings(fixed: true, fixedColor: "#ABCDEF", added: ["#2468AC"]))
    } else {
        let calendar = Calendar.current
        let data = [("客户报价跟进", "明天联系客户确认报价。上海 → 德班，核对 40HQ 价格后再回复。", 0, true), ("便签产品的想法", "随手记录想法", -1, false), ("项目复盘", "回顾项目，整理下一步", -7, false), ("周末想去的地方", "公园散步", -1, false)]
        for (title, body, offset, visible) in data {
            let id = store.create()
            store.edit(id) { $0.manualTitle = title; $0.body = body; $0.todos = [Todo(text: "核对最新报价"), Todo(text: "已完成事项", done: true)] }
            store.arrange(id) { $0.modified = calendar.date(byAdding: .day, value: offset, to: Date())!; $0.visible = visible }
        }
    }
    try expect(store.save(), "fixture save")
}
