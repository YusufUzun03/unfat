/// Macro split settings (data-and-science.md §3.4; SPEC defaults).
///
/// Overrides: pass a custom `proteinGramsPerKg` or `fatFraction`. Non-finite or
/// negative overrides are treated as 0; `fatFraction` is clamped to 0...1.
public struct MacroSettings: Sendable, Hashable, Codable {
    /// Default protein, g per kg of reference body weight.
    public static let defaultProteinGramsPerKg: Double = 1.8
    /// Default fat share of total kcal.
    public static let defaultFatFraction: Double = 0.27

    public var proteinGramsPerKg: Double
    public var fatFraction: Double

    public init(proteinGramsPerKg: Double = MacroSettings.defaultProteinGramsPerKg,
                fatFraction: Double = MacroSettings.defaultFatFraction) {
        self.proteinGramsPerKg = proteinGramsPerKg
        self.fatFraction = fatFraction
    }
}

/// Daily macro targets in grams (unrounded; use `DisplayRounding.grams` for display).
public struct MacroTargets: Sendable, Hashable, Codable {
    public let proteinG: Double
    public let fatG: Double
    public let carbsG: Double
    /// True when protein + fat alone exceed the calorie target, so carbs were clamped to 0
    /// and the macro total is above the target.
    public let exceedsCalorieTarget: Bool
}

public enum Macros {
    public static let kcalPerGramProtein: Double = 4
    public static let kcalPerGramCarbs: Double = 4
    public static let kcalPerGramFat: Double = 9

    /// Protein = g/kg × reference weight; fat = fraction × kcal / 9; carbs = remainder / 4, never negative.
    ///
    /// `referenceWeightKg` is the body weight protein is scaled by; callers may pass goal
    /// weight for users with a high BMI (§3.4). Protein and fat are kept as requested
    /// when the target is too small; only carbs are clamped (and `exceedsCalorieTarget` set).
    /// Non-positive or non-finite kcal/weight are treated as 0.
    public static func targets(kcal: Double, referenceWeightKg: Double,
                               settings: MacroSettings = MacroSettings()) -> MacroTargets {
        let kcal = nonNegative(kcal)
        let weight = nonNegative(referenceWeightKg)
        let perKg = nonNegative(settings.proteinGramsPerKg)
        let fatFraction = min(1, nonNegative(settings.fatFraction))

        let proteinG = perKg * weight
        let fatKcal = fatFraction * kcal
        let remainder = kcal - proteinG * kcalPerGramProtein - fatKcal
        return MacroTargets(
            proteinG: proteinG,
            fatG: fatKcal / kcalPerGramFat,
            carbsG: max(0, remainder) / kcalPerGramCarbs,
            exceedsCalorieTarget: remainder < 0
        )
    }

    private static func nonNegative(_ value: Double) -> Double {
        value.isFinite && value > 0 ? value : 0
    }
}
