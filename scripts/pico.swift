import Foundation
import Darwin

// Run with `swift scripts/pico.swift ...` or compile once with swiftc.
let notificationName = Notification.Name("app.pico.desktop.developer-event.v1")
let knownEvents: Set<String> = ["build-started", "build-succeeded", "build-failed",
                                "test-started", "test-succeeded", "test-failed", "cancelled"]

func send(_ event: String) {
    DistributedNotificationCenter.default().postNotificationName(
        notificationName, object: event, userInfo: nil, deliverImmediately: true
    )
}

func fail(_ message: String, code: Int32 = 64) -> Never {
    FileHandle.standardError.write(Data(("pico: " + message + "\n").utf8))
    exit(code)
}

let args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty || args == ["--help"] || args == ["help"] {
    print("""
    Usage:
      pico notify <event>
      pico build -- <command> [arguments...]
      pico test -- <command> [arguments...]

    Events: build-started, build-succeeded, build-failed,
            test-started, test-succeeded, test-failed, cancelled

    Pico must already be running with developer reactions enabled.
    Notifications are best-effort; no delivery acknowledgment is provided.
    Only event names are sent. Command output stays in this terminal.
    """)
    exit(0)
}

if args.first == "notify" {
    guard args.count == 2, knownEvents.contains(args[1]) else { fail("Unknown event. Use --help.") }
    send(args[1])
    exit(0)
}

guard let kind = args.first, kind == "build" || kind == "test",
      args.count >= 3, args[1] == "--", !args[2].isEmpty else {
    fail("Expected build/test -- <command> [arguments...]. Use --help.")
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
// Preserve argument boundaries: no shell interpolation or command-string eval.
process.arguments = Array(args.dropFirst(2))
process.standardInput = FileHandle.standardInput
process.standardOutput = FileHandle.standardOutput
process.standardError = FileHandle.standardError
send(kind + "-started")
do {
    try process.run()
} catch {
    send(kind + "-failed")
    fail("Could not start the command: \(error.localizedDescription)", code: 126)
}
process.waitUntilExit()
if process.terminationReason == .uncaughtSignal {
    send("cancelled")
    exit(128 + process.terminationStatus)
}
send(kind + (process.terminationStatus == 0 ? "-succeeded" : "-failed"))
exit(process.terminationStatus)
