import Foundation
import os
import SwiftData
import WidgetKit

/// Builds today's `WidgetSnapshot` from `FoodEntry` rows and the profile targets, writes it to the
/// App Group and reloads widget timelines. Call `update(context:)` after every food or target change.
/// Only sums here; nutrition formulas live in UnFatCore.
@MainActor
enum WidgetSnapshotWriter {
    private static let logger = Logger(subsystem: "io.github.yusufuzun03.unfat", category: "Widget")

    /// Sums the entries that fall on `day`'s calendar day; targets come from `profile` (0 when nil).
    static func makeSnapshot(
        entries: [FoodEntry],
        profile: UserProfile?,
        day: Date,
        calendar: Calendar = .current
    ) -> WidgetSnapshot {
        let start = calendar.startOfDay(for: day)
        let dayEntries = entries.filter { calendar.isDate($0.loggedAt, inSameDayAs: start) }
        return WidgetSnapshot(
            date: start,
            kcalEaten: dayEntries.reduce(0) { $0 + $1.kcal },
            kcalTarget: profile?.targetKcal ?? 0,
            proteinEaten: dayEntries.reduce(0) { $0 + $1.protein },
            proteinTarget: profile?.targetProteinG ?? 0,
            carbsEaten: dayEntries.reduce(0) { $0 + $1.carbs },
            carbsTarget: profile?.targetCarbsG ?? 0,
            fatEaten: dayEntries.reduce(0) { $0 + $1.fat },
            fatTarget: profile?.targetFatG ?? 0
        )
    }

    /// Fetches `day`'s entries and the current profile from `context` and builds the snapshot.
    static func snapshot(
        for day: Date = .now,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> WidgetSnapshot {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { entry in
                entry.loggedAt >= start && entry.loggedAt < end
            }
        )
        let entries = try context.fetch(descriptor)
        let profile = try UserProfile.current(in: context)
        return makeSnapshot(entries: entries, profile: profile, day: start, calendar: calendar)
    }

    /// Computes, writes and reloads widgets. Returns the written snapshot, or nil on failure (logged).
    @discardableResult
    static func update(
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current,
        url: URL? = WidgetSnapshotStore.defaultURL,
        reloadWidgets: Bool = true
    ) -> WidgetSnapshot? {
        do {
            let current = try Self.snapshot(for: now, in: context, calendar: calendar)
            try WidgetSnapshotStore.write(current, to: url)
            if reloadWidgets {
                WidgetCenter.shared.reloadAllTimelines()
            }
            return current
        } catch {
            logger.error("widget snapshot update failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
