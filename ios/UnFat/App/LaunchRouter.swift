#if DEBUG
import Foundation

/// Screens reachable with the `-UNFAT_SCREEN <name>` launch argument (CI screenshots job).
/// Raw values are the names used on the command line; append new screens here.
enum LaunchRoute: String, CaseIterable, Sendable {
    case today
    case workout
    case progress
    case add

    var tab: AppTab {
        switch self {
        case .today: .today
        case .workout: .workout
        case .progress: .progress
        case .add: .add
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
