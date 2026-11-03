import Foundation

/// One pickable exercise, seed or custom, in a single shape for lists and search.
struct ExerciseItem: Identifiable, Hashable, Sendable {
    /// `ItemRef` string: `seed:<id>` or `custom:<uuid>`. Also the stable identity.
    let id: String
    let name: String
    let muscle: Muscle
    let equipment: Equipment
    let kind: ExerciseKind
    let met: Double
    let isCustom: Bool

    init(seed: SeedExercise) {
        id = ItemRef.seed(seed.id)
        name = seed.nameTr
        muscle = seed.primaryMuscle
        equipment = seed.equipment
        kind = seed.kind
        met = seed.met
        isCustom = false
    }

    init(custom: CustomExercise) {
        id = custom.exerciseRef
        name = custom.nameTr
        muscle = custom.primaryMuscle
        equipment = custom.equipment
        kind = custom.kind
        met = custom.met
        isCustom = true
    }

    init(
        id: String,
        name: String,
        muscle: Muscle,
        equipment: Equipment,
        kind: ExerciseKind = .strength,
        met: Double = 5.0,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.muscle = muscle
        self.equipment = equipment
        self.kind = kind
        self.met = met
        self.isCustom = isCustom
    }
}

/// Seed + custom exercises with Turkish-folded search and a muscle filter. Custom exercises come first.
struct ExerciseCatalog: Sendable {
    /// Custom exercises (given order), then seed exercises (seed order).
    let items: [ExerciseItem]
    private let index: SeedSearchIndex
    private let positions: [String: Int]

    init(seed: SeedCatalog, custom: [ExerciseItem] = []) {
        let customItems = custom.filter(\.isCustom)
        items = customItems + seed.exercises.map { ExerciseItem(seed: $0) }
        // Same search keys as `SeedCatalog`: Turkish name, English name as alias.
        let aliasesByID = Dictionary(
            seed.exercises.map { (ItemRef.seed($0.id), $0.nameEn == $0.nameTr ? [String]() : [$0.nameEn]) },
            uniquingKeysWith: { first, _ in first }
        )
        index = SeedSearchIndex(items.map { item in
            SearchableText(name: item.name, aliases: item.isCustom ? [] : (aliasesByID[item.id] ?? []))
        })
        positions = Dictionary(
            items.enumerated().map { ($0.element.id, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Matches for `query` (empty = everything), optionally limited to one muscle group.
    /// Custom exercises are listed before seed ones; relevance order is kept inside each group.
    func search(_ query: String, muscle: Muscle? = nil) -> [ExerciseItem] {
        let base: [ExerciseItem]
        if SearchFolding.fold(query).isEmpty {
            base = items
        } else {
            base = index.search(query).map { items[$0] }
        }
        let filtered = muscle.map { wanted in base.filter { $0.muscle == wanted } } ?? base
        return filtered.filter(\.isCustom) + filtered.filter { !$0.isCustom }
    }

    func item(ref: String) -> ExerciseItem? {
        positions[ref].map { items[$0] }
    }

    /// MET of an exercise reference, nil when it is unknown (deleted custom exercise, placeholder ref).
    func met(forRef ref: String) -> Double? {
        item(ref: ref)?.met
    }
}
