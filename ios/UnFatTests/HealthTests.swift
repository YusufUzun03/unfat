import Foundation
import SwiftData
import Testing
@testable import UnFat

private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

// 2027-01-15 12:00 UTC (1_799_971_200 is midnight).
private let noon = Date(timeIntervalSince1970: 1_799_971_200 + 12 * 3600)

private func day(_ offset: Int) -> Date {
    calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: noon))!
}

@Suite("Health mapping")
struct HealthMappingTests {
    @Test func windowIsOldestFirstAndEndsToday() {
        let days = HealthMapping.days(endingOn: noon, count: 7, calendar: calendar)
        #expect(days.count == 7)
        #expect(days.last == day(0))
        #expect(days.first == day(-6))
        #expect(HealthMapping.days(endingOn: noon, count: 0, calendar: calendar).isEmpty)
    }

    @Test func latestPerDayKeepsTheLatestPoint() {
        let points = [
            HealthPoint(date: day(0).addingTimeInterval(7 * 3600), value: 80.4),
            HealthPoint(date: day(0).addingTimeInterval(21 * 3600), value: 79.8),
            HealthPoint(date: day(-1).addingTimeInterval(8 * 3600), value: 81),
        ]
        let samples = HealthMapping.latestPerDay(points, calendar: calendar)
        #expect(samples == [DaySample(day: day(-1), value: 81), DaySample(day: day(0), value: 79.8)])
    }

    @Test func dayValuesRoundStepsAndDropZeros() {
        let values = HealthMapping.dayValues(
            days: [day(-1), day(0)],
            steps: [DaySample(day: day(0), value: 8431.6), DaySample(day: day(-1), value: 0)],
            activeEnergy: [DaySample(day: day(0), value: 312)],
            bodyMass: [],
            calendar: calendar
        )
        #expect(values.count == 2)
        #expect(values[0].isEmpty)
        #expect(values[1] == HealthDayValues(day: day(0), steps: 8432, activeKcal: 312, bodyMassKg: nil))
    }
}

@Suite("Health workout plan")
struct HealthWorkoutPlanTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func writesFinishedSessionWithEnergy() {
        let draft = HealthWorkoutPlan.draft(
            startedAt: start, endedAt: start.addingTimeInterval(3000),
            energyKcal: 240, existingWorkoutID: nil, canShare: true
        )
        #expect(draft == HealthWorkoutDraft(start: start, end: start.addingTimeInterval(3000), energyKcal: 240))
    }

    @Test func zeroEnergyWritesWithoutEnergy() {
        let draft = HealthWorkoutPlan.draft(
            startedAt: start, endedAt: start.addingTimeInterval(60),
            energyKcal: 0, existingWorkoutID: nil, canShare: true
        )
        #expect(draft != nil)
        #expect(draft?.energyKcal == nil)
    }

    @Test func skipRules() {
        let end = start.addingTimeInterval(600)
        #expect(HealthWorkoutPlan.draft(startedAt: start, endedAt: end, energyKcal: 1, existingWorkoutID: UUID(), canShare: true) == nil)
        #expect(HealthWorkoutPlan.draft(startedAt: start, endedAt: end, energyKcal: 1, existingWorkoutID: nil, canShare: false) == nil)
        #expect(HealthWorkoutPlan.draft(startedAt: start, endedAt: nil, energyKcal: 1, existingWorkoutID: nil, canShare: true) == nil)
        #expect(HealthWorkoutPlan.draft(startedAt: start, endedAt: start, energyKcal: 1, existingWorkoutID: nil, canShare: true) == nil)
    }
}

@Suite("Body weight resolution")
struct BodyWeightResolutionTests {
    @Test func newerHealthValueWins() {
        let kg = WorkoutMath.bodyWeightKg(
            userEntry: .init(date: day(-3), kg: 80),
            health: .init(date: day(-1), kg: 78),
            calendar: calendar
        )
        #expect(kg == 78)
    }

    @Test func newerUserEntryWins() {
        let kg = WorkoutMath.bodyWeightKg(
            userEntry: .init(date: day(-1), kg: 80),
            health: .init(date: day(-4), kg: 78),
            calendar: calendar
        )
        #expect(kg == 80)
    }

    @Test func sameDayPrefersTheUsersEntry() {
        let kg = WorkoutMath.bodyWeightKg(
            userEntry: .init(date: day(0).addingTimeInterval(7 * 3600), kg: 80),
            health: .init(date: day(0), kg: 78),
            calendar: calendar
        )
        #expect(kg == 80)
    }

    @Test func fallsBackWhenNothingIsUsable() {
        #expect(WorkoutMath.bodyWeightKg(userEntry: nil, health: nil, calendar: calendar) == WorkoutMath.fallbackBodyWeightKg)
        #expect(WorkoutMath.bodyWeightKg(userEntry: .init(date: day(0), kg: 0), health: nil, calendar: calendar) == WorkoutMath.fallbackBodyWeightKg)
        #expect(WorkoutMath.bodyWeightKg(userEntry: nil, health: .init(date: day(0), kg: 77), calendar: calendar) == 77)
    }
}

@Suite("Health sync")
@MainActor
struct HealthSyncTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
    }

    private func rows() throws -> [HealthDaySummary] {
        try context.fetch(FetchDescriptor<HealthDaySummary>(sortBy: [SortDescriptor(\HealthDaySummary.day)]))
    }

    @Test func refreshDoesNothingBeforeAuthorizationWasRequested() async throws {
        let fake = FakeHealthDataSource(.init(needsRequest: true, steps: [DaySample(day: day(0), value: 5000)]))
        let service = HealthSyncService(source: fake, calendar: calendar)
        await service.refresh(in: context, now: noon)
        #expect(try rows().isEmpty)
        #expect(service.needsConnection)
        #expect(fake.state.authorizationRequests == 0)
    }

    @Test func connectRequestsOnceThenReads() async throws {
        let fake = FakeHealthDataSource(.init(
            steps: [DaySample(day: day(0), value: 8432)],
            activeEnergy: [DaySample(day: day(0), value: 312)],
            bodyMass: [DaySample(day: day(-1), value: 79.5)]
        ))
        let service = HealthSyncService(source: fake, calendar: calendar)
        await service.connect(in: context)
        #expect(fake.state.authorizationRequests == 1)
        #expect(!service.needsConnection)
        // `connect` reads with the real clock; read again with a pinned one.
        await service.refresh(in: context, now: noon)
        let stored = try rows()
        #expect(stored.count == 2)
        #expect(stored.last?.steps == 8432)
        #expect(stored.last?.activeKcal == 312)
        #expect(stored.first?.bodyMassKg == 79.5)
    }

    @Test func emptyReadKeepsExistingValues() async throws {
        let fake = FakeHealthDataSource(.init(needsRequest: false, steps: [DaySample(day: day(0), value: 4000)]))
        let service = HealthSyncService(source: fake, calendar: calendar)
        await service.refresh(in: context, now: noon)
        fake.update { $0.steps = [] }
        await service.refresh(in: context, now: noon)
        let stored = try rows()
        #expect(stored.count == 1)
        #expect(stored.first?.steps == 4000)
    }

    @Test func unavailableSourceIsSilent() async throws {
        let fake = FakeHealthDataSource(.init(isAvailable: false))
        let service = HealthSyncService(source: fake, calendar: calendar)
        await service.refresh(in: context, now: noon)
        #expect(!service.isAvailable)
        #expect(try rows().isEmpty)
    }

    @Test func writeWorkoutStoresTheIDOnce() async throws {
        let fake = FakeHealthDataSource(.init(needsRequest: false))
        let service = HealthSyncService(source: fake, calendar: calendar)
        let session = WorkoutSession(name: "Test", startedAt: noon)
        session.endedAt = noon.addingTimeInterval(3000)
        session.energyKcal = 200
        context.insert(session)
        await service.writeWorkout(for: session, in: context)
        #expect(session.healthKitWorkoutID != nil)
        #expect(fake.state.savedWorkouts.count == 1)
        await service.writeWorkout(for: session, in: context)
        #expect(fake.state.savedWorkouts.count == 1)
    }

    @Test func writeWorkoutSkipsWhenSharingIsNotAllowedOrSaveFails() async throws {
        let session = WorkoutSession(name: "Test", startedAt: noon)
        session.endedAt = noon.addingTimeInterval(3000)
        context.insert(session)

        let denied = FakeHealthDataSource(.init(needsRequest: false, workoutSharingAuthorized: false))
        await HealthSyncService(source: denied, calendar: calendar).writeWorkout(for: session, in: context)
        #expect(session.healthKitWorkoutID == nil)
        #expect(denied.state.savedWorkouts.isEmpty)

        let failing = FakeHealthDataSource(.init(needsRequest: false, failsToSave: true))
        await HealthSyncService(source: failing, calendar: calendar).writeWorkout(for: session, in: context)
        #expect(session.healthKitWorkoutID == nil)
    }
}
