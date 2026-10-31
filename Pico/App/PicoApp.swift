import AppKit
import SwiftUI

@main
struct PicoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            CompanionMenu(controller: delegate.controller)
        } label: {
            PicoMenuBarLabel(timer: delegate.controller.focusTimer)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = CompanionController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller.show()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.savePosition()
    }
}
