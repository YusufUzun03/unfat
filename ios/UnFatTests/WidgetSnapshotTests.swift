import Foundation
import SwiftData
import Testing
@testable import UnFat

@Suite("Widget snapshot")
@MainActor
struct WidgetSnapshotTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let calendar: Calendar

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        self.calendar = calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)))
    }

    private func entry(_ name: String, kcal: Double, protein: Double, carbs: Double, fat: Double, grams: Double, at loggedAt: Date) -> FoodEntry {
        FoodEntry(
            name: name,
            kcalPer100g: kcal,
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            grams: grams,
            source: .seed,
            foodRef: ItemRef.seed(name),
            loggedAt: loggedAt
        )
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "widget-snapshot-\(UUID().uuidString).json")
    }

    @Test func sumsOnlyTheRequestedDay() throws {
        let profile = UserProfile(targetKcal: 2200, targetProteinG: 150, targetCarbsG: 250, targetFatG: 66)
        let entries = [
            entry("a", kcal: 100, protein: 10, carbs: 20, fat: 5, grams: 200, at: try date(3, 0, 5)),
            entry("b", kcal: 50, protein: 2, carbs: 4, fat: 1, grams: 100, at: try date(3, 23, 55)),
            entry("yesterday", kcal: 999, protein: 99, carbs: 99, fat: 99, grams: 100, at: try date(2, 23, 59)),
            entry("tomorrow", kcal: 999, protein: 99, carbs: 99, fat: 99, grams: 100, at: try date(4, 0, 0)),
        ]

        let snapshot = WidgetSnapshotWriter.makeSnapshot(entries: entries, profile: profile, day: try date(3, 12), calendar: calendar)

        #expect(snapshot.date == calendar.startOfDay(for: try date(3, 12)))
        #expect(abs(snapshot.kcalEaten - 250) < 0.0001)
        #expect(abs(snapshot.proteinEaten - 22) < 0.0001)
        #expect(abs(snapshot.carbsEaten - 44) < 0.0001)
        #expect(abs(snapshot.fatEaten - 11) < 0.0001)
        #expect(snapshot.kcalTarget == 2200)
        #expect(snapshot.proteinTarget == 150)
        #expect(snapshot.carbsTarget == 250)
        #expect(snapshot.fatTarget == 66)
    }

    @Test func missingProfileGivesZeroTargets() throws {
        let snapshot = WidgetSnapshotWriter.makeSnapshot(entries: [], profile: nil, day: try date(3, 12), calendar: calendar)
        #expect(snapshot == WidgetSnapshot(date: calendar.startOfDay(for: try date(3, 12))))
    }

    @Test func snapshotFetchesFromContext() throws {
        context.insert(UserProfile(targetKcal: 2000, targetProteinG: 120, targetCarbsG: 230, targetFatG: 60))
        context.insert(entry("today", kcal: 200, protein: 10, carbs: 30, fat: 5, grams: 150, at: try date(3, 9)))
        context.insert(FoodEntry.quickAdd(name: "quick", kcal: 100, loggedAt: try date(3, 15)))
        context.insert(entry("yesterday", kcal: 500, protein: 1, carbs: 1, fat: 1, grams: 100, at: try date(2, 20)))
        try context.save()

        let snapshot = try WidgetSnapshotWriter.snapshot(for: try date(3, 18), in: context, calendar: calendar)
        #expect(abs(snapshot.kcalEaten - 400) < 0.0001)
        #expect(abs(snapshot.proteinEaten - 15) < 0.0001)
        #expect(snapshot.kcalTarget == 2000)
    }

    @Test func updateWritesFileThatStoreReadsBack() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        context.insert(UserProfile(targetKcal: 1800))
        context.insert(entry("today", kcal: 300, protein: 20, carbs: 30, fat: 10, grams: 100, at: try date(3, 9)))
        try context.save()

        let written = WidgetSnapshotWriter.update(
            context: context,
            now: try date(3, 10),
            calendar: calendar,
            url: url,
            reloadWidgets: false
        )

        let snapshot = try #require(written)
        #expect(WidgetSnapshotStore.read(from: url) == snapshot)
        #expect(snapshot.kcalEaten == 300)
        #expect(snapshot.kcalTarget == 1800)
    }

    @Test func storeRoundTripAndMissingFile() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(WidgetSnapshotStore.read(from: url) == nil)

        let snapshot = WidgetSnapshot(date: try date(3, 0), kcalEaten: 1234.5, kcalTarget: 2200, proteinEaten: 80, proteinTarget: 150)
        try WidgetSnapshotStore.write(snapshot, to: url)
        #expect(WidgetSnapshotStore.read(from: url) == snapshot)

        #expect(throws: WidgetSnapshotStore.StoreError.self) {
            try WidgetSnapshotStore.write(snapshot, to: nil)
        }
        #expect(WidgetSnapshotStore.fileName == "widget-snapshot.json")
    }
}
