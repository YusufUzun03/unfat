import Foundation
import SwiftData

/// Schema version 1. The `@Model` types are top-level; when V2 is needed, copy the V1 shapes into
/// this enum (nested types) and add `UnFatSchemaV2` + a stage in `UnFatMigrationPlan`.
/// After the first production CloudKit deploy, synced changes must stay additive (new optional or
/// defaulted fields, new types); never rename or delete a field.
enum UnFatSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] { syncedModels + localModels }

    /// Stored in the synced configuration (CloudKit private DB when sync is on).
    static var syncedModels: [any PersistentModel.Type] {
        [
            UserProfile.self,
            CustomFood.self,
            FoodEntry.self,
            FavoriteFood.self,
            WeightEntry.self,
            Program.self,
            ProgramDay.self,
            PlannedExercise.self,
            WorkoutSession.self,
            SessionExercise.self,
            SetLog.self,
            CustomExercise.self,
        ]
    }

    /// Stored in the local-only configuration; never synced.
    static var localModels: [any PersistentModel.Type] {
        [
            CachedProduct.self,
            HealthDaySummary.self,
        ]
    }
}

enum UnFatMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [UnFatSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
