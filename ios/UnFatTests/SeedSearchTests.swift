import Foundation
import Testing
@testable import UnFat

@Suite("Seed search")
struct SeedSearchTests {
    private func food(_ id: String, _ name: String, aliases: [String] = []) -> SeedFood {
        SeedFood(id: id, name: name, aliases: aliases, per100g: SeedNutrients(kcal: 100, protein: 1, carbs: 1, fat: 1))
    }

    @Test func foldingHandlesTurkishCase() {
        #expect(SearchFolding.fold("İskender") == "iskender")
        #expect(SearchFolding.fold("ISKENDER") == "iskender")
        #expect(SearchFolding.fold("iskender") == "iskender")
        #expect(SearchFolding.fold("ıskender") == "iskender")
        #expect(SearchFolding.fold("IŞIK") == "isik")
        #expect(SearchFolding.fold("Işık") == "isik")
    }

    @Test func foldingRemovesDiacriticsAndPunctuation() {
        #expect(SearchFolding.fold("Mercimek Çorbası") == "mercimek corbasi")
        #expect(SearchFolding.fold("Çiğ köfte") == "cig kofte")
        #expect(SearchFolding.fold("ŞÖNÜĞÇ") == "sonugc")
        #expect(SearchFolding.fold("  Su böreği (dilim) ") == "su boregi dilim")
        #expect(SearchFolding.fold("Crème brûlée") == "creme brulee")
        #expect(SearchFolding.fold("Tavuk-döner, dürüm") == "tavuk doner durum")
        #expect(SearchFolding.fold("   ") == "")
    }

    @Test func diacriticFreeQueryFindsTurkishName() {
        let catalog = SeedCatalog(foods: [food("1", "Mercimek çorbası"), food("2", "Pilav")], exercises: [])
        #expect(catalog.searchFoods("corba").map(\.id) == ["1"])
        #expect(catalog.searchFoods("ÇORBA").map(\.id) == ["1"])
        #expect(catalog.searchFoods("mercimek corbasi").map(\.id) == ["1"])
    }

    @Test func dottedAndDotlessIMatch() {
        let catalog = SeedCatalog(foods: [food("1", "İskender kebap"), food("2", "Izgara köfte"), food("3", "Pilav")], exercises: [])
        for query in ["ISKENDER", "iskender", "İskender", "ıskender"] {
            #expect(catalog.searchFoods(query).map(\.id) == ["1"], "query: \(query)")
        }
        #expect(catalog.searchFoods("izgara").map(\.id) == ["2"])
        #expect(catalog.searchFoods("IZGARA").map(\.id) == ["2"])
        #expect(catalog.searchFoods("ızgara").map(\.id) == ["2"])
    }

    @Test func rankingOrder() {
        let foods = [
            food("substring", "Domatesçorbalık"),           // "corba" inside a word -> substring
            food("alias", "Tarhana", aliases: ["tarhana çorbası"]), // alias word prefix
            food("word", "Mercimek çorbası"),               // name word prefix
            food("prefix", "Çorbalık et"),                  // name prefix
            food("exact", "Çorba"),                         // exact name
            food("none", "Pilav"),
        ]
        let catalog = SeedCatalog(foods: foods, exercises: [])
        #expect(catalog.searchFoods("corba").map(\.id) == ["exact", "prefix", "word", "alias", "substring"])

        let index = SeedSearchIndex(foods.map { SearchableText(name: $0.name, aliases: $0.aliases) })
        #expect(index.rank(at: 4, for: "corba") == .exactName)
        #expect(index.rank(at: 3, for: "corba") == .namePrefix)
        #expect(index.rank(at: 2, for: "corba") == .wordPrefix)
        #expect(index.rank(at: 1, for: "corba") == .alias)
        #expect(index.rank(at: 0, for: "corba") == .substring)
        #expect(index.rank(at: 5, for: "corba") == nil)
    }

    @Test func tiesBreakByShorterNameThenAlphabetical() {
        let foods = [
            food("long", "Mercimek çorbası"),
            food("short", "Yayla çorbası"),
            food("b", "Tavuk çorbası"),
            food("a", "Kelle çorbası"),
        ]
        let catalog = SeedCatalog(foods: foods, exercises: [])
        // All four are word-prefix matches. The three 13-character names sort alphabetically
        // (folded) and come before the 16-character "Mercimek çorbası".
        #expect(catalog.searchFoods("corbasi").map(\.id) == ["a", "b", "short", "long"])
    }

    @Test func aliasExactMatchFindsItem() {
        let catalog = SeedCatalog(foods: [food("1", "Lahmacun", aliases: ["Türk pizzası"]), food("2", "Pizza")], exercises: [])
        #expect(catalog.searchFoods("pizza").map(\.id) == ["2", "1"])
        #expect(catalog.searchFoods("turk pizzasi").map(\.id) == ["1"])
    }

    @Test func multiWordQueryMatchesWordsInAnyOrder() {
        let catalog = SeedCatalog(foods: [food("1", "Tavuk döner dürüm"), food("2", "Et döner")], exercises: [])
        #expect(catalog.searchFoods("durum tavuk").map(\.id) == ["1"])
        #expect(catalog.searchFoods("doner").map(\.id) == ["2", "1"])
    }

    @Test func emptyAndUnmatchedQueries() {
        let catalog = SeedCatalog(foods: [food("1", "Pilav")], exercises: [])
        #expect(catalog.searchFoods("").isEmpty)
        #expect(catalog.searchFoods("   ").isEmpty)
        #expect(catalog.searchFoods("...").isEmpty)
        #expect(catalog.searchFoods("baklava").isEmpty)
    }

    @Test func limitCapsResults() {
        let foods = (1...20).map { food("\($0)", "Çorba \($0)") }
        let catalog = SeedCatalog(foods: foods, exercises: [])
        #expect(catalog.searchFoods("corba", limit: 5).count == 5)
        #expect(catalog.searchFoods("corba", limit: nil).count == 20)
    }

    @Test func exerciseSearchUsesTurkishAndEnglishNames() {
        let exercises = [
            SeedExercise(id: "ex-1", nameTr: "Bench press", nameEn: "Barbell Bench Press", primaryMuscle: .chest,
                         secondaryMuscles: [.triceps], equipment: .barbell, kind: .strength, met: 5.0),
            SeedExercise(id: "ex-2", nameTr: "Şınav", nameEn: "Push-up", primaryMuscle: .chest,
                         equipment: .bodyweight, kind: .strength, met: 3.8),
        ]
        let catalog = SeedCatalog(foods: [], exercises: exercises)
        #expect(catalog.searchExercises("bench").map(\.id) == ["ex-1"])
        #expect(catalog.searchExercises("barbell").map(\.id) == ["ex-1"])
        #expect(catalog.searchExercises("sinav").map(\.id) == ["ex-2"])
        #expect(catalog.searchExercises("push up").map(\.id) == ["ex-2"])
        #expect(catalog.exercise(id: "ex-2")?.nameTr == "Şınav")
        #expect(catalog.food(id: "missing") == nil)
    }
}
