// AppKit owns graceful termination and startup state; never send kill signals.
import AppKit
import Foundation

func applications() -> [NSRunningApplication] {
    NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == "local.paperdock.app" }
}

func output(_ value: Any) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
}

do {
    let args = CommandLine.arguments
    switch args.dropFirst().first {
    case "list":
        try output(applications().map { app in
            ["pid": Int(app.processIdentifier),
             "executable": app.executableURL?.path ?? "",
             "finishedLaunching": app.isFinishedLaunching] as [String: Any]
        })
    case "quit":
        guard args.count == 4, let pid = Int32(args[2]),
              let app = applications().first(where: { $0.processIdentifier == pid }),
              app.executableURL?.path == args[3] else {
            throw NSError(domain: "PaperDockDelivery", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Application identity changed; quit refused"])
        }
        guard app.terminate() else {
            throw NSError(domain: "PaperDockDelivery", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Normal quit request was refused"])
        }
        try output(["requested": true])
    default:
        throw NSError(domain: "PaperDockDelivery", code: 64,
                      userInfo: [NSLocalizedDescriptionKey: "Usage: delivery-host list | quit PID EXECUTABLE"])
    }
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
