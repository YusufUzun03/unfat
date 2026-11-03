import SwiftUI

/// Haptic tokens for `.sensoryFeedback` (SPEC "Design decisions" > Haptics).
/// `.warning` is never used for targets.
enum Haptics {
    /// A food entry was logged.
    static var foodLogged: SensoryFeedback { .success }
    /// A workout set was checked.
    static var setChecked: SensoryFeedback { .impact(weight: .light) }
    /// The rest timer reached zero.
    static var restFinished: SensoryFeedback { .success }
    /// A barcode was recognized by the scanner.
    static var barcodeScanned: SensoryFeedback { .success }
    /// A keypad key was pressed.
    static var keyTap: SensoryFeedback { .selection }
}
