import Foundation
import Testing
@testable import UnFatCore

// MARK: - MET kcal

@Test func metKcalNet() {
    // (6 - 1) * 3.5 * 80 / 200 * 60 = 5 * 3.5 * 0.4 * 60 = 420
    #expect(approx(Workout.metKcal(met: 6, weightKg: 80, minutes: 60), 420))
    // (3.5 - 1) * 3.5 * 70 / 200 * 45 = 2.5 * 3.5 * 0.35 * 45 = 137.8125
    #expect(approx(Workout.metKcal(met: 3.5, weightKg: 70, minutes: 45), 137.8125))
}

@Test func metKcalClampsInvalidToZero() {
    #expect(Workout.metKcal(met: 1, weightKg: 80, minutes: 60) == 0)
    #expect(Workout.metKcal(met: 0.5, weightKg: 80, minutes: 60) == 0)
    #expect(Workout.metKcal(met: 6, weightKg: 0, minutes: 60) == 0)
    #expect(Workout.metKcal(met: 6, weightKg: 80, minutes: -5) == 0)
    #expect(Workout.metKcal(met: .nan, weightKg: 80, minutes: 60) == 0)
}

// MARK: - e1RM

@Test func epleyValues() {
    // 100 * (1 + 5/30) = 116.666...
    #expect(approx(Workout.epleyOneRepMax(weightKg: 100, reps: 5)!, 116.666667, tolerance: 1e-5))
    // reps == 1 -> weight exactly (Epley formula would give 103.33)
    #expect(Workout.epleyOneRepMax(weightKg: 100, reps: 1) == 100)
    // 100 * (1 + 10/30) = 133.333...
    #expect(approx(Workout.epleyOneRepMax(weightKg: 100, reps: 10)!, 133.333333, tolerance: 1e-5))
}

@Test func epleyRejectsOutOfRange() {
    #expect(Workout.epleyOneRepMax(weightKg: 100, reps: 11) == nil)
    #expect(Workout.epleyOneRepMax(weightKg: 100, reps: 0) == nil)
    #expect(Workout.epleyOneRepMax(weightKg: 100, reps: -3) == nil)
    #expect(Workout.epleyOneRepMax(weightKg: 0, reps: 5) == nil)
    #expect(Workout.epleyOneRepMax(weightKg: -20, reps: 5) == nil)
}

// MARK: - PR detection

private func set(_ id: String, _ weight: Double, _ reps: Int, _ d: Int) -> SetRecord {
    SetRecord(exerciseID: id, date: day(d), weightKg: weight, reps: reps)
}

@Test func detectsE1RMAndMaxWeightPRs() {
    // history bench: 100x5 (e1RM 116.67), 110x1 (e1RM 110, max 110)
    // new: 105x5 -> e1RM 122.5 > 116.67 (PR), max 105 < 110
    //      112.5x1 -> max 112.5 > 110 (PR), e1RM 112.5 < 122.5
    let history = [set("bench", 100, 5, 0), set("bench", 110, 1, 0)]
    let new = [set("bench", 105, 5, 7), set("bench", 112.5, 1, 7)]
    let prs = PersonalRecords.detect(newSets: new, history: history)
    #expect(prs.count == 2)
    #expect(prs[0].kind == .estimatedOneRepMax)
    #expect(approx(prs[0].valueKg, 122.5))
    #expect(approx(prs[0].previousBestKg, 116.666667, tolerance: 1e-5))
    #expect(prs[0].set == new[0])
    #expect(prs[1].kind == .maxWeight)
    #expect(prs[1].valueKg == 112.5)
    #expect(prs[1].previousBestKg == 110)
}

@Test func noPRWhenEqualOrLowerOrNoHistory() {
    let history = [set("squat", 140, 3, 0)]
    // equal weight and reps -> no PR; deadlift has no history -> no PR
    let new = [set("squat", 140, 3, 5), set("deadlift", 200, 1, 5)]
    #expect(PersonalRecords.detect(newSets: new, history: history).isEmpty)
}

@Test func highRepSetCountsOnlyForMaxWeight() {
    // 12 reps: no e1RM, but 90 kg beats max 85
    let history = [set("row", 85, 8, 0)]
    let prs = PersonalRecords.detect(newSets: [set("row", 90, 12, 3)], history: history)
    #expect(prs.count == 1)
    #expect(prs[0].kind == .maxWeight)
}

@Test func onePRPerKindBestValueWins() {
    // two new sets both beat history max 60; only the best (65) is reported
    let history = [set("ohp", 60, 1, 0)]
    let prs = PersonalRecords.detect(newSets: [set("ohp", 62.5, 1, 2), set("ohp", 65, 1, 2)], history: history)
    #expect(prs.count == 2) // e1RM (65 == weight at 1 rep) and max weight
    #expect(prs.allSatisfy { $0.valueKg == 65 })
}

@Test func invalidSetsIgnored() {
    let history = [set("curl", 20, 10, 0), set("curl", 500, 0, 0)] // 0-rep set ignored
    let prs = PersonalRecords.detect(newSets: [set("curl", 22, 8, 1), set("curl", -50, 5, 1)], history: history)
    // 22 > 20 max -> PR; e1RM 22*(1+8/30) = 27.8667 > 20*(1+10/30) = 26.6667 -> PR
    #expect(prs.count == 2)
    #expect(approx(prs[0].valueKg, 27.866667, tolerance: 1e-5))
    #expect(prs[1].valueKg == 22)
}
