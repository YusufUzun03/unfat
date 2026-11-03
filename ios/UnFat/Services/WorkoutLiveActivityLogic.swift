import Foundation

// Pure parts of the workout Live Activity: which set is next, what the activity shows, what to do
// with the activities that exist, what to remember across a relaunch. No ActivityKit, no database,
// no clock reads (every function takes `now`), so all of it is covered by `LiveActivityTests`.

/// Done flags of one exercise, in set order. A value snapshot of `SessionExercise` / `SetLog`.
struct WorkoutExerciseProgress: Equatable, Sendable {
    var name: String
    /// `SetLog.isDone` per set.
    var sets: [Bool]
    var restSeconds: Int
}

/// The set the "Set tamam" button completes.
struct WorkoutNextSet: Equatable, Sendable {
    var exerciseIndex: Int
    var setIndex: Int
    /// True when no open set is left; the indices then point at the last set of the last exercise.
    var isComplete: Bool
}

/// What the activity should show right now. `sessionID` ties it to `WorkoutActivityAttributes`.
struct WorkoutActivityDesired: Equatable, Sendable {
    var sessionID: UUID
    var workoutName: String
    var state: WorkoutActivityAttributes.ContentState
}

/// What to do with the activities that exist (indices into the list the caller passed in).
struct WorkoutActivityReconciliation: Equatable, Sendable {
    var endIndices: [Int]
    var updateIndex: Int?
    var requestsNew: Bool
}

/// The "rest is over" notification: when, and which exercise comes next (nil when none is left).
struct WorkoutRestNotificationPlan: Equatable, Sendable {
    var end: Date
    var exerciseName: String?
}

/// A running rest, saved to the App Group so a relaunch (for example the system starting the app
/// in the background for a Live Activity button) can pick it up again.
struct WorkoutRestState: Codable, Equatable, Sendable {
    var sessionID: UUID
    var start: Date
    var end: Date
}

/// What a stored `WorkoutRestState` means at launch.
enum WorkoutRestRecovery: Equatable, Sendable {
    /// Nothing usable: no state, another session, or a broken window.
    case none
    case running(ClosedRange<Date>)
    /// The rest ran out while the app was not running.
    case over
}

enum WorkoutLiveActivityLogic {
    // MARK: - Next set

    /// The first open set (exercise order, then set order). When every set is done: the last set of
    /// the last exercise that has sets, marked complete. nil when the workout has no sets at all.
    static func nextSet(in exercises: [WorkoutExerciseProgress]) -> WorkoutNextSet? {
        for (exerciseIndex, exercise) in exercises.enumerated() {
            if let setIndex = exercise.sets.firstIndex(of: false) {
                return WorkoutNextSet(exerciseIndex: exerciseIndex, setIndex: setIndex, isComplete: false)
            }
        }
        guard let last = exercises.lastIndex(where: { !$0.sets.isEmpty }) else { return nil }
        return WorkoutNextSet(
            exerciseIndex: last,
            setIndex: exercises[last].sets.count - 1,
            isComplete: true
        )
    }

    static func doneCount(in exercises: [WorkoutExerciseProgress]) -> Int {
        exercises.reduce(0) { total, exercise in total + exercise.sets.filter { $0 }.count }
    }

    // MARK: - Content

    /// `rest` is the running rest window (nil when none runs). `restOver` marks a rest that ran out and
    /// was not followed by a new set yet; it only counts while no rest runs.
    static func contentState(
        workoutName: String,
        exercises: [WorkoutExerciseProgress],
        rest: ClosedRange<Date>?,
        restOver: Bool
    ) -> WorkoutActivityAttributes.ContentState {
        let isOver = restOver && rest == nil
        guard let next = nextSet(in: exercises) else {
            return WorkoutActivityAttributes.ContentState(
                exerciseName: workoutName,
                setNumber: 0,
                setCount: 0,
                restStart: rest?.lowerBound,
                restEnd: rest?.upperBound,
                restOver: isOver,
                canCompleteSet: false
            )
        }
        let exercise = exercises[next.exerciseIndex]
        return WorkoutActivityAttributes.ContentState(
            exerciseName: exercise.name,
            setNumber: next.setIndex + 1,
            setCount: exercise.sets.count,
            restStart: rest?.lowerBound,
            restEnd: rest?.upperBound,
            restOver: isOver,
            canCompleteSet: !next.isComplete
        )
    }

    // MARK: - Activities

    /// Keeps the first activity of the desired session, ends every other one (orphans of a finished
    /// session, duplicates), and asks for a new one only when none matches and the user has not
    /// dismissed this session's activity (`isSuppressed`). Without a desired session everything ends.
    static func reconcile(
        existing: [UUID],
        desired: UUID?,
        isSuppressed: Bool
    ) -> WorkoutActivityReconciliation {
        guard let desired else {
            return WorkoutActivityReconciliation(
                endIndices: Array(existing.indices),
                updateIndex: nil,
                requestsNew: false
            )
        }
        let match = existing.firstIndex(of: desired)
        return WorkoutActivityReconciliation(
            endIndices: existing.indices.filter { $0 != match },
            updateIndex: match,
            requestsNew: match == nil && !isSuppressed
        )
    }

    // MARK: - Notification

    /// nil unless a rest runs inside a live session.
    static func notificationPlan(
        state: WorkoutActivityAttributes.ContentState?,
        rest: ClosedRange<Date>?
    ) -> WorkoutRestNotificationPlan? {
        guard let state, let rest else { return nil }
        return WorkoutRestNotificationPlan(
            end: rest.upperBound,
            exerciseName: state.canCompleteSet ? state.exerciseName : nil
        )
    }

    /// Seconds until `end`, or nil when it is not in the future (a time interval trigger needs > 0).
    static func notificationDelay(end: Date, now: Date) -> TimeInterval? {
        end > now ? end.timeIntervalSince(now) : nil
    }

    // MARK: - Relaunch

    static func recover(
        _ stored: WorkoutRestState?,
        activeSessionID: UUID?,
        now: Date
    ) -> WorkoutRestRecovery {
        guard let stored, let activeSessionID, stored.sessionID == activeSessionID,
              stored.start <= stored.end
        else { return .none }
        return stored.end > now ? .running(stored.start...stored.end) : .over
    }
}

/// Reads and writes `workout-rest-state.json` in the App Group container. Only the app touches it.
enum WorkoutRestStateStore {
    static let fileName = "workout-rest-state.json"

    enum StoreError: Error {
        /// The App Group container is unavailable (missing entitlement).
        case noContainer
    }

    /// nil when the App Group container is unavailable.
    static var defaultURL: URL? {
        AppGroup.containerURL?.appending(path: fileName, directoryHint: .notDirectory)
    }

    /// The stored state, or nil when the file is missing or unreadable.
    static func read(from url: URL? = WorkoutRestStateStore.defaultURL) -> WorkoutRestState? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WorkoutRestState.self, from: data)
    }

    /// Writes `state`; nil removes the file (no rest is running).
    static func write(_ state: WorkoutRestState?, to url: URL? = WorkoutRestStateStore.defaultURL) throws {
        guard let url else { throw StoreError.noContainer }
        guard let state else {
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: url)
            }
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
    }
}
