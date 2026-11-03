import Foundation

/// App Group shared by the app and the widget extension (widget snapshot, SwiftData store).
enum AppGroup {
    static let identifier = "group.io.github.yusufuzun03.unfat"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
