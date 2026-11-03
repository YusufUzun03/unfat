#if DEBUG
import Foundation
import SwiftData

/// Realistic sample data for `-UNFAT_SCREEN` screenshot routes, previews and tests:
/// a profile, 6 food entries today, 30 days of weigh-ins, one 3-day program and 2 past sessions.
/// Seed references (`seed:fixture-...`) are placeholders and do not resolve to bundled seed items;
/// every row carries its own display name, so nothing needs to resolve.
@MainActor
enum Fixtures {
    static func populate(_ context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        insertProfile(context, today: today, calendar: calendar)
        insertFood(context, today: today, calendar: calendar)
        insertWeights(context, today: today, calendar: calendar)
        let days = insertProgram(context)
        insertSessions(context, days: days, today: today, calendar: calendar)
        do {
            try context.save()
        } catch {
            assertionFailure("Fixture save failed: \(error)")
        }
    }

    // MARK: - Profile

    private static func insertProfile(_ context: ModelContext, today: Date, calendar: Calendar) {
        let profile = UserProfile(
            sex: .male,
            birthYear: 1998,
            heightCm: 178,
            activityLevel: .moderate,
            goal: .lose,
            weeklyRateKg: 0.5,
            targetKcal: 2200,
            targetProteinG: 150,
            targetCarbsG: 250,
            targetFatG: 66,
            unitSystem: .metric,
            onboardingCompletedAt: calendar.date(byAdding: .day, value: -30, to: today)
        )
        context.insert(profile)
    }

    // MARK: - Food

    private struct FoodFixture {
        let minute: Int
        let name: String
        let kcal: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double?
        let grams: Double
        let serving: String
        let ref: String
    }

    private static func insertFood(_ context: ModelContext, today: Date, calendar: Calendar) {
        let yogurt = CustomFood(
            name: "Ev yoğurdu",
            kcalPer100g: 63,
            proteinPer100g: 3.5,
            carbsPer100g: 4.7,
            fatPer100g: 3.3,
            servingLabel: "kase",
            servingGrams: 200
        )
        context.insert(yogurt)

        let seedFoods: [FoodFixture] = [
            FoodFixture(minute: 8 * 60 + 5, name: "Menemen", kcal: 95, protein: 5.5, carbs: 4.5, fat: 6.5,
                        fiber: 1.2, grams: 250, serving: "porsiyon", ref: ItemRef.seed("fixture-menemen")),
            FoodFixture(minute: 8 * 60 + 10, name: "Simit", kcal: 275, protein: 9, carbs: 52, fat: 3.5,
                        fiber: 2.5, grams: 100, serving: "adet", ref: ItemRef.seed("fixture-simit")),
            FoodFixture(minute: 13 * 60, name: "Mercimek çorbası", kcal: 56, protein: 3.6, carbs: 8.2, fat: 1.2,
                        fiber: 1.6, grams: 250, serving: "kase", ref: ItemRef.seed("fixture-mercimek")),
            FoodFixture(minute: 13 * 60 + 5, name: "Tavuk döner dürüm", kcal: 215, protein: 13, carbs: 22, fat: 8,
                        fiber: 1.5, grams: 280, serving: "adet", ref: ItemRef.seed("fixture-durum")),
            FoodFixture(minute: 16 * 60 + 30, name: "Ayran", kcal: 37, protein: 1.7, carbs: 2.6, fat: 2.0,
                        fiber: nil, grams: 300, serving: "bardak", ref: ItemRef.seed("fixture-ayran")),
        ]
        for food in seedFoods {
            let entry = FoodEntry(
                name: food.name,
                kcalPer100g: food.kcal,
                proteinPer100g: food.protein,
                carbsPer100g: food.carbs,
                fatPer100g: food.fat,
                fiberPer100g: food.fiber,
                grams: food.grams,
                servingLabel: food.serving,
                servingCount: 1,
                source: .seed,
                foodRef: food.ref,
                loggedAt: today.addingTimeInterval(TimeInterval(food.minute * 60))
            )
            context.insert(entry)
        }

        let yogurtEntry = FoodEntry(
            snapshotOf: yogurt,
            grams: 200,
            servingLabel: "kase",
            servingCount: 1,
            loggedAt: today.addingTimeInterval(TimeInterval((10 * 60 + 30) * 60))
        )
        context.insert(yogurtEntry)

        context.insert(FavoriteFood(foodRef: ItemRef.seed("fixture-ayran"), name: "Ayran", defaultGrams: 300, servingLabel: "bardak"))
    }

    // MARK: - Weight

    /// 30 daily weigh-ins ending today: a slow downward trend (about 0.5 kg/week) with daily noise.
    private static func insertWeights(_ context: ModelContext, today: Date, calendar: Calendar) {
        for daysAgo in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let raw = 82.6 + 0.07 * Double(daysAgo) + 0.35 * sin(Double(daysAgo) * 1.3)
            let kg = (raw * 10).rounded() / 10
            context.insert(WeightEntry(date: day.addingTimeInterval(7 * 3600 + 30 * 60), kg: kg))
        }
    }

    // MARK: - Program

    private struct PlannedFixture {
        let ref: String
        let name: String
        let sets: Int
        let repMin: Int
        let repMax: Int
        let rest: Int
        let weight: Double
    }

    private static let programDays: [(name: String, exercises: [PlannedFixture])] = [
        ("A Günü", [
            PlannedFixture(ref: ItemRef.seed("fixture-squat"), name: "Squat", sets: 3, repMin: 5, repMax: 8, rest: 150, weight: 80),
            PlannedFixture(ref: ItemRef.seed("fixture-bench"), name: "Bench press", sets: 3, repMin: 6, repMax: 10, rest: 120, weight: 60),
            PlannedFixture(ref: ItemRef.seed("fixture-row"), name: "Barbell row", sets: 3, repMin: 8, repMax: 12, rest: 90, weight: 50),
            PlannedFixture(ref: ItemRef.seed("fixture-lateral"), name: "Lateral raise", sets: 3, repMin: 12, repMax: 15, rest: 60, weight: 8),
        ]),
        ("B Günü", [
            PlannedFixture(ref: ItemRef.seed("fixture-deadlift"), name: "Deadlift", sets: 3, repMin: 5, repMax: 5, rest: 180, weight: 100),
            PlannedFixture(ref: ItemRef.seed("fixture-ohp"), name: "Overhead press", sets: 3, repMin: 6, repMax: 10, rest: 120, weight: 40),
            PlannedFixture(ref: ItemRef.seed("fixture-pulldown"), name: "Lat pulldown", sets: 3, repMin: 8, repMax: 12, rest: 90, weight: 55),
            PlannedFixture(ref: ItemRef.seed("fixture-curl"), name: "Biceps curl", sets: 3, repMin: 10, repMax: 12, rest: 60, weight: 12),
        ]),
        ("C Günü", [
            PlannedFixture(ref: ItemRef.seed("fixture-legpress"), name: "Leg press", sets: 3, repMin: 10, repMax: 12, rest: 120, weight: 140),
            PlannedFixture(ref: ItemRef.seed("fixture-incline"), name: "Incline dumbbell press", sets: 3, repMin: 8, repMax: 12, rest: 90, weight: 22),
            PlannedFixture(ref: ItemRef.seed("fixture-cablerow"), name: "Seated cable row", sets: 3, repMin: 10, repMax: 12, rest: 90, weight: 50),
            PlannedFixture(ref: ItemRef.seed("fixture-pushdown"), name: "Triceps pushdown", sets: 3, repMin: 12, repMax: 15, rest: 60, weight: 25),
        ]),
    ]

    /// Returns the program days in order.
    private static func insertProgram(_ context: ModelContext) -> [ProgramDay] {
        let program = Program(name: "Full Body 3 Gün")
        context.insert(program)
        var days: [ProgramDay] = []
        for (dayIndex, dayFixture) in programDays.enumerated() {
            let day = ProgramDay(name: dayFixture.name, order: dayIndex)
            context.insert(day)
            day.program = program
            days.append(day)
            for (exerciseIndex, fixture) in dayFixture.exercises.enumerated() {
                let planned = PlannedExercise(
                    exerciseRef: fixture.ref,
                    exerciseName: fixture.name,
                    order: exerciseIndex,
                    sets: fixture.sets,
                    repMin: fixture.repMin,
                    repMax: fixture.repMax,
                    restSeconds: fixture.rest,
                    targetWeightKg: fixture.weight
                )
                context.insert(planned)
                planned.day = day
            }
        }
        return days
    }

    // MARK: - Sessions

    /// Day A four days ago and day B two days ago, every set done.
    private static func insertSessions(_ context: ModelContext, days: [ProgramDay], today: Date, calendar: Calendar) {
        let sessions: [(dayIndex: Int, daysAgo: Int, startMinute: Int, durationMinutes: Int, kcal: Double)] = [
            (0, 4, 18 * 60 + 15, 62, 320),
            (1, 2, 18 * 60 + 30, 58, 300),
        ]
        for plan in sessions {
            let fixtureDay = programDays[plan.dayIndex]
            guard let date = calendar.date(byAdding: .day, value: -plan.daysAgo, to: today) else { continue }
            let start = date.addingTimeInterval(TimeInterval(plan.startMinute * 60))
            let session = WorkoutSession(
                name: fixtureDay.name,
                startedAt: start,
                programDayID: days.indices.contains(plan.dayIndex) ? days[plan.dayIndex].uuid : nil
            )
            session.endedAt = start.addingTimeInterval(TimeInterval(plan.durationMinutes * 60))
            session.energyKcal = plan.kcal
            context.insert(session)

            var minute = 5
            for (exerciseIndex, fixture) in fixtureDay.exercises.enumerated() {
                let exercise = SessionExercise(
                    exerciseRef: fixture.ref,
                    exerciseName: fixture.name,
                    order: exerciseIndex,
                    restSeconds: fixture.rest
                )
                context.insert(exercise)
                exercise.session = session
                for setIndex in 0..<fixture.sets {
                    let reps = max(fixture.repMin, fixture.repMax - setIndex)
                    let log = SetLog(
                        order: setIndex,
                        reps: reps,
                        weightKg: fixture.weight,
                        isDone: true,
                        completedAt: start.addingTimeInterval(TimeInterval(minute * 60))
                    )
                    context.insert(log)
                    log.sessionExercise = exercise
                    minute += 4
                }
            }
        }
    }
}
#endif
