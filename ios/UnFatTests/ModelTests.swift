import Foundation
import SwiftData
import Testing
@testable import UnFat

@Suite("SwiftData models")
@MainActor
struct ModelTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
    }

    @Test func profileDefaultsAndTypedAccessors() throws {
        let profile = UserProfile(sex: .male, goal: .lose, weeklyRateKg: 0.5, targetKcal: 2200)
        context.insert(profile)
        try context.save()

        let fetched = try #require(try UserProfile.current(in: context))
        #expect(fetched.sex == .male)
        #expect(fetched.sexRaw == "male")
        #expect(fetched.goal == .lose)
        #expect(fetched.activityLevel == .moderate)
        #expect(fetched.unitSystem == .metric)
        #expect(fetched.targetKcal == 2200)

        fetched.activityLevel = .veryActive
        #expect(fetched.activityLevelRaw == "veryActive")
        fetched.goalRaw = "unknown-value"
        #expect(fetched.goal == .maintain)
    }

    @Test func currentProfileIsMostRecentlyUpdated() throws {
        let older = UserProfile(targetKcal: 1800)
        older.updatedAt = Date(timeIntervalSince1970: 1_000)
        let newer = UserProfile(targetKcal: 2400)
        newer.updatedAt = Date(timeIntervalSince1970: 2_000)
        context.insert(older)
        context.insert(newer)
        try context.save()

        #expect(try UserProfile.current(in: context)?.targetKcal == 2400)
    }

    @Test func programRelationshipsAndCascadeDelete() throws {
        let program = Program(name: "Upper/Lower")
        context.insert(program)
        for index in [1, 0] {
            let day = ProgramDay(name: "Day \(index)", order: index)
            context.insert(day)
            day.program = program
            let exercise = PlannedExercise(exerciseRef: ItemRef.seed("ex-000\(index)"), exerciseName: "Ex \(index)", order: 0)
            context.insert(exercise)
            exercise.day = day
        }
        try context.save()

        #expect(program.days?.count == 2)
        #expect(program.sortedDays.map(\.order) == [0, 1])
        #expect(program.sortedDays.first?.sortedExercises.first?.exerciseRef == "seed:ex-0000")
        #expect(program.sortedDays.first?.exercises?.first?.day?.program?.name == "Upper/Lower")

        context.delete(program)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Program>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ProgramDay>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PlannedExercise>()) == 0)
    }

    @Test func sessionRelationshipsAndCascadeDelete() throws {
        let session = WorkoutSession(name: "A")
        context.insert(session)
        #expect(session.isActive)
        let exercise = SessionExercise(exerciseRef: ItemRef.seed("ex-0001"), exerciseName: "Bench press", order: 0)
        context.insert(exercise)
        exercise.session = session
        for index in [2, 0, 1] {
            let log = SetLog(order: index, reps: 8, weightKg: 60, isDone: index < 2, rpe: index == 0 ? 8 : nil)
            context.insert(log)
            log.sessionExercise = exercise
        }
        session.endedAt = session.startedAt.addingTimeInterval(3_600)
        try context.save()

        #expect(!session.isActive)
        #expect(session.sortedExercises.count == 1)
        let logs = try #require(session.sortedExercises.first?.sortedSetLogs)
        #expect(logs.map(\.order) == [0, 1, 2])
        #expect(logs.map(\.isDone) == [true, true, false])
        #expect(logs.first?.rpe == 8)

        context.delete(session)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SessionExercise>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SetLog>()) == 0)
    }

    @Test func foodEntrySnapshotIsIndependentOfCustomFood() throws {
        let food = CustomFood(name: "Ev yoğurdu", kcalPer100g: 63, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.3)
        context.insert(food)
        let entry = FoodEntry(snapshotOf: food, grams: 200, servingLabel: "kase", servingCount: 1)
        context.insert(entry)
        try context.save()

        food.name = "Yağsız yoğurt"
        food.kcalPer100g = 40
        food.fatPer100g = 0.5
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<FoodEntry>()).first)
        #expect(fetched.name == "Ev yoğurdu")
        #expect(fetched.kcalPer100g == 63)
        #expect(fetched.fatPer100g == 3.3)
        #expect(fetched.source == .custom)
        #expect(fetched.foodRef == "custom:\(food.uuid.uuidString)")
        #expect(abs(fetched.kcal - 126) < 0.0001)

        context.delete(food)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<FoodEntry>()) == 1)
    }

    @Test func foodEntryFromSeedAndQuickAdd() throws {
        let seed = SeedFood(
            id: "tr-0001",
            name: "Mercimek çorbası",
            per100g: SeedNutrients(kcal: 56, protein: 3.6, carbs: 8.2, fat: 1.2, fiber: 1.6)
        )
        let entry = FoodEntry(snapshotOf: seed, grams: 250, servingLabel: "kase", servingCount: 1)
        let quick = FoodEntry.quickAdd(name: "Kahve", kcal: 120)
        context.insert(entry)
        context.insert(quick)
        try context.save()

        #expect(entry.foodRef == "seed:tr-0001")
        #expect(entry.source == .seed)
        #expect(abs(entry.kcal - 140) < 0.0001)
        #expect(abs(entry.protein - 9) < 0.0001)
        #expect(abs((entry.fiber ?? 0) - 4) < 0.0001)
        #expect(quick.source == .quickAdd)
        #expect(quick.foodRef == ItemRef.quickAdd)
        #expect(quick.kcal == 120)
        #expect(quick.protein == 0)
    }

    @Test func localModelsAndCustomExercise() throws {
        let product = CachedProduct(barcode: "8690000000001")
        product.isNotFound = true
        let health = HealthDaySummary(day: Date(timeIntervalSince1970: 0), steps: 8_000, activeKcal: 420)
        let custom = CustomExercise(nameTr: "Kablo crossover", primaryMuscle: .chest, equipment: .cable)
        context.insert(product)
        context.insert(health)
        context.insert(custom)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<CachedProduct>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<HealthDaySummary>()) == 1)
        #expect(custom.primaryMuscle == .chest)
        #expect(custom.kind == .strength)
        #expect(custom.exerciseRef.hasPrefix("custom:"))
    }

    @Test func persistentContainerWithTwoConfigurations() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "unfat-store-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurations = ModelContainerFactory.configurations(syncEnabled: false, directory: directory)
        #expect(configurations.map(\.name) == ["Synced", "Local"])
        #expect(configurations.map(\.url.lastPathComponent) == ["Synced.store", "Local.store"])

        let persistent = try ModelContainerFactory.makePersistent(syncEnabled: false, directory: directory)
        let diskContext = ModelContext(persistent)
        diskContext.insert(UserProfile(targetKcal: 2000))
        diskContext.insert(WeightEntry(kg: 80))
        diskContext.insert(CachedProduct(barcode: "123"))
        try diskContext.save()

        #expect(try diskContext.fetchCount(FetchDescriptor<UserProfile>()) == 1)
        #expect(try diskContext.fetchCount(FetchDescriptor<WeightEntry>()) == 1)
        #expect(try diskContext.fetchCount(FetchDescriptor<CachedProduct>()) == 1)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "Synced.store").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "Local.store").path(percentEncoded: false)))
    }

    @Test func syncPreferenceDefaultsOff() throws {
        let suiteName = "unfat-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(SyncPreference.isEnabled(in: defaults) == false)
        SyncPreference.setEnabled(true, in: defaults)
        #expect(SyncPreference.isEnabled(in: defaults))
    }

    #if DEBUG
    @Test func fixturesPopulateContainer() throws {
        let now = Date.now
        Fixtures.populate(context, now: now)

        #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<FoodEntry>()) == 6)
        #expect(try context.fetchCount(FetchDescriptor<WeightEntry>()) == 30)
        #expect(try context.fetchCount(FetchDescriptor<Program>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ProgramDay>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 2)

        let program = try #require(try context.fetch(FetchDescriptor<Program>()).first)
        #expect(program.sortedDays.count == 3)
        #expect(program.sortedDays.allSatisfy { ($0.exercises?.count ?? 0) == 4 })

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        #expect(sessions.allSatisfy { !$0.isActive && $0.programDayID != nil })
        #expect(sessions.allSatisfy { session in
            session.sortedExercises.allSatisfy { ($0.setLogs?.count ?? 0) == 3 }
        })

        let snapshot = try WidgetSnapshotWriter.snapshot(for: now, in: context)
        #expect(snapshot.kcalTarget == 2200)
        #expect(snapshot.kcalEaten > 1_000 && snapshot.kcalEaten < snapshot.kcalTarget)
    }
    #endif
}
