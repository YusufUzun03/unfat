import Foundation
import SwiftData
import Testing
@testable import UnFat

@Suite("Food log service")
@MainActor
struct FoodLogServiceTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let calendar: Calendar
    let catalog: SeedCatalog

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        self.calendar = calendar
        catalog = SeedCatalog(
            foods: [
                SeedFood(
                    id: "tr-test-soup",
                    name: "Mercimek çorbası",
                    per100g: SeedNutrients(kcal: 63, protein: 2.7, carbs: 8.2, fat: 2.3, fiber: 1.5),
                    servings: [SeedServing(label: "kase", grams: 250), SeedServing(label: "kepçe", grams: 120)]
                ),
                SeedFood(
                    id: "tr-test-ayran",
                    name: "Ayran",
                    per100g: SeedNutrients(kcal: 37, protein: 1.7, carbs: 2.6, fat: 2.0, fiber: nil),
                    servings: [SeedServing(label: "bardak", grams: 200)]
                ),
            ],
            exercises: []
        )
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)))
    }

    @discardableResult
    private func insertEntry(
        _ name: String,
        kcal: Double,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        grams: Double = 100,
        ref: String? = nil,
        at loggedAt: Date
    ) -> FoodEntry {
        let entry = FoodEntry(
            name: name,
            kcalPer100g: kcal,
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            grams: grams,
            servingLabel: "kase",
            servingCount: grams / 250,
            source: .seed,
            foodRef: ref ?? ItemRef.seed(name),
            loggedAt: loggedAt
        )
        context.insert(entry)
        return entry
    }

    private func allEntries() throws -> [FoodEntry] {
        try context.fetch(FetchDescriptor<FoodEntry>())
    }

    // MARK: - Day totals

    @Test func totalsSumOnlyTheRequestedDay() throws {
        insertEntry("a", kcal: 100, protein: 10, carbs: 20, fat: 5, grams: 200, at: try date(3, 8))
        insertEntry("b", kcal: 50, protein: 2, carbs: 4, fat: 1, grams: 100, at: try date(3, 23, 55))
        insertEntry("yesterday", kcal: 999, protein: 99, carbs: 99, fat: 99, at: try date(2, 23, 59))
        insertEntry("tomorrow", kcal: 999, protein: 99, carbs: 99, fat: 99, at: try date(4, 0, 0))
        try context.save()

        let totals = try FoodLogService.totals(on: try date(3, 12), in: context, calendar: calendar)
        #expect(abs(totals.kcal - 250) < 0.0001)
        #expect(abs(totals.protein - 22) < 0.0001)
        #expect(abs(totals.carbs - 44) < 0.0001)
        #expect(abs(totals.fat - 11) < 0.0001)

        let inMemory = FoodLogService.totals(
            of: FoodLogService.entries(on: try date(3, 12), from: try allEntries(), calendar: calendar)
        )
        #expect(inMemory == totals)
    }

    @Test func entriesAreOldestFirst() throws {
        insertEntry("late", kcal: 10, at: try date(3, 20))
        insertEntry("early", kcal: 10, at: try date(3, 7))
        insertEntry("mid", kcal: 10, at: try date(3, 13))
        try context.save()

        let names = try FoodLogService.entries(on: try date(3, 12), in: context, calendar: calendar).map(\.name)
        #expect(names == ["early", "mid", "late"])
        let inMemoryNames = FoodLogService.entries(on: try date(3, 12), from: try allEntries(), calendar: calendar).map(\.name)
        #expect(inMemoryNames == ["early", "mid", "late"])
    }

    @Test func emptyDayHasZeroTotals() throws {
        let totals = try FoodLogService.totals(on: try date(3, 12), in: context, calendar: calendar)
        #expect(totals == .zero)
    }

    @Test func deleteUpdatesTotals() throws {
        let first = insertEntry("a", kcal: 200, at: try date(3, 8))
        insertEntry("b", kcal: 100, at: try date(3, 12))
        try context.save()
        #expect(try FoodLogService.totals(on: try date(3, 12), in: context, calendar: calendar).kcal == 300)

        try FoodLogService.delete(first, in: context)

        #expect(try FoodLogService.totals(on: try date(3, 12), in: context, calendar: calendar).kcal == 100)
        #expect(try allEntries().count == 1)
    }

    // MARK: - Recents, favorites, search

    @Test func recentsAreNewestFirstAndDistinct() throws {
        insertEntry("old soup", kcal: 63, ref: ItemRef.seed("tr-test-soup"), at: try date(1, 12))
        insertEntry("ayran", kcal: 37, ref: ItemRef.seed("tr-test-ayran"), at: try date(2, 12))
        insertEntry("new soup", kcal: 63, ref: ItemRef.seed("tr-test-soup"), at: try date(3, 12))
        try context.save()

        let recents = FoodLogService.recentFoods(from: try allEntries(), customFoods: [], catalog: catalog)
        #expect(recents.map(\.foodRef) == [ItemRef.seed("tr-test-soup"), ItemRef.seed("tr-test-ayran")])
        // Resolved from the catalog, not from the entry snapshot.
        #expect(recents.first?.name == "Mercimek çorbası")
    }

    @Test func recentsAreLimitedAndSkipQuickEntries() throws {
        for index in 0..<15 {
            insertEntry("food \(index)", kcal: 10, ref: ItemRef.seed("missing-\(index)"), at: try date(3, 6, index))
        }
        let quick = FoodEntry.quickAdd(name: "Hızlı kcal", kcal: 300, loggedAt: try date(3, 23))
        context.insert(quick)
        try context.save()

        let recents = FoodLogService.recentFoods(from: try allEntries(), customFoods: [], catalog: catalog, limit: 10)
        #expect(recents.count == 10)
        #expect(!recents.contains { $0.foodRef == ItemRef.quickAdd })
        // Unresolvable refs fall back to the newest entry snapshot.
        #expect(recents.first?.name == "food 14")
    }

    @Test func recentsResolveCustomFoods() throws {
        let custom = CustomFood(name: "Ev yoğurdu", kcalPer100g: 63, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.3, servingLabel: "kase", servingGrams: 200)
        context.insert(custom)
        context.insert(FoodEntry(snapshotOf: custom, grams: 200, loggedAt: try date(3, 9)))
        try context.save()

        let recents = FoodLogService.recentFoods(from: try allEntries(), customFoods: [custom], catalog: catalog)
        #expect(recents.count == 1)
        #expect(recents[0].source == .custom)
        #expect(recents[0].servings == [SeedServing(label: "kase", grams: 200)])
    }

    @Test func searchPutsCustomFoodsFirst() throws {
        let custom = CustomFood(name: "Mercimek köftesi", kcalPer100g: 180, proteinPer100g: 6, carbsPer100g: 25, fatPer100g: 6)
        context.insert(custom)
        try context.save()

        let results = FoodLogService.search("mercimek", customFoods: [custom], catalog: catalog)
        #expect(results.map(\.name) == ["Mercimek köftesi", "Mercimek çorbası"])
        #expect(FoodLogService.search("xyz", customFoods: [custom], catalog: catalog).isEmpty)
    }

    @Test func addFavoriteSkipsDuplicatesAndQuickEntries() throws {
        let entry = insertEntry("Ayran", kcal: 37, ref: ItemRef.seed("tr-test-ayran"), at: try date(3, 12))
        let quick = FoodEntry.quickAdd(name: "Hızlı kcal", kcal: 300, loggedAt: try date(3, 13))
        context.insert(quick)
        try context.save()

        #expect(try FoodLogService.addFavorite(from: entry, in: context))
        #expect(try !FoodLogService.addFavorite(from: entry, in: context))
        #expect(try !FoodLogService.addFavorite(from: quick, in: context))
        #expect(try context.fetch(FetchDescriptor<FavoriteFood>()).count == 1)
    }

    // MARK: - Portion math and snapshots

    @Test func servingUnitGramsAreAmountTimesServingGrams() throws {
        let food = LoggableFood(seed: try #require(catalog.food(id: "tr-test-soup")))
        let units = food.portionUnits
        #expect(units.map(\.chipTitle) == ["1 kase", "1 kepçe", "100 g", "g"])

        let kase = try #require(units.first)
        #expect(FoodLogService.grams(amount: 1.5, unit: kase) == 375)
        #expect(FoodLogService.grams(amount: 2, unit: .hundredGrams) == 200)
        #expect(FoodLogService.grams(amount: 180, unit: .grams) == 180)
    }

    @Test func foodWithoutServingsOffersOnlyGramUnits() {
        let food = LoggableFood(seed: SeedFood(
            id: "x", name: "X", per100g: SeedNutrients(kcal: 100, protein: 1, carbs: 1, fat: 1, fiber: nil)
        ))
        #expect(food.portionUnits.map(\.id) == ["g100", "g"])
        #expect(food.defaultGrams == 100)
    }

    @Test func makeEntrySnapshotsPer100gValuesAndServing() throws {
        let food = LoggableFood(seed: try #require(catalog.food(id: "tr-test-soup")))
        let kase = try #require(food.portionUnits.first)
        let entry = FoodLogService.makeEntry(food: food, unit: kase, amount: 1.5, loggedAt: try date(3, 13))

        #expect(entry.name == "Mercimek çorbası")
        #expect(entry.kcalPer100g == 63)
        #expect(entry.proteinPer100g == 2.7)
        #expect(entry.carbsPer100g == 8.2)
        #expect(entry.fatPer100g == 2.3)
        #expect(entry.fiberPer100g == 1.5)
        #expect(entry.grams == 375)
        #expect(entry.servingLabel == "kase")
        #expect(entry.servingCount == 1.5)
        #expect(entry.source == .seed)
        #expect(entry.foodRef == "seed:tr-test-soup")
        #expect(abs(entry.kcal - 236.25) < 0.0001)

        let grams = FoodLogService.makeEntry(food: food, unit: .grams, amount: 80, loggedAt: try date(3, 13))
        #expect(grams.grams == 80)
        #expect(grams.servingLabel == nil)
        #expect(grams.servingCount == nil)
    }

    @Test func logInsertsEntryAndEditKeepsSnapshot() throws {
        let food = LoggableFood(seed: try #require(catalog.food(id: "tr-test-ayran")))
        let bardak = try #require(food.portionUnits.first)
        let entry = try FoodLogService.log(food: food, unit: bardak, amount: 1, loggedAt: try date(3, 12), in: context)
        #expect(try allEntries().count == 1)
        #expect(entry.grams == 200)

        try FoodLogService.update(entry, unit: .grams, amount: 150, loggedAt: try date(3, 14), in: context)
        #expect(entry.grams == 150)
        #expect(entry.servingLabel == nil)
        #expect(entry.kcalPer100g == 37)
        let expectedTime = try date(3, 14)
        #expect(entry.loggedAt == expectedTime)
    }

    @Test func logRejectsNonPositiveAmount() throws {
        let food = LoggableFood(seed: try #require(catalog.food(id: "tr-test-ayran")))
        #expect(throws: FoodLogError.self) {
            try FoodLogService.log(food: food, unit: .grams, amount: 0, in: context)
        }
        #expect(try allEntries().isEmpty)
    }

    @Test func quickEntriesStoreKcalAsOneHundredGrams() throws {
        let entry = try FoodLogService.logQuick(name: "Hızlı kcal", kcal: 420, loggedAt: try date(3, 15), in: context)
        #expect(entry.grams == 100)
        #expect(entry.kcalPer100g == 420)
        #expect(entry.foodRef == ItemRef.quickAdd)
        #expect(entry.kcal == 420)
        #expect(entry.protein == 0)

        try FoodLogService.updateQuick(entry, name: "Kuruyemiş", kcal: 180, loggedAt: try date(3, 16), in: context)
        #expect(entry.name == "Kuruyemiş")
        #expect(entry.kcal == 180)
    }

    @Test func amountTextConversions() {
        #expect(FoodLogService.amount(from: "12.5") == 12.5)
        #expect(FoodLogService.amount(from: "") == nil)
        #expect(FoodLogService.canonicalAmount(1.5, maxFractionDigits: 2) == "1.5")
        #expect(FoodLogService.canonicalAmount(2, maxFractionDigits: 2) == "2")
        #expect(FoodLogService.canonicalAmount(1.0 / 3.0, maxFractionDigits: 2) == "0.33")
        #expect(FoodLogService.canonicalAmount(0, maxFractionDigits: 1) == "0")
    }

    // MARK: - Copy yesterday

    @Test func copyYesterdayDuplicatesEntriesAtTheSameTimeOfDay() throws {
        insertEntry("breakfast", kcal: 200, protein: 8, carbs: 30, fat: 4, grams: 150, at: try date(2, 8, 5))
        insertEntry("dinner", kcal: 300, grams: 250, at: try date(2, 19, 40))
        insertEntry("older", kcal: 999, at: try date(1, 12))
        try context.save()

        let now = try date(3, 9)
        #expect(try FoodLogService.yesterdayEntries(now: now, in: context, calendar: calendar).count == 2)

        let count = try FoodLogService.copyYesterday(now: now, in: context, calendar: calendar)
        #expect(count == 2)

        let today = try FoodLogService.entries(on: now, in: context, calendar: calendar)
        #expect(today.map(\.name) == ["breakfast", "dinner"])
        let expectedTimes = [try date(3, 8, 5), try date(3, 19, 40)]
        #expect(today.map(\.loggedAt) == expectedTimes)
        #expect(today[0].grams == 150)
        #expect(today[0].proteinPer100g == 8)
        #expect(today[0].foodRef == ItemRef.seed("breakfast"))
        #expect(today[0].servingLabel == "kase")

        // Yesterday is untouched.
        #expect(try FoodLogService.entries(on: try date(2, 12), in: context, calendar: calendar).count == 2)
        #expect(try allEntries().count == 5)
    }

    @Test func copyYesterdayWithNothingToCopyAddsNothing() throws {
        insertEntry("older", kcal: 100, at: try date(1, 12))
        try context.save()
        let count = try FoodLogService.copyYesterday(now: try date(3, 9), in: context, calendar: calendar)
        #expect(count == 0)
        #expect(try allEntries().count == 1)
    }

    // MARK: - Custom food

    @Test func decimalInputAcceptsCommaAndRejectsGarbage() {
        #expect(DecimalInput.parse("12,5") == 12.5)
        #expect(DecimalInput.parse(" 7.25 ") == 7.25)
        #expect(DecimalInput.parse("0") == 0)
        #expect(DecimalInput.parse("") == nil)
        #expect(DecimalInput.parse("abc") == nil)
        #expect(DecimalInput.parse("-3") == nil)
        #expect(DecimalInput.parse("1,2,3") == nil)
    }

    @Test func customFoodDraftValidation() {
        var draft = CustomFoodDraft()
        #expect(!draft.isValid)

        draft.name = "  Ev yoğurdu "
        draft.kcalText = "63"
        #expect(draft.isValid)
        #expect(draft.trimmedName == "Ev yoğurdu")
        #expect(draft.protein == 0)

        draft.proteinText = "3,5"
        #expect(draft.protein == 3.5)

        draft.fatText = "abc"
        #expect(!draft.isValid)
        draft.fatText = ""

        draft.servingLabel = "kase"
        #expect(!draft.isValid)
        draft.servingGramsText = "200"
        #expect(draft.isValid)
        draft.servingGramsText = "0"
        #expect(!draft.isValid)
    }

    @Test func createCustomFoodStoresValuesAndServing() throws {
        var draft = CustomFoodDraft()
        draft.name = "Ev yoğurdu"
        draft.kcalText = "63"
        draft.proteinText = "3,5"
        draft.carbsText = "4,7"
        draft.fatText = "3,3"
        draft.servingLabel = "kase"
        draft.servingGramsText = "200"

        let food = try FoodLogService.createCustomFood(draft, in: context)
        #expect(food.name == "Ev yoğurdu")
        #expect(food.kcalPer100g == 63)
        #expect(food.proteinPer100g == 3.5)
        #expect(food.servingLabel == "kase")
        #expect(food.servingGrams == 200)
        #expect(try context.fetch(FetchDescriptor<CustomFood>()).count == 1)

        let loggable = LoggableFood(custom: food)
        #expect(loggable.foodRef == food.foodRef)
        #expect(loggable.defaultGrams == 200)

        #expect(throws: FoodLogError.self) {
            try FoodLogService.createCustomFood(CustomFoodDraft(), in: context)
        }
    }

    @Test func editableFoodKeepsEntrySnapshotAndAddsSourceServings() throws {
        let entry = insertEntry("Mercimek çorbası", kcal: 70, grams: 250, ref: ItemRef.seed("tr-test-soup"), at: try date(3, 13))
        try context.save()

        let food = FoodLogService.editableFood(for: entry, customFoods: [], catalog: catalog)
        #expect(food.kcalPer100g == 70)
        #expect(food.servings.map(\.label) == ["kase", "kepçe"])

        let orphan = insertEntry("Eski yemek", kcal: 40, grams: 250, ref: ItemRef.seed("gone"), at: try date(3, 14))
        let orphanFood = FoodLogService.editableFood(for: orphan, customFoods: [], catalog: catalog)
        #expect(orphanFood.servings.map(\.label) == ["kase"])
    }
}

#if DEBUG
@MainActor
@Test func foodLogDebugRoutesParseAndBuildFixtures() throws {
    #expect(LaunchRoute(rawValue: "today-empty")?.destination == .screen(.foodLog(.todayEmpty)))
    #expect(LaunchRoute(rawValue: "custom-food")?.destination == .screen(.foodLog(.customFood)))

    let container = try #require(FoodLogFixtures.makeContainer(.todayEmpty))
    let today = try FoodLogService.entries(on: .now, in: container.mainContext)
    let yesterday = try FoodLogService.yesterdayEntries(in: container.mainContext)
    #expect(today.isEmpty)
    #expect(yesterday.count == 3)
}
#endif
