import SwiftUI
import UIKit

/// Color tokens (SPEC "Design decisions" > Color). One accent; everything else is a system semantic color.
/// Over target is never red: the overflow uses `overTarget` (an opaque secondary gray).
enum Palette {
    /// Coral accent #FF6A3D, from the `AccentColor` asset (same value in light and dark).
    static var accent: Color { Color("AccentColor") }

    static var groupedBackground: Color { Color(uiColor: .systemGroupedBackground) }
    static var secondaryGroupedBackground: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    static var label: Color { Color(uiColor: .label) }
    static var secondaryLabel: Color { Color(uiColor: .secondaryLabel) }
    static var tertiaryLabel: Color { Color(uiColor: .tertiaryLabel) }
    static var separator: Color { Color(uiColor: .separator) }

    /// Track of rings and bars; also the resting fill of chips and keypad keys.
    static var track: Color { Color(uiColor: .tertiarySystemFill) }
    /// Pressed state of filled controls (keypad keys).
    static var pressedFill: Color { Color(uiColor: .secondarySystemFill) }

    /// Second ring lap and "kcal fazla" text when over target. Opaque (`systemGray`), because the
    /// translucent `secondaryLabel` turns brown where the lap overlaps the accent stroke.
    static var overTarget: Color { Color(uiColor: .systemGray) }
    /// Text on accent-filled controls (selected chips).
    static var onAccent: Color { .white }
    /// System red, for destructive actions only.
    static var destructive: Color { .red }
}
