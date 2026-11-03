import Foundation

/// Top level of `seed/exercises.json`: `{"version": 1, "exercises": [...]}`.
struct SeedExerciseFile: Decodable, Sendable {
    var version: Int
    var exercises: [SeedExercise]

    private enum CodingKeys: String, CodingKey {
        case version
        case exercises
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exercises = try container.decodeIfPresent(LossyArray<SeedExercise>.self, forKey: .exercises)?.elements ?? []
    }
}

/// A bundled, read-only exercise. Required keys: `id`, `nameTr`, `primaryMuscle`, `kind`, `met`.
/// Unknown values in `secondaryMuscles` are dropped; an unknown `equipment` becomes `.other`;
/// a missing `nameEn` falls back to `nameTr`. An unknown `primaryMuscle` or `kind` skips the item.
struct SeedExercise: Codable, Sendable, Hashable, Identifiable {
    var id: String
    var nameTr: String
    var nameEn: String
    var primaryMuscle: Muscle
    var secondaryMuscles: [Muscle]
    var equipment: Equipment
    var kind: ExerciseKind
    var met: Double

    init(
        id: String,
        nameTr: String,
        nameEn: String,
        primaryMuscle: Muscle,
        secondaryMuscles: [Muscle] = [],
        equipment: Equipment,
        kind: ExerciseKind,
        met: Double
    ) {
        self.id = id
        self.nameTr = nameTr
        self.nameEn = nameEn
        self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.kind = kind
        self.met = met
    }

    private enum CodingKeys: String, CodingKey {
        case id, nameTr, nameEn, primaryMuscle, secondaryMuscles, equipment, kind, met
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        nameTr = try container.decode(String.self, forKey: .nameTr)
        nameEn = try container.decodeIfPresent(String.self, forKey: .nameEn) ?? nameTr
        primaryMuscle = try container.decode(Muscle.self, forKey: .primaryMuscle)
        let secondaryRaw = try container.decodeIfPresent([String].self, forKey: .secondaryMuscles) ?? []
        secondaryMuscles = secondaryRaw.compactMap(Muscle.init(rawValue:))
        let equipmentRaw = try container.decodeIfPresent(String.self, forKey: .equipment) ?? ""
        equipment = Equipment(rawValue: equipmentRaw) ?? .other
        kind = try container.decode(ExerciseKind.self, forKey: .kind)
        met = try container.decode(Double.self, forKey: .met)
    }

    var exerciseRef: String { ItemRef.seed(id) }
}
