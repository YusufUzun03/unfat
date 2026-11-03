import SwiftUI

/// Tunable design values. Release builds always use `standard`; DEBUG builds may override them
/// through `\.designValues` (set by the DEBUG tuning panel).
struct DesignValues: Equatable, Sendable {
    var springDuration: Double = 0.35
    var springBounce: Double = 0.15
    var ringSpringDuration: Double = 0.6
    var ringSpringBounce: Double = 0.1
    /// Ring stroke width at the reference 110 pt diameter; scales with the ring.
    var ringStroke: Double = 11

    static let standard = DesignValues()
}

extension EnvironmentValues {
    @Entry var designValues: DesignValues = .standard
}

enum MotionToken: Sendable {
    /// Default UI spring: `.spring(duration: 0.35, bounce: 0.15)`.
    case standard
    /// Calorie ring fill: `.spring(duration: 0.6, bounce: 0.1)`.
    case ring
}

/// Motion tokens (SPEC "Design decisions" > Motion). Sheets and navigation keep system transitions.
enum Motion {
    /// Reduce Motion: no spring. `standard` becomes a short ease (pairs with opacity transitions),
    /// `ring` is not animated at all.
    static func animation(
        _ token: MotionToken,
        values: DesignValues = .standard,
        reduceMotion: Bool
    ) -> Animation? {
        if reduceMotion {
            return token == .ring ? nil : .easeInOut(duration: 0.2)
        }
        switch token {
        case .standard:
            return .spring(duration: values.springDuration, bounce: values.springBounce)
        case .ring:
            return .spring(duration: values.ringSpringDuration, bounce: values.ringSpringBounce)
        }
    }
}

private struct MotionModifier<Value: Equatable>: ViewModifier {
    let token: MotionToken
    let value: Value
    @Environment(\.designValues) private var designValues
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(
            Motion.animation(token, values: designValues, reduceMotion: reduceMotion),
            value: value
        )
    }
}

extension View {
    /// Animates changes of `value` with a motion token, honoring Reduce Motion and DEBUG tuning.
    func motion<Value: Equatable>(_ token: MotionToken, value: Value) -> some View {
        modifier(MotionModifier(token: token, value: value))
    }
}
