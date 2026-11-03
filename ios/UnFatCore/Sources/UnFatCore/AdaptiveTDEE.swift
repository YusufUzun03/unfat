import Foundation

/// Logged food energy for one calendar day.
public struct DailyIntake: Sendable, Hashable, Codable {
    public let date: Date
    public let kcal: Double

    public init(date: Date, kcal: Double) {
        self.date = date
        self.kcal = kcal
    }
}

/// Successful adaptive TDEE update.
public struct AdaptiveTDEEEstimate: Sendable, Hashable, Codable {
    /// New blended and clamped estimate, kcal/day. This is the value to suggest.
    public let tdee: Double
    /// Raw observed TDEE from energy balance before blending, kcal/day.
    public let observedTDEE: Double
    /// Mean logged intake over the window, kcal/day.
    public let meanIntakeKcal: Double
    /// Trend weight change over the window (end - start), kg.
    public let trendDeltaKg: Double
    /// Days between the first and last weigh-in of the window (the N in the formula).
    public let days: Int
    public let weighIns: Int
    public let loggedDays: Int
    /// True when the +/-15 % clamp changed the blended value.
    public let wasClamped: Bool
}

/// Why no estimate could be produced. Associated values are what was found.
public enum AdaptiveTDEEIneligibility: Sendable, Hashable, Codable {
    case invalidPreviousEstimate
    case spanTooShort(days: Int)
    case tooFewWeighIns(count: Int)
    case tooFewLoggedDays(count: Int)
}

public enum AdaptiveTDEEResult: Sendable, Hashable, Codable {
    case estimate(AdaptiveTDEEEstimate)
    case ineligible(AdaptiveTDEEIneligibility)

    /// The estimate, or nil when ineligible.
    public var estimate: AdaptiveTDEEEstimate? {
        if case .estimate(let value) = self { return value }
        return nil
    }
}

/// Adaptive TDEE from logged intake and trend weight (data-and-science.md §3.3; SPEC).
///
/// Algorithm, meant to run once per week:
/// 1. Window = the last `windowDays` calendar days ending on the latest weigh-in day.
///    `start`/`end` = first/last weigh-in day inside the window; `days` = end - start.
///    A `windowDays` below 15 is raised to 15 so the 14-day span stays reachable.
/// 2. Eligible when `days >= 14`, weigh-in days in [start, end] >= 10 and logged intake
///    days in [start, end] >= 10. Checked in that order; the first failure is returned.
/// 3. Trend = EMA (alpha 0.1) over *all* supplied weigh-ins, so history before the
///    window seeds `T_start` instead of a single noisy weight.
/// 4. `observed = mean(intake on logged days) - (T_end - T_start) × 7,700 / days`.
/// 5. `blended = previous + k × (observed - previous)`, k = `blendFactor` (default 0.25,
///    the upper end of §3.3's 0.1-0.25: weekly updates with >= 10 logged days in 14+).
/// 6. Clamp to `previous × (1 ± 0.15)` (SPEC: +/-15 %/week). The clamp is per call;
///    the caller is responsible for calling at most once a week.
///
/// Silent in §3.3 / SPEC, decided here: several weigh-ins per day are averaged and
/// count as one weigh-in; several intake records per day are summed and count as one
/// logged day; intake records with non-finite or negative kcal are ignored (0 kcal is a
/// valid logged day); the optional [0.8, 1.6] × BMR × 1.2 bound from §3.3 is not applied.
public enum AdaptiveTDEE {
    public static let minimumSpanDays = 14
    public static let minimumWeighIns = 10
    public static let minimumLoggedDays = 10
    public static let defaultWindowDays = 28
    public static let defaultBlendFactor: Double = 0.25
    public static let maxWeeklyChangeFraction: Double = 0.15

    public static func update(
        weights: [WeightEntry],
        intakes: [DailyIntake],
        previousEstimate: Double,
        windowDays: Int = defaultWindowDays,
        blendFactor: Double = defaultBlendFactor,
        alpha: Double = Trend.defaultAlpha,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> AdaptiveTDEEResult {
        guard previousEstimate.isFinite, previousEstimate > 0 else {
            return .ineligible(.invalidPreviousEstimate)
        }
        let series = DailySeries(entries: weights, calendar: calendar)
        guard let seriesStart = series.startDay, !series.values.isEmpty else {
            return .ineligible(.spanTooShort(days: 0))
        }

        let lastIndex = series.values.count - 1
        let windowFirstIndex = max(0, lastIndex - max(windowDays, minimumSpanDays + 1) + 1)
        guard let startIndex = (windowFirstIndex...lastIndex).first(where: { series.values[$0] != nil }) else {
            return .ineligible(.spanTooShort(days: 0))
        }
        let days = lastIndex - startIndex
        guard days >= minimumSpanDays else { return .ineligible(.spanTooShort(days: days)) }

        let weighIns = series.values[startIndex...lastIndex].compactMap { $0 }.count
        guard weighIns >= minimumWeighIns else { return .ineligible(.tooFewWeighIns(count: weighIns)) }

        var intakeByDay: [Int: Double] = [:]
        for intake in intakes where intake.kcal.isFinite && intake.kcal >= 0 {
            let offset = DayMath.offset(from: seriesStart, to: intake.date, calendar: calendar)
            guard offset >= startIndex, offset <= lastIndex else { continue }
            intakeByDay[offset, default: 0] += intake.kcal
        }
        let loggedDays = intakeByDay.count
        guard loggedDays >= minimumLoggedDays else { return .ineligible(.tooFewLoggedDays(count: loggedDays)) }

        let trends = Trend.ema(series.values, alpha: alpha)
        guard let trendStart = trends[startIndex], let trendEnd = trends[lastIndex] else {
            return .ineligible(.tooFewWeighIns(count: weighIns))
        }
        let meanIntake = intakeByDay.values.reduce(0, +) / Double(loggedDays)
        let delta = trendEnd - trendStart
        let observed = meanIntake - delta * Energy.kcalPerKg / Double(days)

        let k = min(1, max(0, blendFactor.isFinite ? blendFactor : defaultBlendFactor))
        let blended = previousEstimate + k * (observed - previousEstimate)
        let lower = previousEstimate * (1 - maxWeeklyChangeFraction)
        let upper = previousEstimate * (1 + maxWeeklyChangeFraction)
        let clamped = min(upper, max(lower, blended))

        return .estimate(AdaptiveTDEEEstimate(
            tdee: clamped,
            observedTDEE: observed,
            meanIntakeKcal: meanIntake,
            trendDeltaKg: delta,
            days: days,
            weighIns: weighIns,
            loggedDays: loggedDays,
            wasClamped: clamped != blended
        ))
    }
}
