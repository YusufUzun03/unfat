import Foundation
import Testing

/// Tolerance comparison for Double results.
func approx(_ a: Double, _ b: Double, tolerance: Double = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}

/// Gregorian calendar fixed to UTC so day bucketing is deterministic on every machine.
let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// 2026-01-01 00:00:00 UTC.
let baseDate = Date(timeIntervalSince1970: 1_767_225_600)

/// `baseDate` + `day` days + `hour` hours.
func day(_ day: Int, hour: Int = 8) -> Date {
    baseDate.addingTimeInterval(Double(day) * 86_400 + Double(hour) * 3_600)
}
