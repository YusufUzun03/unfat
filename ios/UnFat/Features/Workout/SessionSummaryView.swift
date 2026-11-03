import SwiftData
import SwiftUI

/// Numbers, personal records and per-exercise sets of a finished session.
/// Used right after "Bitir" (with a "Tamam" button) and read-only from history.
struct SessionSummaryView: View {
    let summary: SessionSummary
    let session: WorkoutSession?
    let onDone: (() -> Void)?

    init(summary: SessionSummary, session: WorkoutSession? = nil, onDone: (() -> Void)? = nil) {
        self.summary = summary
        self.session = session
        self.onDone = onDone
    }

    var body: some View {
        List {
            Section {
                row("Süre", WorkoutFormat.duration(summary.duration))
                row("Hacim", WorkoutFormat.kg(summary.volumeKg))
                row("Enerji", WorkoutFormat.kcal(summary.energyKcal))
                row("Tamamlanan set", summary.doneSetCount.formatted())
                row("Egzersiz", summary.exerciseCount.formatted())
            }

            if !summary.records.isEmpty {
                Section("Rekorlar") {
                    ForEach(summary.records) { record in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "trophy")
                                .foregroundStyle(Palette.accent)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(verbatim: record.exerciseName)
                                Text(verbatim: record.kind.title)
                                    .font(.footnote)
                                    .foregroundStyle(Palette.secondaryLabel)
                            }
                            Spacer(minLength: Spacing.sm)
                            Text(verbatim: WorkoutFormat.kg(record.valueKg))
                                .roundedNumbers()
                                .foregroundStyle(Palette.accent)
                        }
                    }
                }
            }

            if let session {
                let exercises = session.sortedExercises.filter { exercise in
                    exercise.sortedSetLogs.contains(where: \.isDone)
                }
                if !exercises.isEmpty {
                    Section("Egzersizler") {
                        ForEach(exercises) { exercise in
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(verbatim: exercise.exerciseName)
                                Text(verbatim: setsText(exercise))
                                    .font(.footnote)
                                    .foregroundStyle(Palette.secondaryLabel)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tamam", action: onDone)
                }
            }
        }
    }

    private func row(_ title: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent(title) {
            Text(verbatim: value).roundedNumbers()
        }
    }

    private func setsText(_ exercise: SessionExercise) -> String {
        exercise.sortedSetLogs
            .filter(\.isDone)
            .map { "\(WorkoutFormat.kg($0.weightKg)) × \($0.reps)" }
            .joined(separator: ", ")
    }
}

/// Read-only summary of a past session: computes the summary (including the records it set).
struct SessionDetailView: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Query(sort: \CustomExercise.createdAt) private var customExercises: [CustomExercise]
    @State private var summary: SessionSummary?

    var body: some View {
        Group {
            if let summary {
                SessionSummaryView(summary: summary, session: session)
            } else {
                Color.clear
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let catalog = ExerciseCatalog(seed: .shared, custom: customExercises.map(ExerciseItem.init(custom:)))
            summary = try? WorkoutSessionService.summary(for: session, catalog: catalog, in: context)
        }
    }
}
