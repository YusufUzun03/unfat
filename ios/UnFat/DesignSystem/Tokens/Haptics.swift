import SwiftUI

/// Haptic tokens for `.sensoryFeedback` (SPEC "Design decisions" > Haptics).
/// `.warning` is never used for targets.
enum Haptics {
    /// A food entry was logged.
    static var foodLogged: SensoryFeedback { .success }
    /// A workout set was checked.
    static var setChecked: SensoryFeedback { .impact(weight: .light) }
    /// A keypad key was pressed.
    static var keyTap: SensoryFeedback { .selection }
}
