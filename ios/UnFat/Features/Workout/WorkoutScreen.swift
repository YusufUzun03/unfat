import SwiftData
import SwiftUI

/// "Antrenman" tab: the running session, programs and their days, empty workout, history.
struct WorkoutScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Program.order) private var programs: [Program]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    /// Owned here so the rest keeps running while the session is minimized.
    @State private var rest = RestTimerController()
    @State private var presentedSession: WorkoutSession?
    @State private var editingProgram: Program?
    @State private var pendingStart: PendingStart?
    @State private var showsTemplates = false
    @State private var programToDelete: Program?
    @State private var errorShown = false

    /// What the user asked to start while another session is still active.
    private struct PendingStart {
        let day: ProgramDay?
    }

    private static let historyLimit = 20

    private var activeSession: WorkoutSession? {
        sessions.first { $0.isActive }
    }

    private var history: [WorkoutSession] {
        Array(sessions.filter { !$0.isActive }.prefix(Self.historyLimit))
    }

    private var visiblePrograms: [Program] {
        programs.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            List {
                if let activeSession {
                    Section {
                        Button {
                            presentedSession = activeSession
                        } label: {
                            HStack {
                                Text("Devam eden antrenman")
                                    .fontWeight(.semibold)
                                Spacer(minLength: Spacing.sm)
                                Text(activeSession.startedAt, style: .timer)
                                    .roundedNumbers()
                            }
                            .foregroundStyle(Palette.accent)
                            .contentShape(.rect)
                        }
                    }
                }

                programsSection

                Section {
                    Button {
                        requestStart(day: nil)
                    } label: {
                        Label("Boş antrenman başlat", systemImage: "plus.circle")
                            .foregroundStyle(Palette.accent)
                    }
                }

                if !history.isEmpty {
                    Section("Geçmiş") {
                        ForEach(history) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                HistoryRow(session: session)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Antrenman")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: addProgram) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Yeni program"))
                }
            }
        }
        .restTimerCompletion(rest)
        .fullScreenCover(item: $presentedSession) { session in
            ActiveSessionView(session: session, rest: rest) {
                presentedSession = nil
            }
        }
        .sheet(item: $editingProgram, onDismiss: removeEmptyPrograms) { program in
            NavigationStack {
                ProgramEditorView(program: program)
            }
        }
        .sheet(isPresented: $showsTemplates) {
            TemplateListView { template in
                createProgram(from: template)
            }
        }
        .confirmationDialog(
            "Devam eden bir antrenman var",
            isPresented: Binding(get: { pendingStart != nil }, set: { if !$0 { pendingStart = nil } }),
            titleVisibility: .visible,
            presenting: pendingStart
        ) { pending in
            Button("Devam eden antrenmana dön") {
                presentedSession = activeSession
            }
            Button("Mevcut antrenmanı bitir ve başlat") {
                closeActiveSession()
                start(day: pending.day)
            }
            Button("Vazgeç", role: .cancel) {}
        }
        .confirmationDialog(
            "Program silinsin mi?",
            isPresented: Binding(get: { programToDelete != nil }, set: { if !$0 { programToDelete = nil } }),
            titleVisibility: .visible,
            presenting: programToDelete
        ) { program in
            Button("Sil", role: .destructive) {
                context.delete(program)
                try? context.save()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: { _ in
            Text("Geçmiş antrenmanlar silinmez.")
        }
        .alert("Kaydedilemedi", isPresented: $errorShown) {
            Button("Tamam", role: .cancel) {}
        }
    }

    // MARK: - Programs

    @ViewBuilder
    private var programsSection: some View {
        if visiblePrograms.isEmpty {
            Section("Programların") {
                Button {
                    showsTemplates = true
                } label: {
                    Label("Şablondan başla", systemImage: "square.stack")
                        .foregroundStyle(Palette.accent)
                }
            }
        } else {
            Section("Programların") {
                ForEach(visiblePrograms) { program in
                    programHeader(program)
                    ForEach(program.sortedDays) { day in
                        Button {
                            requestStart(day: day)
                        } label: {
                            dayRow(day)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func programHeader(_ program: Program) -> some View {
        HStack {
            Text(verbatim: program.name.isEmpty ? String(localized: "Yeni program") : program.name)
                .font(.headline)
            Spacer(minLength: Spacing.sm)
            Menu {
                Button {
                    editingProgram = program
                } label: {
                    Label("Düzenle", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    programToDelete = program
                } label: {
                    Label("Sil", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Palette.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(Text("Program seçenekleri"))
        }
    }

    private func dayRow(_ day: ProgramDay) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: day.name)
                Text("\((day.exercises ?? []).count) egzersiz")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            Spacer(minLength: Spacing.sm)
            Image(systemName: "play.fill")
                .font(.footnote)
                .foregroundStyle(Palette.accent)
        }
        .contentShape(.rect)
    }

    // MARK: - Actions

    private func addProgram() {
        let order = (programs.map(\.order).max() ?? -1) + 1
        let program = Program(name: "", order: order)
        context.insert(program)
        editingProgram = program
    }

    /// Drops a program that was created with "+" but never named or given a day.
    private func removeEmptyPrograms() {
        for program in programs where program.name.isEmpty && (program.days ?? []).isEmpty {
            context.delete(program)
        }
        try? context.save()
    }

    private func createProgram(from template: ProgramTemplate) {
        do {
            try WorkoutSessionService.createProgram(from: template, catalog: .shared, in: context)
        } catch {
            errorShown = true
        }
    }

    private func requestStart(day: ProgramDay?) {
        if activeSession != nil {
            pendingStart = PendingStart(day: day)
        } else {
            start(day: day)
        }
    }

    private func start(day: ProgramDay?) {
        do {
            let session = try WorkoutSessionService.startSession(
                day: day,
                emptyName: String(localized: "Antrenman"),
                in: context
            )
            rest.skip()
            presentedSession = session
        } catch {
            errorShown = true
        }
    }

    /// Finishes the running session (keeping its done sets), or deletes it when nothing was done.
    private func closeActiveSession() {
        guard let session = activeSession else { return }
        do {
            if WorkoutSessionService.hasNoDoneSets(session) {
                try WorkoutSessionService.discard(session, in: context)
            } else {
                let custom = (try? context.fetch(FetchDescriptor<CustomExercise>())) ?? []
                let catalog = ExerciseCatalog(seed: .shared, custom: custom.map(ExerciseItem.init(custom:)))
                _ = try WorkoutSessionService.finish(session, catalog: catalog, in: context)
            }
        } catch {
            errorShown = true
        }
    }
}

/// One history row: day name and date, then duration and volume.
private struct HistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text(verbatim: session.name)
                Spacer(minLength: Spacing.sm)
                Text(session.startedAt, format: .dateTime.day().month(.abbreviated))
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            Text(verbatim: detail)
                .font(.footnote)
                .foregroundStyle(Palette.secondaryLabel)
                .monospacedDigit()
        }
    }

    private var detail: String {
        let duration = WorkoutFormat.duration(WorkoutSessionService.duration(of: session) ?? 0)
        let volume = WorkoutFormat.kg(WorkoutSessionService.volumeKg(of: session))
        return "\(duration) · \(volume)"
    }
}

/// Built-in program templates; picking one creates a copy as the user's program.
struct TemplateListView: View {
    let onPick: (ProgramTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(ProgramTemplate.all) { template in
                Button {
                    onPick(template)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(verbatim: template.name)
                        Text("\(template.dayCount) gün")
                            .font(.footnote)
                            .foregroundStyle(Palette.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Şablonlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }
}
