#if DEBUG
import SwiftData
import SwiftUI

/// Food log screens reachable from `-UNFAT_SCREEN` besides the plain `today` and `add` routes.
enum FoodLogDebugScreen: Hashable, Sendable {
    /// Today tab with no entries today, but entries yesterday (copy-yesterday button visible).
    case todayEmpty
    /// Today tab with a day total above the target.
    case todayOver
    /// Add sheet with "mercimek" typed in the search field.
    case addSearch
    /// Amount editor for a seed food with "1 kase" selected.
    case entryEditor
    case quickKcal
    case customFood
}

/// Fixture data for the food log routes. Dates are relative to `now`, so output is deterministic
/// apart from the clock itself.
@MainActor
enum FoodLogFixtures {
    /// Three entries yesterday (breakfast, lunch, dinner), so recents and copy-yesterday have data.
    static func addYesterday(_ context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let yesterday = FoodLogService.yesterday(of: now, calendar: calendar)
        let meals: [(minute: Int, name: String, kcal: Double, protein: Double, carbs: Double, fat: Double,
                     grams: Double, serving: String, ref: String)] = [
            (8 * 60 + 20, "Yulaf ezmesi", 370, 13, 60, 7, 60, "kase", "fixture-yulaf"),
            (13 * 60 + 10, "Tavuklu pilav", 165, 9, 24, 4, 300, "porsiyon", "fixture-pilav"),
            (19 * 60 + 40, "Mercimek çorbası", 56, 3.6, 8.2, 1.2, 250, "kase", "fixture-mercimek"),
        ]
        for meal in meals {
            context.insert(FoodEntry(
                name: meal.name,
                kcalPer100g: meal.kcal,
                proteinPer100g: meal.protein,
                carbsPer100g: meal.carbs,
                fatPer100g: meal.fat,
                grams: meal.grams,
                servingLabel: meal.serving,
                servingCount: 1,
                source: .seed,
                foodRef: ItemRef.seed(meal.ref),
                loggedAt: yesterday.addingTimeInterval(TimeInterval(meal.minute * 60))
            ))
        }
    }

    static func makeContainer(_ kind: FoodLogDebugScreen, now: Date = .now, calendar: Calendar = .current) -> ModelContainer? {
        do {
            let container = try ModelContainerFactory.makeInMemory()
            let context = container.mainContext
            Fixtures.populate(context, now: now, calendar: calendar)
            addYesterday(context, now: now, calendar: calendar)
            switch kind {
            case .todayEmpty:
                for entry in try FoodLogService.entries(on: now, in: context, calendar: calendar) {
                    context.delete(entry)
                }
            case .todayOver:
                let evening = calendar.startOfDay(for: now).addingTimeInterval(20 * 3600)
                context.insert(FoodEntry.quickAdd(name: "Akşam yemeği", kcal: 900, loggedAt: evening))
            case .addSearch, .entryEditor, .quickKcal, .customFood:
                break
            }
            try context.save()
            return container
        } catch {
            return nil
        }
    }
}

struct FoodLogDebugView: View {
    let kind: FoodLogDebugScreen
    @State private var container: ModelContainer?

    var body: some View {
        Group {
            if let container {
                content
                    .modelContainer(container)
            } else {
                Color.clear
            }
        }
        .task {
            if container == nil { container = FoodLogFixtures.makeContainer(kind) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .todayEmpty, .todayOver:
            TodayScreen()
        case .addSearch:
            AddSheet(initialSearch: "mercimek")
        case .entryEditor:
            NavigationStack {
                EntryEditorView(food: Self.editorFood, initialUnitID: Self.editorUnitID) {}
            }
        case .quickKcal:
            NavigationStack {
                QuickKcalView {}
            }
        case .customFood:
            NavigationStack {
                CustomFoodForm { _ in }
            }
        }
    }

    /// The bundled lentil soup when present, otherwise a stand-in with the same shape.
    private static var editorFood: LoggableFood {
        let seed = SeedCatalog.shared.searchFoods("mercimek çorbası", limit: 1).first
            ?? SeedFood(
                id: "debug-mercimek",
                name: "Mercimek çorbası",
                per100g: SeedNutrients(kcal: 56, protein: 3.6, carbs: 8.2, fat: 1.2, fiber: 1.6),
                servings: [SeedServing(label: "kase", grams: 250), SeedServing(label: "kaşık", grams: 15)]
            )
        return LoggableFood(seed: seed)
    }

    private static var editorUnitID: String? {
        editorFood.portionUnits.first(where: { $0.label == "kase" })?.id
    }
}
#endif
