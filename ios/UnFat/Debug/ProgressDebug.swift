#if DEBUG
import SwiftData
import SwiftUI

/// Progress screens reachable from `-UNFAT_SCREEN` (the plain `progress` route is the tab itself).
enum ProgressDebugScreen: Hashable, Sendable {
    /// 90 day range selected.
    case range90
    /// No weigh-ins, food entries or workouts.
    case empty
    /// The "Kilo ekle" sheet content.
    case weightEntry
    /// Detail of the most recently trained fixture exercise.
    case exercise
}

/// Each route gets its own in-memory container so the shared fixture container stays untouched.
struct ProgressDebugView: View {
    let kind: ProgressDebugScreen
    @State private var container: ModelContainer?
    @State private var exerciseRef: String?

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
            if container == nil { make() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .range90:
            ProgressScreen(initialRange: .days90)
        case .empty:
            ProgressScreen()
        case .weightEntry:
            WeightEntrySheet(initialText: "81,6")
        case .exercise:
            NavigationStack {
                if let exerciseRef {
                    ExerciseProgressView(ref: exerciseRef)
                }
            }
        }
    }

    @MainActor
    private func make() {
        guard let made = try? ModelContainerFactory.makeInMemory() else { return }
        let context = made.mainContext
        Fixtures.populate(context, now: .now)
        if kind == .empty {
            try? context.delete(model: WeightEntry.self)
            try? context.delete(model: FoodEntry.self)
            try? context.delete(model: WorkoutSession.self)
            try? context.save()
        }
        if kind == .exercise {
            let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
            exerciseRef = ProgressData.exerciseRows(sessions: sessions).first?.ref
        }
        container = made
    }
}
#endif
