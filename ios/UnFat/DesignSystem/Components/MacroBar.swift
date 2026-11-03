import SwiftUI

/// One macro: title, "eaten / target g", and a 5 pt capsule bar with accent fill (clamped at full).
struct MacroBar: View {
    let title: LocalizedStringKey
    /// Eaten grams.
    let eaten: Double
    /// Target grams.
    let target: Double

    private static let barHeight: CGFloat = 5

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(max(eaten / target, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer(minLength: Spacing.xs)
                Text("\(Self.grams(eaten)) / \(Self.grams(target)) g")
                    .roundedNumbers()
                    .foregroundStyle(Palette.secondaryLabel)
                    .contentTransition(.numericText(value: eaten))
            }
            .font(.subheadline)

            Capsule()
                .fill(Palette.track)
                .frame(height: Self.barHeight)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Palette.accent)
                            .frame(width: proxy.size.width * fraction)
                    }
                }
                .accessibilityHidden(true)
        }
        .motion(.standard, value: eaten)
        .accessibilityElement(children: .combine)
    }

    private static func grams(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}

#Preview {
    @Previewable @State var protein = 52.0
    List {
        MacroBar(title: "Protein", eaten: protein, target: 120)
        MacroBar(title: "Karbonhidrat", eaten: 180, target: 220)
        MacroBar(title: "Yağ", eaten: 70, target: 65)
        Button(String("Change")) { protein = Double.random(in: 0...140) }
    }
}
