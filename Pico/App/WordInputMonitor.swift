import AppKit
import Carbon
import CoreGraphics

enum WordInput {
    case append(String), backspace, commit, clear
}

/// Optional text input, separate from the permission-free activity animation.
/// Never stores events, writes logs, accesses the clipboard, or modifies input.
final class WordInputMonitor {
    var onInput: ((WordInput) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var hasPermission: Bool { CGPreflightListenEventAccess() }
    var isSecureInput: Bool { IsSecureEventInputEnabled() }
    var isRunning: Bool {
        guard let tap else { return false }
        return CFMachPortIsValid(tap) && CGEvent.tapIsEnabled(tap: tap)
    }

    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        stop()
        guard hasPermission, !isSecureInput else { return false }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.rightMouseDown.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap, place: .tailAppendEventTap,
            options: .listenOnly, eventsOfInterest: mask,
            callback: WordInputMonitor.callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            return false
        }
        self.tap = port
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return isRunning
    }

    func requestPermission() { _ = CGRequestListenEventAccess() }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private static let callback: CGEventTapCallBack = { _, type, event, context in
        guard let context else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<WordInputMonitor>.fromOpaque(context).takeUnretainedValue()
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            monitor.onInput?(.clear)
            // The controller retries outside this callback after checking consent.
            return Unmanaged.passUnretained(event)
        }
        guard !monitor.isSecureInput else {
            monitor.onInput?(.clear)
            return Unmanaged.passUnretained(event)
        }
        if type == .leftMouseDown || type == .rightMouseDown {
            monitor.onInput?(.clear)
        } else if type == .keyDown {
            monitor.receive(event)
        }
        return Unmanaged.passUnretained(event)
    }

    private func receive(_ event: CGEvent) {
        guard !event.flags.contains(.maskCommand), !event.flags.contains(.maskControl),
              NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            onInput?(.clear)
            return
        }
        switch event.getIntegerValueField(.keyboardEventKeycode) {
        case 49, 36, 76, 48: onInput?(.commit); return
        case 51: onInput?(.backspace); return
        case 53, 117, 123...126: onInput?(.clear); return
        default: break
        }
        var buffer = [UniChar](repeating: 0, count: 32)
        var length = 0
        buffer.withUnsafeMutableBufferPointer { pointer in
            event.keyboardGetUnicodeString(maxStringLength: pointer.count,
                                           actualStringLength: &length,
                                           unicodeString: pointer.baseAddress)
        }
        guard length > 0 else { return }
        let text = String(decoding: buffer.prefix(min(length, buffer.count)), as: UTF16.self)
        guard text.unicodeScalars.allSatisfy({
            !CharacterSet.controlCharacters.contains($0) && $0.properties.generalCategory != .privateUse
        }) else { return }
        onInput?(.append(text))
    }

    deinit { stop() }
}
