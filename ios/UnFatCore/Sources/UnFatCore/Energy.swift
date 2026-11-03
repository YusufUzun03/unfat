/// Energy equations: BMR, TDEE and goal-adjusted calorie target
/// (data-and-science.md §3.1, §3.2, §3.3 step 5, §3.5).
public enum Energy {
    /// Energy density of body-weight change, kcal per kg (§3.3: rho = 7,700).
    public static let kcalPerKg: Double = 7_700

    /// Maximum goal rate as a fraction of body weight per week (§3.5: <= 1 % BW/week).
    public static let maxWeeklyRateFraction: Double = 0.01

    /// Mifflin-St Jeor BMR in kcal/day.
    /// Men: 10W + 6.25H - 5A + 5; women: 10W + 6.25H - 5A - 161.
    public static func bmr(_ profile: Profile) -> Double {
        let base = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * profile.ageYears
        switch profile.sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    /// TDEE = BMR × activity multiplier.
    public static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.multiplier
    }

    /// Convenience: TDEE straight from a profile.
    public static func tdee(_ profile: Profile) -> Double {
        tdee(bmr: bmr(profile), activity: profile.activity)
    }

    /// Largest allowed weekly rate in kg for the given body weight (1 % of it).
    /// Non-positive or non-finite weight gives 0.
    public static func maxWeeklyRateKg(weightKg: Double) -> Double {
        guard weightKg.isFinite, weightKg > 0 else { return 0 }
        return weightKg * maxWeeklyRateFraction
    }

    /// Goal-adjusted daily target:
    /// `target = tdee + sign × appliedRate × 7,700 / 7`, with the rate capped at 1 % BW/week.
    ///
    /// The cap applies to both losing and gaining. The result is floored at 0 kcal
    /// (only reachable with absurd inputs); it is never clamped to the minimum-intake
    /// floors, see `Floors`.
    public static func target(tdee: Double, plan: GoalPlan, weightKg: Double) -> CalorieTarget {
        let requested = plan.sanitizedRateKg
        let cap = maxWeeklyRateKg(weightKg: weightKg)
        let applied = min(requested, cap)
        let dailyDelta = plan.goal.sign * applied * kcalPerKg / 7
        return CalorieTarget(
            kcal: max(0, tdee + dailyDelta),
            dailyDeltaKcal: dailyDelta,
            appliedWeeklyRateKg: applied,
            wasRateCapped: applied < requested
        )
    }
}

/// Result of `Energy.target`.
public struct CalorieTarget: Sendable, Hashable, Codable {
    /// Daily calorie target, kcal (unrounded; use `DisplayRounding.kcal` for display).
    public let kcal: Double
    /// Signed daily adjustment relative to TDEE (negative = deficit).
    public let dailyDeltaKcal: Double
    /// Rate magnitude actually used after the 1 % cap, kg/week.
    public let appliedWeeklyRateKg: Double
    /// True when the requested rate exceeded the cap.
    public let wasRateCapped: Bool
}
