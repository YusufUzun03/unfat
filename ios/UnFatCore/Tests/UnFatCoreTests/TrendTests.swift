import Foundation
import Testing
@testable import UnFatCore

// MARK: - EMA

@Test func emaWithGapCarriesTrend() {
    // T0 = 80 (seed); day 1 missing -> 80; T2 = 80 + 0.1*(81 - 80) = 80.1;
    // T3 = 80.1 + 0.1*(79 - 80.1) = 80.1 - 0.11 = 79.99
    let t = Trend.ema([80, nil, 81, 79])
    #expect(t.count == 4)
    #expect(approx(t[0]!, 80))
    #expect(approx(t[1]!, 80))
    #expect(approx(t[2]!, 80.1))
    #expect(approx(t[3]!, 79.99))
}

@Test func emaLeadingGapsAndInvalidValues() {
    // leading nil -> nil; 0 and NaN are treated as missing
    let t = Trend.ema([nil, 70, 0, Double.nan, 72])
    #expect(t[0] == nil)
    #expect(approx(t[1]!, 70))
    #expect(approx(t[2]!, 70))
    #expect(approx(t[3]!, 70))
    // 70 + 0.1*(72 - 70) = 70.2
    #expect(approx(t[4]!, 70.2))
    #expect(Trend.ema([]).isEmpty)
}

@Test func dailyTrendFillsGapsAndAveragesSameDay() {
    // day 0: 80 and 82 -> 81; day 1 missing; day 2: 82; day 3: 80
    // T = 81, 81, 81 + 0.1*(82-81) = 81.1, 81.1 + 0.1*(80-81.1) = 80.99
    let entries = [
        WeightEntry(date: day(0, hour: 7), weightKg: 80),
        WeightEntry(date: day(0, hour: 20), weightKg: 82),
        WeightEntry(date: day(3), weightKg: 80),
        WeightEntry(date: day(2), weightKg: 82),
    ]
    let points = Trend.daily(entries, calendar: utcCalendar)
    #expect(points.count == 4)
    #expect(points[0].day == baseDate)
    #expect(approx(points[0].weightKg!, 81))
    #expect(points[1].weightKg == nil)
    #expect(approx(points[1].trendKg, 81))
    #expect(approx(points[2].trendKg, 81.1))
    #expect(approx(points[3].trendKg, 80.99))
    #expect(Trend.daily([], calendar: utcCalendar).isEmpty)
}

// MARK: - Adaptive TDEE

private func dailyWeights(_ days: ClosedRange<Int>, kg: Double = 80) -> [WeightEntry] {
    days.map { WeightEntry(date: day($0), weightKg: kg) }
}

private func dailyIntakes(_ days: [Int], kcal: Double) -> [DailyIntake] {
    days.map { DailyIntake(date: day($0, hour: 13), kcal: kcal) }
}

@Test func adaptiveStableWeightEqualsIntake() throws {
    // weight flat -> delta 0 -> observed = mean intake 2500;
    // blended = 2400 + 0.25*(2500 - 2400) = 2425 (within +/-15 % of 2400)
    let result = AdaptiveTDEE.update(weights: dailyWeights(0...14),
                                     intakes: dailyIntakes(Array(0...14), kcal: 2500),
                                     previousEstimate: 2400, calendar: utcCalendar)
    let e = try #require(result.estimate)
    #expect(approx(e.observedTDEE, 2500))
    #expect(approx(e.tdee, 2425))
    #expect(e.days == 14 && e.weighIns == 15 && e.loggedDays == 15)
    #expect(!e.wasClamped)
}

@Test func adaptiveWithTrendLoss() throws {
    // days 0...13 at 80, day 14 at 79: T_start = 80, T_end = 80 + 0.1*(79 - 80) = 79.9
    // delta = -0.1; observed = 2000 - (-0.1)*7700/14 = 2000 + 55 = 2055
    // blended = 2000 + 0.25*55 = 2013.75
    var weights = dailyWeights(0...13)
    weights.append(WeightEntry(date: day(14), weightKg: 79))
    let result = AdaptiveTDEE.update(weights: weights,
                                     intakes: dailyIntakes(Array(0...14), kcal: 2000),
                                     previousEstimate: 2000, calendar: utcCalendar)
    let e = try #require(result.estimate)
    #expect(approx(e.trendDeltaKg, -0.1))
    #expect(approx(e.observedTDEE, 2055))
    #expect(approx(e.tdee, 2013.75))
}

@Test func adaptiveClampsUpAndDown() throws {
    // up: observed 4000, blended 2000 + 0.25*2000 = 2500 -> clamp 2000*1.15 = 2300
    let up = try #require(AdaptiveTDEE.update(weights: dailyWeights(0...14),
                                              intakes: dailyIntakes(Array(0...14), kcal: 4000),
                                              previousEstimate: 2000, calendar: utcCalendar).estimate)
    #expect(approx(up.tdee, 2300))
    #expect(up.wasClamped)
    // down: observed 500, blended 2000 - 0.25*1500 = 1625 -> clamp 2000*0.85 = 1700
    let down = try #require(AdaptiveTDEE.update(weights: dailyWeights(0...14),
                                                intakes: dailyIntakes(Array(0...14), kcal: 500),
                                                previousEstimate: 2000, calendar: utcCalendar).estimate)
    #expect(approx(down.tdee, 1700))
    #expect(down.wasClamped)
}

@Test func adaptiveUsesWindowAndHistory() throws {
    // 40 days of data, window 28 -> window covers days 12...39, days = 27;
    // intakes outside the window are ignored: 28 logged days
    let result = AdaptiveTDEE.update(weights: dailyWeights(0...39),
                                     intakes: dailyIntakes(Array(0...39), kcal: 2200),
                                     previousEstimate: 2200, calendar: utcCalendar)
    let e = try #require(result.estimate)
    #expect(e.days == 27)
    #expect(e.weighIns == 28)
    #expect(e.loggedDays == 28)
    #expect(approx(e.tdee, 2200))
}

@Test func adaptiveIneligibleSpan() {
    // days 0...13 -> span 13 < 14
    let result = AdaptiveTDEE.update(weights: dailyWeights(0...13),
                                     intakes: dailyIntakes(Array(0...13), kcal: 2000),
                                     previousEstimate: 2000, calendar: utcCalendar)
    #expect(result == .ineligible(.spanTooShort(days: 13)))
    #expect(result.estimate == nil)
}

@Test func adaptiveIneligibleWeighIns() {
    // weigh-ins on days 0, 2, ..., 14 -> span 14 but only 8 weigh-ins
    let weights = stride(from: 0, through: 14, by: 2).map { WeightEntry(date: day($0), weightKg: 80) }
    let result = AdaptiveTDEE.update(weights: weights,
                                     intakes: dailyIntakes(Array(0...14), kcal: 2000),
                                     previousEstimate: 2000, calendar: utcCalendar)
    #expect(result == .ineligible(.tooFewWeighIns(count: 8)))
}

@Test func adaptiveIneligibleLoggedDays() {
    // 9 logged days (two records on day 0 count once)
    var intakes = dailyIntakes(Array(0...8), kcal: 2000)
    intakes.append(DailyIntake(date: day(0, hour: 19), kcal: 300))
    let result = AdaptiveTDEE.update(weights: dailyWeights(0...14), intakes: intakes,
                                     previousEstimate: 2000, calendar: utcCalendar)
    #expect(result == .ineligible(.tooFewLoggedDays(count: 9)))
}

@Test func adaptiveIneligibleInputs() {
    #expect(AdaptiveTDEE.update(weights: dailyWeights(0...14),
                                intakes: dailyIntakes(Array(0...14), kcal: 2000),
                                previousEstimate: 0, calendar: utcCalendar) == .ineligible(.invalidPreviousEstimate))
    #expect(AdaptiveTDEE.update(weights: [], intakes: [], previousEstimate: 2000,
                                calendar: utcCalendar) == .ineligible(.spanTooShort(days: 0)))
}

@Test func adaptiveSumsSameDayIntake() throws {
    // each day: 1500 + 500 = 2000 -> observed 2000 with flat weight
    let intakes = dailyIntakes(Array(0...14), kcal: 1500) + (0...14).map { DailyIntake(date: day($0, hour: 20), kcal: 500) }
    let e = try #require(AdaptiveTDEE.update(weights: dailyWeights(0...14), intakes: intakes,
                                             previousEstimate: 2000, calendar: utcCalendar).estimate)
    #expect(approx(e.meanIntakeKcal, 2000))
    #expect(e.loggedDays == 15)
}
