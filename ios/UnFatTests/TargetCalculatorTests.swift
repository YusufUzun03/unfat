import Foundation
import SwiftData
import Testing
@testable import UnFat

// No `import UnFatCore` here: `Sex` / `ActivityLevel` would be ambiguous with the app enums.

@Suite("TargetCalculator")
struct TargetCalculatorTests {
    private let year = 2026

    /// Male, born 1996 (age 30), 180 cm, 80 kg, moderate, lose 0.5 kg/week.
    private func maleInput(goal: WeightGoal = .lose, rate: Double = 0.5) -> TargetInput {
        TargetInput(sex: .male, birthYear: 1996, heightCm: 180, weightKg: 80,
                    activity: .moderate, goal: goal, weeklyRateKg: rate)
    }

    @Test func handComputedLoseCase() throws {
        // Mifflin-St Jeor (male): 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
        // TDEE = 1780 * 1.55 (moderate) = 2759
        // Deficit = 0.5 kg/week * 7700 / 7 = 550 -> 2209 -> nearest 10 = 2210
        // Protein = 1.8 * 80 = 144 g
        // Fat = 0.27 * 2210 / 9 = 596.7 / 9 = 66.3 -> 66 g
        // Carbs = (2210 - 576 - 596.7) / 4 = 259.325 -> 259 g
        // Floor: male minimum 1500 and BMR 1780 are both below 2210 -> no warning
        let result = try #require(TargetCalculator.calculate(maleInput(), currentYear: year))
        #expect(abs(result.bmr - 1780) < 1e-9)
        #expect(abs(result.tdee - 2759) < 1e-9)
        #expect(result.kcal == 2210)
        #expect(result.proteinG == 144)
        #expect(result.fatG == 66)
        #expect(result.carbsG == 259)
        #expect(!result.wasRateCapped)
        #expect(abs(result.appliedWeeklyRateKg - 0.5) < 1e-9)
        #expect(abs(result.maxWeeklyRateKg - 0.8) < 1e-9)
        #expect(!result.floor.hasWarning)
    }

    @Test func maintainIgnoresRate() throws {
        // TDEE 2759 -> nearest 10 = 2760
        let result = try #require(TargetCalculator.calculate(maleInput(goal: .maintain, rate: 0.5), currentYear: year))
        #expect(result.kcal == 2760)
        #expect(result.appliedWeeklyRateKg == 0)
    }

    @Test func invalidInputReturnsNil() {
        var input = maleInput()
        input.weightKg = 0
        #expect(TargetCalculator.calculate(input, currentYear: year) == nil)

        input = maleInput()
        input.heightCm = 0
        #expect(TargetCalculator.calculate(input, currentYear: year) == nil)

        input = maleInput()
        input.birthYear = year // age 0
        #expect(TargetCalculator.calculate(input, currentYear: year) == nil)
    }

    @Test func rateIsCappedAtOnePercentOfBodyWeight() throws {
        // 50 kg -> cap 0.5 kg/week; requested 1.0 is reduced to 0.5
        let input = TargetInput(sex: .female, birthYear: 1996, heightCm: 160, weightKg: 50,
                                activity: .light, goal: .lose, weeklyRateKg: 1.0)
        let result = try #require(TargetCalculator.calculate(input, currentYear: year))
        #expect(result.wasRateCapped)
        #expect(abs(result.appliedWeeklyRateKg - 0.5) < 1e-9)
        #expect(abs(result.maxWeeklyRateKg - 0.5) < 1e-9)
    }

    @Test func lowTargetWarnsButIsNotChanged() throws {
        // Female, age 30, 160 cm, 50 kg, light (1.375), lose 0.5:
        // BMR = 500 + 1000 - 150 - 161 = 1189; TDEE = 1189 * 1.375 = 1634.875
        // 1634.875 - 550 = 1084.875 -> 1080 kcal: below 1200 (women) and below BMR 1189
        // Protein 90 g; fat = 0.27 * 1080 / 9 = 32.4 -> 32 g; carbs = (1080 - 360 - 291.6) / 4 = 107.1 -> 107 g
        let input = TargetInput(sex: .female, birthYear: 1996, heightCm: 160, weightKg: 50,
                                activity: .light, goal: .lose, weeklyRateKg: 0.5)
        let result = try #require(TargetCalculator.calculate(input, currentYear: year))
        #expect(result.kcal == 1080)
        #expect(result.proteinG == 90)
        #expect(result.fatG == 32)
        #expect(result.carbsG == 107)
        #expect(result.floor.isBelowMinimum)
        #expect(result.floor.isBelowBMR)
        #expect(result.floor.hasWarning)
    }

    @Test func roundsKcalToNearestTen() {
        #expect(TargetCalculator.roundedKcal(2204) == 2200)
        #expect(TargetCalculator.roundedKcal(2205) == 2210)
        #expect(TargetCalculator.roundedKcal(2209.9) == 2210)
    }
}

@Suite("Onboarding save")
@MainActor
struct OnboardingSaveTests {
    private func filledModel() -> OnboardingModel {
        let model = OnboardingModel(currentYear: 2026)
        model.sex = .male
        model.birthYear = 1996
        model.heightCm = 180
        model.weightText = "80"
        model.activity = .moderate
        model.goal = .lose
        model.weeklyRateKg = 0.5
        return model
    }

    @Test func saveCreatesOneProfileAndOneWeightEntry() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let model = filledModel()
        try model.save(in: context, now: Date(timeIntervalSince1970: 1_000_000))

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let weights = try context.fetch(FetchDescriptor<WeightEntry>())
        #expect(profiles.count == 1)
        #expect(weights.count == 1)
        let profile = try #require(profiles.first)
        #expect(profile.onboardingCompletedAt != nil)
        #expect(profile.sex == .male)
        #expect(profile.birthYear == 1996)
        #expect(profile.heightCm == 180)
        #expect(profile.goal == .lose)
        #expect(profile.weeklyRateKg == 0.5)
        #expect(profile.targetKcal == 2210)
        #expect(profile.targetProteinG == 144)
        #expect(profile.targetCarbsG == 259)
        #expect(profile.targetFatG == 66)
        #expect(weights.first?.kg == 80)
    }

    @Test func savingTwiceUpsertsTheProfile() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        try filledModel().save(in: context)
        try filledModel().save(in: context)
        #expect(try context.fetch(FetchDescriptor<UserProfile>()).count == 1)
    }

    @Test func incompleteInputThrows() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let model = OnboardingModel(currentYear: 2026)
        #expect(throws: OnboardingError.self) {
            try model.save(in: container.mainContext)
        }
    }

    @Test func editingKcalRecomputesMacrosButMacroEditKeepsOthers() {
        let model = filledModel()
        model.refreshTargets()
        model.setKcal(2000)
        // protein 144, fat 0.27 * 2000 / 9 = 60, carbs (2000 - 576 - 540) / 4 = 221
        #expect(model.proteinG == 144)
        #expect(model.fatG == 60)
        #expect(model.carbsG == 221)
        model.setValue(200, for: .protein)
        #expect(model.proteinG == 200)
        #expect(model.kcal == 2000)
        #expect(model.fatG == 60)
    }
}
