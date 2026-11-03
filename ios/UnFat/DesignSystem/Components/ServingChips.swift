import SwiftUI

struct ServingOption: Identifiable, Hashable, Sendable {
    let id: String
    /// Display text, e.g. "1 kase" (comes from data, shown verbatim).
    let title: String
}

/// Horizontal, single-selection serving chips. Selected = accent capsule with white text.
struct ServingChips: View {
    let options: [ServingOption]
    @Binding var selection: ServingOption.ID?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xs) {
                ForEach(options) { option in
                    chip(option, isSelected: option.id == selection)
                }
            }
            .padding(.horizontal, Spacing.sideMargin)
            .padding(.vertical, Spacing.xxs)
        }
        .scrollIndicators(.hidden)
        .motion(.standard, value: selection)
    }

    private func chip(_ option: ServingOption, isSelected: Bool) -> some View {
        Button {
            selection = option.id
        } label: {
            Text(option.title)
                .font(.subheadline)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .foregroundStyle(isSelected ? Palette.onAccent : Palette.label)
                .background(Capsule().fill(isSelected ? Palette.accent : Palette.track))
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection: String? = "kase"
    ServingChips(
        options: [
            ServingOption(id: "g100", title: "100 g"),
            ServingOption(id: "kase", title: "1 kase"),
            ServingOption(id: "kepce", title: "1 kepçe"),
            ServingOption(id: "porsiyon", title: "1 porsiyon"),
        ],
        selection: $selection
    )
}
