import SwiftUI

struct RootView: View {
    @State private var selection: AppTab = .today
    @State private var isAddSheetPresented = false
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
        if let launchTab, launchTab != .add {
            _selection = State(initialValue: launchTab)
        }
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
            AddSheet()
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
