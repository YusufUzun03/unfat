import Foundation
import SwiftData
import UnFatCore

/// Range of the weight and weekly intake charts.
enum ProgressRange: Int, CaseIterable, Identifiable, Sendable {
    case days30 = 30
    case days90 = 90

    var id: Int { rawValue }
    var days: Int { rawValue }

    /// Weeks between x-axis labels, so 90 days stays readable on a phone.
    var axisWeekStride: Int { self == .days30 ? 1 : 3 }
}

/// The profile fields the Progress tab needs, detached from SwiftData.
struct ProfileInputs: Equatable, Sendable {
    var sex: Sex
    var birthYear: Int
    var heightCm: Double
    var activity: ActivityLevel
    var goal: WeightGoal
    var weeklyRateKg: Double
    var targetKcal: Double

    init(
        sex: Sex,
        birthYear: Int,
        heightCm: Double,
        activity: ActivityLevel,
        goal: WeightGoal,
        weeklyRateKg: Double,
        targetKcal: Double
    ) {
        self.sex = sex
        self.birthYear = birthYear
        self.heightCm = heightCm
        self.activity = activity
        self.goal = goal
        self.weeklyRateKg = weeklyRateKg
        self.targetKcal = targetKcal
    }

    init(_ profile: UserProfile) {
        self.init(
            sex: profile.sex,
            birthYear: profile.birthYear,
            heightCm: profile.heightCm,
            activity: profile.activityLevel,
            goal: profile.goal,
            weeklyRateKg: profile.weeklyRateKg,
            targetKcal: profile.targetKcal
        )
    }
}

/// State of the adaptive TDEE card.
enum EnergyCard: Equatable, Sendable {
    /// Not enough data (or no profile to derive the starting estimate from): shows the found counts.
    case needsData(weighInDays: Int, loggedDays: Int, spanDays: Int)
    /// An estimate exists. `suggestion.isSignificant` decides whether a new target is offered.
    case ready(tdee: Double, weighIns: Int, loggedDays: Int, suggestion: TargetSuggestion)

    /// The new target to offer, nil when the current one is up to date.
    var offeredTargetKcal: Double? {
        if case .ready(_, _, _, let suggestion) = self, suggestion.isSignificant {
            return suggestion.suggestedKcal
        }
        return nil
    }
}

/// Everything the weight, weekly intake and energy sections show.
struct ProgressSnapshot: Equatable, Sendable {
    var range: ProgressRange
    /// Daily trend points inside the range (gaps carry `weightKg == nil`).
    var points: [TrendPoint]
    /// Latest trend weight (over all fetched weigh-ins), nil without a weigh-in.
    var trendNowKg: Double?
    /// Trend change over the range, nil with fewer than two points.
    var trendChangeKg: Double?
    var weeks: [WeeklyIntake]
    var energy: EnergyCard

    var hasWeights: Bool { trendNowKg != nil }

    /// Y domain of the weight chart: the data (measured and trend) padded by 0.5 kg. Nil without points.
    var weightDomain: ClosedRange<Double>? {
        let values = points.flatMap { [$0.weightKg, $0.trendKg] }.compactMap { $0 }
        guard let low = values.min(), let high = values.max() else { return nil }
        return (low - 0.5)...(high + 0.5)
    }

    /// The point closest in time to `date` (chart selection).
    func nearestPoint(to date: Date) -> TrendPoint? {
        points.min { abs($0.day.timeIntervalSince(date)) < abs($1.day.timeIntervalSince(date)) }
    }

    /// The week bar that contains `date` (chart selection).
    func week(containing date: Date, calendar: Calendar = .current) -> WeeklyIntake? {
        weeks.first { week in
            guard let end = calendar.date(byAdding: .day, value: 7, to: week.weekStart) else { return false }
            return date >= week.weekStart && date < end
        }
    }
}

/// One exercise in the record list.
struct ExerciseRow: Identifiable, Equatable, Sendable {
    let ref: String
    let name: String
    let summary: ExerciseSummary

    var id: String { ref }
}

/// Data behind `ExerciseProgressView`.
struct ExerciseDetail: Equatable, Sendable {
    let ref: String
    let name: String
    /// Oldest first.
    let sessions: [ExerciseSession]
    let records: [ExerciseRecord]

    /// Best e1RM per session (sessions without an estimate are left out), oldest first.
    var estimates: [ExerciseEstimate] {
        sessions.compactMap { session in
            session.bestEstimate.map { ExerciseEstimate(day: session.day, estimateKg: $0) }
        }
    }

    /// Y domain of the e1RM chart, padded by 5 % of the spread (at least 2.5 kg). Nil without estimates.
    var estimateDomain: ClosedRange<Double>? {
        let values = estimates.map { $0.estimateKg }
        guard let low = values.min(), let high = values.max() else { return nil }
        let pad = max(2.5, (high - low) * 0.05)
        return (low - pad)...(high + pad)
    }

    func nearestEstimate(to date: Date) -> ExerciseEstimate? {
        estimates.min { abs($0.day.timeIntervalSince(date)) < abs($1.day.timeIntervalSince(date)) }
    }
}

/// One point of the e1RM chart.
struct ExerciseEstimate: Equatable, Sendable, Identifiable {
    let day: Date
    let estimateKg: Double

    var id: Date { day }
}

/// Weight entry input rules (kg field in the "Kilo ekle" sheet).
enum WeightInput {
    static let validRangeKg: ClosedRange<Double> = 30...300

    /// Parses a typed value; accepts a comma or a dot as the decimal separator.
    /// Nil when it is not a number or outside `validRangeKg`.
    static func parseKg(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, let value = Double(normalized), value.isFinite else { return nil }
        guard validRangeKg.contains(value) else { return nil }
        return value
    }

    /// A weigh-in cannot be in the future.
    static func isDateAllowed(_ date: Date, now: Date = .now) -> Bool {
        date <= now
    }

    static func canSave(text: String, date: Date, now: Date = .now) -> Bool {
        parseKg(text) != nil && isDateAllowed(date, now: now)
    }
}

/// Builds the Progress tab's numbers from plain rows. Views fetch rows (bounded by `dataStart`) and call
/// this; no math lives in the views.
enum ProgressData {
    /// Days of history before the chart window that seed the trend and cover the TDEE window.
    static let seedDays = AdaptiveTDEE.defaultWindowDays

    /// First day to fetch weigh-ins and food entries from for a range: the chart window or the TDEE
    /// window (whichever is longer) plus the seed days.
    static func dataStart(range: ProgressRange, now: Date, calendar: Calendar = .current) -> Date {
        let days = max(range.days, AdaptiveTDEE.defaultWindowDays) + seedDays
        return ProgressStats.windowStart(days: days, endingOn: now, calendar: calendar)
    }

    // MARK: - Snapshot

    static func snapshot(
        weights: [UnFatCore.WeightEntry],
        intakes: [DailyIntake],
        profile: ProfileInputs?,
        range: ProgressRange,
        now: Date,
        calendar: Calendar = .current
    ) -> ProgressSnapshot {
        let start = ProgressStats.windowStart(days: range.days, endingOn: now, calendar: calendar)
        let trend = Trend.daily(weights, calendar: calendar)
        return ProgressSnapshot(
            range: range,
            points: trend.filter { $0.day >= start },
            trendNowKg: trend.last?.trendKg,
            trendChangeKg: ProgressStats.trendChange(trend, since: start),
            weeks: ProgressStats.weeklyIntake(intakes, from: start, through: now, calendar: calendar),
            energy: energyCard(weights: weights, intakes: intakes, profile: profile, now: now, calendar: calendar)
        )
    }

    /// Adaptive TDEE over the last 28 days. The starting estimate is the formula TDEE from the profile and
    /// the latest trend weight (the profile does not store a TDEE).
    static func energyCard(
        weights: [UnFatCore.WeightEntry],
        intakes: [DailyIntake],
        profile: ProfileInputs?,
        now: Date,
        calendar: Calendar = .current
    ) -> EnergyCard {
        let latest = Trend.daily(weights, calendar: calendar).last
        let coverage = ProgressStats.coverage(
            weights: weights,
            intakes: intakes,
            endingOn: latest?.day ?? now,
            calendar: calendar
        )
        let needsData = EnergyCard.needsData(
            weighInDays: coverage.weighInDays,
            loggedDays: coverage.loggedDays,
            spanDays: coverage.spanDays
        )
        guard let profile, let latest else { return needsData }

        let input = TargetInput(
            sex: profile.sex,
            birthYear: profile.birthYear,
            heightCm: profile.heightCm,
            weightKg: latest.trendKg,
            activity: profile.activity,
            goal: profile.goal,
            weeklyRateKg: profile.weeklyRateKg
        )
        guard let previous = TargetCalculator.calculate(input, currentYear: calendar.component(.year, from: now)) else {
            return needsData
        }
        let result = AdaptiveTDEE.update(
            weights: weights,
            intakes: intakes,
            previousEstimate: previous.tdee,
            calendar: calendar
        )
        guard let estimate = result.estimate else { return needsData }
        let suggestion = TargetCalculator.targetSuggestion(
            tdee: estimate.tdee,
            goal: profile.goal,
            weeklyRateKg: profile.weeklyRateKg,
            weightKg: latest.trendKg,
            currentKcal: profile.targetKcal
        )
        return .ready(
            tdee: estimate.tdee,
            weighIns: estimate.weighIns,
            loggedDays: estimate.loggedDays,
            suggestion: suggestion
        )
    }

    // MARK: - Rows to core values

    static func coreWeights(_ entries: [WeightEntry]) -> [UnFatCore.WeightEntry] {
        entries.map { UnFatCore.WeightEntry(date: $0.date, weightKg: $0.kg) }
    }

    static func intakes(_ entries: [FoodEntry]) -> [DailyIntake] {
        entries.map { DailyIntake(date: $0.loggedAt, kcal: $0.kcal) }
    }

    // MARK: - Writes

    /// Saves a weigh-in. A second entry on the same day is allowed.
    @MainActor
    @discardableResult
    static func addWeight(kg: Double, date: Date, in context: ModelContext) throws -> WeightEntry {
        let entry = WeightEntry(date: date, kg: kg)
        context.insert(entry)
        try context.save()
        return entry
    }

    /// Takes over a suggested target: sets the calorie target, re-derives the macros the way the goal editor
    /// does, stamps `updatedAt` and saves.
    @MainActor
    static func acceptSuggestion(
        kcal: Double,
        weightKg: Double,
        profile: UserProfile,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        let macros = TargetCalculator.macros(kcal: kcal, weightKg: weightKg)
        profile.targetKcal = kcal
        profile.targetProteinG = macros.proteinG
        profile.targetCarbsG = macros.carbsG
        profile.targetFatG = macros.fatG
        profile.updatedAt = now
        try context.save()
    }

    // MARK: - Exercises

    /// Exercises with at least one done set in a finished session, most recently trained first.
    /// The name comes from the newest session that contains the exercise.
    @MainActor
    static func exerciseRows(sessions: [WorkoutSession], calendar: Calendar = .current) -> [ExerciseRow] {
        let finished = sessions.filter { !$0.isActive }
        let names = latestNames(in: finished)
        let sets = finished.flatMap { WorkoutSessionService.setRecords(of: $0) }
        return ProgressStats.exerciseSummaries(sets, calendar: calendar).map {
            ExerciseRow(ref: $0.exerciseID, name: names[$0.exerciseID] ?? "", summary: $0)
        }
    }

    @MainActor
    static func exerciseDetail(ref: String, sessions: [WorkoutSession], calendar: Calendar = .current) -> ExerciseDetail {
        let finished = sessions.filter { !$0.isActive }
        let names = latestNames(in: finished)
        let sets = finished.flatMap { WorkoutSessionService.setRecords(of: $0) }.filter { $0.exerciseID == ref }
        return ExerciseDetail(
            ref: ref,
            name: names[ref] ?? "",
            sessions: ProgressStats.exerciseSessions(sets, calendar: calendar),
            records: ProgressStats.exerciseRecords(sets)
        )
    }

    @MainActor
    private static func latestNames(in sessions: [WorkoutSession]) -> [String: String] {
        var names: [String: String] = [:]
        for session in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            for exercise in session.sortedExercises where !exercise.exerciseName.isEmpty {
                names[exercise.exerciseRef] = exercise.exerciseName
            }
        }
        return names
    }
}
