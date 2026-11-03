/// Minimum-intake guard (data-and-science.md §3.5). Warns only; never clamps or blocks.
public enum Floors {
    /// Warning threshold, kcal/day: 1,200 for women, 1,500 for men.
    public static func minimumKcal(for sex: Sex) -> Double {
        switch sex {
        case .female: 1_200
        case .male: 1_500
        }
    }

    /// Assess a target. "Below" is strict: exactly 1,200 / 1,500 does not warn.
    /// `bmr` is optional; when given, a target strictly below it sets `isBelowBMR`
    /// (§3.5: never set a target below BMR without an explicit warning).
    public static func assess(kcal: Double, sex: Sex, bmr: Double? = nil) -> FloorAssessment {
        FloorAssessment(
            isBelowMinimum: kcal < minimumKcal(for: sex),
            isBelowBMR: bmr.map { kcal < $0 } ?? false
        )
    }
}

/// Warning flags for a calorie target. The target itself is left unchanged.
public struct FloorAssessment: Sendable, Hashable, Codable {
    public let isBelowMinimum: Bool
    public let isBelowBMR: Bool

    public var hasWarning: Bool { isBelowMinimum || isBelowBMR }
}
