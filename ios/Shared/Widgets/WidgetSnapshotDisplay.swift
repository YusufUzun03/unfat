import Foundation

/// Turns the stored `WidgetSnapshot` into what a widget shows at a given moment.
/// Pure functions, no WidgetKit: unit-tested in the app test target.
enum WidgetSnapshotDisplay {
    /// The snapshot to render at `now`. A missing file gives an empty no-target snapshot; a snapshot
    /// from another day keeps its targets but counts as nothing eaten (date rollover).
    static func snapshot(stored: WidgetSnapshot?, now: Date, calendar: Calendar = .current) -> WidgetSnapshot {
        let today = calendar.startOfDay(for: now)
        guard var snapshot = stored else { return WidgetSnapshot(date: today) }
        guard calendar.isDate(snapshot.date, inSameDayAs: now) else {
            snapshot.date = today
            snapshot.kcalEaten = 0
            snapshot.proteinEaten = 0
            snapshot.carbsEaten = 0
            snapshot.fatEaten = 0
            return snapshot
        }
        return snapshot
    }

    /// Start of the calendar day after `now`, when the timeline must roll over.
    static func nextMidnight(after now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
    }
}

extension WidgetSnapshot {
    /// False until onboarding saved a calorie target; widgets then show a neutral "set a goal" state.
    var hasTarget: Bool { kcalTarget > 0 }

    /// Eaten / target; 0 without a target. Can exceed 1.
    var kcalProgress: Double {
        guard hasTarget else { return 0 }
        return max(kcalEaten, 0) / kcalTarget
    }

    var isOverTarget: Bool { hasTarget && kcalEaten > kcalTarget }

    /// Display-only difference: kcal left, or kcal over once past the target. Never negative.
    var kcalLeftOrOver: Double {
        isOverTarget ? kcalEaten - kcalTarget : max(kcalTarget - kcalEaten, 0)
    }

    /// Fixture for the widget placeholder, previews and the debug gallery.
    static func sample(date: Date = .now, calendar: Calendar = .current) -> WidgetSnapshot {
        WidgetSnapshot(
            date: calendar.startOfDay(for: date),
            kcalEaten: 1240,
            kcalTarget: 2000,
            proteinEaten: 80,
            proteinTarget: 150,
            carbsEaten: 140,
            carbsTarget: 220,
            fatEaten: 40,
            fatTarget: 65
        )
    }
}
