import Foundation
import SwiftData

/// Summed nutrition of a set of entries.
struct DayTotals: Equatable, Sendable {
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0

    static let zero = DayTotals()
}

/// One way to measure a food in the entry editor: a serving of the food, 100 g, or plain grams.
/// The amount typed on the keypad is in this unit; `grams = amount * gramsPerUnit`.
struct PortionUnit: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case serving
        case hundredGrams
        case grams
    }

    let id: String
    let kind: Kind
    /// Serving name ("kase") for `.serving`; empty otherwise.
    let label: String
    let gramsPerUnit: Double

    static let hundredGrams = PortionUnit(id: "g100", kind: .hundredGrams, label: "", gramsPerUnit: 100)
    static let grams = PortionUnit(id: "g", kind: .grams, label: "", gramsPerUnit: 1)

    static func serving(index: Int, label: String, grams: Double) -> PortionUnit {
        PortionUnit(id: servingID(index), kind: .serving, label: label, gramsPerUnit: grams)
    }

    static func servingID(_ index: Int) -> String { "s\(index)" }

    /// Chip text: "1 kase", "100 g", "g" (units and data names, shown verbatim).
    var chipTitle: String {
        switch kind {
        case .serving: "1 \(label)"
        case .hundredGrams: "100 g"
        case .grams: "g"
        }
    }

    /// Text after the typed amount: "kase", "× 100 g", "g".
    var amountSuffix: String {
        switch kind {
        case .serving: label
        case .hundredGrams: "× 100 g"
        case .grams: "g"
        }
    }

    var maxFractionDigits: Int { kind == .grams ? 1 : 2 }

    var option: ServingOption { ServingOption(id: id, title: chipTitle) }
}

/// A food that can be logged: a bundled seed food, a custom food, or the snapshot of an earlier entry
/// whose source food no longer resolves. Plain values only, so it can travel through navigation.
struct LoggableFood: Hashable, Sendable, Identifiable {
    var foodRef: String
    var name: String
    var source: FoodSource
    var kcalPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var fiberPer100g: Double?
    var servings: [SeedServing]

    var id: String { foodRef }

    init(seed food: SeedFood) {
        foodRef = food.foodRef
        name = food.name
        source = .seed
        kcalPer100g = food.per100g.kcal
        proteinPer100g = food.per100g.protein
        carbsPer100g = food.per100g.carbs
        fatPer100g = food.per100g.fat
        fiberPer100g = food.per100g.fiber
        servings = food.servings
    }

    init(custom food: CustomFood) {
        foodRef = food.foodRef
        name = food.name
        source = .custom
        kcalPer100g = food.kcalPer100g
        proteinPer100g = food.proteinPer100g
        carbsPer100g = food.carbsPer100g
        fatPer100g = food.fatPer100g
        fiberPer100g = food.fiberPer100g
        if let label = food.servingLabel, let grams = food.servingGrams, grams > 0, !label.isEmpty {
            servings = [SeedServing(label: label, grams: grams)]
        } else {
            servings = []
        }
    }

    /// Snapshot values of an existing entry. The serving it used (if any) becomes the only serving.
    init(snapshotOf entry: FoodEntry) {
        foodRef = entry.foodRef
        name = entry.name
        source = entry.source
        kcalPer100g = entry.kcalPer100g
        proteinPer100g = entry.proteinPer100g
        carbsPer100g = entry.carbsPer100g
        fatPer100g = entry.fatPer100g
        fiberPer100g = entry.fiberPer100g
        if let label = entry.servingLabel, !label.isEmpty {
            let count = entry.servingCount ?? 1
            let gramsPerServing = count > 0 ? entry.grams / count : 0
            servings = gramsPerServing > 0 ? [SeedServing(label: label, grams: gramsPerServing)] : []
        } else {
            servings = []
        }
    }

    /// Serving units first, then "100 g" and "g".
    var portionUnits: [PortionUnit] {
        var units: [PortionUnit] = []
        for (index, serving) in servings.enumerated() where serving.grams > 0 && !serving.label.isEmpty {
            units.append(.serving(index: index, label: serving.label, grams: serving.grams))
        }
        units.append(.hundredGrams)
        units.append(.grams)
        return units
    }

    /// Grams of the first serving, or 100 g when the food has none.
    var defaultGrams: Double {
        servings.first(where: { $0.grams > 0 && !$0.label.isEmpty })?.grams ?? 100
    }

    func nutrients(forGrams grams: Double) -> DayTotals {
        DayTotals(
            kcal: kcalPer100g * grams / 100,
            protein: proteinPer100g * grams / 100,
            carbs: carbsPer100g * grams / 100,
            fat: fatPer100g * grams / 100
        )
    }
}

/// Parsing of typed decimal numbers (Turkish comma or dot).
enum DecimalInput {
    /// A finite, non-negative number written with digits and one optional "," or "."; nil otherwise.
    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty,
              trimmed.allSatisfy({ ("0"..."9").contains($0) || $0 == "." }),
              let value = Double(trimmed),
              value.isFinite
        else { return nil }
        return value
    }
}

/// Text fields of the custom food form, validated into numbers.
struct CustomFoodDraft: Hashable, Sendable {
    var name = ""
    /// Set when the draft comes from a scanned product; saved with the food.
    var brand: String?
    var barcode: String?
    var kcalText = ""
    var proteinText = ""
    var carbsText = ""
    var fatText = ""
    var servingLabel = ""
    var servingGramsText = ""

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedServingLabel: String { servingLabel.trimmingCharacters(in: .whitespacesAndNewlines) }

    var kcal: Double? { DecimalInput.parse(kcalText) }

    /// 0 when blank, the value when valid, nil when the text is not a number.
    private static func macro(_ text: String) -> Double? {
        text.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : DecimalInput.parse(text)
    }

    var protein: Double? { Self.macro(proteinText) }
    var carbs: Double? { Self.macro(carbsText) }
    var fat: Double? { Self.macro(fatText) }

    /// Both serving fields blank = no serving; otherwise both must be valid.
    var servingIsValid: Bool {
        let gramsBlank = servingGramsText.trimmingCharacters(in: .whitespaces).isEmpty
        if trimmedServingLabel.isEmpty { return gramsBlank }
        guard let grams = DecimalInput.parse(servingGramsText) else { return false }
        return grams > 0
    }

    var isValid: Bool {
        !trimmedName.isEmpty && kcal != nil && protein != nil && carbs != nil && fat != nil && servingIsValid
    }
}

enum FoodLogError: Error {
    case invalidInput
}

/// Everything the Today and add-sheet screens need that is not drawing: day totals, recents,
/// search, portion math, snapshot entries, edit/delete, copy yesterday. Views call this and do no
/// nutrition math themselves.
@MainActor
enum FoodLogService {
    private static let seedPrefix = "seed:"
    private static let customPrefix = "custom:"

    // MARK: - Day queries

    /// Entries that fall on `day`'s calendar day, oldest first.
    static func entries(on day: Date, from entries: [FoodEntry], calendar: Calendar = .current) -> [FoodEntry] {
        entries
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
            .sorted { lhs, rhs in
                if lhs.loggedAt != rhs.loggedAt { return lhs.loggedAt < rhs.loggedAt }
                return lhs.createdAt < rhs.createdAt
            }
    }

    static func entries(on day: Date, in context: ModelContext, calendar: Calendar = .current) throws -> [FoodEntry] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { entry in
                entry.loggedAt >= start && entry.loggedAt < end
            },
            sortBy: [SortDescriptor(\FoodEntry.loggedAt)]
        )
        return try context.fetch(descriptor)
    }

    static func totals(of entries: [FoodEntry]) -> DayTotals {
        entries.reduce(into: DayTotals.zero) { totals, entry in
            totals.kcal += entry.kcal
            totals.protein += entry.protein
            totals.carbs += entry.carbs
            totals.fat += entry.fat
        }
    }

    static func totals(on day: Date, in context: ModelContext, calendar: Calendar = .current) throws -> DayTotals {
        totals(of: try entries(on: day, in: context, calendar: calendar))
    }

    static func yesterday(of day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: day)) ?? day.addingTimeInterval(-86_400)
    }

    // MARK: - Foods: recents, favorites, search

    /// `quick` and `photo` entries have no food behind them.
    static func isLoggableRef(_ foodRef: String) -> Bool {
        !foodRef.isEmpty && foodRef != ItemRef.quickAdd && foodRef != ItemRef.photo
    }

    private static func lookup(foodRef: String, customFoods: [CustomFood], catalog: SeedCatalog) -> LoggableFood? {
        if foodRef.hasPrefix(seedPrefix), let food = catalog.food(id: String(foodRef.dropFirst(seedPrefix.count))) {
            return LoggableFood(seed: food)
        }
        if foodRef.hasPrefix(customPrefix),
           let uuid = UUID(uuidString: String(foodRef.dropFirst(customPrefix.count))),
           let food = customFoods.first(where: { $0.uuid == uuid }) {
            return LoggableFood(custom: food)
        }
        return nil
    }

    /// The food behind `foodRef`: bundled seed food, custom food, or the newest entry's snapshot.
    static func resolve(
        foodRef: String,
        entries: [FoodEntry],
        customFoods: [CustomFood],
        catalog: SeedCatalog = .shared
    ) -> LoggableFood? {
        guard isLoggableRef(foodRef) else { return nil }
        if let food = lookup(foodRef: foodRef, customFoods: customFoods, catalog: catalog) { return food }
        let newest = entries
            .filter { $0.foodRef == foodRef }
            .max { $0.loggedAt < $1.loggedAt }
        return newest.map { LoggableFood(snapshotOf: $0) }
    }

    /// The food an existing entry is edited with: the entry's own snapshot values and serving first,
    /// then the other servings of the source food when it still resolves.
    static func editableFood(
        for entry: FoodEntry,
        customFoods: [CustomFood],
        catalog: SeedCatalog = .shared
    ) -> LoggableFood {
        var food = LoggableFood(snapshotOf: entry)
        guard isLoggableRef(entry.foodRef),
              let source = lookup(foodRef: entry.foodRef, customFoods: customFoods, catalog: catalog)
        else { return food }
        for serving in source.servings where !food.servings.contains(where: { $0.label == serving.label }) {
            food.servings.append(serving)
        }
        return food
    }

    /// Last `limit` distinct foods from the entry history, newest first.
    static func recentFoods(
        from entries: [FoodEntry],
        customFoods: [CustomFood],
        catalog: SeedCatalog = .shared,
        limit: Int = 10
    ) -> [LoggableFood] {
        let newestFirst = entries.sorted { $0.loggedAt > $1.loggedAt }
        var seen = Set<String>()
        var result: [LoggableFood] = []
        for entry in newestFirst {
            guard result.count < limit else { break }
            guard isLoggableRef(entry.foodRef), seen.insert(entry.foodRef).inserted else { continue }
            let food = lookup(foodRef: entry.foodRef, customFoods: customFoods, catalog: catalog)
                ?? LoggableFood(snapshotOf: entry)
            result.append(food)
        }
        return result
    }

    /// Favorites in their saved order. A favorite whose food cannot be resolved is left out.
    static func favoriteFoods(
        _ favorites: [FavoriteFood],
        entries: [FoodEntry],
        customFoods: [CustomFood],
        catalog: SeedCatalog = .shared
    ) -> [LoggableFood] {
        favorites
            .sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.createdAt < rhs.createdAt
            }
            .compactMap { favorite in
                resolve(foodRef: favorite.foodRef, entries: entries, customFoods: customFoods, catalog: catalog)
            }
    }

    /// Custom foods first (best match first), then scanned Open Food Facts products from the cache,
    /// then bundled foods. Cached products without a name or kcal value are left out.
    static func search(
        _ query: String,
        customFoods: [CustomFood],
        cachedProducts: [CachedProduct] = [],
        catalog: SeedCatalog = .shared,
        limit: Int = 50
    ) -> [LoggableFood] {
        let customIndex = SeedSearchIndex(customFoods.map { SearchableText(name: $0.name) })
        let customs = customIndex.search(query).map { LoggableFood(custom: customFoods[$0]) }
        let scanned = cachedProducts
            .filter { !$0.isNotFound && $0.name != nil && $0.kcalPer100g != nil }
            .sorted { $0.fetchedAt > $1.fetchedAt }
        let scannedIndex = SeedSearchIndex(scanned.map { SearchableText(name: $0.name ?? "", aliases: [$0.brand].compactMap { $0 }) })
        let offFoods = scannedIndex.search(query).compactMap {
            LoggableFood(product: BarcodeLookupService.product(from: scanned[$0]))
        }
        let seeds = catalog.searchFoods(query, limit: limit).map { LoggableFood(seed: $0) }
        return customs + offFoods + seeds
    }

    // MARK: - Portion math

    /// Amount typed on the keypad (canonical text, "." decimal); nil when empty.
    static func amount(from text: String) -> Double? {
        KeypadInput.decimal(text).map { NSDecimalNumber(decimal: $0).doubleValue }
    }

    static func grams(amount: Double, unit: PortionUnit) -> Double {
        amount * unit.gramsPerUnit
    }

    /// Canonical keypad text for a number: rounded to `maxFractionDigits`, no trailing zeros, "." decimal.
    static func canonicalAmount(_ value: Double, maxFractionDigits: Int) -> String {
        guard value.isFinite, value > 0 else { return "0" }
        var text = String(format: "%.\(max(maxFractionDigits, 0))f", value)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }

    // MARK: - Writing entries

    private static func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Snapshot entry for `amount` of `unit` of `food` (not inserted).
    static func makeEntry(food: LoggableFood, unit: PortionUnit, amount: Double, loggedAt: Date) -> FoodEntry {
        let isServing = unit.kind == .serving
        return FoodEntry(
            name: food.name,
            kcalPer100g: food.kcalPer100g,
            proteinPer100g: food.proteinPer100g,
            carbsPer100g: food.carbsPer100g,
            fatPer100g: food.fatPer100g,
            fiberPer100g: food.fiberPer100g,
            grams: grams(amount: amount, unit: unit),
            servingLabel: isServing ? unit.label : nil,
            servingCount: isServing ? amount : nil,
            source: food.source,
            foodRef: food.foodRef,
            loggedAt: loggedAt
        )
    }

    @discardableResult
    static func log(
        food: LoggableFood,
        unit: PortionUnit,
        amount: Double,
        loggedAt: Date = .now,
        in context: ModelContext
    ) throws -> FoodEntry {
        guard amount > 0, unit.gramsPerUnit > 0 else { throw FoodLogError.invalidInput }
        let entry = makeEntry(food: food, unit: unit, amount: amount, loggedAt: loggedAt)
        context.insert(entry)
        try save(context)
        return entry
    }

    /// Changes the amount and time of an entry; its nutrition snapshot stays as logged.
    static func update(
        _ entry: FoodEntry,
        unit: PortionUnit,
        amount: Double,
        loggedAt: Date,
        in context: ModelContext
    ) throws {
        guard amount > 0, unit.gramsPerUnit > 0 else { throw FoodLogError.invalidInput }
        let isServing = unit.kind == .serving
        entry.grams = grams(amount: amount, unit: unit)
        entry.servingLabel = isServing ? unit.label : nil
        entry.servingCount = isServing ? amount : nil
        entry.loggedAt = loggedAt
        try save(context)
    }

    @discardableResult
    static func logQuick(name: String, kcal: Double, loggedAt: Date = .now, in context: ModelContext) throws -> FoodEntry {
        guard kcal > 0 else { throw FoodLogError.invalidInput }
        let entry = FoodEntry.quickAdd(name: name, kcal: kcal, loggedAt: loggedAt)
        context.insert(entry)
        try save(context)
        return entry
    }

    static func updateQuick(
        _ entry: FoodEntry,
        name: String,
        kcal: Double,
        loggedAt: Date,
        in context: ModelContext
    ) throws {
        guard kcal > 0 else { throw FoodLogError.invalidInput }
        entry.name = name
        entry.kcalPer100g = kcal
        entry.grams = 100
        entry.loggedAt = loggedAt
        try save(context)
    }

    static func delete(_ entry: FoodEntry, in context: ModelContext) throws {
        context.delete(entry)
        try save(context)
    }

    // MARK: - Copy yesterday

    static func yesterdayEntries(
        now: Date = .now,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> [FoodEntry] {
        try entries(on: yesterday(of: now, calendar: calendar), in: context, calendar: calendar)
    }

    /// Duplicates yesterday's entries onto today, keeping each time of day. Returns how many were copied.
    @discardableResult
    static func copyYesterday(
        now: Date = .now,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> Int {
        let source = try yesterdayEntries(now: now, in: context, calendar: calendar)
        for entry in source {
            let copy = FoodEntry(
                name: entry.name,
                kcalPer100g: entry.kcalPer100g,
                proteinPer100g: entry.proteinPer100g,
                carbsPer100g: entry.carbsPer100g,
                fatPer100g: entry.fatPer100g,
                fiberPer100g: entry.fiberPer100g,
                grams: entry.grams,
                servingLabel: entry.servingLabel,
                servingCount: entry.servingCount,
                source: entry.source,
                foodRef: entry.foodRef,
                loggedAt: calendar.date(byAdding: .day, value: 1, to: entry.loggedAt) ?? now,
                tag: entry.tag
            )
            context.insert(copy)
        }
        if !source.isEmpty { try save(context) }
        return source.count
    }

    // MARK: - Favorites and custom foods

    /// Pins the food of `entry` unless it is already a favorite or has no food behind it.
    /// Returns true when a favorite was added.
    @discardableResult
    static func addFavorite(from entry: FoodEntry, in context: ModelContext) throws -> Bool {
        guard isLoggableRef(entry.foodRef) else { return false }
        let existing = try context.fetch(FetchDescriptor<FavoriteFood>())
        guard !existing.contains(where: { $0.foodRef == entry.foodRef }) else { return false }
        let order = (existing.map(\.order).max() ?? -1) + 1
        context.insert(FavoriteFood(
            foodRef: entry.foodRef,
            name: entry.name,
            defaultGrams: entry.grams,
            servingLabel: entry.servingLabel,
            order: order
        ))
        try save(context)
        return true
    }

    @discardableResult
    static func createCustomFood(_ draft: CustomFoodDraft, in context: ModelContext) throws -> CustomFood {
        guard draft.isValid,
              let kcal = draft.kcal,
              let protein = draft.protein,
              let carbs = draft.carbs,
              let fat = draft.fat
        else { throw FoodLogError.invalidInput }
        let hasServing = !draft.trimmedServingLabel.isEmpty
        let food = CustomFood(
            name: draft.trimmedName,
            brand: draft.brand,
            barcode: draft.barcode,
            kcalPer100g: kcal,
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            servingLabel: hasServing ? draft.trimmedServingLabel : nil,
            servingGrams: hasServing ? DecimalInput.parse(draft.servingGramsText) : nil
        )
        context.insert(food)
        try save(context)
        return food
    }
}
