#if DEBUG
import Foundation

/// Where a launch route lands: a tab of the root `TabView`, or a full-screen DEBUG screen.
enum LaunchDestination: Hashable, Sendable {
    case tab(AppTab)
    case screen(DebugScreen)
}

/// Screens reachable with the `-UNFAT_SCREEN <name>` launch argument (CI screenshots job).
/// Raw values are the names used on the command line; append new screens here.
enum LaunchRoute: String, CaseIterable, Sendable {
    case today
    case workout
    case progress
    case add
    /// Design-system gallery, from the top (rings, macro bars).
    case gallery
    /// Gallery from the number roll section (numbers, chips, keypad).
    case gallery2 = "gallery-2"
    /// Gallery from the rest timer section (rest timer, rows).
    case gallery3 = "gallery-3"
    /// Gallery with the tuning panel open.
    case galleryTuning = "gallery-tuning"

    var destination: LaunchDestination {
        switch self {
        case .today: .tab(.today)
        case .workout: .tab(.workout)
        case .progress: .tab(.progress)
        case .add: .tab(.add)
        case .gallery: .screen(.gallery(firstSection: .ring, showsTuning: false))
        case .gallery2: .screen(.gallery(firstSection: .numbers, showsTuning: false))
        case .gallery3: .screen(.gallery(firstSection: .restTimer, showsTuning: false))
        case .galleryTuning: .screen(.gallery(firstSection: .ring, showsTuning: true))
        }
    }
}

enum LaunchRouter {
    static let argument = "-UNFAT_SCREEN"

    /// Returns the route named after `-UNFAT_SCREEN`, or nil when absent or unknown.
    static func route(arguments: [String] = ProcessInfo.processInfo.arguments) -> LaunchRoute? {
        guard let index = arguments.firstIndex(of: argument),
              arguments.indices.contains(index + 1)
        else { return nil }
        return LaunchRoute(rawValue: arguments[index + 1])
    }
}
#endif
