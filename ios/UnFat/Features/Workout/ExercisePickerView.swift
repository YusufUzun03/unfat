import SwiftData
import SwiftUI

/// Exercise picker: Turkish diacritic-insensitive search, muscle filter chips, custom exercises first.
/// Presented in a sheet; calls `onPick` and dismisses when a row is tapped.
struct ExercisePickerView: View {
    let onPick: (ExerciseItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomExercise.createdAt, order: .reverse) private var customExercises: [CustomExercise]
    @State private var catalog = ExerciseCatalog(seed: .shared)
    @State private var query = ""
    @State private var muscleSelection: String? = Self.allID
    @State private var showsCreateSheet = false

    private static let allID = "all"

    private var muscleOptions: [ServingOption] {
        [ServingOption(id: Self.allID, title: String(localized: "Tümü"))]
            + Muscle.allCases.map { ServingOption(id: $0.rawValue, title: $0.title) }
    }

    private var selectedMuscle: Muscle? {
        muscleSelection.flatMap { Muscle(rawValue: $0) }
    }

    private var results: [ExerciseItem] {
        catalog.search(query, muscle: selectedMuscle)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ServingChips(options: muscleOptions, selection: $muscleSelection)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    Button {
                        showsCreateSheet = true
                    } label: {
                        Label("Özel egzersiz", systemImage: "plus.circle")
                            .foregroundStyle(Palette.accent)
                    }
                }
                Section {
                    ForEach(results) { item in
                        Button {
                            onPick(item)
                            dismiss()
                        } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Egzersiz ekle")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Egzersiz ara")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
            .sheet(isPresented: $showsCreateSheet) {
                CustomExerciseSheet()
            }
            .onChange(of: customExercises.map(\.uuid), initial: true) {
                catalog = ExerciseCatalog(seed: .shared, custom: customExercises.map(ExerciseItem.init(custom:)))
            }
        }
    }

    private func row(_ item: ExerciseItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: item.name)
            Text(verbatim: "\(item.muscle.title) · \(item.equipment.title)")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

/// Creates a `CustomExercise` (name, muscle, equipment).
struct CustomExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var muscle: Muscle = .chest
    @State private var equipment: Equipment = .barbell
    @State private var saveFailed = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Egzersiz adı", text: $name)
                        .textInputAutocapitalization(.sentences)
                }
                Section {
                    Picker("Kas grubu", selection: $muscle) {
                        ForEach(Muscle.allCases, id: \.self) { muscle in
                            Text(verbatim: muscle.title).tag(muscle)
                        }
                    }
                    Picker("Ekipman", selection: $equipment) {
                        ForEach(Equipment.allCases, id: \.self) { equipment in
                            Text(verbatim: equipment.title).tag(equipment)
                        }
                    }
                }
            }
            .navigationTitle("Özel egzersiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .alert("Kaydedilemedi", isPresented: $saveFailed) {
                Button("Tamam", role: .cancel) {}
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let exercise = CustomExercise(
            nameTr: trimmedName,
            primaryMuscle: muscle,
            equipment: equipment,
            kind: muscle == .cardio ? .cardio : .strength
        )
        context.insert(exercise)
        do {
            try context.save()
            dismiss()
        } catch {
            context.delete(exercise)
            saveFailed = true
        }
    }
}

#Preview {
    ExercisePickerView { _ in }
}
