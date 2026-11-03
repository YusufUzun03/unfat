import Foundation
import SwiftData
import Testing
import UnFatCore
@testable import UnFat

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func exercise(_ name: String, _ sets: [Bool], rest: Int = 90) -> WorkoutExerciseProgress {
    WorkoutExerciseProgress(name: name, sets: sets, restSeconds: rest)
}

private typealias ContentState = WorkoutActivityAttributes.ContentState

// MARK: - Next set

@Suite("Live Activity next set")
struct LiveActivityNextSetTests {
    @Test func firstOpenSetWins() {
        let exercises = [exercise("Bench", [true, false, false]), exercise("Row", [false, false])]
        #expect(WorkoutLiveActivityLogic.nextSet(in: exercises) == WorkoutNextSet(exerciseIndex: 0, setIndex: 1, isComplete: false))
    }

    @Test func movesOnToTheNextExerciseWhenOneIsDone() {
        let exercises = [exercise("Bench", [true, true]), exercise("Row", [true, false])]
        #expect(WorkoutLiveActivityLogic.nextSet(in: exercises) == WorkoutNextSet(exerciseIndex: 1, setIndex: 1, isComplete: false))
    }

    @Test func takesTheEarliestOpenSetWhenDoneOutOfOrder() {
        let exercises = [exercise("Bench", [true, false, true])]
        #expect(WorkoutLiveActivityLogic.nextSet(in: exercises) == WorkoutNextSet(exerciseIndex: 0, setIndex: 1, isComplete: false))
    }

    @Test func everySetDonePointsAtTheLastSetAndIsComplete() {
        let exercises = [exercise("Bench", [true, true]), exercise("Row", [true, true, true])]
        #expect(WorkoutLiveActivityLogic.nextSet(in: exercises) == WorkoutNextSet(exerciseIndex: 1, setIndex: 2, isComplete: true))
    }

    @Test func trailingExerciseWithoutSetsIsSkippedWhenComplete() {
        let exercises = [exercise("Bench", [true]), exercise("Empty", [])]
        #expect(WorkoutLiveActivityLogic.nextSet(in: exercises) == WorkoutNextSet(exerciseIndex: 0, setIndex: 0, isComplete: true))
    }

    @Test func noSetsAtAllHasNoNextSet() {
        #expect(WorkoutLiveActivityLogic.nextSet(in: []) == nil)
        #expect(WorkoutLiveActivityLogic.nextSet(in: [exercise("Empty", [])]) == nil)
    }

    @Test func countsDoneSets() {
        let exercises = [exercise("Bench", [true, false, true]), exercise("Row", [true])]
        #expect(WorkoutLiveActivityLogic.doneCount(in: exercises) == 3)
        #expect(WorkoutLiveActivityLogic.doneCount(in: []) == 0)
    }
}

// MARK: - Content

@Suite("Live Activity content")
struct LiveActivityContentTests {
    private let rest = t0...t0.addingTimeInterval(90)

    @Test func showsTheNextOpenSet() {
        let state = WorkoutLiveActivityLogic.contentState(
            workoutName: "A Günü",
            exercises: [exercise("Bench", [true, false, false]), exercise("Row", [false, false])],
            rest: nil,
            restOver: false
        )
        #expect(state == ContentState(exerciseName: "Bench", setNumber: 2, setCount: 3))
    }

    @Test func movesToTheNextExerciseAfterTheLastSet() {
        let state = WorkoutLiveActivityLogic.contentState(
            workoutName: "A Günü",
            exercises: [exercise("Bench", [true, true]), exercise("Row", [false, false, false])],
            rest: nil,
            restOver: false
        )
        #expect(state.exerciseName == "Row")
        #expect(state.setNumber == 1)
        #expect(state.setCount == 3)
        #expect(state.canCompleteSet)
    }

    @Test func completeWorkoutHidesTheCompleteButton() {
        let state = WorkoutLiveActivityLogic.contentState(
            workoutName: "A Günü",
            exercises: [exercise("Bench", [true, true, true])],
            rest: nil,
            restOver: false
        )
        #expect(state.exerciseName == "Bench")
        #expect(state.setNumber == 3)
        #expect(state.setCount == 3)
        #expect(!state.canCompleteSet)
    }

    @Test func workoutWithoutSetsShowsItsNameAndNoButton() {
        let state = WorkoutLiveActivityLogic.contentState(workoutName: "A Günü", exercises: [], rest: nil, restOver: false)
        #expect(state.exerciseName == "A Günü")
        #expect(state.setNumber == 0)
        #expect(state.setCount == 0)
        #expect(!state.canCompleteSet)
    }

    @Test func carriesTheRunningRest() {
        let state = WorkoutLiveActivityLogic.contentState(
            workoutName: "A Günü",
            exercises: [exercise("Bench", [true, false])],
            rest: rest,
            restOver: false
        )
        #expect(state.restStart == rest.lowerBound)
        #expect(state.restEnd == rest.upperBound)
        #expect(!state.restOver)
    }

    @Test func restOverOnlyCountsWithoutARunningRest() {
        let exercises = [exercise("Bench", [true, false])]
        let running = WorkoutLiveActivityLogic.contentState(workoutName: "A", exercises: exercises, rest: rest, restOver: true)
        #expect(!running.restOver)
        let idle = WorkoutLiveActivityLogic.contentState(workoutName: "A", exercises: exercises, rest: nil, restOver: true)
        #expect(idle.restOver)
        #expect(idle.restStart == nil)
        #expect(idle.restEnd == nil)
    }

    @Test func stateSurvivesJSONRoundTrip() throws {
        let state = ContentState(
            exerciseName: "Bench",
            setNumber: 2,
            setCount: 4,
            restStart: t0,
            restEnd: t0.addingTimeInterval(60),
            restOver: false,
            canCompleteSet: true
        )
        let decoded = try JSONDecoder().decode(ContentState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
    }
}

// MARK: - Phase

@Suite("Live Activity phase")
struct LiveActivityPhaseTests {
    private func state(start: Date? = nil, end: Date? = nil, restOver: Bool = false) -> ContentState {
        ContentState(exerciseName: "Bench", setNumber: 1, setCount: 3, restStart: start, restEnd: end, restOver: restOver)
    }

    @Test func runningRestIsResting() {
        let running = state(start: t0, end: t0.addingTimeInterval(60))
        #expect(running.restPhase(isStale: false, now: t0.addingTimeInterval(10)) == .resting(t0...t0.addingTimeInterval(60)))
    }

    @Test func staleRestIsOver() {
        let running = state(start: t0, end: t0.addingTimeInterval(60))
        #expect(running.restPhase(isStale: true, now: t0.addingTimeInterval(10)) == .over)
    }

    @Test func elapsedRestIsOverEvenWhenNotStale() {
        let running = state(start: t0, end: t0.addingTimeInterval(60))
        #expect(running.restPhase(isStale: false, now: t0.addingTimeInterval(61)) == .over)
        #expect(running.restPhase(isStale: false, now: t0.addingTimeInterval(60)) == .over)
    }

    @Test func restOverFlagIsOver() {
        #expect(state(restOver: true).restPhase(isStale: false, now: t0) == .over)
        let withWindow = state(start: t0, end: t0.addingTimeInterval(60), restOver: true)
        #expect(withWindow.restPhase(isStale: false, now: t0.addingTimeInterval(10)) == .over)
    }

    @Test func noRestIsNotResting() {
        #expect(state().restPhase(isStale: false, now: t0) == .notResting)
        // A stale activity without a rest has nothing that could have run out.
        #expect(state().restPhase(isStale: true, now: t0) == .notResting)
    }

    @Test func brokenWindowIsNotResting() {
        let broken = state(start: t0.addingTimeInterval(60), end: t0)
        #expect(broken.restPhase(isStale: false, now: t0) == .notResting)
    }

    @Test func staleDateIsTheEndOfTheRunningRest() {
        #expect(state(start: t0, end: t0.addingTimeInterval(60)).staleDate == t0.addingTimeInterval(60))
        #expect(state().staleDate == nil)
        #expect(state(restOver: true).staleDate == nil)
        #expect(state(start: t0, end: t0.addingTimeInterval(60), restOver: true).staleDate == nil)
    }
}

// MARK: - Activities

@Suite("Live Activity reconcile")
struct LiveActivityReconcileTests {
    private let a = UUID()
    private let b = UUID()

    @Test func withoutADesiredSessionEverythingEnds() {
        let none = WorkoutLiveActivityLogic.reconcile(existing: [], desired: nil, isSuppressed: false)
        #expect(none == WorkoutActivityReconciliation(endIndices: [], updateIndex: nil, requestsNew: false))
        let orphans = WorkoutLiveActivityLogic.reconcile(existing: [a, b], desired: nil, isSuppressed: false)
        #expect(orphans == WorkoutActivityReconciliation(endIndices: [0, 1], updateIndex: nil, requestsNew: false))
    }

    @Test func keepsTheMatchAndEndsTheRest() {
        let plan = WorkoutLiveActivityLogic.reconcile(existing: [b, a, a], desired: a, isSuppressed: false)
        #expect(plan == WorkoutActivityReconciliation(endIndices: [0, 2], updateIndex: 1, requestsNew: false))
    }

    @Test func requestsANewActivityWhenNoneMatches() {
        let fresh = WorkoutLiveActivityLogic.reconcile(existing: [], desired: a, isSuppressed: false)
        #expect(fresh == WorkoutActivityReconciliation(endIndices: [], updateIndex: nil, requestsNew: true))
        let replaced = WorkoutLiveActivityLogic.reconcile(existing: [b], desired: a, isSuppressed: false)
        #expect(replaced == WorkoutActivityReconciliation(endIndices: [0], updateIndex: nil, requestsNew: true))
    }

    @Test func aDismissedActivityIsNotRequestedAgain() {
        let plan = WorkoutLiveActivityLogic.reconcile(existing: [], desired: a, isSuppressed: true)
        #expect(plan == WorkoutActivityReconciliation(endIndices: [], updateIndex: nil, requestsNew: false))
    }

    @Test func suppressionDoesNotStopUpdatesOfAnExistingActivity() {
        let plan = WorkoutLiveActivityLogic.reconcile(existing: [a], desired: a, isSuppressed: true)
        #expect(plan == WorkoutActivityReconciliation(endIndices: [], updateIndex: 0, requestsNew: false))
    }
}

// MARK: - Notification

@Suite("Live Activity notification")
struct LiveActivityNotificationTests {
    private let rest = t0...t0.addingTimeInterval(90)

    @Test func planNamesTheNextExerciseWhileASetIsOpen() {
        let state = ContentState(exerciseName: "Bench", setNumber: 2, setCount: 3)
        let plan = WorkoutLiveActivityLogic.notificationPlan(state: state, rest: rest)
        #expect(plan == WorkoutRestNotificationPlan(end: rest.upperBound, exerciseName: "Bench"))
    }

    @Test func planOmitsTheNameWhenEverySetIsDone() {
        let state = ContentState(exerciseName: "Bench", setNumber: 3, setCount: 3, canCompleteSet: false)
        let plan = WorkoutLiveActivityLogic.notificationPlan(state: state, rest: rest)
        #expect(plan == WorkoutRestNotificationPlan(end: rest.upperBound, exerciseName: nil))
    }

    @Test func noPlanWithoutASessionOrARest() {
        let state = ContentState(exerciseName: "Bench", setNumber: 1, setCount: 3)
        #expect(WorkoutLiveActivityLogic.notificationPlan(state: nil, rest: rest) == nil)
        #expect(WorkoutLiveActivityLogic.notificationPlan(state: state, rest: nil) == nil)
        #expect(WorkoutLiveActivityLogic.notificationPlan(state: nil, rest: nil) == nil)
    }

    @Test func delayIsOnlyDefinedForTheFuture() {
        let end = t0.addingTimeInterval(60)
        #expect(WorkoutLiveActivityLogic.notificationDelay(end: end, now: t0) == 60)
        #expect(WorkoutLiveActivityLogic.notificationDelay(end: end, now: end) == nil)
        #expect(WorkoutLiveActivityLogic.notificationDelay(end: end, now: end.addingTimeInterval(1)) == nil)
    }

    @Test func identifierIsFixedSoANewScheduleReplacesTheOld() {
        #expect(WorkoutRestNotification.identifier == "workout-rest-end")
    }
}

// MARK: - Relaunch

@Suite("Live Activity relaunch")
struct LiveActivityRelaunchTests {
    private let session = UUID()

    private func stored(start: Date = t0, end: Date = t0.addingTimeInterval(90), session: UUID? = nil) -> WorkoutRestState {
        WorkoutRestState(sessionID: session ?? self.session, start: start, end: end)
    }

    @Test func runningRestIsRecovered() {
        let recovery = WorkoutLiveActivityLogic.recover(stored(), activeSessionID: session, now: t0.addingTimeInterval(30))
        #expect(recovery == .running(t0...t0.addingTimeInterval(90)))
    }

    @Test func expiredRestIsOver() {
        let atEnd = WorkoutLiveActivityLogic.recover(stored(), activeSessionID: session, now: t0.addingTimeInterval(90))
        #expect(atEnd == .over)
        let later = WorkoutLiveActivityLogic.recover(stored(), activeSessionID: session, now: t0.addingTimeInterval(600))
        #expect(later == .over)
    }

    @Test func unusableStateIsIgnored() {
        let now = t0.addingTimeInterval(30)
        #expect(WorkoutLiveActivityLogic.recover(nil, activeSessionID: session, now: now) == .none)
        #expect(WorkoutLiveActivityLogic.recover(stored(), activeSessionID: nil, now: now) == .none)
        #expect(WorkoutLiveActivityLogic.recover(stored(), activeSessionID: UUID(), now: now) == .none)
        let broken = stored(start: t0.addingTimeInterval(120), end: t0)
        #expect(WorkoutLiveActivityLogic.recover(broken, activeSessionID: session, now: now) == .none)
    }
}

@Suite("Live Activity rest state file")
struct LiveActivityRestStateStoreTests {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appending(
            path: "workout-rest-state-\(UUID().uuidString).json",
            directoryHint: .notDirectory
        )
    }

    private let state = WorkoutRestState(
        sessionID: UUID(uuidString: "5B1A6E55-0D5C-4C69-9E34-2D6A7E0C9B11") ?? UUID(),
        start: t0,
        end: t0.addingTimeInterval(90)
    )

    @Test func writesAndReadsBack() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try WorkoutRestStateStore.write(state, to: url)
        #expect(WorkoutRestStateStore.read(from: url) == state)
    }

    @Test func nilRemovesTheFile() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try WorkoutRestStateStore.write(state, to: url)
        try WorkoutRestStateStore.write(nil, to: url)
        #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
        #expect(WorkoutRestStateStore.read(from: url) == nil)
        // Removing what is not there is not an error.
        try WorkoutRestStateStore.write(nil, to: url)
    }

    @Test func missingOrBrokenFilesReadAsNil() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(WorkoutRestStateStore.read(from: url) == nil)
        #expect(WorkoutRestStateStore.read(from: nil) == nil)
        try Data("not json".utf8).write(to: url)
        #expect(WorkoutRestStateStore.read(from: url) == nil)
    }

    @Test func missingContainerThrows() {
        #expect(throws: WorkoutRestStateStore.StoreError.self) {
            try WorkoutRestStateStore.write(state, to: nil)
        }
    }
}

@Suite("Rest timer restore")
@MainActor
struct RestTimerRestoreTests {
    @Test func restoresARunningRestWithoutAnEvent() {
        let timer = RestTimerController()
        var events: [RestTimerEvent] = []
        timer.onEvent = { events.append($0) }

        timer.restore(start: t0, end: t0.addingTimeInterval(90), now: t0.addingTimeInterval(30))
        #expect(timer.isRunning)
        #expect(timer.interval == t0...t0.addingTimeInterval(90))
        #expect(events.isEmpty)
        #expect(timer.finishedCount == 0)
    }

    @Test func ignoresARestThatIsAlreadyOver() {
        let timer = RestTimerController()
        timer.restore(start: t0, end: t0.addingTimeInterval(90), now: t0.addingTimeInterval(90))
        #expect(!timer.isRunning)
        timer.restore(start: t0, end: t0.addingTimeInterval(90), now: t0.addingTimeInterval(200))
        #expect(!timer.isRunning)
    }

    @Test func ignoresABrokenWindow() {
        let timer = RestTimerController()
        timer.restore(start: t0.addingTimeInterval(90), end: t0, now: t0.addingTimeInterval(-10))
        #expect(!timer.isRunning)
        #expect(timer.interval == nil)
    }
}

// MARK: - Intent bridge

@Suite("Workout intent bridge")
@MainActor
struct WorkoutIntentBridgeTests {
    @MainActor
    final class Recorder {
        var actions: [WorkoutIntentAction] = []
    }

    @Test func queuesUntilTheHandlerIsInstalledThenReplaysInOrder() async throws {
        // The hosted test app already installed its own handler; put it back at the end.
        let original = WorkoutIntentBridge.handler
        defer { WorkoutIntentBridge.handler = original }
        WorkoutIntentBridge.handler = nil

        let recorder = Recorder()
        await WorkoutIntentBridge.perform(.skipRest)
        await WorkoutIntentBridge.perform(.addRestTime)
        #expect(recorder.actions.isEmpty)

        WorkoutIntentBridge.handler = { action in recorder.actions.append(action) }
        for _ in 0..<200 where recorder.actions.count < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(recorder.actions == [.skipRest, .addRestTime])

        // With a handler installed an action runs straight away, and only once.
        await WorkoutIntentBridge.perform(.completeSet)
        #expect(recorder.actions == [.skipRest, .addRestTime, .completeSet])
    }
}

// MARK: - Controller (not live: no ActivityKit, notifications or App Group)

@Suite("Live Activity controller")
@MainActor
struct WorkoutLiveActivityControllerTests {
    let container: ModelContainer
    let controller: WorkoutLiveActivityController
    var context: ModelContext { container.mainContext }
    var rest: RestTimerController { controller.rest }

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        controller = WorkoutLiveActivityController(container: container, rest: RestTimerController(), isLive: false)
    }

    private func item() -> ExerciseItem {
        let ref = ItemRef.custom(UUID(uuidString: "11111111-2222-3333-4444-555555555555")!)
        return ExerciseItem(id: ref, name: "Test lift", muscle: .chest, equipment: .barbell, met: 6, isCustom: true)
    }

    private func startSession() throws -> (WorkoutSession, SessionExercise) {
        let session = try WorkoutSessionService.startSession(day: nil, emptyName: "A Günü", in: context, now: t0)
        let exercise = try WorkoutSessionService.addExercise(item(), to: session, in: context)
        return (session, exercise)
    }

    @Test func unitTestsNeverRunLive() {
        #expect(!WorkoutLiveActivityController.shouldRunLive())
    }

    @Test func noSessionMeansNoActivity() {
        #expect(controller.currentDesired() == nil)
    }

    @Test func desiredStateFollowsTheSession() throws {
        let (session, _) = try startSession()
        let desired = try #require(controller.currentDesired())
        #expect(desired.sessionID == session.uuid)
        #expect(desired.workoutName == "A Günü")
        #expect(desired.state == ContentState(exerciseName: "Test lift", setNumber: 1, setCount: 3))
    }

    @Test func completeSetButtonMarksTheNextSetAndStartsTheRest() async throws {
        let (_, lift) = try startSession()
        await controller.handle(.completeSet)

        #expect(lift.sortedSetLogs.map(\.isDone) == [true, false, false])
        let interval = try #require(rest.interval)
        #expect(abs(interval.upperBound.timeIntervalSince(interval.lowerBound) - 90) < 0.001)

        let state = try #require(controller.currentDesired()).state
        #expect(state.setNumber == 2)
        #expect(state.restStart == interval.lowerBound)
        #expect(state.restEnd == interval.upperBound)
        #expect(state.canCompleteSet)
    }

    @Test func completeSetButtonStopsAtTheLastSet() async throws {
        let (_, lift) = try startSession()
        for _ in 0..<5 {
            await controller.handle(.completeSet)
        }
        #expect(lift.sortedSetLogs.map(\.isDone) == [true, true, true])
        let state = try #require(controller.currentDesired()).state
        #expect(state.setNumber == 3)
        #expect(!state.canCompleteSet)
    }

    @Test func addRestTimeMovesTheEndByFifteenSeconds() async throws {
        _ = try startSession()
        await controller.handle(.addRestTime)
        #expect(!rest.isRunning, "nothing to extend without a rest")

        await controller.handle(.completeSet)
        let before = try #require(rest.endDate)
        await controller.handle(.addRestTime)
        #expect(rest.endDate == before.addingTimeInterval(15))
        let state = try #require(controller.currentDesired()).state
        #expect(state.restEnd == before.addingTimeInterval(15))
    }

    @Test func skipRestClearsTheRest() async throws {
        _ = try startSession()
        await controller.handle(.completeSet)
        #expect(rest.isRunning)

        await controller.handle(.skipRest)
        #expect(!rest.isRunning)
        let state = try #require(controller.currentDesired()).state
        #expect(state.restStart == nil)
        #expect(!state.restOver)
    }

    @Test func aRestThatRanOutIsOverUntilTheNextSetIsDone() throws {
        let (_, lift) = try startSession()
        rest.start(seconds: 60, now: t0)
        #expect(rest.completeIfElapsed(now: t0.addingTimeInterval(61)))

        let over = try #require(controller.currentDesired()).state
        #expect(over.restOver)
        #expect(over.restStart == nil)
        #expect(over.setNumber == 1)

        // Moving on (a set completed in the app) clears the "over" state.
        WorkoutSessionService.toggleSet(lift.sortedSetLogs[0], now: t0)
        let moved = try #require(controller.currentDesired()).state
        #expect(!moved.restOver)
        #expect(moved.setNumber == 2)
    }

    @Test func aButtonPressAfterTheRestRanOutFinishesItFirst() async throws {
        _ = try startSession()
        rest.start(seconds: 60, now: .now.addingTimeInterval(-120))
        #expect(rest.isRunning)

        await controller.handle(.skipRest)
        #expect(!rest.isRunning)
        #expect(rest.finishedCount == 1)
        let state = try #require(controller.currentDesired()).state
        #expect(state.restOver)
    }

    @Test func aFinishedSessionLeavesNothingToShow() throws {
        let (session, _) = try startSession()
        rest.start(seconds: 60, now: t0)
        #expect(rest.completeIfElapsed(now: t0.addingTimeInterval(61)))
        let over = try #require(controller.currentDesired()).state
        #expect(over.restOver)

        try WorkoutSessionService.discard(session, in: context)
        #expect(controller.currentDesired() == nil)

        // A new session does not inherit the old "over" state.
        let (next, _) = try startSession()
        let desired = try #require(controller.currentDesired())
        #expect(desired.sessionID == next.uuid)
        #expect(!desired.state.restOver)
    }

    @Test func syncDoesNothingWhenNotLive() async {
        await controller.sync().value
        #expect(controller.currentDesired() == nil)
    }
}

#if DEBUG
@Test func liveActivityGalleryRouteParsesAndMapsToItsScreen() {
    #expect(LaunchRouter.route(arguments: ["UnFat", "-UNFAT_SCREEN", "gallery-live-activity"]) == .galleryLiveActivity)
    #expect(LaunchRoute.galleryLiveActivity.destination == .screen(.liveActivityGallery))
}
#endif
