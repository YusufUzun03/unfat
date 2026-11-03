import Foundation

// Typed values for SwiftData models. Models store the raw String (CloudKit-friendly) and expose
// these through computed accessors; seed JSON decodes into the same enums.

enum Sex: String, Codable, Sendable, CaseIterable {
    case female
    case male
}

enum ActivityLevel: String, Codable, Sendable, CaseIterable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive
}

enum WeightGoal: String, Codable, Sendable, CaseIterable {
    case lose
    case maintain
    case gain
}

enum UnitSystem: String, Codable, Sendable, CaseIterable {
    case metric
    case imperial
}

/// Where a `FoodEntry` snapshot came from.
enum FoodSource: String, Codable, Sendable, CaseIterable {
    case seed
    case openFoodFacts = "off"
    case custom
    case quickAdd = "quick"
    case photo
}

enum Muscle: String, Codable, Sendable, CaseIterable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case forearms
    case quads
    case hamstrings
    case glutes
    case calves
    case core
    case fullBody
    case cardio
}

enum Equipment: String, Codable, Sendable, CaseIterable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case kettlebell
    case band
    case other
}

enum ExerciseKind: String, Codable, Sendable, CaseIterable {
    case strength
    case cardio
}

/// String references used instead of relationships (`FoodEntry.foodRef`, `PlannedExercise.exerciseRef`, ...).
/// Format: `seed:<seed id>`, `off:<barcode>`, `custom:<uuid>`, or the fixed `quick` / `photo` markers.
enum ItemRef {
    static let quickAdd = "quick"
    static let photo = "photo"

    static func seed(_ id: String) -> String { "seed:\(id)" }
    static func openFoodFacts(_ barcode: String) -> String { "off:\(barcode)" }
    static func custom(_ uuid: UUID) -> String { "custom:\(uuid.uuidString)" }
}
