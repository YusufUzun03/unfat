#if DEBUG
import SwiftUI

/// Non-tab screens reachable from `-UNFAT_SCREEN`; `RootView` presents them full screen.
enum DebugScreen: Hashable, Sendable, Identifiable {
    case gallery(firstSection: GallerySection, showsTuning: Bool)

    var id: Self { self }
}

struct DebugScreenView: View {
    let screen: DebugScreen

    var body: some View {
        switch screen {
        case let .gallery(firstSection, showsTuning):
            GalleryView(firstSection: firstSection, showsTuning: showsTuning)
        }
    }
}
#endif
