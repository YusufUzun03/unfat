import Foundation
import SwiftData
import UnFatCore

/// Weight and reps of one set, detached from SwiftData.
struct SetValue: Equatable, Sendable {
    var weightKg: Double
    var reps: Int
}

/// A set to create for a session exercise, with the value it was prefilled from (if any).
struct PrefilledSet: Equatable, Sendable {
    var value: SetValue
    /// The same set index in the last session of this exercise; nil when there is no history.
    var previous: SetValue?
}

/// A personal record reached in a session.
struct RecordItem: Identifiable, Hashable, Sendable {
    let exerciseRef: String
    let exerciseName: String
    let kind: PRKind
    let valueKg: Double
    let previousBestKg: Double

    var id: String { "\(exerciseRef)|\(kind.rawValue)" }
}

/// Numbers shown on the finish summary and in history.
struct SessionSummary: Hashable, Sendable {
    var duration: TimeInterval
    /// Sum of weight x reps over done sets.
    var volumeKg: Double
    var doneSetCount: Int
    var exerciseCount: Int
    var energyKcal: Double
    var records: [RecordItem]
}

/// Pure workout helpers (no SwiftData).
enum WorkoutMath {
    /// MET used when an exercise is unknown (SPEC "Nutrition and training logic").
    static let fallbackMET = 5.0
    /// Body weight used for kcal when the user has no weigh-in yet.
    static let fallbackBodyWeightKg = 70.0

    /// Sets for an exercise that is about to start. Set `i` takes the values of set `i` of the last
    /// session; sets beyond that repeat its last set. Without history: planned reps and
    /// `plannedWeightKg` (empty = 0 kg).
    static func prefill(
        previous: [SetValue],
        setCount: Int,
        plannedReps: Int,
        plannedWeightKg: Double = 0
    ) -> [PrefilledSet] {
        guard setCount > 0 else { return [] }
        return (0..<setCount).map { index in
            guard let last = previous.last else {
                return PrefilledSet(value: SetValue(weightKg: plannedWeightKg, reps: plannedReps), previous: nil)
            }
            let source = previous.indices.contains(index) ? previous[index] : last
            return PrefilledSet(value: source, previous: source)
        }
    }

    static func volume(of sets: [SetValue]) -> Double {
        sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    /// A body weight with the date it was recorded.
    struct DatedWeight: Equatable, Sendable {
        var date: Date
        var kg: Double
    }

    /// Body weight for kcal math: the more recent of the user's last weigh-in and the last Health body
    /// mass, falling back to `fallbackBodyWeightKg`. Health values only carry a day, so on the same
    /// calendar day the user's own entry wins. Non-positive values are ignored.
    static func bodyWeightKg(
        userEntry: DatedWeight?,
        health: DatedWeight?,
        calendar: Calendar = .current
    ) -> Double {
        let user = userEntry.flatMap { $0.kg > 0 ? $0 : nil }
        let fromHealth = health.flatMap { $0.kg > 0 ? $0 : nil }
        switch (user, fromHealth) {
        case let (user?, fromHealth?):
            let userDay = calendar.startOfDay(for: user.date)
            return calendar.startOfDay(for: fromHealth.date) > userDay ? fromHealth.kg : user.kg
        case let (user?, nil): return user.kg
        case let (nil, fromHealth?): return fromHealth.kg
        case (nil, nil): return fallbackBodyWeightKg
        }
    }
}

/// Session logic behind the Workout tab: start, edit, finish, summary, templates.
/// Views call into this and stay thin.
@MainActor
enum WorkoutSessionService {
    static let defaultSetCount = 3
    static let defaultReps = 10
    static let defaultRestSeconds = 90

    // MARK: - Queries

    /// The session that has not been finished yet (newest first if sync produced several).
    static func activeSession(in context: ModelContext) -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).first { $0.isActive }
    }

    /// Finished sessions, newest first.
    static func finishedSessions(in context: ModelContext) throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
        return try context.fetch(descriptor).filter { !$0.isActive }
    }

    /// Done sets of the most recent finished session (before `date`) that contains `ref`.
    static func previousSets(
        forRef ref: String,
        before date: Date = .distantFuture,
        in context: ModelContext
    ) throws -> [SetValue] {
        for session in try finishedSessions(in: context) where session.startedAt < date {
            for exercise in session.sortedExercises where exercise.exerciseRef == ref {
                let done = exercise.sortedSetLogs.filter(\.isDone).map { SetValue(weightKg: $0.weightKg, reps: $0.reps) }
                if !done.isEmpty { return done }
            }
        }
        return []
    }

    // MARK: - Start and edit

    /// Creates an active session. From a program day it copies the planned exercises with sets
    /// prefilled from the last session of each exercise; without a day the session is empty.
    @discardableResult
    static func startSession(
        day: ProgramDay?,
        emptyName: String = "Antrenman",
        in context: ModelContext,
        now: Date = .now
    ) throws -> WorkoutSession {
        let session = WorkoutSession(name: day?.name ?? emptyName, startedAt: now, programDayID: day?.uuid)
        context.insert(session)
        if let day {
            for planned in day.sortedExercises {
                let previous = try previousSets(forRef: planned.exerciseRef, in: context)
                try appendExercise(
                    ref: planned.exerciseRef,
                    name: planned.exerciseName,
                    restSeconds: planned.restSeconds,
                    setCount: planned.sets,
                    plannedReps: planned.repMin,
                    plannedWeightKg: planned.targetWeightKg ?? 0,
                    previous: previous,
                    to: session,
                    in: context
                )
            }
        }
        try context.save()
        return session
    }

    /// Adds an exercise (picked in the session) at the end with default sets, prefilled from history.
    @discardableResult
    static func addExercise(
        _ item: ExerciseItem,
        to session: WorkoutSession,
        restSeconds: Int = defaultRestSeconds,
        in context: ModelContext
    ) throws -> SessionExercise {
        let previous = try previousSets(forRef: item.id, in: context)
        let exercise = try appendExercise(
            ref: item.id,
            name: item.name,
            restSeconds: restSeconds,
            setCount: defaultSetCount,
            plannedReps: defaultReps,
            plannedWeightKg: 0,
            previous: previous,
            to: session,
            in: context
        )
        try context.save()
        return exercise
    }

    @discardableResult
    private static func appendExercise(
        ref: String,
        name: String,
        restSeconds: Int,
        setCount: Int,
        plannedReps: Int,
        plannedWeightKg: Double,
        previous: [SetValue],
        to session: WorkoutSession,
        in context: ModelContext
    ) throws -> SessionExercise {
        let order = (session.exercises ?? []).map(\.order).max().map { $0 + 1 } ?? 0
        let exercise = SessionExercise(exerciseRef: ref, exerciseName: name, order: order, restSeconds: restSeconds)
        context.insert(exercise)
        exercise.session = session
        let sets = WorkoutMath.prefill(
            previous: previous,
            setCount: setCount,
            plannedReps: plannedReps,
            plannedWeightKg: plannedWeightKg
        )
        for (index, set) in sets.enumerated() {
            let log = SetLog(order: index, reps: set.value.reps, weightKg: set.value.weightKg)
            context.insert(log)
            log.sessionExercise = exercise
        }
        return exercise
    }

    /// Appends a set that repeats the last one of the exercise (or default values when empty).
    @discardableResult
    static func addSet(to exercise: SessionExercise, in context: ModelContext) -> SetLog {
        let logs = exercise.sortedSetLogs
        let last = logs.last
        let log = SetLog(
            order: (logs.last?.order ?? -1) + 1,
            reps: last?.reps ?? defaultReps,
            weightKg: last?.weightKg ?? 0
        )
        context.insert(log)
        log.sessionExercise = exercise
        return log
    }

    /// Removes a set and renumbers the rest.
    static func deleteSet(_ log: SetLog, from exercise: SessionExercise, in context: ModelContext) {
        // Unlink first: a deleted model stays in the relationship array until the next save.
        exercise.setLogs?.removeAll { $0.uuid == log.uuid }
        context.delete(log)
        let remaining = exercise.sortedSetLogs
        for (index, set) in remaining.enumerated() { set.order = index }
    }

    static func deleteExercise(_ exercise: SessionExercise, in context: ModelContext) {
        exercise.session?.exercises?.removeAll { $0.uuid == exercise.uuid }
        context.delete(exercise)
    }

    /// Flips a set's done state; `completedAt` is set when it becomes done. Returns the new state.
    @discardableResult
    static func toggleSet(_ log: SetLog, now: Date = .now) -> Bool {
        log.isDone.toggle()
        log.completedAt = log.isDone ? now : nil
        return log.isDone
    }

    // MARK: - Finish

    /// Ends the session: drops sets that were not done (and exercises left empty), stores the
    /// end time and estimated energy, saves, and returns the summary.
    static func finish(
        _ session: WorkoutSession,
        catalog: ExerciseCatalog,
        in context: ModelContext,
        now: Date = .now
    ) throws -> SessionSummary {
        for exercise in session.sortedExercises {
            for log in exercise.sortedSetLogs where !log.isDone {
                context.delete(log)
            }
            if !exercise.sortedSetLogs.contains(where: \.isDone) {
                context.delete(exercise)
            }
        }
        // Save the deletions first so the relationships no longer list the removed rows.
        try context.save()
        session.endedAt = now
        let result = try summary(for: session, catalog: catalog, in: context, now: now)
        session.energyKcal = result.energyKcal
        try context.save()
        return result
    }

    /// True when no set of the session is done (the "Bitir" sheet then offers to discard it).
    static func hasNoDoneSets(_ session: WorkoutSession) -> Bool {
        !session.sortedExercises.contains { $0.sortedSetLogs.contains(where: \.isDone) }
    }

    static func discard(_ session: WorkoutSession, in context: ModelContext) throws {
        context.delete(session)
        try context.save()
    }

    // MARK: - Summary

    /// Summary of a session. PRs are detected against finished sessions that started earlier,
    /// so reopening an old session shows the records it set at the time.
    static func summary(
        for session: WorkoutSession,
        catalog: ExerciseCatalog,
        in context: ModelContext,
        now: Date = .now
    ) throws -> SessionSummary {
        var newSets: [SetRecord] = []
        var values: [SetValue] = []
        var metTotal = 0.0
        var exerciseCount = 0
        var namesByRef: [String: String] = [:]

        for exercise in session.sortedExercises {
            let done = exercise.sortedSetLogs.filter(\.isDone)
            guard !done.isEmpty else { continue }
            exerciseCount += 1
            namesByRef[exercise.exerciseRef] = exercise.exerciseName
            let met = catalog.met(forRef: exercise.exerciseRef) ?? WorkoutMath.fallbackMET
            for log in done {
                values.append(SetValue(weightKg: log.weightKg, reps: log.reps))
                metTotal += met
                newSets.append(SetRecord(
                    exerciseID: exercise.exerciseRef,
                    date: log.completedAt ?? session.startedAt,
                    weightKg: log.weightKg,
                    reps: log.reps
                ))
            }
        }

        let duration = max(0, (session.endedAt ?? now).timeIntervalSince(session.startedAt))
        let averageMET = values.isEmpty ? WorkoutMath.fallbackMET : metTotal / Double(values.count)
        let bodyWeightKg = try latestWeightKg(in: context)
        let kcal = Workout.metKcal(met: averageMET, weightKg: bodyWeightKg, minutes: duration / 60)

        let history = try historyRecords(before: session.startedAt, excluding: session.uuid, in: context)
        let records = PersonalRecords.detect(newSets: newSets, history: history).map { record in
            RecordItem(
                exerciseRef: record.exerciseID,
                exerciseName: namesByRef[record.exerciseID] ?? catalog.item(ref: record.exerciseID)?.name ?? "",
                kind: record.kind,
                valueKg: record.valueKg,
                previousBestKg: record.previousBestKg
            )
        }

        return SessionSummary(
            duration: duration,
            volumeKg: WorkoutMath.volume(of: values),
            doneSetCount: values.count,
            exerciseCount: exerciseCount,
            energyKcal: kcal,
            records: records
        )
    }

    private static func latestWeightKg(in context: ModelContext) throws -> Double {
        var weightDescriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\WeightEntry.date, order: .reverse)])
        weightDescriptor.fetchLimit = 1
        var healthDescriptor = FetchDescriptor<HealthDaySummary>(
            predicate: #Predicate { $0.bodyMassKg != nil },
            sortBy: [SortDescriptor(\HealthDaySummary.day, order: .reverse)]
        )
        healthDescriptor.fetchLimit = 1
        let user = try context.fetch(weightDescriptor).first.map { WorkoutMath.DatedWeight(date: $0.date, kg: $0.kg) }
        let health = try context.fetch(healthDescriptor).first.flatMap { row in
            row.bodyMassKg.map { WorkoutMath.DatedWeight(date: row.day, kg: $0) }
        }
        return WorkoutMath.bodyWeightKg(userEntry: user, health: health)
    }

    private static func historyRecords(
        before date: Date,
        excluding sessionID: UUID,
        in context: ModelContext
    ) throws -> [SetRecord] {
        var records: [SetRecord] = []
        for session in try finishedSessions(in: context) where session.startedAt < date && session.uuid != sessionID {
            for exercise in session.sortedExercises {
                for log in exercise.sortedSetLogs where log.isDone {
                    records.append(SetRecord(
                        exerciseID: exercise.exerciseRef,
                        date: log.completedAt ?? session.startedAt,
                        weightKg: log.weightKg,
                        reps: log.reps
                    ))
                }
            }
        }
        return records
    }

    /// Sum of weight x reps over the done sets of a session (history rows).
    static func volumeKg(of session: WorkoutSession) -> Double {
        let values = session.sortedExercises.flatMap { exercise in
            exercise.sortedSetLogs.filter(\.isDone).map { SetValue(weightKg: $0.weightKg, reps: $0.reps) }
        }
        return WorkoutMath.volume(of: values)
    }

    /// Elapsed time of a finished session; nil while it is active.
    static func duration(of session: WorkoutSession) -> TimeInterval? {
        session.endedAt.map { max(0, $0.timeIntervalSince(session.startedAt)) }
    }

    // MARK: - Programs

    /// Creates a program from a built-in template at the end of the program list.
    @discardableResult
    static func createProgram(
        from template: ProgramTemplate,
        catalog: SeedCatalog,
        in context: ModelContext,
        now: Date = .now
    ) throws -> Program {
        let programs = try context.fetch(FetchDescriptor<Program>())
        let program = Program(
            name: template.name,
            order: (programs.map(\.order).max() ?? -1) + 1,
            templateID: template.id
        )
        context.insert(program)
        for (dayIndex, dayTemplate) in template.days.enumerated() {
            let day = ProgramDay(name: dayTemplate.name, order: dayIndex)
            context.insert(day)
            day.program = program
            for (exerciseIndex, entry) in dayTemplate.exercises.enumerated() {
                let planned = PlannedExercise(
                    exerciseRef: ItemRef.seed(entry.exerciseID),
                    exerciseName: catalog.exercise(id: entry.exerciseID)?.nameTr ?? entry.exerciseID,
                    order: exerciseIndex,
                    sets: entry.sets,
                    repMin: entry.repMin,
                    repMax: entry.repMax,
                    restSeconds: entry.restSeconds
                )
                context.insert(planned)
                planned.day = day
            }
        }
        try context.save()
        return program
    }

    /// Adds an exercise to a program day with the default 3 x 8 and 90 s rest.
    @discardableResult
    static func addPlannedExercise(_ item: ExerciseItem, to day: ProgramDay, in context: ModelContext) -> PlannedExercise {
        let order = (day.exercises ?? []).map(\.order).max().map { $0 + 1 } ?? 0
        let planned = PlannedExercise(
            exerciseRef: item.id,
            exerciseName: item.name,
            order: order,
            sets: 3,
            repMin: 8,
            repMax: 8,
            restSeconds: 90
        )
        context.insert(planned)
        planned.day = day
        day.program?.updatedAt = .now
        return planned
    }
}
