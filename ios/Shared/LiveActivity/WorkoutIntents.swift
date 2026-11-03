import AppIntents
import Foundation

/// What a Live Activity button asked for.
enum WorkoutIntentAction: Equatable, Sendable {
    case addRestTime
    case skipRest
    case completeSet
}

/// Hand-off from the intents to the app. `LiveActivityIntent`s are compiled into the app and the
/// widget extension, but the system runs `perform()` in the app process (launching it in the
/// background if needed), so `UnFatApp.init` installs the handler and the intents just forward.
/// Actions that arrive before the handler exists are queued and replayed when it is installed.
@MainActor
enum WorkoutIntentBridge {
    typealias Handler = @MainActor @Sendable (WorkoutIntentAction) async -> Void

    static var handler: Handler? {
        didSet { replayQueuedActions() }
    }

    private static var queued: [WorkoutIntentAction] = []

    /// Returns when the handler has finished, so the intent stays alive until the activity is updated.
    static func perform(_ action: WorkoutIntentAction) async {
        guard let handler else {
            queued.append(action)
            return
        }
        await handler(action)
    }

    private static func replayQueuedActions() {
        guard let handler, !queued.isEmpty else { return }
        let actions = queued
        queued = []
        Task {
            for action in actions {
                await handler(action)
            }
        }
    }
}

/// "+15 sn" on the rest banner.
struct AddRestTimeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "+15 sn"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await WorkoutIntentBridge.perform(.addRestTime)
        return .result()
    }
}

/// "Geç" on the rest banner.
struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Geç"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await WorkoutIntentBridge.perform(.skipRest)
        return .result()
    }
}

/// "Set tamam" while no rest runs (or after it ended).
struct CompleteSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Set tamam"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await WorkoutIntentBridge.perform(.completeSet)
        return .result()
    }
}
