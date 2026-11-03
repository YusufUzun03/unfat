import Foundation
import SwiftUI
import UnFatCore

extension Muscle {
    /// Turkish display name (a `String`, so it can also feed `ServingOption`).
    var title: String {
        switch self {
        case .chest: String(localized: "Göğüs")
        case .back: String(localized: "Sırt")
        case .shoulders: String(localized: "Omuz")
        case .biceps: String(localized: "Biseps")
        case .triceps: String(localized: "Triseps")
        case .forearms: String(localized: "Ön kol")
        case .quads: String(localized: "Ön bacak")
        case .hamstrings: String(localized: "Arka bacak")
        case .glutes: String(localized: "Kalça")
        case .calves: String(localized: "Kalf")
        case .core: String(localized: "Karın")
        case .fullBody: String(localized: "Tüm vücut")
        case .cardio: String(localized: "Kardiyo")
        }
    }
}

extension Equipment {
    var title: String {
        switch self {
        case .barbell: String(localized: "Barbell")
        case .dumbbell: String(localized: "Dumbbell")
        case .machine: String(localized: "Makine")
        case .cable: String(localized: "Kablo")
        case .bodyweight: String(localized: "Vücut ağırlığı")
        case .kettlebell: String(localized: "Kettlebell")
        case .band: String(localized: "Direnç bandı")
        case .other: String(localized: "Diğer")
        }
    }
}

extension PRKind {
    /// Short Turkish label for the record list.
    var title: String {
        switch self {
        case .estimatedOneRepMax: String(localized: "Tahmini 1TM")
        case .maxWeight: String(localized: "En yüksek ağırlık")
        }
    }
}

/// Number and duration formatting shared by the Workout screens.
enum WorkoutFormat {
    /// "1 sa 2 dk" / "45 dk" (locale aware, two largest units).
    static func duration(_ seconds: TimeInterval) -> String {
        let value = Duration.seconds(max(0, seconds))
        if seconds < 60 {
            return value.formatted(.units(allowed: [.seconds], width: .abbreviated))
        }
        return value.formatted(
            .units(allowed: [.hours, .minutes], width: .abbreviated, maximumUnitCount: 2, zeroValueUnitsDisplay: .hide)
        )
    }

    /// Weight or volume in kg: whole numbers without decimals, one decimal otherwise.
    static func kg(_ value: Double) -> String {
        String(localized: "\(value.formatted(.number.precision(.fractionLength(0...1)))) kg")
    }

    static func kcal(_ value: Double) -> String {
        String(localized: "\(value.formatted(.number.precision(.fractionLength(0)))) kcal")
    }

    /// "3 × 8" or "3 × 6-8" for a planned exercise.
    static func plan(sets: Int, repMin: Int, repMax: Int) -> String {
        repMin == repMax ? "\(sets) × \(repMin)" : "\(sets) × \(repMin)-\(repMax)"
    }
}
