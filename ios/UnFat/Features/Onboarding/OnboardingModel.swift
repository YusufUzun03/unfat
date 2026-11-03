import Foundation
import Observation
import SwiftData
import SwiftUI
import UnFatCore

/// Pushed steps of the onboarding flow, in order.
enum OnboardingStep: Int, CaseIterable, Hashable, Sendable {
    case sex
    case body
    case weight
    case activity
    case goal
    case targets

    /// 1-based position for the "1 / 6" indicator.
    var number: Int { rawValue + 1 }
    static var count: Int { allCases.count }
}

/// A single editable target value.
enum TargetField: Hashable, Identifiable, Sendable {
    case kcal
    case protein
    case carbs
    case fat

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .kcal: "Kalori"
        case .protein: "Protein"
        case .carbs: "Karbonhidrat"
        case .fat: "Yağ"
        }
    }
}

enum OnboardingError: Error {
    case incompleteInput
}

/// State shared by every onboarding step and by `GoalEditorView`.
/// Nutrition math lives in `TargetCalculator` / `UnFatCore`; this type only holds input and edits.
@MainActor
@Observable
final class OnboardingModel {
    static let heightRange: ClosedRange<Int> = 120...220
    static let weightRange: ClosedRange<Double> = 30...300
    static let rateOptions: [Double] = [0.25, 0.5, 0.75, 1.0]
    static let minimumAge = 13

    let currentYear: Int

    // Body data. `sex` and `activity` start unset so "Devam" stays disabled until chosen.
    var sex: Sex?
    var birthYear: Int
    var heightCm: Int = 170
    /// Canonical keypad text of the body weight in kg ("72.5").
    var weightText: String = ""
    var activity: ActivityLevel?

    // Goal.
    var goal: WeightGoal = .maintain
    var weeklyRateKg: Double = 0.5

    // Targets: computed from the input, then freely editable.
    private(set) var kcal: Double = 0
    private(set) var proteinG: Double = 0
    private(set) var carbsG: Double = 0
    private(set) var fatG: Double = 0
    private(set) var bmr: Double?
    private var calculatedFor: TargetInput?

    /// The target value being edited in the keypad sheet.
    var editingField: TargetField?

    init(currentYear: Int = Calendar.current.component(.year, from: .now)) {
        self.currentYear = currentYear
        self.birthYear = currentYear - 28
    }

    /// Prefilled from an existing profile (goal editor). Stored targets are kept until the input changes.
    convenience init(profile: UserProfile, weightKg: Double, currentYear: Int = Calendar.current.component(.year, from: .now)) {
        self.init(currentYear: currentYear)
        sex = profile.sex
        birthYear = profile.birthYear
        heightCm = Int(profile.heightCm.rounded())
        weightText = String(format: "%.1f", weightKg)
        activity = profile.activityLevel
        goal = profile.goal
        weeklyRateKg = profile.weeklyRateKg > 0 ? profile.weeklyRateKg : 0.5
        if let input, let result = TargetCalculator.calculate(input, currentYear: currentYear) {
            bmr = result.bmr
            calculatedFor = input
            if profile.targetKcal > 0 {
                kcal = profile.targetKcal
                proteinG = profile.targetProteinG
                carbsG = profile.targetCarbsG
                fatG = profile.targetFatG
            } else {
                apply(result)
            }
        }
    }

    // MARK: - Derived input

    var birthYearRange: ClosedRange<Int> { 1940...(currentYear - Self.minimumAge) }

    /// Body weight parsed from the keypad text; nil when empty or outside `weightRange`.
    var weightKg: Double? {
        guard let decimal = KeypadInput.decimal(weightText) else { return nil }
        let value = NSDecimalNumber(decimal: decimal).doubleValue
        return Self.weightRange.contains(value) ? value : nil
    }

    var input: TargetInput? {
        guard let sex, let activity, let weightKg else { return nil }
        return TargetInput(
            sex: sex,
            birthYear: birthYear,
            heightCm: Double(heightCm),
            weightKg: weightKg,
            activity: activity,
            goal: goal,
            weeklyRateKg: weeklyRateKg
        )
    }

    var maxWeeklyRateKg: Double {
        TargetCalculator.maxWeeklyRateKg(weightKg: weightKg ?? 0)
    }

    /// True when the chosen rate is above the recommended 1 % of body weight per week.
    var isRateCapped: Bool {
        goal != .maintain && weightKg != nil && weeklyRateKg > maxWeeklyRateKg + 0.000_001
    }

    /// Rate that is actually stored: 0 for maintain, otherwise capped at `maxWeeklyRateKg`.
    var effectiveRateKg: Double {
        goal == .maintain ? 0 : min(weeklyRateKg, maxWeeklyRateKg)
    }

    /// Floor assessment of the current (possibly edited) calorie target.
    var floor: FloorAssessment? {
        guard let sex else { return nil }
        return TargetCalculator.assessFloor(kcal: kcal, sex: sex, bmr: bmr)
    }

    func value(for field: TargetField) -> Double {
        switch field {
        case .kcal: kcal
        case .protein: proteinG
        case .carbs: carbsG
        case .fat: fatG
        }
    }

    // MARK: - Targets

    /// Recomputes the targets when the input changed since the last calculation.
    /// Manual edits survive until the input changes.
    func refreshTargets() {
        guard let input, input != calculatedFor,
              let result = TargetCalculator.calculate(input, currentYear: currentYear)
        else { return }
        apply(result)
        bmr = result.bmr
        calculatedFor = input
    }

    /// Editing kcal recomputes the macros from it.
    func setKcal(_ value: Double) {
        kcal = value
        let grams = TargetCalculator.macros(kcal: value, weightKg: weightKg ?? 0)
        proteinG = grams.proteinG
        carbsG = grams.carbsG
        fatG = grams.fatG
    }

    /// Editing one macro keeps everything else as it is.
    func setValue(_ value: Double, for field: TargetField) {
        switch field {
        case .kcal: setKcal(value)
        case .protein: proteinG = value
        case .carbs: carbsG = value
        case .fat: fatG = value
        }
    }

    private func apply(_ result: TargetResult) {
        kcal = result.kcal
        proteinG = result.proteinG
        carbsG = result.carbsG
        fatG = result.fatG
    }

    // MARK: - Saving

    /// Upserts the single `UserProfile`, inserts the first `WeightEntry` and marks onboarding complete.
    func save(in context: ModelContext, now: Date = .now) throws {
        guard let sex, let activity, let weightKg else { throw OnboardingError.incompleteInput }
        refreshTargets()
        let profile: UserProfile
        if let existing = try UserProfile.current(in: context) {
            profile = existing
        } else {
            profile = UserProfile()
            context.insert(profile)
        }
        profile.sex = sex
        profile.birthYear = birthYear
        profile.heightCm = Double(heightCm)
        profile.activityLevel = activity
        applyGoal(to: profile, now: now)
        profile.onboardingCompletedAt = now
        context.insert(WeightEntry(date: now, kg: weightKg))
        try context.save()
    }

    /// Writes goal, rate and targets to an existing profile (goal editor).
    func saveGoal(to profile: UserProfile, in context: ModelContext, now: Date = .now) throws {
        applyGoal(to: profile, now: now)
        try context.save()
    }

    private func applyGoal(to profile: UserProfile, now: Date) {
        profile.goal = goal
        profile.weeklyRateKg = effectiveRateKg
        profile.targetKcal = kcal
        profile.targetProteinG = proteinG
        profile.targetCarbsG = carbsG
        profile.targetFatG = fatG
        profile.updatedAt = now
    }
}
