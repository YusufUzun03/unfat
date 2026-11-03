import SwiftData
import SwiftUI

struct RootView: View {
    @State private var selection: AppTab = .today
    @State private var isAddSheetPresented = false
    /// Bumped when the add sheet logged something; the haptic plays from here because the sheet dismisses itself.
    @State private var loggedTick = 0
    @Query private var profiles: [UserProfile]
    /// Off for hosted unit tests and DEBUG screenshot routes (fixtures already hold a completed profile).
    private let onboardingGateEnabled: Bool
    /// Tab requested by the DEBUG launch router; always nil in Release.
    private let launchTab: AppTab?
    #if DEBUG
    /// Full-screen DEBUG screen requested by the launch router (e.g. the gallery).
    private let launchScreen: DebugScreen?
    @State private var debugScreen: DebugScreen? = nil
    #endif

    init() {
        #if DEBUG
        switch LaunchRouter.route()?.destination {
        case .tab(let tab):
            launchTab = tab
            launchScreen = nil
        case .screen(let screen):
            launchTab = nil
            launchScreen = screen
        case nil:
            launchTab = nil
            launchScreen = nil
        }
        #else
        launchTab = nil
        #endif
        var gateEnabled = !ModelContainerFactory.isRunningUnitTests()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(LaunchRouter.argument) { gateEnabled = false }
        #endif
        onboardingGateEnabled = gateEnabled
        if let launchTab, launchTab != .add {
            _selection = State(initialValue: launchTab)
        }
    }

    private var needsOnboarding: Bool {
        onboardingGateEnabled && !profiles.contains { $0.onboardingCompletedAt != nil }
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Bugün", systemImage: "sun.max", value: AppTab.today) {
                TodayScreen()
            }
            Tab("Antrenman", systemImage: "dumbbell", value: AppTab.workout) {
                WorkoutScreen()
            }
            Tab("İlerleme", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                ProgressScreen()
            }
            Tab("Ekle", systemImage: "plus", value: AppTab.add, role: .search) {
                Color.clear
            }
        }
        .onChange(of: selection) { oldValue, newValue in
            // The add tab never stays selected: it opens the sheet over the previous tab.
            if newValue == .add {
                selection = oldValue
                isAddSheetPresented = true
            }
        }
        .sheet(isPresented: $isAddSheetPresented) {
            AddSheet(onLogged: { loggedTick += 1 })
        }
        .sensoryFeedback(Haptics.foodLogged, trigger: loggedTick)
        .fullScreenCover(isPresented: .constant(needsOnboarding)) {
            OnboardingFlow()
        }
        .task {
            if launchTab == .add {
                isAddSheetPresented = true
            }
            #if DEBUG
            if let launchScreen {
                debugScreen = launchScreen
            }
            #endif
        }
        #if DEBUG
        .fullScreenCover(item: $debugScreen) { screen in
            DebugScreenView(screen: screen)
        }
        #endif
    }
}
