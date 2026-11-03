import Foundation
import SwiftData
import Testing
import UnFatCore
@testable import UnFat

private let progressCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    calendar.firstWeekday = 2
    return calendar
}()

/// 2027-01-13 12:00 UTC, a Wednesday.
private let progressNow = Date(timeIntervalSince1970: 1_799_841_600)

private func progressDay(_ daysAgo: Int, hour: Int = 12) -> Date {
    let start = progressCalendar.startOfDay(for: progressNow)
    let day = progressCalendar.date(byAdding: .day, value: -daysAgo, to: start) ?? start
    return day.addingTimeInterval(Double(hour) * 3_600)
}

private let progressProfile = ProfileInputs(
    sex: .male,
    birthYear: 1998,
    heightCm: 178,
    activity: .moderate,
    goal: .lose,
    weeklyRateKg: 0.5,
    targetKcal: 2200
)

/// 28 flat 80 kg weigh-ins and a logged intake on each of the same days.
private func flatSeries(intakeKcal: Double) -> (weights: [UnFatCore.WeightEntry], intakes: [DailyIntake]) {
    let weights = (0..<28).map { UnFatCore.WeightEntry(date: progressDay($0, hour: 7), weightKg: 80) }
    let intakes = (0..<28).map { DailyIntake(date: progressDay($0), kcal: intakeKcal) }
    return (weights, intakes)
}

@Suite("Progress data")
@MainActor
struct ProgressDataTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
    }

    // MARK: Weekly grouping and range bounds

    @Test func weeklyBarsGroupLoggedDaysByCalendarWeek() {
        // Weeks start on Monday: Jan 11-17 holds Jan 11, 12, 13; Jan 4-10 holds Jan 7 and Jan 5.
        let intakes = [
            DailyIntake(date: progressDay(0), kcal: 2000),      // Jan 13
            DailyIntake(date: progressDay(1), kcal: 2400),      // Jan 12
            DailyIntake(date: progressDay(2), kcal: 2200),      // Jan 11
            DailyIntake(date: progressDay(6), kcal: 1800),      // Jan 7
            DailyIntake(date: progressDay(6, hour: 20), kcal: 200),
            DailyIntake(date: progressDay(8), kcal: 1000),      // Jan 5
        ]
        let snapshot = ProgressData.snapshot(
            weights: [], intakes: intakes, profile: nil, range: .days30, now: progressNow, calendar: progressCalendar
        )
        #expect(snapshot.weeks.count == 2)
        #expect(snapshot.weeks[0].loggedDays == 2)
        #expect(abs(snapshot.weeks[0].meanKcal - 1_500) < 1e-9)   // (2000 + 1000) / 2
        #expect(snapshot.weeks[1].loggedDays == 3)
        #expect(abs(snapshot.weeks[1].meanKcal - 2_200) < 1e-9)
    }

    @Test func rangeBoundsLimitPointsAndFetchWindow() {
        // 100 daily weigh-ins ending today.
        let weights = (0..<100).map { UnFatCore.WeightEntry(date: progressDay($0, hour: 7), weightKg: 80 - Double($0) * 0.01) }
        let thirty = ProgressData.snapshot(
            weights: weights, intakes: [], profile: nil, range: .days30, now: progressNow, calendar: progressCalendar
        )
        let ninety = ProgressData.snapshot(
            weights: weights, intakes: [], profile: nil, range: .days90, now: progressNow, calendar: progressCalendar
        )
        #expect(thirty.points.count == 30)
        #expect(ninety.points.count == 90)
        let start30 = ProgressStats.windowStart(days: 30, endingOn: progressNow, calendar: progressCalendar)
        #expect(thirty.points.allSatisfy { $0.day >= start30 })
        #expect(thirty.trendNowKg == ninety.trendNowKg)

        // Fetch windows: the chart window or the TDEE window (28), whichever is longer, plus 28 seed days.
        let fetch30 = ProgressData.dataStart(range: .days30, now: progressNow, calendar: progressCalendar)
        let fetch90 = ProgressData.dataStart(range: .days90, now: progressNow, calendar: progressCalendar)
        #expect(fetch30 == ProgressStats.windowStart(days: 58, endingOn: progressNow, calendar: progressCalendar))
        #expect(fetch90 == ProgressStats.windowStart(days: 118, endingOn: progressNow, calendar: progressCalendar))
    }

    @Test func emptyDataGivesAnEmptySnapshot() {
        let snapshot = ProgressData.snapshot(
            weights: [], intakes: [], profile: progressProfile, range: .days30, now: progressNow, calendar: progressCalendar
        )
        #expect(!snapshot.hasWeights)
        #expect(snapshot.points.isEmpty)
        #expect(snapshot.trendChangeKg == nil)
        #expect(snapshot.weeks.isEmpty)
        #expect(snapshot.energy == .needsData(weighInDays: 0, loggedDays: 0, spanDays: 0))
    }

    // MARK: Adaptive TDEE card

    @Test func energyCardNeedsMoreDataBelowTheMinimums() {
        let weights = (0..<5).map { UnFatCore.WeightEntry(date: progressDay($0, hour: 7), weightKg: 80) }
        let intakes = (0..<3).map { DailyIntake(date: progressDay($0), kcal: 2000) }
        let card = ProgressData.energyCard(
            weights: weights, intakes: intakes, profile: progressProfile, now: progressNow, calendar: progressCalendar
        )
        #expect(card == .needsData(weighInDays: 5, loggedDays: 3, spanDays: 4))
        #expect(card.offeredTargetKcal == nil)
    }

    @Test func energyCardWithoutProfileFallsBackToCounts() {
        let series = flatSeries(intakeKcal: 2500)
        let card = ProgressData.energyCard(
            weights: series.weights, intakes: series.intakes, profile: nil, now: progressNow, calendar: progressCalendar
        )
        #expect(card == .needsData(weighInDays: 28, loggedDays: 28, spanDays: 27))
    }

    /// Flat weight and intake equal to the formula TDEE keep the estimate at that TDEE, so the suggested
    /// target is the goal-adjusted formula target and the threshold can be probed around it.
    @Test func suggestionAppearsFromFiftyKcalDifference() throws {
        let formula = try #require(TargetCalculator.calculate(
            TargetInput(
                sex: .male, birthYear: 1998, heightCm: 178, weightKg: 80,
                activity: .moderate, goal: .lose, weeklyRateKg: 0.5
            ),
            currentYear: progressCalendar.component(.year, from: progressNow)
        ))
        let series = flatSeries(intakeKcal: formula.tdee)

        func card(currentTarget: Double) -> EnergyCard {
            var profile = progressProfile
            profile.targetKcal = currentTarget
            return ProgressData.energyCard(
                weights: series.weights, intakes: series.intakes, profile: profile,
                now: progressNow, calendar: progressCalendar
            )
        }

        guard case .ready(let tdee, let weighIns, let loggedDays, let reference) = card(currentTarget: formula.kcal) else {
            Issue.record("expected an estimate")
            return
        }
        #expect(abs(tdee - formula.tdee) < 1e-6)
        #expect(weighIns == 28)
        #expect(loggedDays == 28)
        let suggested = reference.suggestedKcal
        #expect(suggested == formula.kcal)

        // 0 and 49 kcal apart: hidden. 50 and 60 apart, either side: shown with the suggested value.
        for hidden in [0.0, 49, -49] {
            #expect(card(currentTarget: suggested + hidden).offeredTargetKcal == nil)
        }
        for shown in [50.0, 60, -50, -60] {
            #expect(card(currentTarget: suggested + shown).offeredTargetKcal == suggested)
        }
    }

    // MARK: Accepting a suggestion

    @Test func acceptingASuggestionUpdatesTargetsAndMacros() throws {
        let profile = UserProfile(
            sex: .male, goal: .lose, weeklyRateKg: 0.5,
            targetKcal: 2200, targetProteinG: 150, targetCarbsG: 220, targetFatG: 70
        )
        profile.updatedAt = Date(timeIntervalSince1970: 1_000)
        context.insert(profile)
        try context.save()

        try ProgressData.acceptSuggestion(kcal: 2_100, weightKg: 80, profile: profile, in: context, now: progressNow)

        let stored = try #require(try UserProfile.current(in: context))
        let macros = TargetCalculator.macros(kcal: 2_100, weightKg: 80)
        #expect(stored.targetKcal == 2_100)
        #expect(stored.targetProteinG == macros.proteinG)
        #expect(stored.targetCarbsG == macros.carbsG)
        #expect(stored.targetFatG == macros.fatG)
        #expect(stored.updatedAt == progressNow)
        // The goal itself is untouched.
        #expect(stored.goal == .lose)
        #expect(stored.weeklyRateKg == 0.5)
    }

    // MARK: Weight entry

    @Test func weightInputAcceptsCommaAndDotWithinRange() {
        #expect(WeightInput.parseKg("82,4") == 82.4)
        #expect(WeightInput.parseKg("82.4") == 82.4)
        #expect(WeightInput.parseKg(" 70 ") == 70)
        #expect(WeightInput.parseKg("30") == 30)
        #expect(WeightInput.parseKg("300") == 300)
    }

    @Test func weightInputRejectsInvalidValues() {
        for text in ["", " ", "abc", "29,9", "300,1", "0", "-80", "1,2,3", "nan", "inf", "8 2"] {
            #expect(WeightInput.parseKg(text) == nil, "should reject \(text)")
        }
    }

    @Test func weightEntryDateCannotBeInTheFuture() {
        #expect(WeightInput.isDateAllowed(progressNow, now: progressNow))
        #expect(WeightInput.isDateAllowed(progressNow.addingTimeInterval(-86_400), now: progressNow))
        #expect(!WeightInput.isDateAllowed(progressNow.addingTimeInterval(60), now: progressNow))
        #expect(WeightInput.canSave(text: "82,4", date: progressNow, now: progressNow))
        #expect(!WeightInput.canSave(text: "82,4", date: progressNow.addingTimeInterval(3_600), now: progressNow))
        #expect(!WeightInput.canSave(text: "20", date: progressNow, now: progressNow))
    }

    @Test func twoWeightEntriesOnTheSameDayAreAllowed() throws {
        try ProgressData.addWeight(kg: 82.4, date: progressDay(0, hour: 7), in: context)
        try ProgressData.addWeight(kg: 82.0, date: progressDay(0, hour: 20), in: context)
        let entries = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(entries.count == 2)
        #expect(Set(entries.map(\.kg)) == [82.4, 82.0])
    }

    // MARK: Exercises

    private func insertSession(
        daysAgo: Int,
        exercises: [(ref: String, name: String, sets: [(kg: Double, reps: Int, done: Bool)])],
        finished: Bool = true
    ) {
        let start = progressDay(daysAgo, hour: 18)
        let session = WorkoutSession(name: "Test", startedAt: start, programDayID: nil)
        context.insert(session)
        if finished { session.endedAt = start.addingTimeInterval(3_600) }
        for (index, spec) in exercises.enumerated() {
            let exercise = SessionExercise(exerciseRef: spec.ref, exerciseName: spec.name, order: index, restSeconds: 90)
            context.insert(exercise)
            exercise.session = session
            for (setIndex, value) in spec.sets.enumerated() {
                let log = SetLog(order: setIndex, reps: value.reps, weightKg: value.kg)
                log.isDone = value.done
                log.completedAt = value.done ? start.addingTimeInterval(600) : nil
                context.insert(log)
                log.sessionExercise = exercise
            }
        }
    }

    @Test func exerciseRowsListDoneSetsOfFinishedSessionsNewestFirst() throws {
        insertSession(daysAgo: 9, exercises: [
            (ref: "bench", name: "Bench Press", sets: [(80, 6, true), (100, 1, false)]),
            (ref: "squat", name: "Squat", sets: [(100, 5, true)]),
        ])
        insertSession(daysAgo: 2, exercises: [
            (ref: "bench", name: "Bench Press", sets: [(82.5, 6, true)]),
        ])
        // Active session and a never-done exercise do not count.
        insertSession(daysAgo: 0, exercises: [(ref: "row", name: "Row", sets: [(50, 10, true)])], finished: false)
        insertSession(daysAgo: 1, exercises: [(ref: "curl", name: "Curl", sets: [(20, 10, false)])])
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let rows = ProgressData.exerciseRows(sessions: sessions, calendar: progressCalendar)
        #expect(rows.map(\.ref) == ["bench", "squat"])
        #expect(rows.map(\.name) == ["Bench Press", "Squat"])
        // Best bench e1RM: 82.5 x 6 = 82.5 * 1.2 = 99.0; the undone 100 x 1 set is ignored.
        #expect(abs((rows[0].summary.bestEstimate ?? 0) - 99.0) < 1e-9)
        #expect(rows[0].summary.bestSet.weightKg == 82.5)

        let detail = ProgressData.exerciseDetail(ref: "bench", sessions: sessions, calendar: progressCalendar)
        #expect(detail.name == "Bench Press")
        #expect(detail.sessions.count == 2)
        #expect(detail.sessions[0].day < detail.sessions[1].day)
        #expect(detail.records.map(\.kind) == [.estimatedOneRepMax, .maxWeight])
        #expect(detail.records[1].valueKg == 82.5)
    }
}
