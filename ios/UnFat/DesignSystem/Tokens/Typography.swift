import SwiftUI

/// Type tokens (SPEC "Design decisions" > Type). SF Pro for text via system text styles,
/// SF Rounded for numbers. All styles are text-style based, so they follow Dynamic Type.
extension Font {
    /// Hero numbers: 34 pt semibold rounded at the default size (large title style).
    static var heroNumber: Font { .system(.largeTitle, design: .rounded, weight: .semibold) }
    /// Numbers inside rows and summaries.
    static var rowNumber: Font { .system(.body, design: .rounded) }
    /// Keypad key labels.
    static var keypadKey: Font { .system(.title2, design: .rounded, weight: .medium) }
}

extension View {
    /// SF Rounded with fixed-width digits, for any number that changes or lines up.
    func roundedNumbers() -> some View {
        fontDesign(.rounded).monospacedDigit()
    }
}
