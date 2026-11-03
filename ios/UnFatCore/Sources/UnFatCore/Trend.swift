import Foundation

/// One body-weight measurement.
public struct WeightEntry: Sendable, Hashable, Codable {
    public let date: Date
    public let weightKg: Double

    public init(date: Date, weightKg: Double) {
        self.date = date
        self.weightKg = weightKg
    }
}

/// Trend value for one calendar day.
public struct TrendPoint: Sendable, Hashable, Codable {
    /// Start of the calendar day.
    public let day: Date
    /// Measured weight that day (mean of that day's weigh-ins), or nil when missing.
    public let weightKg: Double?
    /// EMA trend weight at the end of that day.
    public let trendKg: Double
}

/// Exponential moving average trend weight, Hacker's Diet style (data-and-science.md §3.3 step 1).
public enum Trend {
    /// Smoothing factor (§3.3: alpha = 0.1, about 10-day smoothing).
    public static let defaultAlpha: Double = 0.1

    /// EMA over a daily series where `nil` marks a missing day.
    ///
    /// `T_t = T_(t-1) + alpha × (W_t - T_(t-1))`. The first non-nil value seeds the trend.
    /// Missing days carry the previous trend forward unchanged (no interpolation).
    /// Leading nils produce nil (no trend yet). Non-finite or non-positive weights are
    /// treated as missing. `alpha` is clamped to 0...1.
    public static func ema(_ values: [Double?], alpha: Double = defaultAlpha) -> [Double?] {
        let a = min(1, max(0, alpha.isFinite ? alpha : defaultAlpha))
        var trend: Double?
        return values.map { value in
            if let w = value, w.isFinite, w > 0 {
                trend = trend.map { $0 + a * (w - $0) } ?? w
            }
            return trend
        }
    }

    /// Daily trend from dated weigh-ins.
    ///
    /// Entries are bucketed by calendar day in `calendar` (its time zone decides the
    /// day boundary); several weigh-ins on one day are averaged. The output has one
    /// point per day from the first to the last weigh-in day, gaps included.
    /// Invalid weights (non-finite or <= 0) are dropped. Empty input gives `[]`.
    public static func daily(_ entries: [WeightEntry], alpha: Double = defaultAlpha,
                             calendar: Calendar = Calendar(identifier: .gregorian)) -> [TrendPoint] {
        let series = DailySeries(entries: entries, calendar: calendar)
        guard let start = series.startDay else { return [] }
        let trends = ema(series.values, alpha: alpha)
        return series.values.indices.compactMap { index in
            guard let trend = trends[index],
                  let day = calendar.date(byAdding: .day, value: index, to: start) else { return nil }
            return TrendPoint(day: day, weightKg: series.values[index], trendKg: trend)
        }
    }
}

/// Weigh-ins bucketed into a dense per-day array (internal helper).
struct DailySeries {
    let startDay: Date?
    /// Index 0 = `startDay`; nil = no weigh-in that day.
    let values: [Double?]

    init(entries: [WeightEntry], calendar: Calendar) {
        let valid = entries.filter { $0.weightKg.isFinite && $0.weightKg > 0 }
        guard let first = valid.map({ calendar.startOfDay(for: $0.date) }).min() else {
            startDay = nil
            values = []
            return
        }
        var sums: [Int: (total: Double, count: Int)] = [:]
        for entry in valid {
            let offset = DayMath.offset(from: first, to: entry.date, calendar: calendar)
            let current = sums[offset] ?? (0, 0)
            sums[offset] = (current.total + entry.weightKg, current.count + 1)
        }
        let last = sums.keys.max() ?? 0
        startDay = first
        values = (0...last).map { offset in sums[offset].map { $0.total / Double($0.count) } }
    }
}

enum DayMath {
    /// Whole calendar days from the day of `start` to the day of `date` (DST-safe).
    static func offset(from start: Date, to date: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                to: calendar.startOfDay(for: date)).day ?? 0
    }
}
