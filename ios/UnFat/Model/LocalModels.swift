import Foundation
import SwiftData

// Local-only models (configuration with `cloudKitDatabase: .none`). They never sync:
// HealthKit data must not leave the device (guideline 5.1.3(ii)). Defaults are kept anyway so
// the types stay valid if a configuration is ever reshuffled.

/// Open Food Facts lookup cache, keyed by barcode (one row per barcode, upserted by the client).
@Model
final class CachedProduct {
    var barcode: String = ""
    var name: String?
    var brand: String?
    var kcalPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var fiberPer100g: Double?
    var servingLabel: String?
    var servingGrams: Double?
    var imageURLString: String?
    /// true when OFF answered "product not found", so repeated scans skip the network.
    var isNotFound: Bool = false
    var fetchedAt: Date = Date.now

    init(barcode: String, fetchedAt: Date = .now) {
        self.barcode = barcode
        self.fetchedAt = fetchedAt
    }
}

/// Per-day values read from HealthKit (one row per calendar day, `day` = start of day).
@Model
final class HealthDaySummary {
    var day: Date = Date.now
    var steps: Int?
    var activeKcal: Double?
    /// Latest body mass sample of the day from Health (not user-entered; those are `WeightEntry`).
    var bodyMassKg: Double?
    var updatedAt: Date = Date.now

    init(day: Date, steps: Int? = nil, activeKcal: Double? = nil, bodyMassKg: Double? = nil) {
        self.day = day
        self.steps = steps
        self.activeKcal = activeKcal
        self.bodyMassKg = bodyMassKg
    }
}
