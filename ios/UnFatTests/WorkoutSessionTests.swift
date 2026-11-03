import Foundation
import SwiftData
import Testing
import UnFatCore
@testable import UnFat

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@Suite("Workout math")
struct WorkoutMathTests {
    @Test func prefillUsesTheSameIndexOfTheLastSession() {
        let previous = [
            SetValue(weightKg: 60, reps: 10),
            SetValue(weightKg: 62.5, reps: 8),
            SetValue(weightKg: 65, reps: 6),
        ]
        let sets = WorkoutMath.prefill(previous: previous, setCount: 3, plannedReps: 8)
        #expect(sets.map(\.value) == previous)
        #expect(sets.map(\.previous) == previous)
    }

    @Test func prefillRepeatsTheLastSetForExtraSets() {
        let previous = [SetValue(weightKg: 50, reps: 12), SetValue(weightKg: 55, reps: 10)]
        let sets = WorkoutMath.prefill(previous: previous, setCount: 4, plannedReps: 8)
        #expect(sets.count == 4)
        #expect(sets[2].value == SetValue(weightKg: 55, reps: 10))
        #expect(sets[3].value == SetValue(weightKg: 55, reps: 10))
    }

    @Test func prefillWithoutHistoryUsesThePlan() {
        let sets = WorkoutMath.prefill(previous: [], setCount: 3, plannedReps: 8, plannedWeightKg: 40)
        #expect(sets.count == 3)
        #expect(sets.allSatisfy { $0.value == SetValue(weightKg: 40, reps: 8) })
        #expect(sets.allSatisfy { $0.previous == nil })
        #expect(WorkoutMath.prefill(previous: [], setCount: 0, plannedReps: 8).isEmpty)
    }

    @Test func volumeIsWeightTimesReps() {
        let sets = [SetValue(weightKg: 80, reps: 5), SetValue(weightKg: 62.5, reps: 8), SetValue(weightKg: 0, reps: 20)]
        #expect(WorkoutMath.volume(of: sets) == 400 + 500)
        #expect(WorkoutMath.volume(of: []) == 0)
    }
}

@Suite("Rest timer")
@MainActor
struct RestTimerTests {
    @Test func mathEndRemainingAndAdjust() {
        let end = RestTimerMath.end(start: t0, seconds: 90)
        #expect(end == t0.addingTimeInterval(90))
        #expect(RestTimerMath.remaining(end: end, now: t0.addingTimeInterval(30)) == 60)
        #expect(RestTimerMath.remaining(end: end, now: t0.addingTimeInterval(200)) == 0)

        let longer = RestTimerMath.adjustedEnd(start: t0, end: end, delta: 15, now: t0.addingTimeInterval(10))
        #expect(longer == t0.addingTimeInterval(105))
        let shorter = RestTimerMath.adjustedEnd(start: t0, end: end, delta: -15, now: t0.addingTimeInterval(10))
        #expect(shorter == t0.addingTimeInterval(75))
        // Moving the end to or before "now" ends the rest.
        #expect(RestTimerMath.adjustedEnd(start: t0, end: end, delta: -15, now: t0.addingTimeInterval(80)) == nil)
    }

    @Test func startAdjustAndSkip() {
        let timer = RestTimerController()
        var events: [RestTimerEvent] = []
        timer.onEvent = { events.append($0) }

        timer.start(seconds: 90, now: t0)
        #expect(timer.isRunning)
        #expect(timer.interval == t0...t0.addingTimeInterval(90))

        timer.adjust(by: 15, now: t0.addingTimeInterval(5))
        #expect(timer.endDate == t0.addingTimeInterval(105))
        timer.adjust(by: -15, now: t0.addingTimeInterval(5))
        #expect(timer.endDate == t0.addingTimeInterval(90))

        timer.skip()
        #expect(!timer.isRunning)
        #expect(timer.interval == nil)
        #expect(timer.finishedCount == 0)
        #expect(events == [
            .started(start: t0, end: t0.addingTimeInterval(90)),
            .adjusted(start: t0, end: t0.addingTimeInterval(105)),
            .adjusted(start: t0, end: t0.addingTimeInterval(90)),
            .skipped,
        ])
    }

    @Test func subtractingPastTheEndSkips() {
        let timer = RestTimerController()
        timer.start(seconds: 20, now: t0)
        timer.adjust(by: -15, now: t0.addingTimeInterval(10))
        #expect(!timer.isRunning)
    }

    @Test func completesOnlyAfterTheEndDate() {
        let timer = RestTimerController()
        var events: [RestTimerEvent] = []
        timer.onEvent = { events.append($0) }
        timer.start(seconds: 60, now: t0)

        #expect(!timer.completeIfElapsed(now: t0.addingTimeInterval(59)))
        #expect(timer.isRunning)
        #expect(timer.completeIfElapsed(now: t0.addingTimeInterval(60)))
        #expect(!timer.isRunning)
        #expect(timer.finishedCount == 1)
        #expect(events.last == .finished)
        // Nothing left to complete.
        #expect(!timer.completeIfElapsed(now: t0.addingTimeInterval(120)))
        #expect(timer.finishedCount == 1)
    }

    @Test func nonPositiveDurationDoesNotStart() {
        let timer = RestTimerController()
        timer.start(seconds: 0, now: t0)
        #expect(!timer.isRunning)
    }
}

@Suite("Program templates")
@MainActor
struct ProgramTemplateTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
    }

    @Test func templateShapes() {
        #expect(ProgramTemplate.fullBody.dayCount == 3)
        #expect(ProgramTemplate.upperLower.dayCount == 4)
        #expect(ProgramTemplate.pushPullLegs.dayCount == 6)
        #expect(ProgramTemplate.all.map(\.id) == ["full-body-3", "upper-lower-4", "ppl-6"])
        for template in ProgramTemplate.all {
            #expect(template.days.allSatisfy { !$0.exercises.isEmpty })
            for day in template.days {
                let ids = day.exercises.map(\.exerciseID)
                #expect(Set(ids).count == ids.count)
            }
        }
    }

    @Test func templateExercisesExistInTheBundledSeed() {
        let seed = SeedCatalog.shared
        // The seed is empty when the bundle resource is missing (e.g. a bare test host).
        guard !seed.exercises.isEmpty else { return }
        for template in ProgramTemplate.all {
            for day in template.days {
                for entry in day.exercises {
                    #expect(seed.exercise(id: entry.exerciseID) != nil, "missing \(entry.exerciseID)")
                }
            }
        }
    }

    @Test func createProgramCopiesTheTemplate() throws {
        for template in ProgramTemplate.all {
            let program = try WorkoutSessionService.createProgram(from: template, catalog: .empty, in: context)
            #expect(program.name == template.name)
            #expect(program.templateID == template.id)
            #expect(program.sortedDays.count == template.dayCount)
            for (day, dayTemplate) in zip(program.sortedDays, template.days) {
                #expect(day.name == dayTemplate.name)
                #expect(day.sortedExercises.count == dayTemplate.exercises.count)
                for (planned, entry) in zip(day.sortedExercises, dayTemplate.exercises) {
                    #expect(planned.exerciseRef == ItemRef.seed(entry.exerciseID))
                    #expect(planned.sets == entry.sets)
                    #expect(planned.repMin == entry.repMin)
                    #expect(planned.repMax == entry.repMax)
                    #expect(planned.restSeconds == entry.restSeconds)
                }
            }
        }
        let programs = try context.fetch(FetchDescriptor<Program>())
        #expect(programs.count == 3)
        #expect(Set(programs.map(\.order)).count == 3)
    }

    @Test func createProgramTwiceKeepsBothCopies() throws {
        try WorkoutSessionService.createProgram(from: .fullBody, catalog: .empty, in: context)
        try WorkoutSessionService.createProgram(from: .fullBody, catalog: .empty, in: context)
        #expect(try context.fetch(FetchDescriptor<Program>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<ProgramDay>()).count == 6)
    }
}

@Suite("Workout session service")
@MainActor
struct WorkoutSessionServiceTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
    }

    private static let ref = ItemRef.custom(UUID(uuidString: "11111111-2222-3333-4444-555555555555")!)

    private func item(met: Double = 6) -> ExerciseItem {
        ExerciseItem(id: Self.ref, name: "Test lift", muscle: .chest, equipment: .barbell, met: met, isCustom: true)
    }

    private var catalog: ExerciseCatalog {
        ExerciseCatalog(seed: .empty, custom: [item()])
    }

    /// Runs and finishes one session with `sets` done sets of `weight` x `reps`.
    @discardableResult
    private func finishedSession(
        start: Date,
        minutes: Double = 60,
        weight: Double,
        reps: Int,
        sets: Int = 3
    ) throws -> (WorkoutSession, SessionSummary) {
        let session = try WorkoutSessionService.startSession(day: nil, in: context, now: start)
        let exercise = try WorkoutSessionService.addExercise(item(), to: session, in: context)
        for log in exercise.sortedSetLogs.prefix(sets) {
            log.weightKg = weight
            log.reps = reps
            WorkoutSessionService.toggleSet(log, now: start.addingTimeInterval(600))
        }
        let summary = try WorkoutSessionService.finish(
            session,
            catalog: catalog,
            in: context,
            now: start.addingTimeInterval(minutes * 60)
        )
        return (session, summary)
    }

    @Test func startFromADayCopiesPlannedExercisesWithPlannedValues() throws {
        let program = try WorkoutSessionService.createProgram(from: .fullBody, catalog: .empty, in: context)
        let day = try #require(program.sortedDays.first)
        let session = try WorkoutSessionService.startSession(day: day, in: context, now: t0)

        #expect(session.isActive)
        #expect(session.name == day.name)
        #expect(session.programDayID == day.uuid)
        #expect(session.sortedExercises.count == day.sortedExercises.count)
        for (exercise, planned) in zip(session.sortedExercises, day.sortedExercises) {
            #expect(exercise.exerciseRef == planned.exerciseRef)
            #expect(exercise.restSeconds == planned.restSeconds)
            #expect(exercise.sortedSetLogs.count == planned.sets)
            #expect(exercise.sortedSetLogs.allSatisfy { $0.reps == planned.repMin && !$0.isDone })
        }
        #expect(WorkoutSessionService.activeSession(in: context)?.uuid == session.uuid)
    }

    @Test func emptySessionStartsWithoutExercises() throws {
        let session = try WorkoutSessionService.startSession(day: nil, emptyName: "Antrenman", in: context, now: t0)
        #expect(session.name == "Antrenman")
        #expect(session.programDayID == nil)
        #expect(session.sortedExercises.isEmpty)
        #expect(WorkoutSessionService.hasNoDoneSets(session))
    }

    @Test func nextSessionIsPrefilledFromTheLastOne() throws {
        try finishedSession(start: t0, weight: 70, reps: 8)

        let session = try WorkoutSessionService.startSession(day: nil, in: context, now: t0.addingTimeInterval(86_400))
        let exercise = try WorkoutSessionService.addExercise(item(), to: session, in: context)
        let logs = exercise.sortedSetLogs
        #expect(logs.count == 3)
        #expect(logs.allSatisfy { $0.weightKg == 70 && $0.reps == 8 && !$0.isDone })

        let previous = try WorkoutSessionService.previousSets(forRef: Self.ref, before: .distantFuture, in: context)
        #expect(previous == Array(repeating: SetValue(weightKg: 70, reps: 8), count: 3))
    }

    @Test func toggleSetStoresCompletionTime() throws {
        let session = try WorkoutSessionService.startSession(day: nil, in: context, now: t0)
        let exercise = try WorkoutSessionService.addExercise(item(), to: session, in: context)
        let log = try #require(exercise.sortedSetLogs.first)

        #expect(WorkoutSessionService.toggleSet(log, now: t0.addingTimeInterval(30)))
        #expect(log.isDone)
        #expect(log.completedAt == t0.addingTimeInterval(30))
        #expect(!WorkoutSessionService.hasNoDoneSets(session))
        #expect(!WorkoutSessionService.toggleSet(log))
        #expect(log.completedAt == nil)
    }

    @Test func addAndDeleteSetsKeepOrderContiguous() throws {
        let session = try WorkoutSessionService.startSession(day: nil, in: context, now: t0)
        let exercise = try WorkoutSessionService.addExercise(item(), to: session, in: context)
        let added = WorkoutSessionService.addSet(to: exercise, in: context)
        #expect(added.order == 3)
        #expect(exercise.sortedSetLogs.count == 4)

        WorkoutSessionService.deleteSet(exercise.sortedSetLogs[1], from: exercise, in: context)
        #expect(exercise.sortedSetLogs.map(\.order) == [0, 1, 2])
    }

    @Test func finishDropsUndoneSetsAndSummarizesVolume() throws {
        let session = try WorkoutSessionService.startSession(day: nil, in: context, now: t0)
        let exercise = try WorkoutSessionService.addExercise(item(), to: session, in: context)
        let logs = exercise.sortedSetLogs
        for log in logs.prefix(2) {
            log.weightKg = 60
            log.reps = 10
            WorkoutSessionService.toggleSet(log, now: t0.addingTimeInterval(300))
        }
        let summary = try WorkoutSessionService.finish(session, catalog: catalog, in: context, now: t0.addingTimeInterval(1_800))

        #expect(!session.isActive)
        #expect(session.endedAt == t0.addingTimeInterval(1_800))
        #expect(exercise.sortedSetLogs.count == 2)
        #expect(summary.doneSetCount == 2)
        #expect(summary.exerciseCount == 1)
        #expect(summary.volumeKg == 1_200)
        #expect(summary.duration == 1_800)
        #expect(session.energyKcal == summary.energyKcal)
        #expect(WorkoutSessionService.activeSession(in: context) == nil)
        #expect(WorkoutSessionService.volumeKg(of: session) == 1_200)
        #expect(WorkoutSessionService.duration(of: session) == 1_800)
    }

    @Test func finishRemovesExercisesWithoutDoneSets() throws {
        let session = try WorkoutSessionService.startSession(day: nil, in: context, now: t0)
        try WorkoutSessionService.addExercise(item(), to: session, in: context)
        _ = try WorkoutSessionService.finish(session, catalog: catalog, in: context, now: t0.addingTimeInterval(60))
        #expect(session.sortedExercises.isEmpty)
    }

    @Test func summaryEnergyUsesMETAndLatestBodyWeight() throws {
        context.insert(WeightEntry(date: t0.addingTimeInterval(-86_400 * 3), kg: 90))
        context.insert(WeightEntry(date: t0.addingTimeInterval(-86_400), kg: 80))
        // MET 6, 80 kg, 60 minutes: (6 - 1) * 3.5 * 80 / 200 * 60 = 420 kcal.
        let (_, summary) = try finishedSession(start: t0, minutes: 60, weight: 50, reps: 10)
        #expect(abs(summary.energyKcal - 420) < 0.001)
    }

    @Test func summaryEnergyFallsBackWithoutWeightOrCatalogEntry() throws {
        let session = try WorkoutSessionService.startSession(day: nil, in: context, now: t0)
        let unknown = ExerciseItem(id: "seed:fixture-unknown", name: "Unknown", muscle: .back, equipment: .other)
        let exercise = try WorkoutSessionService.addExercise(unknown, to: session, in: context)
        let log = try #require(exercise.sortedSetLogs.first)
        WorkoutSessionService.toggleSet(log, now: t0.addingTimeInterval(60))
        let summary = try WorkoutSessionService.finish(
            session,
            catalog: ExerciseCatalog(seed: .empty),
            in: context,
            now: t0.addingTimeInterval(3_600)
        )
        // MET 5.0 and 70 kg for 60 minutes: (5 - 1) * 3.5 * 70 / 200 * 60 = 294 kcal.
        #expect(abs(summary.energyKcal - 294) < 0.001)
    }

    @Test func firstSessionHasNoRecords() throws {
        let (_, summary) = try finishedSession(start: t0, weight: 80, reps: 5)
        #expect(summary.records.isEmpty)
    }

    @Test func heavierLaterSessionSetsRecords() throws {
        try finishedSession(start: t0, weight: 80, reps: 5)
        let (_, summary) = try finishedSession(start: t0.addingTimeInterval(86_400), weight: 85, reps: 5)

        let kinds = Set(summary.records.map(\.kind))
        #expect(kinds == [.estimatedOneRepMax, .maxWeight])
        let maxWeight = try #require(summary.records.first { $0.kind == .maxWeight })
        #expect(maxWeight.exerciseRef == Self.ref)
        #expect(maxWeight.exerciseName == "Test lift")
        #expect(maxWeight.valueKg == 85)
        #expect(maxWeight.previousBestKg == 80)
    }

    @Test func equalOrLighterSessionSetsNoRecords() throws {
        try finishedSession(start: t0, weight: 80, reps: 5)
        let (_, summary) = try finishedSession(start: t0.addingTimeInterval(86_400), weight: 80, reps: 5)
        #expect(summary.records.isEmpty)
    }

    @Test func reopeningAnOldSessionKeepsItsOwnRecords() throws {
        try finishedSession(start: t0, weight: 80, reps: 5)
        let (second, original) = try finishedSession(start: t0.addingTimeInterval(86_400), weight: 85, reps: 5)
        try finishedSession(start: t0.addingTimeInterval(2 * 86_400), weight: 90, reps: 5)

        let again = try WorkoutSessionService.summary(for: second, catalog: catalog, in: context)
        #expect(again.records == original.records)
        #expect(!again.records.isEmpty)
    }

    @Test func discardRemovesTheSession() throws {
        let session = try WorkoutSessionService.startSession(day: nil, in: context, now: t0)
        try WorkoutSessionService.discard(session, in: context)
        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
        #expect(WorkoutSessionService.activeSession(in: context) == nil)
    }

    @Test func finishedSessionsAreNewestFirst() throws {
        try finishedSession(start: t0, weight: 50, reps: 10)
        try finishedSession(start: t0.addingTimeInterval(86_400), weight: 50, reps: 10)
        _ = try WorkoutSessionService.startSession(day: nil, in: context, now: t0.addingTimeInterval(2 * 86_400))

        let finished = try WorkoutSessionService.finishedSessions(in: context)
        #expect(finished.count == 2)
        #expect(finished[0].startedAt > finished[1].startedAt)
    }

    @Test func plannedExerciseGetsDefaults() throws {
        let program = Program(name: "P")
        context.insert(program)
        let day = ProgramDay(name: "D", order: 0)
        context.insert(day)
        day.program = program

        let first = WorkoutSessionService.addPlannedExercise(item(), to: day, in: context)
        let second = WorkoutSessionService.addPlannedExercise(item(), to: day, in: context)
        #expect(first.sets == 3 && first.repMin == 8 && first.repMax == 8 && first.restSeconds == 90)
        #expect(first.order == 0 && second.order == 1)
        #expect(first.exerciseRef == Self.ref)
    }
}

@Suite("Exercise catalog")
struct ExerciseCatalogTests {
    private func custom(_ name: String, muscle: Muscle = .chest) -> ExerciseItem {
        ExerciseItem(
            id: ItemRef.custom(UUID()),
            name: name,
            muscle: muscle,
            equipment: .bodyweight,
            isCustom: true
        )
    }

    @Test func searchIgnoresTurkishDiacriticsAndListsCustomFirst() {
        let seed = SeedCatalog(
            foods: [],
            exercises: [
                SeedExercise(
                    id: "ex-1",
                    nameTr: "Şınav",
                    nameEn: "Push-up",
                    primaryMuscle: .chest,
                    secondaryMuscles: [],
                    equipment: .bodyweight,
                    kind: .strength,
                    met: 3.8
                ),
            ]
        )
        let catalog = ExerciseCatalog(seed: seed, custom: [custom("Sinav varyasyonu")])

        let results = catalog.search("sinav")
        #expect(results.map(\.name) == ["Sinav varyasyonu", "Şınav"])
        #expect(results.first?.isCustom == true)
        #expect(catalog.search("").count == 2)
        #expect(catalog.search("sinav", muscle: .back).isEmpty)
        #expect(catalog.item(ref: ItemRef.seed("ex-1"))?.name == "Şınav")
        #expect(catalog.met(forRef: "seed:missing") == nil)
    }
}

#if DEBUG
@Test func workoutDebugRoutesParse() {
    let names = ["workout-empty", "program-editor", "exercise-picker", "session", "session-summary"]
    for name in names {
        #expect(LaunchRouter.route(arguments: ["UnFat", "-UNFAT_SCREEN", name]) != nil, "route \(name)")
    }
    #expect(LaunchRoute.workoutEmpty.destination == .screen(.workout(.empty)))
    #expect(LaunchRoute.sessionSummary.destination == .screen(.workout(.sessionSummary)))
}
#endif
