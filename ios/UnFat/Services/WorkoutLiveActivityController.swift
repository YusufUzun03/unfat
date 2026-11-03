import ActivityKit
import Foundation
import Observation
import os
import SwiftData
import UserNotifications

/// The "rest is over" local notification. One fixed identifier, so a new schedule replaces the old
/// one. There is no notification delegate, so nothing is shown while the app is in the foreground.
enum WorkoutRestNotification {
    static let identifier = "workout-rest-end"

    /// Returns whether notifications are allowed after the request.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Does nothing when the end is not in the future.
    static func schedule(_ plan: WorkoutRestNotificationPlan, now: Date = .now) async {
        guard let delay = WorkoutLiveActivityLogic.notificationDelay(end: plan.end, now: now) else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Dinlenme bitti")
        if let name = plan.exerciseName {
            content.body = String(localized: "Sıradaki: \(name)")
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Removes the pending notification and one that was already delivered.
    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

/// Owns the workout Live Activity and the shared rest timer.
///
/// - Starts, updates and ends the activity so it mirrors the active `WorkoutSession` and the rest
///   timer (`sync()`); it ends activities that belong to no active session (orphans).
/// - Answers the activity buttons (`handle(_:)`, installed on `WorkoutIntentBridge` by `UnFatApp`).
///   The intents run in this process, so this is the one place that reads the database for the
///   activity; the widget extension never does.
/// - Keeps a running rest in the App Group so a relaunch picks it up, and schedules the local
///   notification for the end of the rest.
///
/// `isLive == false` (unit tests, `-UNFAT_SCREEN` screenshots) switches ActivityKit, notifications
/// and App Group writes off; the database and rest logic keep working, so tests can drive it.
///
/// It only conforms to `Observable` (no macro): views just need it in the environment, nothing
/// observes its properties. Views observe `rest`.
@MainActor
final class WorkoutLiveActivityController: Observable {
    private static let logger = Logger(subsystem: "io.github.yusufuzun03.unfat", category: "LiveActivity")

    /// The app's only rest timer. `WorkoutScreen` hands it to `ActiveSessionView`.
    let rest: RestTimerController

    private let container: ModelContainer
    private let isLive: Bool

    /// Session the rest bookkeeping below belongs to.
    private var trackedSessionID: UUID?
    /// The rest ran out and no set was completed since (see `restOverAnchor`).
    private var restOver = false
    /// Done sets when the rest ran out; a different count means the user moved on.
    private var restOverAnchor = 0
    /// What `workout-rest-state.json` holds.
    private var persistedRest: WorkoutRestState?
    /// What the pending notification was last set up for.
    private var scheduledNotification: WorkoutRestNotificationPlan?
    /// Session this process started or adopted an activity for; if that activity disappears, the
    /// user dismissed it (or the system ended it).
    private var requestedSessionID: UUID?
    /// Session whose activity was dismissed: it is not started again until the session changes.
    private var suppressedSessionID: UUID?
    private var lastApplied: WorkoutActivityDesired?
    private var queueTail: Task<Void, Never>?
    private var didRequestAuthorization = false

    init(container: ModelContainer, rest: RestTimerController, isLive: Bool) {
        self.container = container
        self.rest = rest
        self.isLive = isLive
        rest.onEvent = { [weak self] event in
            self?.restDidChange(event)
        }
    }

    /// False in unit tests and for `-UNFAT_SCREEN` launches (fixture data, no real activity).
    static func shouldRunLive(processInfo: ProcessInfo = .processInfo) -> Bool {
        if ModelContainerFactory.isRunningUnitTests(processInfo) { return false }
        #if DEBUG
        if processInfo.arguments.contains(LaunchRouter.argument) { return false }
        #endif
        return true
    }

    // MARK: - Launch

    /// Call once from `UnFatApp.init`, before the intent handler is installed: restores a rest that
    /// was running, clears stale notifications, then adopts, updates, starts or ends the activity.
    func launch(now: Date = .now) {
        guard isLive else { return }
        let session = WorkoutSessionService.activeSession(in: container.mainContext)
        trackedSessionID = session?.uuid
        let stored = WorkoutRestStateStore.read()
        persistedRest = stored
        switch WorkoutLiveActivityLogic.recover(stored, activeSessionID: session?.uuid, now: now) {
        case .none:
            break
        case .running(let interval):
            rest.restore(start: interval.lowerBound, end: interval.upperBound, now: now)
        case .over:
            markRestOver()
        }
        enqueue { WorkoutRestNotification.cancel() }
        sync()
    }

    /// Asks once per process, from a user action (never from an intent that woke the app).
    func requestNotificationAuthorization() {
        guard isLive, !didRequestAuthorization else { return }
        didRequestAuthorization = true
        Task { await WorkoutRestNotification.requestAuthorization() }
    }

    // MARK: - Sync

    /// Brings the activity, the notification and the saved rest in line with the database and the
    /// rest timer. Call after every change to the active session. The task finishes when the
    /// activity was updated; ActivityKit calls run one after the other, in call order.
    @discardableResult
    func sync() -> Task<Void, Never> {
        guard isLive else { return Task {} }
        let desired = currentDesired()
        persistRest(sessionID: desired?.sessionID)
        let notification = WorkoutLiveActivityLogic.notificationPlan(state: desired?.state, rest: rest.interval)
        let notificationChanged = notification != scheduledNotification
        scheduledNotification = notification
        return enqueue { [weak self] in
            await self?.apply(desired)
            guard notificationChanged else { return }
            if let notification {
                await WorkoutRestNotification.schedule(notification)
            } else {
                WorkoutRestNotification.cancel()
            }
        }
    }

    /// What the activity should show now; nil without an active session.
    func currentDesired() -> WorkoutActivityDesired? {
        guard let session = WorkoutSessionService.activeSession(in: container.mainContext) else {
            trackedSessionID = nil
            restOver = false
            return nil
        }
        if trackedSessionID != session.uuid {
            trackedSessionID = session.uuid
            restOver = false
        }
        let exercises = Self.progress(of: session)
        if restOver, WorkoutLiveActivityLogic.doneCount(in: exercises) != restOverAnchor {
            restOver = false
        }
        return WorkoutActivityDesired(
            sessionID: session.uuid,
            workoutName: session.name,
            state: WorkoutLiveActivityLogic.contentState(
                workoutName: session.name,
                exercises: exercises,
                rest: rest.interval,
                restOver: restOver
            )
        )
    }

    private static func progress(of session: WorkoutSession) -> [WorkoutExerciseProgress] {
        session.sortedExercises.map { exercise in
            WorkoutExerciseProgress(
                name: exercise.exerciseName,
                sets: exercise.sortedSetLogs.map(\.isDone),
                restSeconds: exercise.restSeconds
            )
        }
    }

    // MARK: - Rest timer events

    private func restDidChange(_ event: RestTimerEvent) {
        switch event {
        case .finished:
            markRestOver()
        case .started, .adjusted, .skipped:
            restOver = false
        }
        sync()
    }

    private func markRestOver() {
        restOver = true
        if let session = WorkoutSessionService.activeSession(in: container.mainContext) {
            // The flag belongs to this session even if no sync has seen it yet.
            trackedSessionID = session.uuid
            restOverAnchor = WorkoutLiveActivityLogic.doneCount(in: Self.progress(of: session))
        } else {
            restOverAnchor = 0
        }
    }

    private func persistRest(sessionID: UUID?) {
        let wanted: WorkoutRestState?
        if let sessionID, let interval = rest.interval {
            wanted = WorkoutRestState(sessionID: sessionID, start: interval.lowerBound, end: interval.upperBound)
        } else {
            wanted = nil
        }
        guard wanted != persistedRest else { return }
        do {
            try WorkoutRestStateStore.write(wanted)
            persistedRest = wanted
        } catch {
            Self.logger.error("rest state write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Intents

    /// Runs a Live Activity button. The rest timer is brought up to date first, because the app may
    /// have been suspended while the rest ran out.
    func handle(_ action: WorkoutIntentAction) async {
        rest.completeIfElapsed()
        switch action {
        case .addRestTime:
            rest.adjust(by: RestTimerMath.adjustStep)
        case .skipRest:
            rest.skip()
        case .completeSet:
            completeNextSet()
        }
        await sync().value
    }

    /// "Set tamam": completes the first open set and starts that exercise's rest, like the check
    /// button in `ActiveSessionView`.
    private func completeNextSet() {
        let context = container.mainContext
        guard let session = WorkoutSessionService.activeSession(in: context) else { return }
        let exercises = session.sortedExercises
        guard let next = WorkoutLiveActivityLogic.nextSet(in: Self.progress(of: session)),
              !next.isComplete,
              exercises.indices.contains(next.exerciseIndex)
        else { return }
        let exercise = exercises[next.exerciseIndex]
        let logs = exercise.sortedSetLogs
        guard logs.indices.contains(next.setIndex) else { return }
        let isDone = WorkoutSessionService.toggleSet(logs[next.setIndex])
        do {
            try context.save()
        } catch {
            Self.logger.error("set save failed: \(error.localizedDescription, privacy: .public)")
        }
        if isDone {
            rest.start(seconds: exercise.restSeconds)
        }
    }

    // MARK: - ActivityKit

    /// Queues `work` behind everything queued before it, so activity requests, updates and
    /// notification changes never overlap or overtake each other.
    @discardableResult
    private func enqueue(_ work: @escaping @MainActor @Sendable () async -> Void) -> Task<Void, Never> {
        let previous = queueTail
        let task = Task { @MainActor in
            await previous?.value
            await work()
        }
        queueTail = task
        return task
    }

    /// Makes the system's activities match `desired`. Activities are looked up fresh each time and
    /// never stored.
    private func apply(_ desired: WorkoutActivityDesired?) async {
        let active = Activity<WorkoutActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
        let existing = active.map { $0.attributes.sessionID }

        if let desired {
            // An activity this process started or adopted is gone: the user dismissed it.
            if !existing.contains(desired.sessionID), requestedSessionID == desired.sessionID {
                suppressedSessionID = desired.sessionID
            }
        } else {
            requestedSessionID = nil
            suppressedSessionID = nil
            lastApplied = nil
        }

        let plan = WorkoutLiveActivityLogic.reconcile(
            existing: existing,
            desired: desired?.sessionID,
            isSuppressed: suppressedSessionID != nil && suppressedSessionID == desired?.sessionID
        )
        for index in plan.endIndices {
            await Self.endActivities(sessionID: existing[index])
        }
        guard let desired else { return }

        let content = ActivityContent(state: desired.state, staleDate: desired.state.staleDate)
        if let index = plan.updateIndex {
            requestedSessionID = desired.sessionID
            if lastApplied != desired {
                await Self.updateActivity(sessionID: existing[index], content: content)
                lastApplied = desired
            }
        } else if plan.requestsNew {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            do {
                _ = try Activity.request(
                    attributes: WorkoutActivityAttributes(
                        workoutName: desired.workoutName,
                        sessionID: desired.sessionID
                    ),
                    content: content,
                    pushType: nil
                )
                requestedSessionID = desired.sessionID
                lastApplied = desired
            } catch {
                Self.logger.error("activity request failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // `Activity` is not Sendable: look it up again off the main actor instead of sending it there.
    nonisolated private static func endActivities(sessionID: UUID) async {
        for activity in Activity<WorkoutActivityAttributes>.activities
        where activity.attributes.sessionID == sessionID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    nonisolated private static func updateActivity(
        sessionID: UUID,
        content: ActivityContent<WorkoutActivityAttributes.ContentState>
    ) async {
        for activity in Activity<WorkoutActivityAttributes>.activities
        where activity.attributes.sessionID == sessionID {
            await activity.update(content)
        }
    }
}
