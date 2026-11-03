import SwiftData
import SwiftUI

/// Ends the rest timer when its end date passes (also after the app returns to the foreground).
/// Applied to the active session and to the Workout tab so a minimized session still completes.
private struct RestTimerCompletion: ViewModifier {
    let rest: RestTimerController
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task(id: rest.endDate) {
                while !Task.isCancelled {
                    guard let end = rest.endDate else { return }
                    let wait = end.timeIntervalSinceNow
                    if wait <= 0 {
                        rest.completeIfElapsed()
                        return
                    }
                    try? await Task.sleep(for: .seconds(wait))
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { rest.completeIfElapsed() }
            }
    }
}

extension View {
    func restTimerCompletion(_ rest: RestTimerController) -> some View {
        modifier(RestTimerCompletion(rest: rest))
    }
}

/// The workout in progress: sets per exercise, keypad editing, in-app rest timer, finish summary.
/// Presented full screen by `WorkoutScreen`; `onClose` minimizes it or closes it after finishing.
struct ActiveSessionView: View {
    let session: WorkoutSession
    let rest: RestTimerController
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \CustomExercise.createdAt) private var customExercises: [CustomExercise]
    @State private var catalog = ExerciseCatalog(seed: .shared)
    @State private var previousByRef: [String: [SetValue]] = [:]
    @State private var editing: SetEdit?
    @State private var showsPicker = false
    @State private var showsFinishDialog = false
    @State private var finishedSummary: SessionSummary?
    @State private var isClosing = false
    @State private var saveFailed = false

    /// One kg or reps field of one set, edited in the keypad sheet.
    fileprivate struct SetEdit: Identifiable {
        enum Field: String { case weight, reps }
        let log: SetLog
        let field: Field
        var id: String { "\(log.uuid.uuidString)-\(field.rawValue)" }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isClosing {
                    Color.clear
                } else if let finishedSummary {
                    SessionSummaryView(summary: finishedSummary, session: session) {
                        isClosing = true
                        onClose()
                    }
                    .navigationTitle("Özet")
                    .navigationBarTitleDisplayMode(.inline)
                } else {
                    sessionList
                }
            }
        }
        .restTimerCompletion(rest)
        .sensoryFeedback(Haptics.restFinished, trigger: rest.finishedCount)
        .interactiveDismissDisabled()
    }

    // MARK: - Session list

    private var sessionList: some View {
        List {
            ForEach(session.sortedExercises) { exercise in
                exerciseSection(exercise)
            }
            Section {
                Button {
                    showsPicker = true
                } label: {
                    Label("Egzersiz ekle", systemImage: "plus.circle")
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                }
                .accessibilityLabel(Text("Küçült"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Text(session.startedAt, style: .timer)
                    .monospacedDigit()
                    .foregroundStyle(Palette.secondaryLabel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Bitir") { showsFinishDialog = true }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let interval = rest.interval {
                RestTimerView(
                    interval: interval,
                    onSubtract15: { rest.adjust(by: -RestTimerMath.adjustStep) },
                    onAdd15: { rest.adjust(by: RestTimerMath.adjustStep) },
                    onSkip: { rest.skip() }
                )
                .padding(Spacing.md)
                .background(.bar)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .motion(.standard, value: rest.isRunning)
        .sheet(item: $editing) { edit in
            SetValueSheet(edit: edit) { value in
                apply(value, to: edit)
            }
        }
        .sheet(isPresented: $showsPicker) {
            ExercisePickerView { item in
                addExercise(item)
            }
        }
        .confirmationDialog(
            WorkoutSessionService.hasNoDoneSets(session)
                ? Text("Hiç set tamamlanmadı")
                : Text("Antrenman bitirilsin mi?"),
            isPresented: $showsFinishDialog,
            titleVisibility: .visible
        ) {
            if WorkoutSessionService.hasNoDoneSets(session) {
                Button("Antrenmanı sil", role: .destructive, action: discard)
            } else {
                Button("Bitir", action: finish)
            }
            Button("Devam et", role: .cancel) {}
        } message: {
            if !WorkoutSessionService.hasNoDoneSets(session) {
                Text("Tamamlanmayan setler silinir.")
            }
        }
        .alert("Kaydedilemedi", isPresented: $saveFailed) {
            Button("Tamam", role: .cancel) {}
        }
        .task(id: session.sortedExercises.map(\.exerciseRef)) {
            loadPrevious()
        }
        .onChange(of: customExercises.map(\.uuid), initial: true) {
            catalog = ExerciseCatalog(seed: .shared, custom: customExercises.map(ExerciseItem.init(custom:)))
        }
    }

    private func exerciseSection(_ exercise: SessionExercise) -> some View {
        let logs = exercise.sortedSetLogs
        let previous = previousByRef[exercise.exerciseRef] ?? []
        return Section {
            SetRowHeader()
            ForEach(Array(logs.enumerated()), id: \.element.uuid) { index, log in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    SetRow(
                        number: index + 1,
                        weightKg: log.weightKg,
                        reps: log.reps,
                        isDone: log.isDone,
                        onEditWeight: { editing = SetEdit(log: log, field: .weight) },
                        onEditReps: { editing = SetEdit(log: log, field: .reps) },
                        onToggle: { toggle(log, in: exercise) }
                    )
                    if let hint = previousHint(previous, index: index) {
                        Text(verbatim: hint)
                            .font(.caption)
                            .foregroundStyle(Palette.tertiaryLabel)
                            .monospacedDigit()
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        WorkoutSessionService.deleteSet(log, from: exercise, in: context)
                        save()
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
            }
            Button {
                WorkoutSessionService.addSet(to: exercise, in: context)
                save()
            } label: {
                Label("Set ekle", systemImage: "plus")
                    .foregroundStyle(Palette.accent)
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: exercise.exerciseName)
                        .font(.headline)
                        .foregroundStyle(Palette.label)
                    if let muscle = muscle(of: exercise) {
                        Text(verbatim: muscle.title)
                            .font(.footnote)
                            .foregroundStyle(Palette.secondaryLabel)
                    }
                }
                Spacer(minLength: Spacing.sm)
                Menu {
                    Button(role: .destructive) {
                        WorkoutSessionService.deleteExercise(exercise, in: context)
                        save()
                    } label: {
                        Label("Egzersizi sil", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Palette.accent)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel(Text("Egzersiz seçenekleri"))
            }
            .textCase(nil)
        }
    }

    // MARK: - Actions

    private func toggle(_ log: SetLog, in exercise: SessionExercise) {
        let done = WorkoutSessionService.toggleSet(log)
        save()
        if done {
            rest.start(seconds: exercise.restSeconds)
        }
    }

    private func apply(_ value: Double, to edit: SetEdit) {
        switch edit.field {
        case .weight: edit.log.weightKg = value
        case .reps: edit.log.reps = Int(value.rounded())
        }
        save()
    }

    private func addExercise(_ item: ExerciseItem) {
        do {
            try WorkoutSessionService.addExercise(item, to: session, in: context)
        } catch {
            saveFailed = true
        }
    }

    private func finish() {
        do {
            let summary = try WorkoutSessionService.finish(session, catalog: catalog, in: context)
            rest.skip()
            finishedSummary = summary
        } catch {
            saveFailed = true
        }
    }

    private func discard() {
        // Stop rendering the session before its model is deleted.
        isClosing = true
        rest.skip()
        do {
            try WorkoutSessionService.discard(session, in: context)
        } catch {
            isClosing = false
            saveFailed = true
            return
        }
        onClose()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            saveFailed = true
        }
    }

    // MARK: - Helpers

    private func muscle(of exercise: SessionExercise) -> Muscle? {
        catalog.item(ref: exercise.exerciseRef)?.muscle
    }

    private func loadPrevious() {
        var result: [String: [SetValue]] = [:]
        for ref in Set(session.sortedExercises.map(\.exerciseRef)) {
            result[ref] = (try? WorkoutSessionService.previousSets(forRef: ref, before: session.startedAt, in: context)) ?? []
        }
        previousByRef = result
    }

    /// "Önceki: 60 kg × 8" for the same set index of the last session (the last set when the
    /// index is beyond it); nil without history.
    private func previousHint(_ previous: [SetValue], index: Int) -> String? {
        guard let value = previous.indices.contains(index) ? previous[index] : previous.last else { return nil }
        return String(localized: "Önceki: \(WorkoutFormat.kg(value.weightKg)) × \(value.reps)")
    }
}

/// Keypad sheet for the kg or reps of one set.
private struct SetValueSheet: View {
    let edit: ActiveSessionView.SetEdit
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(edit: ActiveSessionView.SetEdit, onSave: @escaping (Double) -> Void) {
        self.edit = edit
        self.onSave = onSave
        let current: String
        switch edit.field {
        case .weight:
            let weight = edit.log.weightKg
            if weight <= 0 {
                current = ""
            } else if weight.truncatingRemainder(dividingBy: 1) == 0 {
                current = String(Int(weight))
            } else {
                current = String(format: "%.1f", weight)
            }
        case .reps:
            current = edit.log.reps > 0 ? String(edit.log.reps) : ""
        }
        _text = State(initialValue: current)
    }

    private var value: Double? {
        guard let decimal = KeypadInput.decimal(text) else { return nil }
        return NSDecimalNumber(decimal: decimal).doubleValue
    }

    private var isValid: Bool {
        switch edit.field {
        case .weight: true
        case .reps: (value ?? 0) >= 1
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(verbatim: KeypadInput.displayText(text.isEmpty ? "0" : text))
                        .font(.heroNumber)
                        .roundedNumbers()
                    if edit.field == .weight {
                        Text("kg")
                            .font(.title3)
                            .foregroundStyle(Palette.secondaryLabel)
                    }
                }
                Spacer(minLength: 0)
                Keypad(
                    text: $text,
                    maxIntegerDigits: edit.field == .weight ? 4 : 3,
                    maxFractionDigits: edit.field == .weight ? 1 : 0
                )
                PrimaryActionButton(title: "Tamam") {
                    onSave(value ?? 0)
                    dismiss()
                }
                .disabled(!isValid)
            }
            .padding(Spacing.sideMargin)
            .background(Palette.groupedBackground)
            .navigationTitle(edit.field == .weight ? Text("kg") : Text("Tekrar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }
}
