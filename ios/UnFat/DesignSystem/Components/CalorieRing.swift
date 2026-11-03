import SwiftUI

/// Daily calorie ring: accent fill up to the target, then a second lap in `Palette.overTarget`
/// (never red). Center shows kcal left, or kcal over in the secondary label color.
/// Stroke is 11 pt at the reference 110 pt diameter and scales with `diameter`.
struct CalorieRing: View {
    /// Eaten kcal.
    let value: Double
    /// Target kcal.
    let target: Double
    var diameter: CGFloat = 110

    @Environment(\.designValues) private var designValues

    private static let referenceDiameter: CGFloat = 110

    private var progress: Double {
        guard target > 0 else { return 0 }
        return max(value, 0) / target
    }

    private var isOver: Bool { target > 0 && value > target }

    private var lineWidth: CGFloat {
        CGFloat(designValues.ringStroke) * diameter / Self.referenceDiameter
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round)
    }

    var body: some View {
        ZStack {
            Circle()
                .inset(by: lineWidth / 2)
                .stroke(Palette.track, lineWidth: lineWidth)
            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: min(progress, 1))
                .stroke(Palette.accent, style: strokeStyle)
                .rotationEffect(.degrees(-90))
            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: min(max(progress - 1, 0), 1))
                .stroke(Palette.overTarget, style: strokeStyle)
                .rotationEffect(.degrees(-90))
            center
                .padding(lineWidth * 1.5)
        }
        .frame(width: diameter, height: diameter)
        .motion(.ring, value: progress)
        .accessibilityElement(children: .combine)
    }

    private var center: some View {
        VStack(spacing: 0) {
            // Display-only difference; targets themselves come from UnFatCore.
            NumberRoll(value: isOver ? value - target : max(target - value, 0))
                .font(.system(size: diameter * 0.24, weight: .semibold, design: .rounded))
                .foregroundStyle(isOver ? Palette.overTarget : Palette.label)
            Group {
                if isOver {
                    Text("kcal fazla")
                } else {
                    Text("kcal kaldı")
                }
            }
            .font(.system(size: max(diameter * 0.1, 9)))
            .foregroundStyle(Palette.secondaryLabel)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

#Preview {
    @Previewable @State var value = 820.0
    VStack(spacing: Spacing.lg) {
        HStack(spacing: Spacing.lg) {
            CalorieRing(value: 0, target: 2000)
            CalorieRing(value: value, target: 2000)
        }
        HStack(spacing: Spacing.lg) {
            CalorieRing(value: 2000, target: 2000)
            CalorieRing(value: 2120, target: 2000)
        }
        CalorieRing(value: value, target: 2000, diameter: 180)
        Button(String("Change")) { value = Double.random(in: 0...2800) }
    }
}
