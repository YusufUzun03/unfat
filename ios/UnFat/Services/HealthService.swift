import Foundation
import HealthKit
import os

// HealthKit access behind a small protocol. The live implementation talks to `HKHealthStore`; hosted unit
// tests and `-UNFAT_SCREEN` launches never get it (see `HealthSyncService.makeSource`). HealthKit
// framework objects (collections, samples, the workout builder) are not Sendable, so each one lives
// inside a single async function and only plain values cross to the caller.

/// One calendar day with an optional value. nil means "no data" (which is also what a denied read looks like).
struct DaySample: Equatable, Sendable {
    /// Start of the calendar day.
    var day: Date
    var value: Double?
}

/// A dated value before it is reduced to one value per day.
struct HealthPoint: Equatable, Sendable {
    var date: Date
    var value: Double
}

/// Values for one calendar day, ready to merge into `HealthDaySummary`.
struct HealthDayValues: Equatable, Sendable {
    var day: Date
    var steps: Int?
    var activeKcal: Double?
    var bodyMassKg: Double?

    var isEmpty: Bool { steps == nil && activeKcal == nil && bodyMassKg == nil }
}

/// What to write to Health for a finished session.
struct HealthWorkoutDraft: Equatable, Sendable {
    var start: Date
    var end: Date
    /// Active energy; nil writes the workout without energy.
    var energyKcal: Double?
}

enum HealthError: Error {
    case workoutNotSaved
}

/// Reads and writes Health data. Every method degrades quietly: callers treat thrown errors and empty
/// results the same way (nothing to show).
protocol HealthDataSource: Sendable {
    /// `HKHealthStore.isHealthDataAvailable()`; false on iPad and in some restricted setups.
    var isAvailable: Bool { get }
    /// Shows the system sheet when a request is still pending; resolves when the user is done.
    func requestAuthorization() async throws
    /// True while the system still has a question to ask (`.shouldRequest`). False once asked, and on errors.
    func needsAuthorizationRequest() async -> Bool
    /// True when the user allowed writing workouts.
    func isWorkoutSharingAuthorized() -> Bool
    /// Daily step sums for days in `[from, to)`.
    func dailySteps(from: Date, to: Date) async throws -> [DaySample]
    /// Daily active energy sums in kcal.
    func dailyActiveEnergyKcal(from: Date, to: Date) async throws -> [DaySample]
    /// Latest body mass of each day in kg.
    func dailyBodyMassKg(from: Date, to: Date) async throws -> [DaySample]
    /// Saves a traditional strength training workout and returns its `HKWorkout` UUID.
    func saveStrengthWorkout(_ draft: HealthWorkoutDraft) async throws -> UUID
}

// MARK: - Pure mapping

enum HealthMapping {
    /// The last `count` calendar days ending on `now`'s day, oldest first, as start-of-day dates.
    static func days(endingOn now: Date, count: Int, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        guard count > 0 else { return [] }
        return (0..<count).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    /// Reduces dated values to one per day: the one with the latest date (latest weigh-in of the day).
    static func latestPerDay(_ points: [HealthPoint], calendar: Calendar) -> [DaySample] {
        var latest: [Date: HealthPoint] = [:]
        for point in points {
            let day = calendar.startOfDay(for: point.date)
            if let current = latest[day], current.date >= point.date { continue }
            latest[day] = point
        }
        return latest.map { DaySample(day: $0.key, value: $0.value.value) }.sorted { $0.day < $1.day }
    }

    /// One `HealthDayValues` per requested day. Steps are rounded; zero or negative sums count as no
    /// data (a statistics bucket without samples can come back empty or zero).
    static func dayValues(
        days: [Date],
        steps: [DaySample],
        activeEnergy: [DaySample],
        bodyMass: [DaySample],
        calendar: Calendar
    ) -> [HealthDayValues] {
        let stepsByDay = index(steps, calendar: calendar)
        let energyByDay = index(activeEnergy, calendar: calendar)
        let massByDay = index(bodyMass, calendar: calendar)
        return days.map { rawDay in
            let day = calendar.startOfDay(for: rawDay)
            return HealthDayValues(
                day: day,
                steps: stepsByDay[day].map { Int($0.rounded()) },
                activeKcal: energyByDay[day],
                bodyMassKg: massByDay[day]
            )
        }
    }

    private static func index(_ samples: [DaySample], calendar: Calendar) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for sample in samples {
            guard let value = sample.value, value > 0 else { continue }
            result[calendar.startOfDay(for: sample.day)] = value
        }
        return result
    }
}

/// Decides whether and what to write to Health for a finished session.
enum HealthWorkoutPlan {
    /// nil when nothing should be written: already written, workout sharing not allowed, session not
    /// finished, or an end that is not after the start. Missing or zero energy writes without energy.
    static func draft(
        startedAt: Date,
        endedAt: Date?,
        energyKcal: Double?,
        existingWorkoutID: UUID?,
        canShare: Bool
    ) -> HealthWorkoutDraft? {
        guard existingWorkoutID == nil, canShare, let endedAt, endedAt > startedAt else { return nil }
        let energy = energyKcal.flatMap { $0 > 0 ? $0 : nil }
        return HealthWorkoutDraft(start: startedAt, end: endedAt, energyKcal: energy)
    }
}

// MARK: - Live HealthKit

/// The real `HKHealthStore`. Read types: body mass, steps, active energy. Share types: workouts and
/// active energy. No health records, no background delivery.
struct LiveHealthDataSource: HealthDataSource {
    private let store = HKHealthStore()
    private let calendar: Calendar
    private static let logger = Logger(subsystem: "io.github.yusufuzun03.unfat", category: "Health")

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    private static func readTypes() -> Set<HKObjectType> {
        [HKQuantityType(.bodyMass), HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned)]
    }

    private static func shareTypes() -> Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: Self.shareTypes(), read: Self.readTypes())
    }

    func needsAuthorizationRequest() async -> Bool {
        guard isAvailable else { return false }
        do {
            let status = try await store.statusForAuthorizationRequest(toShare: Self.shareTypes(), read: Self.readTypes())
            return status == .shouldRequest
        } catch {
            Self.logger.error("Authorization status failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func isWorkoutSharingAuthorized() -> Bool {
        store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    func dailySteps(from: Date, to: Date) async throws -> [DaySample] {
        try await dailySums(.stepCount, unit: .count(), from: from, to: to)
    }

    func dailyActiveEnergyKcal(from: Date, to: Date) async throws -> [DaySample] {
        try await dailySums(.activeEnergyBurned, unit: .kilocalorie(), from: from, to: to)
    }

    func dailyBodyMassKg(from: Date, to: Date) async throws -> [DaySample] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
        let massPredicate = HKSamplePredicate.quantitySample(type: HKQuantityType(.bodyMass), predicate: predicate)
        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [massPredicate],
            sortDescriptors: [SortDescriptor<HKQuantitySample>(\.endDate, order: .reverse)]
        )
        let samples = try await descriptor.result(for: store)
        let kilogram = HKUnit.gramUnit(with: .kilo)
        let points = samples.map { HealthPoint(date: $0.endDate, value: $0.quantity.doubleValue(for: kilogram)) }
        return HealthMapping.latestPerDay(points, calendar: calendar)
    }

    /// Daily cumulative sums. The statistics query merges overlapping sources (iPhone and Watch) itself.
    private func dailySums(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from: Date,
        to: Date
    ) async throws -> [DaySample] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(identifier), predicate: predicate),
            options: .cumulativeSum,
            anchorDate: calendar.startOfDay(for: from),
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        return collection.statistics().map { statistics in
            DaySample(
                day: calendar.startOfDay(for: statistics.startDate),
                value: statistics.sumQuantity()?.doubleValue(for: unit)
            )
        }
    }

    func saveStrengthWorkout(_ draft: HealthWorkoutDraft) async throws -> UUID {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: draft.start)
        if let kcal = draft.energyKcal {
            let energy = HKQuantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                start: draft.start,
                end: draft.end
            )
            try await builder.addSamples([energy])
        }
        try await builder.endCollection(at: draft.end)
        guard let workout = try await builder.finishWorkout() else { throw HealthError.workoutNotSaved }
        return workout.uuid
    }
}

// MARK: - Unavailable and fake

/// Used where HealthKit must not be touched (hosted unit tests): reports "not available".
struct UnavailableHealthDataSource: HealthDataSource {
    var isAvailable: Bool { false }
    func requestAuthorization() async throws {}
    func needsAuthorizationRequest() async -> Bool { false }
    func isWorkoutSharingAuthorized() -> Bool { false }
    func dailySteps(from: Date, to: Date) async throws -> [DaySample] { [] }
    func dailyActiveEnergyKcal(from: Date, to: Date) async throws -> [DaySample] { [] }
    func dailyBodyMassKg(from: Date, to: Date) async throws -> [DaySample] { [] }
    func saveStrengthWorkout(_ draft: HealthWorkoutDraft) async throws -> UUID { throw HealthError.workoutNotSaved }
}

#if DEBUG
/// In-memory data source for unit tests and `-UNFAT_SCREEN` launches. State is changed with `update`.
final class FakeHealthDataSource: HealthDataSource {
    struct State: Sendable {
        var isAvailable = true
        /// True until `requestAuthorization()` runs.
        var needsRequest = true
        /// What `isWorkoutSharingAuthorized()` returns after the request (and before, when `needsRequest` is false).
        var workoutSharingAuthorized = true
        var steps: [DaySample] = []
        var activeEnergy: [DaySample] = []
        var bodyMass: [DaySample] = []
        var savedWorkouts: [HealthWorkoutDraft] = []
        var authorizationRequests = 0
        var failsToSave = false
    }

    private let lock: OSAllocatedUnfairLock<State>

    init(_ state: State = State()) {
        lock = OSAllocatedUnfairLock(initialState: state)
    }

    func update(_ change: @Sendable (inout State) -> Void) {
        lock.withLock { change(&$0) }
    }

    var state: State { lock.withLock { $0 } }

    var isAvailable: Bool { lock.withLock { $0.isAvailable } }

    func requestAuthorization() async throws {
        lock.withLock {
            $0.needsRequest = false
            $0.authorizationRequests += 1
        }
    }

    func needsAuthorizationRequest() async -> Bool {
        lock.withLock { $0.isAvailable && $0.needsRequest }
    }

    func isWorkoutSharingAuthorized() -> Bool {
        lock.withLock { !$0.needsRequest && $0.workoutSharingAuthorized }
    }

    func dailySteps(from: Date, to: Date) async throws -> [DaySample] {
        lock.withLock { Self.slice($0.steps, from: from, to: to) }
    }

    func dailyActiveEnergyKcal(from: Date, to: Date) async throws -> [DaySample] {
        lock.withLock { Self.slice($0.activeEnergy, from: from, to: to) }
    }

    func dailyBodyMassKg(from: Date, to: Date) async throws -> [DaySample] {
        lock.withLock { Self.slice($0.bodyMass, from: from, to: to) }
    }

    func saveStrengthWorkout(_ draft: HealthWorkoutDraft) async throws -> UUID {
        try lock.withLock { state in
            if state.failsToSave { throw HealthError.workoutNotSaved }
            state.savedWorkouts.append(draft)
        }
        return UUID()
    }

    private static func slice(_ samples: [DaySample], from: Date, to: Date) -> [DaySample] {
        samples.filter { $0.day >= from && $0.day < to }
    }
}
#endif
