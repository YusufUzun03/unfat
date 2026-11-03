import Foundation
import SwiftData

// Synced models (CloudKit rules: every property optional or defaulted, no unique constraints).

/// The user's body data, goal and daily targets. One per user; with sync on, duplicates from
/// several devices are possible, so readers use `UserProfile.current(in:)` (latest `updatedAt`).
@Model
final class UserProfile {
    var uuid: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var sexRaw: String = Sex.female.rawValue
    var birthYear: Int = 2000
    var heightCm: Double = 170
    var activityLevelRaw: String = ActivityLevel.moderate.rawValue
    var goalRaw: String = WeightGoal.maintain.rawValue
    /// Planned weight change in kg per week, always >= 0; direction comes from `goal`.
    var weeklyRateKg: Double = 0
    /// Daily targets; 0 means "not set yet".
    var targetKcal: Double = 0
    var targetProteinG: Double = 0
    var targetCarbsG: Double = 0
    var targetFatG: Double = 0
    var unitSystemRaw: String = UnitSystem.metric.rawValue
    var onboardingCompletedAt: Date?

    init(
        sex: Sex = .female,
        birthYear: Int = 2000,
        heightCm: Double = 170,
        activityLevel: ActivityLevel = .moderate,
        goal: WeightGoal = .maintain,
        weeklyRateKg: Double = 0,
        targetKcal: Double = 0,
        targetProteinG: Double = 0,
        targetCarbsG: Double = 0,
        targetFatG: Double = 0,
        unitSystem: UnitSystem = .metric,
        onboardingCompletedAt: Date? = nil
    ) {
        self.sexRaw = sex.rawValue
        self.birthYear = birthYear
        self.heightCm = heightCm
        self.activityLevelRaw = activityLevel.rawValue
        self.goalRaw = goal.rawValue
        self.weeklyRateKg = weeklyRateKg
        self.targetKcal = targetKcal
        self.targetProteinG = targetProteinG
        self.targetCarbsG = targetCarbsG
        self.targetFatG = targetFatG
        self.unitSystemRaw = unitSystem.rawValue
        self.onboardingCompletedAt = onboardingCompletedAt
    }

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .female }
        set { sexRaw = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .moderate }
        set { activityLevelRaw = newValue.rawValue }
    }

    var goal: WeightGoal {
        get { WeightGoal(rawValue: goalRaw) ?? .maintain }
        set { goalRaw = newValue.rawValue }
    }

    var unitSystem: UnitSystem {
        get { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
        set { unitSystemRaw = newValue.rawValue }
    }

    /// The profile to use: the most recently updated one (sync can produce duplicates).
    static func current(in context: ModelContext) throws -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\UserProfile.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

/// A user-entered weigh-in. Health weights live in the local-only `HealthDaySummary`.
@Model
final class WeightEntry {
    var uuid: UUID = UUID()
    var date: Date = Date.now
    var kg: Double = 0
    var createdAt: Date = Date.now

    init(date: Date = .now, kg: Double) {
        self.date = date
        self.kg = kg
    }
}
