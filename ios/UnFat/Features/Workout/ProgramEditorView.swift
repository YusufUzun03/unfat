import SwiftData
import SwiftUI

/// Edits a program: name, days (add, rename, delete, reorder). Needs a surrounding `NavigationStack`.
struct ProgramEditorView: View {
    @Bindable var program: Program

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            Section {
                TextField("Program adı", text: $program.name)
            }
            Section("Günler") {
                ForEach(program.sortedDays) { day in
                    NavigationLink {
                        DayEditorView(day: day)
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(verbatim: day.name)
                            Text("\((day.exercises ?? []).count) egzersiz")
                                .font(.footnote)
                                .foregroundStyle(Palette.secondaryLabel)
                        }
                    }
                }
                .onMove(perform: moveDays)
                .onDelete(perform: deleteDays)

                Button {
                    addDay()
                } label: {
                    Label("Gün ekle", systemImage: "plus.circle")
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .navigationTitle(program.name.isEmpty ? String(localized: "Yeni program") : program.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Bitti") { dismiss() }
            }
        }
        .onDisappear {
            program.updatedAt = .now
            try? context.save()
        }
    }

    private func addDay() {
        let days = program.sortedDays
        let day = ProgramDay(name: String(localized: "Gün \(days.count + 1)"), order: (days.last?.order ?? -1) + 1)
        context.insert(day)
        day.program = program
    }

    private func moveDays(from source: IndexSet, to destination: Int) {
        var days = program.sortedDays
        days.move(fromOffsets: source, toOffset: destination)
        for (index, day) in days.enumerated() { day.order = index }
    }

    private func deleteDays(at offsets: IndexSet) {
        let days = program.sortedDays
        let removed = Set(offsets.map { days[$0].uuid })
        for index in offsets { context.delete(days[index]) }
        for (index, day) in days.filter({ !removed.contains($0.uuid) }).enumerated() { day.order = index }
    }
}

/// Edits one program day: name and its planned exercises (add, reorder, delete, tap to edit sets).
struct DayEditorView: View {
    @Bindable var day: ProgramDay

    @Environment(\.modelContext) private var context
    @State private var showsPicker = false

    var body: some View {
        List {
            Section {
                TextField("Gün adı", text: $day.name)
            }
            Section("Egzersizler") {
                ForEach(day.sortedExercises) { planned in
                    NavigationLink {
                        PlannedExerciseEditView(planned: planned)
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(verbatim: planned.exerciseName)
                            Text(verbatim: summary(planned))
                                .font(.footnote)
                                .foregroundStyle(Palette.secondaryLabel)
                        }
                    }
                }
                .onMove(perform: moveExercises)
                .onDelete(perform: deleteExercises)

                Button {
                    showsPicker = true
                } label: {
                    Label("Egzersiz ekle", systemImage: "plus.circle")
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .navigationTitle(day.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showsPicker) {
            ExercisePickerView { item in
                WorkoutSessionService.addPlannedExercise(item, to: day, in: context)
            }
        }
    }

    private func summary(_ planned: PlannedExercise) -> String {
        let plan = WorkoutFormat.plan(sets: planned.sets, repMin: planned.repMin, repMax: planned.repMax)
        return "\(plan) · \(String(localized: "\(planned.restSeconds) sn"))"
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var exercises = day.sortedExercises
        exercises.move(fromOffsets: source, toOffset: destination)
        for (index, planned) in exercises.enumerated() { planned.order = index }
    }

    private func deleteExercises(at offsets: IndexSet) {
        let exercises = day.sortedExercises
        let removed = Set(offsets.map { exercises[$0].uuid })
        for index in offsets { context.delete(exercises[index]) }
        for (index, planned) in exercises.filter({ !removed.contains($0.uuid) }).enumerated() {
            planned.order = index
        }
    }
}

/// Sets, reps and rest seconds of one planned exercise.
struct PlannedExerciseEditView: View {
    @Bindable var planned: PlannedExercise

    /// One reps value for the whole plan: setting it collapses a template's rep range.
    private var reps: Binding<Int> {
        Binding(
            get: { planned.repMin },
            set: { value in
                planned.repMin = value
                planned.repMax = value
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Stepper(value: $planned.sets, in: 1...10) {
                    LabeledContent("Set") {
                        Text(planned.sets, format: .number).monospacedDigit()
                    }
                }
                Stepper(value: reps, in: 1...50) {
                    LabeledContent("Tekrar") {
                        Text(verbatim: planned.repMin == planned.repMax ? "\(planned.repMin)" : "\(planned.repMin)-\(planned.repMax)")
                            .monospacedDigit()
                    }
                }
                Stepper(value: $planned.restSeconds, in: 15...600, step: 15) {
                    LabeledContent("Dinlenme") {
                        Text("\(planned.restSeconds) sn").monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle(planned.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
