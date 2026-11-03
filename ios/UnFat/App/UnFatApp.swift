import SwiftData
import SwiftUI

@main
struct UnFatApp: App {
    /// Built once at launch (see `ModelContainerFactory.makeForApp()`): the iCloud sync preference is
    /// read here, so toggling sync applies on the next launch. DEBUG + `-UNFAT_SCREEN` uses fixtures.
    private let modelContainer: ModelContainer

    init() {
        modelContainer = ModelContainerFactory.makeForApp()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
