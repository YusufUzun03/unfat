import Foundation
import Testing
@testable import UnFat

@Suite("Seed loader")
struct SeedLoaderTests {
    private func temporaryFile(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "seed-\(UUID().uuidString).json")
        try Data(contents.utf8).write(to: url)
        return url
    }

    private let foodsJSON = """
    {
      "version": 1,
      "foods": [
        {
          "id": "tr-0001",
          "name": "Mercimek çorbası",
          "aliases": ["mercimek", "lentil soup"],
          "category": "soup",
          "per100g": { "kcal": 56, "protein": 3.6, "carbs": 8.2, "fat": 1.2, "fiber": 1.6 },
          "servings": [ { "label": "kase", "grams": 250 } ],
          "source": "TürKomp"
        },
        {
          "id": "tr-0002",
          "name": "Simit",
          "per100g": { "kcal": 275, "protein": 9, "carbs": 52, "fat": 3.5 }
        },
        {
          "id": "tr-bad",
          "name": "Missing nutrients"
        }
      ]
    }
    """

    private let exercisesJSON = """
    {
      "version": 1,
      "exercises": [
        {
          "id": "ex-0001",
          "nameTr": "Bench press",
          "nameEn": "Barbell Bench Press",
          "primaryMuscle": "chest",
          "secondaryMuscles": ["triceps", "shoulders", "notAMuscle"],
          "equipment": "barbell",
          "kind": "strength",
          "met": 5.0
        },
        {
          "id": "ex-0002",
          "nameTr": "Şınav",
          "primaryMuscle": "chest",
          "equipment": "smith-machine",
          "kind": "strength",
          "met": 3.8
        },
        {
          "id": "ex-bad",
          "nameTr": "Bad muscle",
          "primaryMuscle": "tentacles",
          "equipment": "bodyweight",
          "kind": "strength",
          "met": 3.0
        }
      ]
    }
    """

    @Test func decodesFoodSchemaWithOptionalFields() throws {
        let foods = try SeedLoader.decodeFoods(Data(foodsJSON.utf8))
        #expect(foods.map(\.id) == ["tr-0001", "tr-0002"])

        let soup = foods[0]
        #expect(soup.name == "Mercimek çorbası")
        #expect(soup.aliases == ["mercimek", "lentil soup"])
        #expect(soup.category == "soup")
        #expect(soup.per100g.fiber == 1.6)
        #expect(soup.servings == [SeedServing(label: "kase", grams: 250)])
        #expect(soup.source == "TürKomp")
        #expect(soup.foodRef == "seed:tr-0001")

        let simit = foods[1]
        #expect(simit.aliases.isEmpty)
        #expect(simit.servings.isEmpty)
        #expect(simit.category.isEmpty)
        #expect(simit.per100g.fiber == nil)
        #expect(simit.per100g.kcal == 275)
    }

    @Test func decodesExercisesLeniently() throws {
        let exercises = try SeedLoader.decodeExercises(Data(exercisesJSON.utf8))
        #expect(exercises.map(\.id) == ["ex-0001", "ex-0002"])

        let bench = exercises[0]
        #expect(bench.nameEn == "Barbell Bench Press")
        #expect(bench.primaryMuscle == .chest)
        #expect(bench.secondaryMuscles == [.triceps, .shoulders])
        #expect(bench.equipment == .barbell)
        #expect(bench.kind == .strength)
        #expect(bench.met == 5.0)
        #expect(bench.exerciseRef == "seed:ex-0001")

        let pushUp = exercises[1]
        #expect(pushUp.nameEn == "Şınav")
        #expect(pushUp.secondaryMuscles.isEmpty)
        #expect(pushUp.equipment == .other)
    }

    @Test func loadsCatalogFromFiles() throws {
        let foodsURL = try temporaryFile(foodsJSON)
        let exercisesURL = try temporaryFile(exercisesJSON)
        defer {
            try? FileManager.default.removeItem(at: foodsURL)
            try? FileManager.default.removeItem(at: exercisesURL)
        }

        let catalog = SeedLoader.load(foodsURL: foodsURL, exercisesURL: exercisesURL)
        #expect(!catalog.isEmpty)
        #expect(catalog.foods.count == 2)
        #expect(catalog.exercises.count == 2)
        #expect(catalog.food(id: "tr-0002")?.name == "Simit")
        #expect(catalog.food(id: "tr-bad") == nil)
        #expect(catalog.searchFoods("lentil").map(\.id) == ["tr-0001"])
        #expect(catalog.searchExercises("sinav").map(\.id) == ["ex-0002"])
    }

    @Test func missingFilesGiveEmptyCatalog() {
        let missing = FileManager.default.temporaryDirectory.appending(path: "does-not-exist-\(UUID().uuidString).json")
        #expect(SeedLoader.loadFoods(from: missing).isEmpty)
        #expect(SeedLoader.loadExercises(from: missing).isEmpty)
        #expect(SeedLoader.loadFoods(from: nil).isEmpty)
        #expect(SeedLoader.loadExercises(from: nil).isEmpty)

        let catalog = SeedLoader.load(foodsURL: missing, exercisesURL: nil)
        #expect(catalog.isEmpty)
        #expect(catalog.searchFoods("corba").isEmpty)
        #expect(catalog.searchExercises("bench").isEmpty)
        #expect(SeedCatalog.empty.isEmpty)
    }

    @Test func missingBundleResourceResolvesToNil() {
        #expect(SeedLoader.resourceURL("no-such-seed-\(UUID().uuidString)", in: .main) == nil)
    }

    @Test func invalidJSONGivesEmptyList() throws {
        let broken = try temporaryFile("{ \"foods\": [ { \"id\": ")
        let wrongShape = try temporaryFile("[1, 2, 3]")
        let noList = try temporaryFile("{ \"version\": 1 }")
        defer {
            for url in [broken, wrongShape, noList] { try? FileManager.default.removeItem(at: url) }
        }

        #expect(SeedLoader.loadFoods(from: broken).isEmpty)
        #expect(SeedLoader.loadExercises(from: broken).isEmpty)
        #expect(SeedLoader.loadFoods(from: wrongShape).isEmpty)
        #expect(SeedLoader.loadFoods(from: noList).isEmpty)
        #expect(SeedLoader.loadExercises(from: noList).isEmpty)
        #expect(throws: (any Error).self) {
            try SeedLoader.decodeFoods(Data("not json".utf8))
        }
    }
}
