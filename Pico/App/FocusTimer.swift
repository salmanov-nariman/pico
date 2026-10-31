import Foundation
import Combine

/// One explicitly started focus or break interval. Deadlines survive delayed ticks
/// and system sleep; no sessions are silently consumed while the user is away.
final class FocusTimer: ObservableObject {
    enum Phase { case focus, rest }
    enum Status { case ready, running, paused, finished }

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var status: Status = .ready
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var focusMinutes: Int
    @Published private(set) var restMinutes: Int
    var onStart: ((Phase) -> Void)?
    var onFinish: ((Phase) -> Void)?
    private var deadline: Date?
    private var ticker: Timer?

    init() {
        focusMinutes = min(120, max(1, UserDefaults.standard.object(forKey: "timer.focusMinutes") as? Int ?? 25))
        restMinutes = min(30, max(1, UserDefaults.standard.object(forKey: "timer.restMinutes") as? Int ?? 5))
    }

    var timeLabel: String {
        let seconds = max(0, Int(ceil(remaining)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var canConfigure: Bool { status == .ready || status == .finished }

    func configure(focus: Int, rest: Int) {
        guard canConfigure else { return }
        focusMinutes = min(120, max(1, focus))
        restMinutes = min(30, max(1, rest))
        UserDefaults.standard.set(focusMinutes, forKey: "timer.focusMinutes")
        UserDefaults.standard.set(restMinutes, forKey: "timer.restMinutes")
    }

    func startNext() {
        guard canConfigure else { return }
        if status == .finished { phase = phase == .focus ? .rest : .focus }
        remaining = TimeInterval((phase == .focus ? focusMinutes : restMinutes) * 60)
        status = .running
        deadline = Date().addingTimeInterval(remaining)
        onStart?(phase)
        startTicker()
    }

    func pause() {
        guard status == .running else { return }
        refresh()
        guard status == .running else { return }
        status = .paused
        deadline = nil
        stopTicker()
    }

    func resume() {
        guard status == .paused else { return }
        status = .running
        deadline = Date().addingTimeInterval(remaining)
        startTicker()
    }

    func reset() {
        stopTicker()
        deadline = nil
        remaining = 0
        phase = .focus
        status = .ready
    }

    func refresh(now: Date = Date()) {
        guard status == .running, let deadline else { return }
        remaining = max(0, deadline.timeIntervalSince(now))
        guard remaining == 0 else { return }
        self.deadline = nil
        stopTicker()
        status = .finished
        onFinish?(phase)
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.refresh() }
        timer.tolerance = 0.05
        ticker = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTicker() { ticker?.invalidate(); ticker = nil }
    deinit { ticker?.invalidate() }
}
