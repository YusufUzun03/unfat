import Foundation
import SwiftData

// Synced models (CloudKit rules: every property optional or defaulted, no unique constraints,
// relationships optional with an explicit inverse). CloudKit relationships are unordered, so
// children carry an `order` field and the parents expose sorted accessors.

/// A training program: Program -> ProgramDay -> PlannedExercise.
@Model
final class Program {
    var uuid: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var order: Int = 0
    var isArchived: Bool = false
    /// Identifier of the built-in template it was created from (task 11), if any.
    var templateID: String?
    @Relationship(deleteRule: .cascade, inverse: \ProgramDay.program)
    var days: [ProgramDay]? = []

    init(name: String, order: Int = 0, templateID: String? = nil) {
        self.name = name
        self.order = order
        self.templateID = templateID
    }

    var sortedDays: [ProgramDay] {
        (days ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class ProgramDay {
    var uuid: UUID = UUID()
    var name: String = ""
    var order: Int = 0
    var program: Program?
    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.day)
    var exercises: [PlannedExercise]? = []

    init(name: String, order: Int) {
        self.name = name
        self.order = order
    }

    var sortedExercises: [PlannedExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class PlannedExercise {
    var uuid: UUID = UUID()
    /// `seed:<exercise id>` or `custom:<uuid>` (see `ItemRef`).
    var exerciseRef: String = ""
    /// Display-name snapshot so the row still renders if a custom exercise is deleted.
    var exerciseName: String = ""
    var order: Int = 0
    var sets: Int = 3
    var repMin: Int = 8
    var repMax: Int = 12
    var restSeconds: Int = 90
    var targetWeightKg: Double?
    var day: ProgramDay?

    init(
        exerciseRef: String,
        exerciseName: String,
        order: Int,
        sets: Int = 3,
        repMin: Int = 8,
        repMax: Int = 12,
        restSeconds: Int = 90,
        targetWeightKg: Double? = nil
    ) {
        self.exerciseRef = exerciseRef
        self.exerciseName = exerciseName
        self.order = order
        self.sets = sets
        self.repMin = repMin
        self.repMax = repMax
        self.restSeconds = restSeconds
        self.targetWeightKg = targetWeightKg
    }
}

/// A performed (or in-progress) workout: WorkoutSession -> SessionExercise -> SetLog.
/// It references its program day by id only, so deleting a program keeps the history.
@Model
final class WorkoutSession {
    var uuid: UUID = UUID()
    var name: String = ""
    var startedAt: Date = Date.now
    /// nil while the session is active.
    var endedAt: Date?
    /// `ProgramDay.uuid` the session was started from; nil for an empty session.
    var programDayID: UUID?
    var notes: String?
    /// Estimated energy for the finished session (computed by UnFatCore, stored for history).
    var energyKcal: Double?
    /// UUID of the `HKWorkout` written for this session, if any.
    var healthKitWorkoutID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise]? = []

    init(name: String, startedAt: Date = .now, programDayID: UUID? = nil) {
        self.name = name
        self.startedAt = startedAt
        self.programDayID = programDayID
    }

    var isActive: Bool { endedAt == nil }

    var sortedExercises: [SessionExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class SessionExercise {
    var uuid: UUID = UUID()
    var exerciseRef: String = ""
    var exerciseName: String = ""
    var order: Int = 0
    var restSeconds: Int = 90
    var session: WorkoutSession?
    @Relationship(deleteRule: .cascade, inverse: \SetLog.sessionExercise)
    var setLogs: [SetLog]? = []

    init(exerciseRef: String, exerciseName: String, order: Int, restSeconds: Int = 90) {
        self.exerciseRef = exerciseRef
        self.exerciseName = exerciseName
        self.order = order
        self.restSeconds = restSeconds
    }

    var sortedSetLogs: [SetLog] {
        (setLogs ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class SetLog {
    var uuid: UUID = UUID()
    var order: Int = 0
    var reps: Int = 0
    var weightKg: Double = 0
    var isDone: Bool = false
    var completedAt: Date?
    var rpe: Double?
    var sessionExercise: SessionExercise?

    init(order: Int, reps: Int, weightKg: Double, isDone: Bool = false, completedAt: Date? = nil, rpe: Double? = nil) {
        self.order = order
        self.reps = reps
        self.weightKg = weightKg
        self.isDone = isDone
        self.completedAt = completedAt
        self.rpe = rpe
    }
}

/// A user-created exercise, referenced as `custom:<uuid>`.
@Model
final class CustomExercise {
    var uuid: UUID = UUID()
    var createdAt: Date = Date.now
    var nameTr: String = ""
    var primaryMuscleRaw: String = Muscle.fullBody.rawValue
    var equipmentRaw: String = Equipment.other.rawValue
    var kindRaw: String = ExerciseKind.strength.rawValue
    var met: Double = 5.0

    init(nameTr: String, primaryMuscle: Muscle, equipment: Equipment, kind: ExerciseKind = .strength, met: Double = 5.0) {
        self.nameTr = nameTr
        self.primaryMuscleRaw = primaryMuscle.rawValue
        self.equipmentRaw = equipment.rawValue
        self.kindRaw = kind.rawValue
        self.met = met
    }

    var primaryMuscle: Muscle {
        get { Muscle(rawValue: primaryMuscleRaw) ?? .fullBody }
        set { primaryMuscleRaw = newValue.rawValue }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .other }
        set { equipmentRaw = newValue.rawValue }
    }

    var kind: ExerciseKind {
        get { ExerciseKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }

    var exerciseRef: String { ItemRef.custom(uuid) }
}
