import Foundation
import SwiftUI

enum KeypadKey: Hashable, Sendable {
    case digit(Int)
    case decimal
    case delete

    /// 3 x 4 layout, row by row: 1 2 3 / 4 5 6 / 7 8 9 / , 0 delete.
    static let layout: [KeypadKey] = (1...9).map { KeypadKey.digit($0) } + [KeypadKey.decimal, .digit(0), .delete]
}

/// Pure editing rules for the keypad. The edited string is canonical: digits with an optional "."
/// as decimal separator (independent of locale); use `displayText` to show it, `decimal` to read it.
enum KeypadInput {
    static func apply(
        _ key: KeypadKey,
        to text: String,
        maxIntegerDigits: Int,
        maxFractionDigits: Int
    ) -> String {
        switch key {
        case .delete:
            return String(text.dropLast())
        case .decimal:
            guard maxFractionDigits > 0, !text.contains(".") else { return text }
            return text.isEmpty ? "0." : text + "."
        case .digit(let digit):
            if let dot = text.firstIndex(of: ".") {
                let fraction = text[text.index(after: dot)...]
                return fraction.count < maxFractionDigits ? text + String(digit) : text
            }
            if text == "0" {
                return String(digit)
            }
            return text.count < maxIntegerDigits ? text + String(digit) : text
        }
    }

    /// Canonical text with the current locale's decimal separator ("12.5" -> "12,5" in Turkish).
    static func displayText(_ text: String, locale: Locale = .current) -> String {
        text.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }

    /// Parsed value of canonical text; nil when empty.
    static func decimal(_ text: String) -> Decimal? {
        guard !text.isEmpty else { return nil }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }
}

/// Custom 3 x 4 number pad with decimal and delete keys and a selection haptic per press.
struct Keypad: View {
    @Binding var text: String
    let maxIntegerDigits: Int
    let maxFractionDigits: Int

    @State private var tapCount = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 3)

    init(text: Binding<String>, maxIntegerDigits: Int = 4, maxFractionDigits: Int = 1) {
        _text = text
        self.maxIntegerDigits = maxIntegerDigits
        self.maxFractionDigits = maxFractionDigits
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.xs) {
            ForEach(KeypadKey.layout, id: \.self) { key in
                Button {
                    press(key)
                } label: {
                    label(for: key)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(.rect)
                }
                .buttonStyle(KeypadKeyStyle())
            }
        }
        .sensoryFeedback(Haptics.keyTap, trigger: tapCount)
    }

    @ViewBuilder
    private func label(for key: KeypadKey) -> some View {
        switch key {
        case .digit(let digit):
            Text(verbatim: String(digit))
        case .decimal:
            Text(verbatim: Locale.current.decimalSeparator ?? ",")
        case .delete:
            Image(systemName: "delete.left")
                .accessibilityLabel(Text("Sil"))
        }
    }

    private func press(_ key: KeypadKey) {
        tapCount += 1
        text = KeypadInput.apply(
            key,
            to: text,
            maxIntegerDigits: maxIntegerDigits,
            maxFractionDigits: maxFractionDigits
        )
    }
}

private struct KeypadKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.keypadKey)
            .foregroundStyle(Palette.label)
            .background(
                RoundedRectangle(cornerRadius: Radius.container, style: .continuous)
                    .fill(configuration.isPressed ? Palette.pressedFill : Palette.track)
            )
    }
}

#Preview {
    @Previewable @State var text = "125"
    VStack(spacing: Spacing.md) {
        Text(verbatim: KeypadInput.displayText(text))
            .font(.heroNumber)
        Keypad(text: $text)
    }
    .padding(Spacing.sideMargin)
}
