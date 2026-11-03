import SwiftData
import SwiftUI

@main
struct UnFatApp: App {
    /// Built once at launch (see `ModelContainerFactory.makeForApp()`): the iCloud sync preference is
    /// read here, so toggling sync applies on the next launch. DEBUG + `-UNFAT_SCREEN` uses fixtures.
    private let modelContainer: ModelContainer
    /// Workout Live Activity and the shared rest timer; in the environment of every screen.
    private let liveActivity: WorkoutLiveActivityController

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container = ModelContainerFactory.makeForApp()
        modelContainer = container
        let controller = WorkoutLiveActivityController(
            container: container,
            rest: RestTimerController(),
            isLive: WorkoutLiveActivityController.shouldRunLive()
        )
        liveActivity = controller
        // Restore first, then accept the Live Activity buttons: an intent that woke the app in the
        // background finds the rest timer and the session already in place.
        controller.launch()
        WorkoutIntentBridge.handler = { [controller] action in
            await controller.handle(action)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(liveActivity)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            // ActivityKit only starts activities in the foreground: this retries a start that was
            // too early at launch, and refreshes the activity after the app was away.
            if newPhase == .active {
                liveActivity.sync()
            }
        }
    }
}
