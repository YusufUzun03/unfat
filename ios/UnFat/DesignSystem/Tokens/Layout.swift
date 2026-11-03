import CoreGraphics

/// Spacing scale 4 / 8 / 12 / 16 / 24 / 32 (SPEC "Design decisions" > Spacing).
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32

    /// Screen side margin.
    static let sideMargin: CGFloat = 16
}

/// Corner radii. Grouped containers use 14 pt with `.continuous` style; chips are capsules.
enum Radius {
    static let container: CGFloat = 14
}
