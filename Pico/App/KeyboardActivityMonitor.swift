import AppKit
import CoreGraphics

/// Passive, opt-in typing visualization. Characters are forwarded transiently, never logged or stored.
final class KeyboardActivityMonitor {
    var onPress: ((String?) -> Void)?
    var onUnavailable: (() -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { tap.map { CFMachPortIsValid($0) && CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func start() -> Bool {
        if isRunning { return true }
        stop()
        guard CGPreflightListenEventAccess() else { return false }
        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        guard let port = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<KeyboardActivityMonitor>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if CGPreflightListenEventAccess(), let tap = owner.tap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    } else {
                        owner.onUnavailable?()
                    }
                } else if type == .keyDown {
                    // Shortcut keys must not be displayed as typed text.
                    guard !event.flags.contains(.maskCommand),
                          !event.flags.contains(.maskControl) else {
                        return Unmanaged.passUnretained(event)
                    }
                    owner.onPress?(KeyboardActivityMonitor.displayGlyph(for: event))
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            return false
        }
        tap = port
        source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private static func displayGlyph(for event: CGEvent) -> String? {
        // Use the event's Unicode text, not a hardcoded US key-code map.
        var buffer = [UniChar](repeating: 0, count: 32)
        var length = 0
        buffer.withUnsafeMutableBufferPointer { pointer in
            event.keyboardGetUnicodeString(maxStringLength: pointer.count,
                                           actualStringLength: &length,
                                           unicodeString: pointer.baseAddress)
        }
        let unicode = String(decoding: buffer.prefix(min(length, buffer.count)), as: UTF16.self)
        let characters = unicode.isEmpty ? (NSEvent(cgEvent: event)?.characters ?? "") : unicode
        guard let first = characters.first else { return nil }
        let glyph = String(first)
        guard glyph.unicodeScalars.allSatisfy({
            !CharacterSet.controlCharacters.contains($0) && $0.properties.generalCategory != .privateUse
        }) else { return nil }
        if glyph == " " { return "␣" }
        guard !glyph.unicodeScalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) }) else {
            return nil
        }
        return glyph
    }

    deinit { stop() }
}
