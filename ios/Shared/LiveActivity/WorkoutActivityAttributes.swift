import ActivityKit
import Foundation

/// Live Activity of a running workout. Shared by the app (which starts and updates it) and the widget
/// extension (which renders it). `ContentState` stays small: the 4 KB ActivityKit limit is far away.
struct WorkoutActivityAttributes: ActivityAttributes {
    /// What the Lock Screen and the Dynamic Island show; the app replaces it on every change.
    struct ContentState: Codable, Hashable, Sendable {
        /// The exercise of the next set to do (the last exercise once every set is done).
        var exerciseName: String
        /// 1-based number of that set; equals `setCount` once every set is done.
        var setNumber: Int
        /// Sets of that exercise. 0 when the workout has no sets yet.
        var setCount: Int
        /// Rest window while a rest runs: `Text(timerInterval:)` counts down by itself, so the app does
        /// not need to wake up every second.
        var restStart: Date?
        var restEnd: Date?
        /// The rest ran out while nothing updated the activity (the app is suspended, or it finished
        /// in the foreground). Without this flag the banner derives the same from `isStale`.
        var restOver: Bool
        /// False when no open set is left, so the "Set tamam" button is hidden.
        var canCompleteSet: Bool

        init(
            exerciseName: String,
            setNumber: Int,
            setCount: Int,
            restStart: Date? = nil,
            restEnd: Date? = nil,
            restOver: Bool = false,
            canCompleteSet: Bool = true
        ) {
            self.exerciseName = exerciseName
            self.setNumber = setNumber
            self.setCount = setCount
            self.restStart = restStart
            self.restEnd = restEnd
            self.restOver = restOver
            self.canCompleteSet = canCompleteSet
        }
    }

    /// Static for the life of the activity.
    var workoutName: String
    /// `WorkoutSession.uuid`; lets the app tell an orphaned activity from the running one.
    var sessionID: UUID
}

/// Which of the three layouts the banner and the island show.
enum WorkoutRestPhase: Equatable, Sendable {
    case notResting
    case resting(ClosedRange<Date>)
    case over
}

extension WorkoutActivityAttributes.ContentState {
    /// `isStale` is `ActivityViewContext.isStale`: the app sets the stale date to the rest end, so the
    /// system re-renders the banner with `isStale == true` the moment the rest runs out.
    func restPhase(isStale: Bool, now: Date = .now) -> WorkoutRestPhase {
        if restOver { return .over }
        guard let restStart, let restEnd, restStart <= restEnd else { return .notResting }
        if isStale || restEnd <= now { return .over }
        return .resting(restStart...restEnd)
    }

    /// Date after which the activity counts as stale: the end of the running rest.
    var staleDate: Date? {
        guard !restOver, restStart != nil else { return nil }
        return restEnd
    }
}

// MARK: - Samples

extension WorkoutActivityAttributes {
    static let sample = WorkoutActivityAttributes(
        workoutName: "A Günü",
        sessionID: UUID(uuidString: "5B1A6E55-0D5C-4C69-9E34-2D6A7E0C9B11") ?? UUID()
    )
}

extension WorkoutActivityAttributes.ContentState {
    /// Fixtures for previews and the debug gallery (`now` keeps the rest window around the present).
    static func sampleResting(now: Date = .now) -> Self {
        Self(
            exerciseName: "Bench press",
            setNumber: 3,
            setCount: 4,
            restStart: now.addingTimeInterval(-30),
            restEnd: now.addingTimeInterval(60)
        )
    }

    static func sampleNotResting() -> Self {
        Self(exerciseName: "Bench press", setNumber: 2, setCount: 4)
    }

    static func sampleRestOver() -> Self {
        Self(exerciseName: "Bench press", setNumber: 3, setCount: 4, restOver: true)
    }
}
