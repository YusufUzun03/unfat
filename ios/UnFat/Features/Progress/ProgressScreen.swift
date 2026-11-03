import SwiftUI

// Named ProgressScreen to avoid clashing with SwiftUI.ProgressView.
struct ProgressScreen: View {
    var body: some View {
        NavigationStack {
            List {}
                .navigationTitle("İlerleme")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}
