import Foundation

/// Standalone deterministic checks; no app launch, keyboard access or real waits.
@main
struct FocusTimerChecks {
    static func main() {
        let timer = FocusTimer()
        var starts = 0
        var finishes = 0
        timer.onStart = { _ in starts += 1 }
        timer.onFinish = { _ in finishes += 1 }
        timer.startNext()
        let focusDuration = timer.remaining
        precondition(timer.status == .running && timer.phase == .focus)
        timer.startNext()
        precondition(starts == 1, "Starting twice must not replace the interval")
        timer.pause()
        let pausedRemaining = timer.remaining
        timer.refresh(now: Date().addingTimeInterval(focusDuration + 3600))
        precondition(timer.status == .paused && timer.remaining == pausedRemaining)
        timer.resume()
        timer.refresh(now: Date().addingTimeInterval(focusDuration + 3600))
        precondition(timer.status == .finished && timer.remaining == 0 && finishes == 1)
        timer.refresh(now: Date().addingTimeInterval(focusDuration + 7200))
        precondition(finishes == 1, "A late tick must not finish twice or consume a break")
        timer.startNext()
        precondition(timer.phase == .rest && timer.status == .running && starts == 2)
        timer.refresh(now: Date().addingTimeInterval(timer.remaining + 1))
        precondition(timer.status == .finished && finishes == 2)
        timer.startNext()
        precondition(timer.phase == .focus && starts == 3)
        timer.reset()
        timer.refresh(now: Date().addingTimeInterval(100000))
        precondition(timer.status == .ready && timer.remaining == 0 && finishes == 2)
        print("FocusTimer checks passed")
    }
}
