#if DEBUG
import SwiftData
import SwiftUI

/// Workout screens reachable from `-UNFAT_SCREEN` (the plain `workout` route is the tab itself,
/// which already shows the fixture program and history).
enum WorkoutDebugScreen: Hashable, Sendable {
    /// Workout tab without programs and history.
    case empty
    case programEditor
    case exercisePicker
    /// Active session: 2 exercises, some sets done, rest timer running.
    case session
    /// Summary after finishing a session that set at least one record.
    case sessionSummary
}

/// Fixture data and rest timer for the session routes. Each route gets its own in-memory
/// container so the shared fixture container stays untouched.
@MainActor
final class WorkoutFixture {
    let container: ModelContainer
    let session: WorkoutSession?
    let summary: SessionSummary?
    let rest = RestTimerController()

    private init(container: ModelContainer, session: WorkoutSession?, summary: SessionSummary?) {
        self.container = container
        self.session = session
        self.summary = summary
    }

    static func make(_ kind: WorkoutDebugScreen, now: Date = .now) -> WorkoutFixture? {
        do {
            let container = try ModelContainerFactory.makeInMemory()
            let context = container.mainContext
            switch kind {
            case .empty:
                return WorkoutFixture(container: container, session: nil, summary: nil)
            case .session:
                Fixtures.populate(context, now: now)
                let session = try makeActiveSession(in: context, now: now)
                let fixture = WorkoutFixture(container: container, session: session, summary: nil)
                // About 1:27 left of a 90 s rest.
                fixture.rest.start(seconds: 90, now: now.addingTimeInterval(-3))
                return fixture
            case .sessionSummary:
                Fixtures.populate(context, now: now)
                let (session, summary) = try makeFinishedSession(in: context, now: now)
                return WorkoutFixture(container: container, session: session, summary: summary)
            case .programEditor, .exercisePicker:
                return nil
            }
        } catch {
            return nil
        }
    }

    private static func firstDay(in context: ModelContext) throws -> ProgramDay {
        let days = try context.fetch(FetchDescriptor<ProgramDay>()).sorted { $0.order < $1.order }
        guard let day = days.first else { throw FixtureError.missingProgram }
        return day
    }

    /// Day A started 25 minutes ago, prefilled from the fixture history: the first exercise is
    /// done, the second has one set done.
    private static func makeActiveSession(in context: ModelContext, now: Date) throws -> WorkoutSession {
        let start = now.addingTimeInterval(-25 * 60)
        let session = try WorkoutSessionService.startSession(day: firstDay(in: context), in: context, now: start)
        let exercises = session.sortedExercises
        for (index, log) in (exercises.first?.sortedSetLogs ?? []).enumerated() {
            WorkoutSessionService.toggleSet(log, now: start.addingTimeInterval(TimeInterval((5 + index * 4) * 60)))
        }
        if exercises.count > 1, let log = exercises[1].sortedSetLogs.first {
            WorkoutSessionService.toggleSet(log, now: start.addingTimeInterval(18 * 60))
        }
        try context.save()
        return session
    }

    /// Day A again, heavier on the first two exercises, all sets done: the first two exercises
    /// set records against the fixture history.
    private static func makeFinishedSession(
        in context: ModelContext,
        now: Date
    ) throws -> (WorkoutSession, SessionSummary) {
        let start = now.addingTimeInterval(-70 * 60)
        let session = try WorkoutSessionService.startSession(day: firstDay(in: context), in: context, now: start)
        var minute = 5
        for (exerciseIndex, exercise) in session.sortedExercises.enumerated() {
            for log in exercise.sortedSetLogs {
                if exerciseIndex < 2 { log.weightKg += exerciseIndex == 0 ? 5 : 2.5 }
                WorkoutSessionService.toggleSet(log, now: start.addingTimeInterval(TimeInterval(minute * 60)))
                minute += 4
            }
        }
        let catalog = ExerciseCatalog(seed: .shared)
        let summary = try WorkoutSessionService.finish(
            session,
            catalog: catalog,
            in: context,
            now: start.addingTimeInterval(62 * 60)
        )
        return (session, summary)
    }

    enum FixtureError: Error {
        case missingProgram
    }
}

/// Hosts one of the workout debug screens.
struct WorkoutDebugView: View {
    let kind: WorkoutDebugScreen
    @State private var fixture: WorkoutFixture?

    var body: some View {
        switch kind {
        case .programEditor:
            ProgramEditorDebugView()
        case .exercisePicker:
            ExercisePickerView { _ in }
        case .empty, .session, .sessionSummary:
            Group {
                if let fixture {
                    content(fixture)
                } else {
                    Color.clear
                }
            }
            .task {
                if fixture == nil { fixture = WorkoutFixture.make(kind) }
            }
        }
    }

    @ViewBuilder
    private func content(_ fixture: WorkoutFixture) -> some View {
        switch kind {
        case .session:
            if let session = fixture.session {
                ActiveSessionView(session: session, rest: fixture.rest) {}
                    .modelContainer(fixture.container)
            }
        case .sessionSummary:
            if let summary = fixture.summary {
                NavigationStack {
                    SessionSummaryView(summary: summary, session: fixture.session) {}
                        .navigationTitle("Özet")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .modelContainer(fixture.container)
            }
        default:
            WorkoutScreen()
                .modelContainer(fixture.container)
        }
    }
}

/// Program editor on the fixture program.
struct ProgramEditorDebugView: View {
    @Query(sort: \Program.order) private var programs: [Program]

    var body: some View {
        NavigationStack {
            if let program = programs.first {
                ProgramEditorView(program: program)
            }
        }
    }
}
#endif
