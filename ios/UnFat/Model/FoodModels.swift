import Foundation
import SwiftData

// Synced models (CloudKit rules: every property optional or defaulted, no unique constraints).

/// A food the user created. Logging it copies its values into a `FoodEntry`, so editing or
/// deleting it never changes history.
@Model
final class CustomFood {
    var uuid: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var name: String = ""
    var brand: String?
    /// Set when the food was created from a barcode that Open Food Facts did not know.
    var barcode: String?
    var kcalPer100g: Double = 0
    var proteinPer100g: Double = 0
    var carbsPer100g: Double = 0
    var fatPer100g: Double = 0
    var fiberPer100g: Double?
    var servingLabel: String?
    var servingGrams: Double?

    init(
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        kcalPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        fiberPer100g: Double? = nil,
        servingLabel: String? = nil,
        servingGrams: Double? = nil
    ) {
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.servingLabel = servingLabel
        self.servingGrams = servingGrams
    }

    var foodRef: String { ItemRef.custom(uuid) }
}

/// One logged food on the timeline. Stores a nutrition snapshot plus a `foodRef` string,
/// never a relationship to a food.
/// Quick-kcal entries use `grams = 100` and `kcalPer100g = kcal` (see `quickAdd`).
@Model
final class FoodEntry {
    var uuid: UUID = UUID()
    var loggedAt: Date = Date.now
    var createdAt: Date = Date.now
    var name: String = ""
    var kcalPer100g: Double = 0
    var proteinPer100g: Double = 0
    var carbsPer100g: Double = 0
    var fatPer100g: Double = 0
    var fiberPer100g: Double?
    var grams: Double = 100
    /// Serving chip used in the editor, e.g. "kase"; display only.
    var servingLabel: String?
    /// Number of servings when a serving chip was used (1.5 kase); display only, `grams` is authoritative.
    var servingCount: Double?
    var sourceRaw: String = FoodSource.custom.rawValue
    /// `seed:<id>`, `off:<barcode>`, `custom:<uuid>`, `quick` or `photo` (see `ItemRef`).
    var foodRef: String = ""
    /// Optional free-text tag; there are no meal buckets.
    var tag: String?

    init(
        name: String,
        kcalPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        fiberPer100g: Double? = nil,
        grams: Double,
        servingLabel: String? = nil,
        servingCount: Double? = nil,
        source: FoodSource,
        foodRef: String,
        loggedAt: Date = .now,
        tag: String? = nil
    ) {
        self.name = name
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.grams = grams
        self.servingLabel = servingLabel
        self.servingCount = servingCount
        self.sourceRaw = source.rawValue
        self.foodRef = foodRef
        self.loggedAt = loggedAt
        self.tag = tag
    }

    /// Snapshot of a custom food; later edits to `food` do not affect this entry.
    convenience init(
        snapshotOf food: CustomFood,
        grams: Double,
        servingLabel: String? = nil,
        servingCount: Double? = nil,
        loggedAt: Date = .now
    ) {
        self.init(
            name: food.name,
            kcalPer100g: food.kcalPer100g,
            proteinPer100g: food.proteinPer100g,
            carbsPer100g: food.carbsPer100g,
            fatPer100g: food.fatPer100g,
            fiberPer100g: food.fiberPer100g,
            grams: grams,
            servingLabel: servingLabel,
            servingCount: servingCount,
            source: .custom,
            foodRef: food.foodRef,
            loggedAt: loggedAt
        )
    }

    /// Snapshot of a bundled seed food.
    convenience init(
        snapshotOf food: SeedFood,
        grams: Double,
        servingLabel: String? = nil,
        servingCount: Double? = nil,
        loggedAt: Date = .now
    ) {
        self.init(
            name: food.name,
            kcalPer100g: food.per100g.kcal,
            proteinPer100g: food.per100g.protein,
            carbsPer100g: food.per100g.carbs,
            fatPer100g: food.per100g.fat,
            fiberPer100g: food.per100g.fiber,
            grams: grams,
            servingLabel: servingLabel,
            servingCount: servingCount,
            source: .seed,
            foodRef: food.foodRef,
            loggedAt: loggedAt
        )
    }

    /// Calories-only entry ("quick kcal"): stored as 100 g of a food with `kcal` per 100 g.
    static func quickAdd(name: String, kcal: Double, loggedAt: Date = .now) -> FoodEntry {
        FoodEntry(
            name: name,
            kcalPer100g: kcal,
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatPer100g: 0,
            grams: 100,
            source: .quickAdd,
            foodRef: ItemRef.quickAdd,
            loggedAt: loggedAt
        )
    }

    var source: FoodSource {
        get { FoodSource(rawValue: sourceRaw) ?? .custom }
        set { sourceRaw = newValue.rawValue }
    }

    // Amounts for this entry: per-100 g value scaled by grams.
    var kcal: Double { kcalPer100g * grams / 100 }
    var protein: Double { proteinPer100g * grams / 100 }
    var carbs: Double { carbsPer100g * grams / 100 }
    var fat: Double { fatPer100g * grams / 100 }
    var fiber: Double? { fiberPer100g.map { $0 * grams / 100 } }
}

/// A pinned food for the top of the add sheet. Points at the food by `foodRef` and keeps a
/// display name so it still renders if the referenced food is gone.
@Model
final class FavoriteFood {
    var uuid: UUID = UUID()
    var createdAt: Date = Date.now
    var foodRef: String = ""
    var name: String = ""
    var defaultGrams: Double?
    var servingLabel: String?
    var order: Int = 0

    init(foodRef: String, name: String, defaultGrams: Double? = nil, servingLabel: String? = nil, order: Int = 0) {
        self.foodRef = foodRef
        self.name = name
        self.defaultGrams = defaultGrams
        self.servingLabel = servingLabel
        self.order = order
    }
}
