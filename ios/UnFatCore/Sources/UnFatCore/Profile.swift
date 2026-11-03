/// Biological sex used by the Mifflin-St Jeor equation and the minimum-intake floors.
public enum Sex: String, Sendable, Hashable, CaseIterable, Codable {
    case female
    case male
}

/// Standard TDEE activity multipliers (data-and-science.md §3.2).
public enum ActivityLevel: String, Sendable, Hashable, CaseIterable, Codable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive
    case extremelyActive

    /// TDEE = BMR × multiplier.
    public var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .lightlyActive: 1.375
        case .moderatelyActive: 1.55
        case .veryActive: 1.725
        case .extremelyActive: 1.9
        }
    }
}

/// Direction of the body-weight goal. The rate magnitude lives in `GoalPlan.weeklyRateKg`.
public enum Goal: String, Sendable, Hashable, CaseIterable, Codable {
    case lose
    case maintain
    case gain

    /// Sign applied to the weekly rate: -1 for lose, 0 for maintain, +1 for gain.
    public var sign: Double {
        switch self {
        case .lose: -1
        case .maintain: 0
        case .gain: 1
        }
    }
}

/// Goal direction plus desired rate of change.
///
/// `weeklyRateKg` is a magnitude in kg/week; the direction comes from `goal`.
/// Negative or non-finite rates are treated as 0 (clamped, not rejected),
/// and `maintain` ignores the rate entirely.
public struct GoalPlan: Sendable, Hashable, Codable {
    public var goal: Goal
    public var weeklyRateKg: Double

    public init(goal: Goal, weeklyRateKg: Double) {
        self.goal = goal
        self.weeklyRateKg = weeklyRateKg
    }

    /// Rate magnitude after sanitising (finite, >= 0; 0 for maintain).
    public var sanitizedRateKg: Double {
        guard goal != .maintain, weeklyRateKg.isFinite, weeklyRateKg > 0 else { return 0 }
        return weeklyRateKg
    }
}

/// Validated body data for the energy equations.
///
/// The initializer is failable: weight, height and age must be finite and > 0,
/// otherwise it returns `nil`. Invalid input is rejected here so every formula
/// downstream can assume sane values. No upper bounds are enforced; plausibility
/// ranges are an input-UI concern. Not `Codable` on purpose: synthesized decoding
/// would bypass the validation; persist the raw fields and rebuild through `init?`.
public struct Profile: Sendable, Hashable {
    public let sex: Sex
    public let ageYears: Double
    public let heightCm: Double
    public let weightKg: Double
    public let activity: ActivityLevel

    public init?(sex: Sex, ageYears: Double, heightCm: Double, weightKg: Double, activity: ActivityLevel) {
        for value in [ageYears, heightCm, weightKg] where !(value.isFinite && value > 0) {
            return nil
        }
        self.sex = sex
        self.ageYears = ageYears
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activity = activity
    }
}
