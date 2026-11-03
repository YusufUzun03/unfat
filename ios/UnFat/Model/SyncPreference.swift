import Foundation

/// iCloud sync opt-in, stored in the App Group defaults. Default OFF.
///
/// The value is read once, when `ModelContainerFactory.makeForApp()` builds the container at launch,
/// because a SwiftData configuration's `cloudKitDatabase` cannot change on a live container.
/// Changing it therefore takes effect on the next launch; the Settings screen (task 15) must say so.
/// The store file is the same in both modes, so data stays on the device when sync is turned off.
enum SyncPreference {
    static let key = "sync.iCloudEnabled"

    /// App Group defaults, or `.standard` when the group is unavailable (tests without entitlements).
    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    static func isEnabled(in defaults: UserDefaults = SyncPreference.defaults) -> Bool {
        defaults.bool(forKey: key)
    }

    static func setEnabled(_ enabled: Bool, in defaults: UserDefaults = SyncPreference.defaults) {
        defaults.set(enabled, forKey: key)
    }
}
