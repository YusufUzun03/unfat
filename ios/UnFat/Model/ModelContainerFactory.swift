import Foundation
import os
import SwiftData

/// Builds the SwiftData container: one container, two configurations.
/// - `Synced`: the synced models, CloudKit private DB when sync is on, `.none` otherwise.
/// - `Local`: OFF cache and HealthKit data, always `.none`.
/// Stores live in the App Group container (`Library/Application Support/Stores/`), falling back to the
/// app's Application Support directory when the group container is unavailable.
enum ModelContainerFactory {
    static let cloudKitContainerIdentifier = "iCloud.io.github.yusufuzun03.unfat"
    static let syncedConfigurationName = "Synced"
    static let localConfigurationName = "Local"
    static let syncedStoreFileName = "Synced.store"
    static let localStoreFileName = "Local.store"

    private static let logger = Logger(subsystem: "io.github.yusufuzun03.unfat", category: "Data")

    static var fullSchema: Schema { Schema(versionedSchema: UnFatSchemaV1.self) }

    static var syncedSchema: Schema {
        Schema(UnFatSchemaV1.syncedModels, version: UnFatSchemaV1.versionIdentifier)
    }

    static var localSchema: Schema {
        Schema(UnFatSchemaV1.localModels, version: UnFatSchemaV1.versionIdentifier)
    }

    /// Directory holding both store files; created if missing.
    static func storeDirectory(groupContainerURL: URL? = AppGroup.containerURL) throws -> URL {
        let base: URL
        if let groupContainerURL {
            base = groupContainerURL.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        } else {
            base = URL.applicationSupportDirectory
        }
        let directory = base.appending(path: "Stores", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func configurations(syncEnabled: Bool, directory: URL) -> [ModelConfiguration] {
        let syncedDatabase: ModelConfiguration.CloudKitDatabase =
            syncEnabled ? .private(cloudKitContainerIdentifier) : .none
        let synced = ModelConfiguration(
            syncedConfigurationName,
            schema: syncedSchema,
            url: directory.appending(path: syncedStoreFileName, directoryHint: .notDirectory),
            cloudKitDatabase: syncedDatabase
        )
        let local = ModelConfiguration(
            localConfigurationName,
            schema: localSchema,
            url: directory.appending(path: localStoreFileName, directoryHint: .notDirectory),
            cloudKitDatabase: .none
        )
        return [synced, local]
    }

    /// On-disk container. `directory` defaults to `storeDirectory()`; tests pass a temp directory.
    static func makePersistent(syncEnabled: Bool, directory: URL? = nil) throws -> ModelContainer {
        let storeURL = try directory ?? storeDirectory()
        return try ModelContainer(
            for: fullSchema,
            migrationPlan: UnFatMigrationPlan.self,
            configurations: configurations(syncEnabled: syncEnabled, directory: storeURL)
        )
    }

    /// In-memory container for tests, previews and screenshot fixtures. Uses a single configuration
    /// with every model (no cross-configuration relationships exist, so behaviour is the same).
    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: fullSchema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: fullSchema,
            migrationPlan: UnFatMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// The container the app runs with:
    /// - DEBUG + `-UNFAT_SCREEN`: in-memory, filled with `Fixtures`.
    /// - Hosted unit tests: empty in-memory, so tests never touch the real store.
    /// - Otherwise: on-disk, sync per `SyncPreference` (read once here; changes apply on next launch).
    ///   If a sync-enabled container fails to load, it retries with sync off before giving up.
    @MainActor
    static func makeForApp(processInfo: ProcessInfo = .processInfo) -> ModelContainer {
        #if DEBUG
        if processInfo.arguments.contains(LaunchRouter.argument) {
            do {
                let container = try makeInMemory()
                Fixtures.populate(container.mainContext)
                return container
            } catch {
                fatalError("Could not create the fixture model container: \(error)")
            }
        }
        #endif

        if isRunningUnitTests(processInfo) {
            do {
                return try makeInMemory()
            } catch {
                fatalError("Could not create the test model container: \(error)")
            }
        }

        let syncEnabled = SyncPreference.isEnabled()
        do {
            return try makePersistent(syncEnabled: syncEnabled)
        } catch {
            logger.error("Model container failed (sync \(syncEnabled, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            if syncEnabled {
                do {
                    return try makePersistent(syncEnabled: false)
                } catch {
                    fatalError("Could not create the model container: \(error)")
                }
            }
            fatalError("Could not create the model container: \(error)")
        }
    }

    static func isRunningUnitTests(_ processInfo: ProcessInfo = .processInfo) -> Bool {
        let environment = processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }
}
