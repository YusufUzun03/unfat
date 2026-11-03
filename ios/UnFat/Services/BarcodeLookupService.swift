import Foundation
import SwiftData

/// What a scanned barcode resolved to.
enum BarcodeLookupOutcome: Equatable {
    /// The user already has a custom food with this barcode; it wins over Open Food Facts.
    case customFood(LoggableFood)
    /// Open Food Facts knows the product (kcal may be missing, see `OFFProduct.hasEnergy`).
    case product(OFFProduct)
    case notFound(barcode: String)
}

/// Barcode lookup order: custom food with this barcode, fresh cache row, network (then cached).
/// Found products stay fresh for 30 days, "not found" answers for 1 day.
@MainActor
struct BarcodeLookupService {
    static let foundTTL: TimeInterval = 30 * 24 * 3600
    static let notFoundTTL: TimeInterval = 24 * 3600

    let fetcher: any OpenFoodFactsFetching
    var now: () -> Date = { .now }

    init(fetcher: any OpenFoodFactsFetching = OpenFoodFactsClient(), now: @escaping () -> Date = { .now }) {
        self.fetcher = fetcher
        self.now = now
    }

    static func isFresh(_ cached: CachedProduct, now: Date) -> Bool {
        let ttl = cached.isNotFound ? notFoundTTL : foundTTL
        return now.timeIntervalSince(cached.fetchedAt) < ttl
    }

    func lookup(_ rawBarcode: String, in context: ModelContext) async throws -> BarcodeLookupOutcome {
        guard let barcode = BarcodeValidator.normalized(rawBarcode) else { throw OFFError.invalidBarcode }

        if let custom = try customFood(withBarcode: barcode, in: context) {
            return .customFood(LoggableFood(custom: custom))
        }

        let cached = try cachedRow(barcode, in: context)
        if let cached, Self.isFresh(cached, now: now()) {
            return Self.outcome(from: cached)
        }

        let result = try await fetcher.fetch(barcode: barcode)
        try store(result, barcode: barcode, row: cached, in: context)
        switch result {
        case .found(let product): return .product(product)
        case .notFound: return .notFound(barcode: barcode)
        }
    }

    // MARK: - Pieces

    private func customFood(withBarcode barcode: String, in context: ModelContext) throws -> CustomFood? {
        // Custom foods are few, so filtering in memory avoids optional-string predicates.
        try context.fetch(FetchDescriptor<CustomFood>())
            .filter { $0.barcode == barcode }
            .max { $0.createdAt < $1.createdAt }
    }

    private func cachedRow(_ barcode: String, in context: ModelContext) throws -> CachedProduct? {
        let descriptor = FetchDescriptor<CachedProduct>(
            predicate: #Predicate { $0.barcode == barcode },
            sortBy: [SortDescriptor(\CachedProduct.fetchedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    /// Upserts the cache row (one row per barcode).
    private func store(_ result: OFFLookupResult, barcode: String, row: CachedProduct?, in context: ModelContext) throws {
        let date = now()
        let cached = row ?? CachedProduct(barcode: barcode, fetchedAt: date)
        if row == nil { context.insert(cached) }
        cached.fetchedAt = date
        switch result {
        case .found(let product):
            cached.isNotFound = false
            cached.name = product.name
            cached.brand = product.brand
            cached.kcalPer100g = product.kcalPer100g
            cached.proteinPer100g = product.proteinPer100g
            cached.carbsPer100g = product.carbsPer100g
            cached.fatPer100g = product.fatPer100g
            cached.fiberPer100g = product.fiberPer100g
            cached.servingLabel = product.servingText
            cached.servingGrams = product.servingGrams
            cached.imageURLString = product.imageURLString
        case .notFound:
            cached.isNotFound = true
            cached.name = nil
            cached.brand = nil
            cached.kcalPer100g = nil
            cached.proteinPer100g = nil
            cached.carbsPer100g = nil
            cached.fatPer100g = nil
            cached.fiberPer100g = nil
            cached.servingLabel = nil
            cached.servingGrams = nil
            cached.imageURLString = nil
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func outcome(from cached: CachedProduct) -> BarcodeLookupOutcome {
        cached.isNotFound ? .notFound(barcode: cached.barcode) : .product(product(from: cached))
    }

    static func product(from cached: CachedProduct) -> OFFProduct {
        OFFProduct(
            barcode: cached.barcode,
            name: cached.name,
            brand: cached.brand,
            kcalPer100g: cached.kcalPer100g,
            proteinPer100g: cached.proteinPer100g,
            carbsPer100g: cached.carbsPer100g,
            fatPer100g: cached.fatPer100g,
            fiberPer100g: cached.fiberPer100g,
            servingText: cached.servingLabel,
            servingGrams: cached.servingGrams,
            imageURLString: cached.imageURLString
        )
    }
}

extension LoggableFood {
    /// A loggable food from an OFF product; nil while the product has no kcal value. Missing macros count as 0.
    /// The serving chip appears only when OFF gave grams for it.
    init?(product: OFFProduct) {
        guard let kcal = product.kcalPer100g else { return nil }
        foodRef = ItemRef.openFoodFacts(product.barcode)
        name = product.name ?? product.barcode
        source = .openFoodFacts
        kcalPer100g = kcal
        proteinPer100g = product.proteinPer100g ?? 0
        carbsPer100g = product.carbsPer100g ?? 0
        fatPer100g = product.fatPer100g ?? 0
        fiberPer100g = product.fiberPer100g
        if let grams = product.servingGrams, grams > 0 {
            servings = [SeedServing(label: String(localized: "porsiyon"), grams: grams)]
        } else {
            servings = []
        }
    }
}

extension CustomFoodDraft {
    /// Form values for the custom food form from whatever OFF knew, plus the barcode.
    @MainActor
    init(product: OFFProduct) {
        func text(_ value: Double?) -> String {
            value.map { FoodLogService.canonicalAmount($0, maxFractionDigits: 1) } ?? ""
        }
        self.init()
        name = product.name ?? ""
        brand = product.brand
        barcode = product.barcode
        kcalText = text(product.kcalPer100g)
        proteinText = text(product.proteinPer100g)
        carbsText = text(product.carbsPer100g)
        fatText = text(product.fatPer100g)
        if let grams = product.servingGrams, grams > 0 {
            servingLabel = String(localized: "porsiyon")
            servingGramsText = FoodLogService.canonicalAmount(grams, maxFractionDigits: 1)
        }
    }

    /// Empty draft that only carries the barcode.
    init(barcode: String) {
        self.init()
        self.barcode = barcode
    }
}
