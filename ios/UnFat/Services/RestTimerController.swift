import Foundation
import Observation

/// Date-based rest timer math. All functions are pure so they are easy to test.
enum RestTimerMath {
    /// Step of the -15 / +15 buttons.
    static let adjustStep: TimeInterval = 15

    static func end(start: Date, seconds: Int) -> Date {
        start.addingTimeInterval(TimeInterval(max(0, seconds)))
    }

    static func remaining(end: Date, now: Date) -> TimeInterval {
        max(0, end.timeIntervalSince(now))
    }

    /// New end date after moving the end by `delta` seconds, or nil when that ends the rest
    /// (the new end is not after `now`). The result is never earlier than `start`.
    static func adjustedEnd(start: Date, end: Date, delta: TimeInterval, now: Date) -> Date? {
        let moved = end.addingTimeInterval(delta)
        guard moved > now else { return nil }
        return max(moved, start)
    }
}

/// What happened to the rest timer. Task 12 (Live Activity) observes these through `onEvent`.
enum RestTimerEvent: Equatable, Sendable {
    case started(start: Date, end: Date)
    case adjusted(start: Date, end: Date)
    case skipped
    case finished
}

/// In-app rest timer. It stores only a start and an end `Date`, so it keeps counting while the
/// app is in the background; views render it with `Text(timerInterval:)`.
@MainActor
@Observable
final class RestTimerController {
    private(set) var startDate: Date?
    private(set) var endDate: Date?
    /// Counts natural completions; drives the success haptic.
    private(set) var finishedCount = 0
    /// Seam for the Live Activity (task 12): called after every state change.
    @ObservationIgnored var onEvent: (@MainActor (RestTimerEvent) -> Void)?

    init() {}

    /// Rest start ... rest end while a rest is running.
    var interval: ClosedRange<Date>? {
        guard let startDate, let endDate, startDate <= endDate else { return nil }
        return startDate...endDate
    }

    var isRunning: Bool { endDate != nil }

    /// Starts (or restarts) a rest of `seconds`. A non-positive duration does nothing.
    func start(seconds: Int, now: Date = .now) {
        guard seconds > 0 else { return }
        let end = RestTimerMath.end(start: now, seconds: seconds)
        startDate = now
        endDate = end
        onEvent?(.started(start: now, end: end))
    }

    /// Moves the end by `delta` seconds (use plus or minus `RestTimerMath.adjustStep`).
    /// Ends the rest when the new end would be in the past.
    func adjust(by delta: TimeInterval, now: Date = .now) {
        guard let startDate, let endDate else { return }
        if let newEnd = RestTimerMath.adjustedEnd(start: startDate, end: endDate, delta: delta, now: now) {
            self.endDate = newEnd
            onEvent?(.adjusted(start: startDate, end: newEnd))
        } else {
            clear()
            onEvent?(.skipped)
        }
    }

    /// The "Geç" button.
    func skip() {
        guard isRunning else { return }
        clear()
        onEvent?(.skipped)
    }

    /// Ends the rest if its end date has passed (called from a sleeping task and on foreground).
    /// Returns true when it completed.
    @discardableResult
    func completeIfElapsed(now: Date = .now) -> Bool {
        guard let endDate, endDate <= now else { return false }
        clear()
        finishedCount += 1
        onEvent?(.finished)
        return true
    }

    private func clear() {
        startDate = nil
        endDate = nil
    }
}
