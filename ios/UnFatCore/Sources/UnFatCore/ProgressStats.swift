import Foundation

/// Mean daily intake of one calendar week, over the days that have a logged intake.
public struct WeeklyIntake: Sendable, Hashable, Codable {
    /// First day of the calendar week (per the calendar's `firstWeekday`), start of day.
    public let weekStart: Date
    /// Mean of the daily totals of the logged days in this week (inside the requested window).
    public let meanKcal: Double
    /// Number of logged days that went into the mean.
    public let loggedDays: Int
}

/// Logged days and weigh-in days found in an adaptive TDEE window.
public struct TDEECoverage: Sendable, Hashable, Codable {
    /// Days between the first and last weigh-in day inside the window (0 when fewer than two).
    public let spanDays: Int
    /// Distinct days with at least one valid weigh-in.
    public let weighInDays: Int
    /// Distinct days with at least one valid intake record.
    public let loggedDays: Int
}

/// Calorie target derived from an adaptive TDEE estimate.
public struct TargetSuggestion: Sendable, Hashable, Codable {
    /// Suggested daily target, rounded to the nearest 10 kcal.
    public let suggestedKcal: Double
    /// `suggestedKcal - currentKcal`.
    public let differenceKcal: Double
    /// True when the difference is at least `ProgressStats.suggestionThresholdKcal` and a current target exists.
    public let isSignificant: Bool
}

/// One training day of one exercise.
public struct ExerciseSession: Sendable, Hashable, Codable {
    /// Start of the calendar day.
    public let day: Date
    /// The set with the highest Epley e1RM that day; the heaviest set when no set has an e1RM.
    public let topSet: SetRecord
    /// Best Epley e1RM of the day (nil when every set is above 10 reps).
    public let bestEstimate: Double?
    /// Sum of weight x reps over the day's valid sets.
    public let volumeKg: Double
}

/// The best value of one record kind for an exercise.
public struct ExerciseRecord: Sendable, Hashable, Codable {
    public let kind: PRKind
    public let valueKg: Double
    /// The set that holds the record (the earliest one on a tie).
    public let set: SetRecord
}

/// One exercise in the record list.
public struct ExerciseSummary: Sendable, Hashable, Codable {
    public let exerciseID: String
    /// Start of the day of the most recent session.
    public let lastDay: Date
    /// All-time best e1RM, nil when no valid set has one.
    public let bestEstimate: Double?
    /// The set behind `bestEstimate`; the heaviest set when there is no estimate.
    public let bestSet: SetRecord
    public let sessionCount: Int
}

/// Aggregations behind the Progress tab. Pure functions; views and the app-side loader only call them.
///
/// Decided here (spec silent):
/// - A "session" of an exercise is one calendar day (`SetRecord` carries no session id).
/// - Invalid sets (reps < 1, non-positive or non-finite weight) are ignored everywhere.
/// - A week's mean is over its logged days only, and only days inside the requested window count,
///   so the first and last bars of a window can rest on fewer than 7 days.
public enum ProgressStats {
    /// A suggested target must differ from the current one by at least this much to be shown.
    public static let suggestionThresholdKcal: Double = 50

    // MARK: - Windows

    /// First day of a window of `days` calendar days that ends on the day of `end` (inclusive).
    /// `days` below 1 is treated as 1.
    public static func windowStart(days: Int, endingOn end: Date,
                                   calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        let endDay = calendar.startOfDay(for: end)
        return calendar.date(byAdding: .day, value: -(max(1, days) - 1), to: endDay) ?? endDay
    }

    // MARK: - Weight

    /// Trend change over a window: last trend value minus the first one on or after `since`.
    /// Nil with fewer than two points in the window.
    public static func trendChange(_ points: [TrendPoint], since: Date) -> Double? {
        let inWindow = points.filter { $0.day >= since }.sorted { $0.day < $1.day }
        guard inWindow.count >= 2, let first = inWindow.first, let last = inWindow.last else { return nil }
        return last.trendKg - first.trendKg
    }

    // MARK: - Intake

    /// Weekly mean of the daily intake totals.
    ///
    /// Intake records of one day are summed; days without records do not exist and so do not
    /// dilute the mean. Records with non-finite or negative kcal are ignored. Only days from the
    /// day of `from` to the day of `through` (inclusive) count. Output is ordered by week, oldest first.
    public static func weeklyIntake(
        _ intakes: [DailyIntake],
        from: Date,
        through: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [WeeklyIntake] {
        let first = calendar.startOfDay(for: from)
        let last = calendar.startOfDay(for: through)
        var perDay: [Date: Double] = [:]
        for intake in intakes where intake.kcal.isFinite && intake.kcal >= 0 {
            let day = calendar.startOfDay(for: intake.date)
            guard day >= first, day <= last else { continue }
            perDay[day, default: 0] += intake.kcal
        }
        var perWeek: [Date: (total: Double, days: Int)] = [:]
        for (day, kcal) in perDay {
            let week = calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
            let current = perWeek[week] ?? (0, 0)
            perWeek[week] = (current.total + kcal, current.days + 1)
        }
        return perWeek
            .map { WeeklyIntake(weekStart: $0.key, meanKcal: $0.value.total / Double($0.value.days), loggedDays: $0.value.days) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    // MARK: - Adaptive TDEE

    /// Weigh-in and logged-day counts in the `windowDays` days ending on the day of `end`.
    public static func coverage(
        weights: [WeightEntry],
        intakes: [DailyIntake],
        windowDays: Int = AdaptiveTDEE.defaultWindowDays,
        endingOn end: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> TDEECoverage {
        let start = windowStart(days: windowDays, endingOn: end, calendar: calendar)
        let endDay = calendar.startOfDay(for: end)
        let weighDays = Set(weights.filter { $0.weightKg.isFinite && $0.weightKg > 0 }
            .map { calendar.startOfDay(for: $0.date) }
            .filter { $0 >= start && $0 <= endDay })
        let loggedDays = Set(intakes.filter { $0.kcal.isFinite && $0.kcal >= 0 }
            .map { calendar.startOfDay(for: $0.date) }
            .filter { $0 >= start && $0 <= endDay })
        var span = 0
        if let firstDay = weighDays.min(), let lastDay = weighDays.max() {
            span = DayMath.offset(from: firstDay, to: lastDay, calendar: calendar)
        }
        return TDEECoverage(spanDays: span, weighInDays: weighDays.count, loggedDays: loggedDays.count)
    }

    /// Daily target for an estimated TDEE and the user's goal (same math as onboarding), rounded to
    /// 10 kcal, compared with the current target.
    public static func targetSuggestion(tdee: Double, plan: GoalPlan, weightKg: Double,
                                        currentKcal: Double) -> TargetSuggestion {
        let raw = Energy.target(tdee: tdee, plan: plan, weightKg: weightKg).kcal
        let suggested = Double(DisplayRounding.kcal(raw / 10)) * 10
        let difference = suggested - currentKcal
        let significant = currentKcal > 0 && abs(difference) >= suggestionThresholdKcal - 1e-9
        return TargetSuggestion(suggestedKcal: suggested, differenceKcal: difference, isSignificant: significant)
    }

    // MARK: - Exercises

    /// Sessions (one per calendar day) of the given sets, oldest first. Pass the sets of one exercise.
    public static func exerciseSessions(_ sets: [SetRecord],
                                        calendar: Calendar = Calendar(identifier: .gregorian)) -> [ExerciseSession] {
        let byDay = Dictionary(grouping: sets.filter(isValid)) { calendar.startOfDay(for: $0.date) }
        return byDay.keys.sorted().compactMap { day in
            guard let daySets = byDay[day]?.sorted(by: { $0.date < $1.date }),
                  let top = topSet(in: daySets) else { return nil }
            return ExerciseSession(
                day: day,
                topSet: top,
                bestEstimate: daySets.compactMap(\.estimatedOneRepMax).max(),
                volumeKg: daySets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
            )
        }
    }

    /// One summary per exercise, most recently trained first (ties by exercise ID).
    public static func exerciseSummaries(_ sets: [SetRecord],
                                         calendar: Calendar = Calendar(identifier: .gregorian)) -> [ExerciseSummary] {
        let byExercise = Dictionary(grouping: sets.filter(isValid), by: \.exerciseID)
        let summaries: [ExerciseSummary] = byExercise.compactMap { id, exerciseSets in
            let sessions = exerciseSessions(exerciseSets, calendar: calendar)
            guard let lastDay = sessions.last?.day else { return nil }
            let best = sessions
                .filter { $0.bestEstimate != nil }
                .max { ($0.bestEstimate ?? 0) < ($1.bestEstimate ?? 0) }
            guard let bestSet = best?.topSet ?? topSet(in: exerciseSets.sorted { $0.date < $1.date }) else { return nil }
            return ExerciseSummary(exerciseID: id, lastDay: lastDay, bestEstimate: best?.bestEstimate,
                                   bestSet: bestSet, sessionCount: sessions.count)
        }
        return summaries.sorted {
            $0.lastDay != $1.lastDay ? $0.lastDay > $1.lastDay : $0.exerciseID < $1.exerciseID
        }
    }

    /// All-time record per kind for the sets of one exercise, in `PRKind.allCases` order.
    /// A kind without a valid set is omitted; on a tie the earliest set holds the record.
    public static func exerciseRecords(_ sets: [SetRecord]) -> [ExerciseRecord] {
        let ordered = sets.filter(isValid).sorted { $0.date < $1.date }
        return PRKind.allCases.compactMap { kind in
            var best: ExerciseRecord?
            for candidate in ordered {
                guard let value = PersonalRecords.value(of: candidate, kind: kind) else { continue }
                if let current = best, value <= current.valueKg { continue }
                best = ExerciseRecord(kind: kind, valueKg: value, set: candidate)
            }
            return best
        }
    }

    /// Highest e1RM set; the heaviest set when none has an e1RM. Earliest wins ties.
    private static func topSet(in sets: [SetRecord]) -> SetRecord? {
        var best: (set: SetRecord, estimate: Double)?
        for candidate in sets {
            guard let estimate = candidate.estimatedOneRepMax else { continue }
            if let current = best, estimate <= current.estimate { continue }
            best = (candidate, estimate)
        }
        if let best { return best.set }
        var heaviest: SetRecord?
        for candidate in sets {
            if let current = heaviest, candidate.weightKg <= current.weightKg { continue }
            heaviest = candidate
        }
        return heaviest
    }

    private static func isValid(_ set: SetRecord) -> Bool {
        set.reps >= 1 && set.weightKg.isFinite && set.weightKg > 0
    }
}

extension DisplayRounding {
    /// Nearest 0.5 kg, half away from zero (strength weights and e1RM). Non-finite values give 0.
    public static func halfKilogram(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return (value * 2).rounded() / 2
    }
}
