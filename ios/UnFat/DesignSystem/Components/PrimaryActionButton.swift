import SwiftUI

/// Full-width accent button for the main action of a screen (e.g. "Ekle" in the entry editor).
struct PrimaryActionButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Palette.accent)
    }
}

#Preview {
    PrimaryActionButton(title: "Ekle") {}
        .padding(Spacing.sideMargin)
}
