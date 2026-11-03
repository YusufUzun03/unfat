import Foundation
import os

/// Bundled seed foods and exercises with their search indexes. Immutable and `Sendable`.
struct SeedCatalog: Sendable {
    let foods: [SeedFood]
    let exercises: [SeedExercise]
    private let foodIndex: SeedSearchIndex
    private let exerciseIndex: SeedSearchIndex
    private let foodPositions: [String: Int]
    private let exercisePositions: [String: Int]

    init(foods: [SeedFood], exercises: [SeedExercise]) {
        self.foods = foods
        self.exercises = exercises
        foodIndex = SeedSearchIndex(foods.map { SearchableText(name: $0.name, aliases: $0.aliases) })
        // Exercises are named in Turkish; the English name counts as an alias.
        exerciseIndex = SeedSearchIndex(exercises.map {
            SearchableText(name: $0.nameTr, aliases: $0.nameEn == $0.nameTr ? [] : [$0.nameEn])
        })
        foodPositions = Dictionary(
            foods.enumerated().map { pair in (pair.element.id, pair.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        exercisePositions = Dictionary(
            exercises.enumerated().map { pair in (pair.element.id, pair.offset) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    static let empty = SeedCatalog(foods: [], exercises: [])

    /// Catalog loaded from the main bundle on first access.
    static let shared: SeedCatalog = SeedLoader.load()

    var isEmpty: Bool { foods.isEmpty && exercises.isEmpty }

    func searchFoods(_ query: String, limit: Int? = 50) -> [SeedFood] {
        foodIndex.search(query, limit: limit).map { foods[$0] }
    }

    func searchExercises(_ query: String, limit: Int? = 50) -> [SeedExercise] {
        exerciseIndex.search(query, limit: limit).map { exercises[$0] }
    }

    func food(id: String) -> SeedFood? {
        foodPositions[id].map { foods[$0] }
    }

    func exercise(id: String) -> SeedExercise? {
        exercisePositions[id].map { exercises[$0] }
    }
}

/// Loads `seed/foods_tr.json` and `seed/exercises.json` from a bundle. A missing or unreadable
/// file yields an empty list (never a crash); invalid items inside a file are skipped.
enum SeedLoader {
    static let foodsResource = "foods_tr"
    static let exercisesResource = "exercises"
    static let subdirectory = "seed"

    private static let logger = Logger(subsystem: "io.github.yusufuzun03.unfat", category: "Seed")

    static func load(bundle: Bundle = .main) -> SeedCatalog {
        load(
            foodsURL: resourceURL(foodsResource, in: bundle),
            exercisesURL: resourceURL(exercisesResource, in: bundle)
        )
    }

    static func load(foodsURL: URL?, exercisesURL: URL?) -> SeedCatalog {
        SeedCatalog(foods: loadFoods(from: foodsURL), exercises: loadExercises(from: exercisesURL))
    }

    /// Looks in `seed/` first (folder reference), then the bundle root (XcodeGen copies grouped
    /// resources flat into the bundle).
    static func resourceURL(_ name: String, in bundle: Bundle) -> URL? {
        bundle.url(forResource: name, withExtension: "json", subdirectory: subdirectory)
            ?? bundle.url(forResource: name, withExtension: "json")
    }

    static func loadFoods(from url: URL?) -> [SeedFood] {
        guard let data = readData(url) else { return [] }
        do {
            return try decodeFoods(data)
        } catch {
            logger.error("foods seed decode failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    static func loadExercises(from url: URL?) -> [SeedExercise] {
        guard let data = readData(url) else { return [] }
        do {
            return try decodeExercises(data)
        } catch {
            logger.error("exercises seed decode failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    static func decodeFoods(_ data: Data) throws -> [SeedFood] {
        try JSONDecoder().decode(SeedFoodFile.self, from: data).foods
    }

    static func decodeExercises(_ data: Data) throws -> [SeedExercise] {
        try JSONDecoder().decode(SeedExerciseFile.self, from: data).exercises
    }

    private static func readData(_ url: URL?) -> Data? {
        guard let url else { return nil }
        do {
            return try Data(contentsOf: url)
        } catch {
            logger.error("seed file unreadable: \(url.lastPathComponent, privacy: .public)")
            return nil
        }
    }
}
