import SwiftUI

/// A number that rolls its digits when it changes (`.numericText`), in SF Rounded with fixed-width digits.
/// Font comes from the caller (`.font(...)`). Reduce Motion swaps the roll for a cross-fade.
struct NumberRoll: View {
    let value: Double
    var fractionDigits: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(value, format: .number.precision(.fractionLength(fractionDigits)))
            .roundedNumbers()
            .contentTransition(reduceMotion ? ContentTransition.opacity : .numericText(value: value))
            .motion(.standard, value: value)
    }
}

#Preview {
    @Previewable @State var value = 1265.0
    VStack(spacing: Spacing.md) {
        NumberRoll(value: value)
            .font(.heroNumber)
        NumberRoll(value: value / 20, fractionDigits: 1)
            .font(.title3)
        Button(String("Change")) { value = Double.random(in: 0...2500) }
    }
}
