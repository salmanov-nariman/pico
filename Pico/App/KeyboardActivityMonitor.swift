import CoreGraphics
import Foundation

/// Observes aggregate activity only, never individual key events or their contents.
/// All methods and callbacks run on the main run loop.
final class KeyboardActivityMonitor {
    var onActivity: (() -> Void)?
    private var timer: Timer?
    private var previousCount: UInt32?

    func start() {
        guard timer == nil else { return }
        // Ignore input from before enabling or resuming synchronization.
        previousCount = Self.keyDownCount()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer.tolerance = 0.01
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        previousCount = nil
    }

    private func poll() {
        let count = Self.keyDownCount()
        let changed = previousCount.map { $0 != count } ?? false
        previousCount = count
        guard changed else { return }
        // Do not replay old activity after a stalled run loop or sleep.
        let age = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: .keyDown
        )
        guard age.isFinite, age >= 0, age < 0.25 else { return }
        onActivity?()
    }

    private static func keyDownCount() -> UInt32 {
        CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
    }

    deinit { timer?.invalidate() }
}
