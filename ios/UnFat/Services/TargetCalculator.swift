import Foundation
import UnFatCore

/// Everything the targets depend on, as collected by onboarding or the goal editor.
/// Uses the app enums (`Sex`, `ActivityLevel`, `WeightGoal`); `TargetCalculator` maps them to `UnFatCore`.
struct TargetInput: Equatable, Sendable {
    var sex: Sex
    var birthYear: Int
    var heightCm: Double
    var weightKg: Double
    var activity: ActivityLevel
    var goal: WeightGoal
    /// Requested rate magnitude in kg/week (ignored for `.maintain`).
    var weeklyRateKg: Double
}

/// Calorie and macro targets, rounded for storage and display (kcal to the nearest 10, grams whole).
struct TargetResult: Equatable, Sendable {
    /// Unrounded Mifflin-St Jeor BMR, kcal/day.
    let bmr: Double
    /// Unrounded TDEE, kcal/day.
    let tdee: Double
    let kcal: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let wasRateCapped: Bool
    let appliedWeeklyRateKg: Double
    let maxWeeklyRateKg: Double
    /// Assessed on the rounded kcal.
    let floor: FloorAssessment
}

/// Whole-gram macro split.
struct MacroGrams: Equatable, Sendable {
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
}

/// Pure mapping from onboarding input to targets. All nutrition math is delegated to `UnFatCore`;
/// this type only converts types and rounds.
enum TargetCalculator {
    /// Returns nil for invalid input (non-positive age, height or weight).
    static func calculate(_ input: TargetInput, currentYear: Int) -> TargetResult? {
        let age = Double(currentYear - input.birthYear)
        guard let profile = Profile(
            sex: input.sex.core,
            ageYears: age,
            heightCm: input.heightCm,
            weightKg: input.weightKg,
            activity: input.activity.core
        ) else { return nil }

        let bmr = Energy.bmr(profile)
        let tdee = Energy.tdee(bmr: bmr, activity: profile.activity)
        let plan = GoalPlan(goal: input.goal.core, weeklyRateKg: input.weeklyRateKg)
        let target = Energy.target(tdee: tdee, plan: plan, weightKg: profile.weightKg)
        let kcal = roundedKcal(target.kcal)
        let grams = macros(kcal: kcal, weightKg: profile.weightKg)
        return TargetResult(
            bmr: bmr,
            tdee: tdee,
            kcal: kcal,
            proteinG: grams.proteinG,
            carbsG: grams.carbsG,
            fatG: grams.fatG,
            wasRateCapped: target.wasRateCapped,
            appliedWeeklyRateKg: target.appliedWeeklyRateKg,
            maxWeeklyRateKg: Energy.maxWeeklyRateKg(weightKg: profile.weightKg),
            floor: Floors.assess(kcal: kcal, sex: profile.sex, bmr: bmr)
        )
    }

    /// Default macro split for a calorie target, in whole grams.
    static func macros(kcal: Double, weightKg: Double) -> MacroGrams {
        let targets = Macros.targets(kcal: kcal, referenceWeightKg: weightKg)
        return MacroGrams(
            proteinG: Double(DisplayRounding.grams(targets.proteinG)),
            carbsG: Double(DisplayRounding.grams(targets.carbsG)),
            fatG: Double(DisplayRounding.grams(targets.fatG))
        )
    }

    /// Goal-aware daily target for an estimated TDEE (the adaptive estimate), compared with the current
    /// target. Same goal math as `calculate`; the result is rounded to 10 kcal.
    static func targetSuggestion(
        tdee: Double,
        goal: WeightGoal,
        weeklyRateKg: Double,
        weightKg: Double,
        currentKcal: Double
    ) -> TargetSuggestion {
        ProgressStats.targetSuggestion(
            tdee: tdee,
            plan: GoalPlan(goal: goal.core, weeklyRateKg: weeklyRateKg),
            weightKg: weightKg,
            currentKcal: currentKcal
        )
    }

    /// Largest recommended weekly rate (1 % of body weight), kg/week.
    static func maxWeeklyRateKg(weightKg: Double) -> Double {
        Energy.maxWeeklyRateKg(weightKg: weightKg)
    }

    /// Minimum-intake / below-BMR assessment for a (possibly user-edited) target.
    static func assessFloor(kcal: Double, sex: Sex, bmr: Double?) -> FloorAssessment {
        Floors.assess(kcal: kcal, sex: sex.core, bmr: bmr)
    }

    /// Nearest 10 kcal, half away from zero.
    static func roundedKcal(_ kcal: Double) -> Double {
        Double(DisplayRounding.kcal(kcal / 10)) * 10
    }
}

// The app enums mirror the UnFatCore ones with their own raw values; map explicitly.
private extension Sex {
    var core: UnFatCore.Sex {
        switch self {
        case .female: .female
        case .male: .male
        }
    }
}

private extension ActivityLevel {
    var core: UnFatCore.ActivityLevel {
        switch self {
        case .sedentary: .sedentary
        case .light: .lightlyActive
        case .moderate: .moderatelyActive
        case .active: .veryActive
        case .veryActive: .extremelyActive
        }
    }
}

private extension WeightGoal {
    var core: UnFatCore.Goal {
        switch self {
        case .lose: .lose
        case .maintain: .maintain
        case .gain: .gain
        }
    }
}
