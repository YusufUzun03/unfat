import Foundation
import Testing
@testable import UnFatCore

// utcCalendar default firstWeekday is Sunday; baseDate = 2026-01-01 (Thursday).
// Weeks (Sun start): Dec 28 - Jan 3 | Jan 4 - Jan 10 | Jan 11 - Jan 17.

private func progressIntake(_ offset: Int, _ kcal: Double, hour: Int = 12) -> DailyIntake {
    DailyIntake(date: day(offset, hour: hour), kcal: kcal)
}

private func progressSet(_ id: String, _ offset: Int, _ kg: Double, _ reps: Int, hour: Int = 18) -> SetRecord {
    SetRecord(exerciseID: id, date: day(offset, hour: hour), weightKg: kg, reps: reps)
}

// MARK: - Windows and weight

@Test func windowStartIsInclusiveOfTheEndDay() {
    // 30 days ending Jan 31 -> starts Jan 2.
    let end = day(30, hour: 15)
    #expect(ProgressStats.windowStart(days: 30, endingOn: end, calendar: utcCalendar) == day(1, hour: 0))
    #expect(ProgressStats.windowStart(days: 1, endingOn: end, calendar: utcCalendar) == day(30, hour: 0))
    #expect(ProgressStats.windowStart(days: 0, endingOn: end, calendar: utcCalendar) == day(30, hour: 0))
}

@Test func trendChangeUsesFirstPointInsideWindow() {
    let points = [
        TrendPoint(day: day(0, hour: 0), weightKg: 80, trendKg: 80),
        TrendPoint(day: day(5, hour: 0), weightKg: 79, trendKg: 79.5),
        TrendPoint(day: day(10, hour: 0), weightKg: 78, trendKg: 78.5),
    ]
    #expect(approx(ProgressStats.trendChange(points, since: day(0, hour: 0))!, -1.5))
    #expect(approx(ProgressStats.trendChange(points, since: day(5, hour: 0))!, -1.0))
    #expect(ProgressStats.trendChange(points, since: day(10, hour: 0)) == nil)
    #expect(ProgressStats.trendChange([], since: day(0, hour: 0)) == nil)
}

// MARK: - Weekly intake

@Test func weeklyIntakeAveragesLoggedDaysOnly() {
    // Week 1 (Jan 1-3 in window): day0 2000 (800 + 1200), day1 2200, day2 missing
    //   -> mean (2000 + 2200) / 2 = 2100 over 2 days.
    // Week 2: day3 = Jan 4: 1800 only -> mean 1800.
    let intakes = [progressIntake(0, 800), progressIntake(0, 1200, hour: 19),
                   progressIntake(1, 2200), progressIntake(3, 1800)]
    let weeks = ProgressStats.weeklyIntake(intakes, from: day(0, hour: 0), through: day(9, hour: 0), calendar: utcCalendar)
    #expect(weeks.count == 2)
    #expect(weeks[0].weekStart == utcCalendar.date(from: DateComponents(year: 2025, month: 12, day: 28)))
    #expect(approx(weeks[0].meanKcal, 2100))
    #expect(weeks[0].loggedDays == 2)
    #expect(approx(weeks[1].meanKcal, 1800))
    #expect(weeks[1].loggedDays == 1)
}

@Test func weeklyIntakeRespectsWindowBoundsAndInvalidValues() {
    let intakes = [
        progressIntake(-1, 3000),           // before window
        progressIntake(0, 2000),
        progressIntake(10, 2400),           // last window day (inclusive)
        progressIntake(11, 9999),           // after window
        progressIntake(2, -50),             // ignored
        progressIntake(3, Double.nan),      // ignored
    ]
    let weeks = ProgressStats.weeklyIntake(intakes, from: day(0, hour: 5), through: day(10, hour: 5), calendar: utcCalendar)
    #expect(weeks.count == 2)
    #expect(approx(weeks[0].meanKcal, 2000))
    #expect(approx(weeks[1].meanKcal, 2400))
    #expect(ProgressStats.weeklyIntake([], from: day(0), through: day(9), calendar: utcCalendar).isEmpty)
}

// MARK: - Coverage and suggestion

@Test func coverageCountsDaysInsideTheWindow() {
    let weights = [
        WeightEntry(date: day(0), weightKg: 80),             // outside the 10-day window ending day 20
        WeightEntry(date: day(12, hour: 7), weightKg: 80),
        WeightEntry(date: day(12, hour: 20), weightKg: 81),  // same day
        WeightEntry(date: day(15), weightKg: 79),
        WeightEntry(date: day(20), weightKg: 79),
    ]
    let intakes = [progressIntake(11, 2000), progressIntake(13, 2000),
                   progressIntake(20, 1900), progressIntake(21, 1900)]
    let c = ProgressStats.coverage(weights: weights, intakes: intakes, windowDays: 10,
                                   endingOn: day(20, hour: 22), calendar: utcCalendar)
    // Window = days 11...20.
    #expect(c.weighInDays == 3)
    #expect(c.spanDays == 8)
    #expect(c.loggedDays == 3)
    let empty = ProgressStats.coverage(weights: [], intakes: [], endingOn: day(5), calendar: utcCalendar)
    #expect(empty == TDEECoverage(spanDays: 0, weighInDays: 0, loggedDays: 0))
}

@Test func targetSuggestionThreshold() {
    // Lose 0.5 kg/week: delta = -0.5 * 7700 / 7 = -550. TDEE 2750 -> 2200.
    let plan = GoalPlan(goal: .lose, weeklyRateKg: 0.5)
    let same = ProgressStats.targetSuggestion(tdee: 2750, plan: plan, weightKg: 80, currentKcal: 2200)
    #expect(same.suggestedKcal == 2200)
    #expect(same.differenceKcal == 0)
    #expect(!same.isSignificant)
    // TDEE 2700 -> 2150: exactly 50 below -> shown.
    let atThreshold = ProgressStats.targetSuggestion(tdee: 2700, plan: plan, weightKg: 80, currentKcal: 2200)
    #expect(atThreshold.suggestedKcal == 2150)
    #expect(atThreshold.differenceKcal == -50)
    #expect(atThreshold.isSignificant)
    // TDEE 2710 -> 2160: 40 below -> hidden.
    let below = ProgressStats.targetSuggestion(tdee: 2710, plan: plan, weightKg: 80, currentKcal: 2200)
    #expect(below.suggestedKcal == 2160)
    #expect(!below.isSignificant)
    // Increase side.
    let up = ProgressStats.targetSuggestion(tdee: 3000, plan: plan, weightKg: 80, currentKcal: 2200)
    #expect(up.suggestedKcal == 2450)
    #expect(up.isSignificant)
    // Rounding to 10: 2433 - 550 = 1883 -> 1880.
    let rounded = ProgressStats.targetSuggestion(tdee: 2433, plan: plan, weightKg: 80, currentKcal: 2200)
    #expect(rounded.suggestedKcal == 1880)
    // No current target set -> never significant.
    #expect(!ProgressStats.targetSuggestion(tdee: 3000, plan: plan, weightKg: 80, currentKcal: 0).isSignificant)
}

// MARK: - Exercises

@Test func exerciseSessionsGroupByDayAndPickTopSet() {
    let sets = [
        progressSet("bench", 0, 60, 8),      // e1RM 60 * (1 + 8/30) = 76
        progressSet("bench", 0, 70, 5),      // 70 * (1 + 5/30) = 81.666...
        progressSet("bench", 0, 40, 20),     // no e1RM (reps > 10), volume 800
        progressSet("bench", 3, 100, 12),    // only a no-e1RM set
        progressSet("bench", 3, 0, 5),       // invalid weight, ignored
    ]
    let sessions = ProgressStats.exerciseSessions(sets, calendar: utcCalendar)
    #expect(sessions.count == 2)
    #expect(sessions[0].topSet.weightKg == 70)
    #expect(approx(sessions[0].bestEstimate!, 81.666667, tolerance: 1e-5))
    #expect(approx(sessions[0].volumeKg, 480 + 350 + 800))
    #expect(sessions[1].bestEstimate == nil)
    #expect(sessions[1].topSet.weightKg == 100)
    #expect(sessions[0].day < sessions[1].day)
}

@Test func exerciseSummariesSortByMostRecentSession() {
    let sets = [
        progressSet("squat", 0, 100, 5),
        progressSet("squat", 7, 105, 5),
        progressSet("bench", 8, 60, 10),
        progressSet("row", 2, 50, 12),   // no e1RM at all
    ]
    let summaries = ProgressStats.exerciseSummaries(sets, calendar: utcCalendar)
    #expect(summaries.map(\.exerciseID) == ["bench", "squat", "row"])
    let squat = summaries[1]
    // Best session is day 7: 105 * (1 + 5/30) = 122.5.
    #expect(approx(squat.bestEstimate!, 122.5))
    #expect(squat.bestSet.weightKg == 105)
    #expect(squat.sessionCount == 2)
    let row = summaries[2]
    #expect(row.bestEstimate == nil)
    #expect(row.bestSet.weightKg == 50)
}

@Test func exerciseRecordsPerKind() {
    let sets = [
        progressSet("bench", 0, 100, 3),    // e1RM 110, max weight 100
        progressSet("bench", 4, 90, 8),     // e1RM 114, max weight 90
        progressSet("bench", 8, 90, 8),     // ties day 4 -> earliest keeps the e1RM record
        progressSet("bench", 9, 120, 15),   // heaviest weight, but no e1RM
    ]
    let records = ProgressStats.exerciseRecords(sets)
    #expect(records.map(\.kind) == [.estimatedOneRepMax, .maxWeight])
    #expect(approx(records[0].valueKg, 114))
    #expect(records[0].set.date == day(4, hour: 18))
    #expect(records[1].valueKg == 120)
    #expect(ProgressStats.exerciseRecords([]).isEmpty)
}

@Test func halfKilogramRounding() {
    #expect(DisplayRounding.halfKilogram(92.4) == 92.5)
    #expect(DisplayRounding.halfKilogram(92.2) == 92)
    #expect(DisplayRounding.halfKilogram(92.75) == 93)
    #expect(DisplayRounding.halfKilogram(.nan) == 0)
}
