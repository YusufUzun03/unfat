import Foundation
import Testing
@testable import UnFat

@Suite("Widget display")
struct WidgetDisplayTests {
    let calendar: Calendar

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        self.calendar = calendar
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)))
    }

    private func stored(on day: Date, eaten: Double = 1240) -> WidgetSnapshot {
        WidgetSnapshot(
            date: calendar.startOfDay(for: day),
            kcalEaten: eaten,
            kcalTarget: 2000,
            proteinEaten: 80,
            proteinTarget: 150,
            carbsEaten: 140,
            carbsTarget: 220,
            fatEaten: 40,
            fatTarget: 65
        )
    }

    @Test func sameDayPassesThrough() throws {
        let snapshot = stored(on: try date(11, 3, 9))
        let shown = WidgetSnapshotDisplay.snapshot(stored: snapshot, now: try date(11, 3, 23, 59), calendar: calendar)
        #expect(shown == snapshot)
    }

    @Test func previousDayKeepsTargetsAndZeroesEaten() throws {
        let snapshot = stored(on: try date(11, 2, 20))
        let now = try date(11, 3, 0, 1)
        let shown = WidgetSnapshotDisplay.snapshot(stored: snapshot, now: now, calendar: calendar)
        #expect(shown.date == calendar.startOfDay(for: now))
        #expect(shown.kcalEaten == 0)
        #expect(shown.proteinEaten == 0)
        #expect(shown.carbsEaten == 0)
        #expect(shown.fatEaten == 0)
        #expect(shown.kcalTarget == 2000)
        #expect(shown.proteinTarget == 150)
        #expect(shown.carbsTarget == 220)
        #expect(shown.fatTarget == 65)
        #expect(shown.hasTarget)
    }

    @Test func missingFileGivesEmptyNoTargetSnapshot() throws {
        let now = try date(11, 3, 12)
        let shown = WidgetSnapshotDisplay.snapshot(stored: nil, now: now, calendar: calendar)
        #expect(shown == WidgetSnapshot(date: calendar.startOfDay(for: now)))
        #expect(!shown.hasTarget)
        #expect(shown.kcalProgress == 0)
        #expect(shown.kcalLeftOrOver == 0)
    }

    @Test func zeroTargetIsNoTargetEvenWithEatenKcal() throws {
        let snapshot = WidgetSnapshot(date: calendar.startOfDay(for: try date(11, 3, 9)), kcalEaten: 300)
        #expect(!snapshot.hasTarget)
        #expect(!snapshot.isOverTarget)
        #expect(snapshot.kcalProgress == 0)
    }

    @Test func kcalLeftBelowTarget() throws {
        let snapshot = stored(on: try date(11, 3, 9), eaten: 1240)
        #expect(!snapshot.isOverTarget)
        #expect(snapshot.kcalLeftOrOver == 760)
        #expect(abs(snapshot.kcalProgress - 0.62) < 0.0001)
    }

    @Test func exactlyAtTargetIsNotOver() throws {
        let snapshot = stored(on: try date(11, 3, 9), eaten: 2000)
        #expect(!snapshot.isOverTarget)
        #expect(snapshot.kcalLeftOrOver == 0)
        #expect(snapshot.kcalProgress == 1)
    }

    @Test func overTargetShowsKcalOver() throws {
        let snapshot = stored(on: try date(11, 3, 9), eaten: 2260)
        #expect(snapshot.isOverTarget)
        #expect(snapshot.kcalLeftOrOver == 260)
        #expect(abs(snapshot.kcalProgress - 1.13) < 0.0001)
    }

    @Test func nextMidnightIsStartOfNextDay() throws {
        let midnight = WidgetSnapshotDisplay.nextMidnight(after: try date(11, 3, 15, 30), calendar: calendar)
        let expected = try date(11, 4, 0)
        #expect(midnight == expected)
        // Exactly at midnight the next rollover is a full day away.
        let atMidnight = WidgetSnapshotDisplay.nextMidnight(after: try date(11, 3, 0), calendar: calendar)
        #expect(atMidnight == expected)
    }

    @Test func nextMidnightAcrossDaylightSavingChange() throws {
        // Europe/London clocks go back on 2026-10-25 (25 hour day); a fixed 24 h add would be wrong.
        var london = Calendar(identifier: .gregorian)
        london.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let now = try #require(london.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12)))
        let expected = try #require(london.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 0)))
        let midnight = WidgetSnapshotDisplay.nextMidnight(after: now, calendar: london)
        #expect(midnight == expected)
        #expect(expected.timeIntervalSince(london.startOfDay(for: now)) == 25 * 3600)
    }

    @Test func timelineEntryAtMidnightRollsOver() throws {
        let snapshot = stored(on: try date(11, 3, 9))
        let midnight = WidgetSnapshotDisplay.nextMidnight(after: try date(11, 3, 21), calendar: calendar)
        let shown = WidgetSnapshotDisplay.snapshot(stored: snapshot, now: midnight, calendar: calendar)
        #expect(shown.kcalEaten == 0)
        #expect(shown.kcalTarget == 2000)
        #expect(shown.date == midnight)
    }
}
