import Foundation

/// Top level of `seed/foods_tr.json`: `{"version": 1, "foods": [...]}`.
struct SeedFoodFile: Decodable, Sendable {
    var version: Int
    var foods: [SeedFood]

    private enum CodingKeys: String, CodingKey {
        case version
        case foods
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        foods = try container.decodeIfPresent(LossyArray<SeedFood>.self, forKey: .foods)?.elements ?? []
    }
}

struct SeedNutrients: Codable, Sendable, Hashable {
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double?
}

struct SeedServing: Codable, Sendable, Hashable {
    var label: String
    var grams: Double
}

/// A bundled, read-only food. Required keys: `id`, `name`, `per100g`; `aliases`, `servings`,
/// `category`, `source` and `per100g.fiber` may be absent.
struct SeedFood: Codable, Sendable, Hashable, Identifiable {
    var id: String
    var name: String
    var aliases: [String]
    var category: String
    var per100g: SeedNutrients
    var servings: [SeedServing]
    var source: String

    init(
        id: String,
        name: String,
        aliases: [String] = [],
        category: String = "",
        per100g: SeedNutrients,
        servings: [SeedServing] = [],
        source: String = ""
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.category = category
        self.per100g = per100g
        self.servings = servings
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, aliases, category, per100g, servings, source
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        per100g = try container.decode(SeedNutrients.self, forKey: .per100g)
        servings = try container.decodeIfPresent([SeedServing].self, forKey: .servings) ?? []
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
    }

    var foodRef: String { ItemRef.seed(id) }
}
