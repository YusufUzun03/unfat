import Testing
@testable import UnFatCore

private let male = Profile(sex: .male, ageYears: 30, heightCm: 180, weightKg: 80, activity: .moderatelyActive)!
private let female = Profile(sex: .female, ageYears: 25, heightCm: 165, weightKg: 60, activity: .sedentary)!

// MARK: - Profile validation

@Test func profileRejectsNonPositiveOrNonFiniteInputs() {
    #expect(Profile(sex: .male, ageYears: 30, heightCm: 180, weightKg: 0, activity: .sedentary) == nil)
    #expect(Profile(sex: .male, ageYears: 30, heightCm: -1, weightKg: 80, activity: .sedentary) == nil)
    #expect(Profile(sex: .male, ageYears: 0, heightCm: 180, weightKg: 80, activity: .sedentary) == nil)
    #expect(Profile(sex: .male, ageYears: .nan, heightCm: 180, weightKg: 80, activity: .sedentary) == nil)
    #expect(Profile(sex: .male, ageYears: 30, heightCm: .infinity, weightKg: 80, activity: .sedentary) == nil)
}

@Test func activityMultipliersMatchResearch() {
    #expect(ActivityLevel.sedentary.multiplier == 1.2)
    #expect(ActivityLevel.lightlyActive.multiplier == 1.375)
    #expect(ActivityLevel.moderatelyActive.multiplier == 1.55)
    #expect(ActivityLevel.veryActive.multiplier == 1.725)
    #expect(ActivityLevel.extremelyActive.multiplier == 1.9)
}

// MARK: - BMR / TDEE

@Test func mifflinMale() {
    // 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
    #expect(approx(Energy.bmr(male), 1780))
}

@Test func mifflinFemale() {
    // 10*60 + 6.25*165 - 5*25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25
    #expect(approx(Energy.bmr(female), 1345.25))
}

@Test func tdeeUsesMultiplier() {
    // 1780 * 1.55 = 2759
    #expect(approx(Energy.tdee(male), 2759))
    // 1345.25 * 1.2 = 1614.3
    #expect(approx(Energy.tdee(female), 1614.3))
    // 1780 * 1.9 = 3382
    #expect(approx(Energy.tdee(bmr: 1780, activity: .extremelyActive), 3382))
}

// MARK: - Goal target

@Test func loseWithinCap() {
    // cap = 1 % of 80 = 0.8 kg/wk; 0.5 kg/wk -> 0.5*7700/7 = 550 kcal/day deficit; 2759 - 550 = 2209
    let t = Energy.target(tdee: 2759, plan: GoalPlan(goal: .lose, weeklyRateKg: 0.5), weightKg: 80)
    #expect(approx(t.kcal, 2209))
    #expect(approx(t.dailyDeltaKcal, -550))
    #expect(approx(t.appliedWeeklyRateKg, 0.5))
    #expect(!t.wasRateCapped)
}

@Test func loseRateIsCappedAtOnePercent() {
    // 1.0 kg/wk requested, cap 0.8 -> 0.8*1100 = 880; 2759 - 880 = 1879
    let t = Energy.target(tdee: 2759, plan: GoalPlan(goal: .lose, weeklyRateKg: 1.0), weightKg: 80)
    #expect(approx(t.kcal, 1879))
    #expect(approx(t.appliedWeeklyRateKg, 0.8))
    #expect(t.wasRateCapped)
}

@Test func gainAddsSurplusAndIsCapped() {
    // 0.25 kg/wk -> +275; 2759 + 275 = 3034
    let t = Energy.target(tdee: 2759, plan: GoalPlan(goal: .gain, weeklyRateKg: 0.25), weightKg: 80)
    #expect(approx(t.kcal, 3034))
    // 60 kg, 1 kg/wk -> cap 0.6 -> +660; 2000 + 660 = 2660
    let capped = Energy.target(tdee: 2000, plan: GoalPlan(goal: .gain, weeklyRateKg: 1), weightKg: 60)
    #expect(approx(capped.kcal, 2660))
    #expect(capped.wasRateCapped)
}

@Test func maintainIgnoresRate() {
    let t = Energy.target(tdee: 2759, plan: GoalPlan(goal: .maintain, weeklyRateKg: 0.5), weightKg: 80)
    #expect(approx(t.kcal, 2759))
    #expect(t.appliedWeeklyRateKg == 0)
    #expect(!t.wasRateCapped)
}

@Test func negativeRateIsClampedToZero() {
    let t = Energy.target(tdee: 2000, plan: GoalPlan(goal: .lose, weeklyRateKg: -0.5), weightKg: 80)
    #expect(approx(t.kcal, 2000))
    #expect(t.appliedWeeklyRateKg == 0)
}

@Test func targetNeverGoesBelowZero() {
    // tdee 500, 100 kg, 1 kg/wk -> -1100 -> floored at 0
    let t = Energy.target(tdee: 500, plan: GoalPlan(goal: .lose, weeklyRateKg: 1), weightKg: 100)
    #expect(t.kcal == 0)
}

// MARK: - Macros

@Test func defaultMacroSplit() {
    // protein 1.8*80 = 144 g (576 kcal); fat 0.27*2000 = 540 kcal = 60 g;
    // carbs (2000 - 576 - 540) / 4 = 884 / 4 = 221 g
    let m = Macros.targets(kcal: 2000, referenceWeightKg: 80)
    #expect(approx(m.proteinG, 144))
    #expect(approx(m.fatG, 60))
    #expect(approx(m.carbsG, 221))
    #expect(!m.exceedsCalorieTarget)
}

@Test func macroOverrides() {
    // protein 2.2*70 = 154 g (616 kcal); fat 0.30*2500 = 750 kcal = 83.333 g;
    // carbs (2500 - 616 - 750) / 4 = 1134 / 4 = 283.5 g
    let m = Macros.targets(kcal: 2500, referenceWeightKg: 70,
                           settings: MacroSettings(proteinGramsPerKg: 2.2, fatFraction: 0.30))
    #expect(approx(m.proteinG, 154))
    #expect(approx(m.fatG, 83.333333, tolerance: 1e-5))
    #expect(approx(m.carbsG, 283.5))
}

@Test func carbsNeverNegative() {
    // protein 180 g = 720 kcal; fat 0.27*900 = 243 kcal = 27 g; 900 - 720 - 243 = -63 -> carbs 0
    let m = Macros.targets(kcal: 900, referenceWeightKg: 100)
    #expect(approx(m.proteinG, 180))
    #expect(approx(m.fatG, 27))
    #expect(m.carbsG == 0)
    #expect(m.exceedsCalorieTarget)
}

@Test func macroInvalidInputsAreZeroed() {
    let m = Macros.targets(kcal: -100, referenceWeightKg: .nan,
                           settings: MacroSettings(proteinGramsPerKg: -1, fatFraction: 2))
    #expect(m.proteinG == 0 && m.fatG == 0 && m.carbsG == 0)
    // fatFraction clamped to 1: all 1800 kcal fat = 200 g, no carbs, protein 0
    let allFat = Macros.targets(kcal: 1800, referenceWeightKg: 80,
                                settings: MacroSettings(proteinGramsPerKg: 0, fatFraction: 1.5))
    #expect(approx(allFat.fatG, 200))
    #expect(allFat.carbsG == 0)
    #expect(!allFat.exceedsCalorieTarget)
}

// MARK: - Floors

@Test func floorsWarnStrictlyBelowThreshold() {
    #expect(Floors.assess(kcal: 1199, sex: .female).isBelowMinimum)
    #expect(!Floors.assess(kcal: 1200, sex: .female).isBelowMinimum)
    #expect(Floors.assess(kcal: 1499, sex: .male).isBelowMinimum)
    #expect(!Floors.assess(kcal: 1500, sex: .male).isBelowMinimum)
    #expect(!Floors.assess(kcal: 1500, sex: .male).hasWarning)
}

@Test func floorsBelowBMRFlag() {
    // target 1700 < BMR 1780 -> BMR warning even though above the 1500 male floor
    let a = Floors.assess(kcal: 1700, sex: .male, bmr: 1780)
    #expect(a.isBelowBMR && !a.isBelowMinimum && a.hasWarning)
    #expect(!Floors.assess(kcal: 1780, sex: .male, bmr: 1780).isBelowBMR)
}

@Test func profileToTargetsPath() {
    // Male 80 kg, TDEE 2759, lose 1 kg/wk -> capped 1879; floor 1500 -> no minimum warning,
    // but below BMR 1780? 1879 >= 1780 -> no.
    let tdee = Energy.tdee(male)
    let target = Energy.target(tdee: tdee, plan: GoalPlan(goal: .lose, weeklyRateKg: 1), weightKg: male.weightKg)
    let floor = Floors.assess(kcal: target.kcal, sex: male.sex, bmr: Energy.bmr(male))
    #expect(DisplayRounding.kcal(target.kcal) == 1879)
    #expect(!floor.hasWarning)
}
