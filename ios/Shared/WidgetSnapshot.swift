import Foundation

/// Today's totals for the widgets, written by the app to the App Group after every change.
/// Widgets read only this file, never the database.
struct WidgetSnapshot: Codable, Sendable, Equatable {
    /// Start of the day the totals belong to. A reader whose current day differs should treat
    /// the eaten values as 0 (date rollover) and keep the targets.
    var date: Date
    var kcalEaten: Double
    var kcalTarget: Double
    var proteinEaten: Double
    var proteinTarget: Double
    var carbsEaten: Double
    var carbsTarget: Double
    var fatEaten: Double
    var fatTarget: Double

    init(
        date: Date,
        kcalEaten: Double = 0,
        kcalTarget: Double = 0,
        proteinEaten: Double = 0,
        proteinTarget: Double = 0,
        carbsEaten: Double = 0,
        carbsTarget: Double = 0,
        fatEaten: Double = 0,
        fatTarget: Double = 0
    ) {
        self.date = date
        self.kcalEaten = kcalEaten
        self.kcalTarget = kcalTarget
        self.proteinEaten = proteinEaten
        self.proteinTarget = proteinTarget
        self.carbsEaten = carbsEaten
        self.carbsTarget = carbsTarget
        self.fatEaten = fatEaten
        self.fatTarget = fatTarget
    }
}

/// Reads and writes `widget-snapshot.json` in the App Group container.
enum WidgetSnapshotStore {
    static let fileName = "widget-snapshot.json"

    enum StoreError: Error {
        /// The App Group container is unavailable (missing entitlement).
        case noContainer
    }

    /// nil when the App Group container is unavailable.
    static var defaultURL: URL? {
        AppGroup.containerURL?.appending(path: fileName, directoryHint: .notDirectory)
    }

    /// The stored snapshot, or nil when the file is missing or unreadable.
    static func read(from url: URL? = WidgetSnapshotStore.defaultURL) -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func write(_ snapshot: WidgetSnapshot, to url: URL? = WidgetSnapshotStore.defaultURL) throws {
        guard let url else { throw StoreError.noContainer }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }
}
