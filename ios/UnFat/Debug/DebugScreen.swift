#if DEBUG
import SwiftUI

/// Non-tab screens reachable from `-UNFAT_SCREEN`; `RootView` presents them full screen.
enum DebugScreen: Hashable, Sendable, Identifiable {
    case gallery(firstSection: GallerySection, showsTuning: Bool)
    case onboarding(OnboardingStep)
    case goalEditor
    case workout(WorkoutDebugScreen)
    case foodLog(FoodLogDebugScreen)

    var id: Self { self }
}

struct DebugScreenView: View {
    let screen: DebugScreen

    var body: some View {
        switch screen {
        case let .gallery(firstSection, showsTuning):
            GalleryView(firstSection: firstSection, showsTuning: showsTuning)
        case let .onboarding(step):
            OnboardingDebugView(step: step)
        case .goalEditor:
            GoalEditorDebugView()
        case let .workout(kind):
            WorkoutDebugView(kind: kind)
        case let .foodLog(kind):
            FoodLogDebugView(kind: kind)
        }
    }
}
#endif
