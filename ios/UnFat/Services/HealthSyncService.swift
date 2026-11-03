import Foundation
import Observation
import os
import SwiftData

/// Merges per-day Health values into the local-only `HealthDaySummary` rows.
@MainActor
enum HealthSummaryStore {
    /// Updates the row of each day or inserts one. A nil value keeps what the row already has
    /// (a later read can come back empty, e.g. while the device is locked). Days without any value
    /// and without a row are skipped. `updatedAt` only moves when a value was applied.
    static func upsert(
        _ values: [HealthDayValues],
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws {
        let existing = try context.fetch(FetchDescriptor<HealthDaySummary>())
        var rows: [Date: HealthDaySummary] = [:]
        for row in existing {
            let day = calendar.startOfDay(for: row.day)
            if rows[day] == nil { rows[day] = row }
        }
        for value in values where !value.isEmpty {
            let day = calendar.startOfDay(for: value.day)
            let row: HealthDaySummary
            if let found = rows[day] {
                row = found
            } else {
                row = HealthDaySummary(day: day)
                context.insert(row)
                rows[day] = row
            }
            if let steps = value.steps { row.steps = steps }
            if let activeKcal = value.activeKcal { row.activeKcal = activeKcal }
            if let bodyMassKg = value.bodyMassKg { row.bodyMassKg = bodyMassKg }
            row.updatedAt = now
        }
        if context.hasChanges { try context.save() }
    }
}

/// Reads Health into the local cache and writes finished workouts. One instance lives in the app
/// environment; Today, onboarding and the active session use it. Everything is silent on failure.
@MainActor
@Observable
final class HealthSyncService {
    /// True while Health is available and the system has not yet asked the user (Today shows "Sağlık'a bağlan").
    private(set) var needsConnection = false

    @ObservationIgnored private let source: any HealthDataSource
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var isRefreshing = false
    private static let logger = Logger(subsystem: "io.github.yusufuzun03.unfat", category: "Health")

    init(source: any HealthDataSource, calendar: Calendar = .current) {
        self.source = source
        self.calendar = calendar
    }

    /// `HKHealthStore.isHealthDataAvailable()`; the Health rows stay hidden when false.
    var isAvailable: Bool { source.isAvailable }

    /// The live source for the app. Hosted unit tests get "unavailable" and DEBUG `-UNFAT_SCREEN`
    /// launches get an empty fake, so neither touches HealthKit.
    static func makeSource(processInfo: ProcessInfo = .processInfo) -> any HealthDataSource {
        if ModelContainerFactory.isRunningUnitTests(processInfo) { return UnavailableHealthDataSource() }
        #if DEBUG
        if processInfo.arguments.contains(LaunchRouter.argument) {
            return FakeHealthDataSource(.init(needsRequest: false))
        }
        #endif
        return LiveHealthDataSource()
    }

    // MARK: - Permissions

    /// Asks the system for Health access (a no-op sheet-wise once asked), then reads.
    func connect(in context: ModelContext) async {
        guard source.isAvailable else { return }
        do {
            try await source.requestAuthorization()
        } catch {
            Self.logger.error("Authorization failed: \(error.localizedDescription, privacy: .public)")
        }
        await refresh(in: context)
    }

    // MARK: - Reading

    /// Reads the last `days` calendar days into the local store. Does nothing before the authorization
    /// request has been shown once, and while another refresh runs. Denied reads look like "no data".
    func refresh(in context: ModelContext, days: Int = 7, now: Date = .now) async {
        guard source.isAvailable, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let needsRequest = await source.needsAuthorizationRequest()
        needsConnection = needsRequest
        guard !needsRequest else { return }

        let window = HealthMapping.days(endingOn: now, count: days, calendar: calendar)
        guard let first = window.first, let last = window.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last)
        else { return }

        let steps = await read("steps") { try await self.source.dailySteps(from: first, to: end) }
        let energy = await read("active energy") { try await self.source.dailyActiveEnergyKcal(from: first, to: end) }
        let mass = await read("body mass") { try await self.source.dailyBodyMassKg(from: first, to: end) }
        let values = HealthMapping.dayValues(
            days: window,
            steps: steps,
            activeEnergy: energy,
            bodyMass: mass,
            calendar: calendar
        )
        do {
            try HealthSummaryStore.upsert(values, in: context, now: now, calendar: calendar)
        } catch {
            Self.logger.error("Health summary save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func read(_ name: String, _ body: () async throws -> [DaySample]) async -> [DaySample] {
        do {
            return try await body()
        } catch {
            Self.logger.error("Reading \(name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - Writing

    /// Writes the finished session to Health (strength training, with energy when known) and stores the
    /// workout UUID on the session. Skips when already written, when workouts may not be shared, or when
    /// the session has no sensible end. Failures are logged only.
    func writeWorkout(for session: WorkoutSession, in context: ModelContext) async {
        guard source.isAvailable else { return }
        guard let draft = HealthWorkoutPlan.draft(
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            energyKcal: session.energyKcal,
            existingWorkoutID: session.healthKitWorkoutID,
            canShare: source.isWorkoutSharingAuthorized()
        ) else { return }
        do {
            let id = try await source.saveStrengthWorkout(draft)
            // The session may have been deleted, or written by another call, while the save ran.
            guard !session.isDeleted, session.healthKitWorkoutID == nil else { return }
            session.healthKitWorkoutID = id
            try context.save()
        } catch {
            Self.logger.error("Workout write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fire-and-forget variant for the UI.
    func writeWorkoutInBackground(for session: WorkoutSession, in context: ModelContext) {
        Task { await writeWorkout(for: session, in: context) }
    }
}
