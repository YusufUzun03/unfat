import SwiftUI
import UIKit
import WidgetKit

/// Colors for the widget views. The extension has no asset catalog, so the accent (#FF6A3D, the same
/// value as the app's `AccentColor` in light and dark) is defined here, once, for app and widgets.
enum WidgetPalette {
    static let accent = Color(red: 1.0, green: 106.0 / 255.0, blue: 61.0 / 255.0)
    static let track = Color(uiColor: .tertiarySystemFill)
    /// Over-target lap and "kcal fazla" text: an opaque gray, never red (see `Palette.overTarget`).
    static let overTarget = Color(uiColor: .systemGray)
}

/// String table shared by the app and the extension (`Widgets.xcstrings`); a table of its own so it
/// never collides with the app's `Localizable.xcstrings`.
let widgetStringTable = "Widgets"

private func wholeNumber(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0)))
}

// MARK: - Ring

/// Calorie ring for widgets: accent fill up to the target, then a gray second lap. Mirrors the app's
/// `CalorieRing` (center shows kcal left, or kcal over in gray) without animation. Fills a square.
struct WidgetCalorieRing: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let lineWidth = diameter * 0.1
            ZStack {
                Circle()
                    .inset(by: lineWidth / 2)
                    .stroke(WidgetPalette.track, lineWidth: lineWidth)
                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: min(snapshot.kcalProgress, 1))
                    .stroke(WidgetPalette.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .widgetAccentable()
                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: min(max(snapshot.kcalProgress - 1, 0), 1))
                    .stroke(WidgetPalette.overTarget, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(wholeNumber(snapshot.kcalLeftOrOver))
                        .font(.system(size: diameter * 0.24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(snapshot.isOverTarget ? WidgetPalette.overTarget : Color.primary)
                    Group {
                        if snapshot.isOverTarget {
                            Text("kcal fazla", tableName: widgetStringTable)
                        } else {
                            Text("kcal kaldı", tableName: widgetStringTable)
                        }
                    }
                    .font(.system(size: max(diameter * 0.1, 9)))
                    .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(lineWidth * 1.5)
            }
            .frame(width: diameter, height: diameter)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .combine)
    }
}

/// Empty track ring with the "set a goal" label, shown while no target exists.
private struct WidgetNoTargetRing: View {
    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let lineWidth = diameter * 0.1
            ZStack {
                Circle()
                    .inset(by: lineWidth / 2)
                    .stroke(WidgetPalette.track, lineWidth: lineWidth)
                Text("Hedefini belirle", tableName: widgetStringTable)
                    .font(.system(size: max(diameter * 0.12, 10), weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .padding(lineWidth * 1.5)
            }
            .frame(width: diameter, height: diameter)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Macro row

/// Title, "eaten / target g" and a 5 pt capsule bar (accent fill, clamped at full), like the app's `MacroBar`.
private struct WidgetMacroRow: View {
    let title: LocalizedStringKey
    let eaten: Double
    let target: Double

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(max(eaten / target, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title, tableName: widgetStringTable)
                Spacer(minLength: 4)
                Text(verbatim: "\(wholeNumber(eaten)) / \(wholeNumber(target)) g")
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12))
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Capsule()
                .fill(WidgetPalette.track)
                .frame(height: 5)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(WidgetPalette.accent)
                            .frame(width: proxy.size.width * fraction)
                            .widgetAccentable()
                    }
                }
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Widget views

/// Small widget: the ring with kcal left (or over) in the center.
struct SmallCalorieWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if snapshot.hasTarget {
            WidgetCalorieRing(snapshot: snapshot)
        } else {
            WidgetNoTargetRing()
        }
    }
}

/// Medium widget: the ring on the left, three macro rows on the right.
struct MediumCalorieWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 16) {
            if snapshot.hasTarget {
                WidgetCalorieRing(snapshot: snapshot)
            } else {
                WidgetNoTargetRing()
            }
            VStack(spacing: 12) {
                WidgetMacroRow(title: "Protein", eaten: snapshot.proteinEaten, target: snapshot.proteinTarget)
                WidgetMacroRow(title: "Karbonhidrat", eaten: snapshot.carbsEaten, target: snapshot.carbsTarget)
                WidgetMacroRow(title: "Yağ", eaten: snapshot.fatEaten, target: snapshot.fatTarget)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Lock Screen circular widget: a `Gauge` with kcal left (or over) in the center. In accented and
/// vibrant rendering the system recolors it, so the accent is applied only in full color.
struct CircularCalorieWidgetView: View {
    let snapshot: WidgetSnapshot

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            if snapshot.hasTarget {
                Gauge(value: min(snapshot.kcalProgress, 1)) {
                    // Short labels: "kcal kaldı" truncates in the 76 pt gauge.
                    if snapshot.isOverTarget {
                        Text("fazla", tableName: widgetStringTable)
                    } else {
                        Text("kaldı", tableName: widgetStringTable)
                    }
                } currentValueLabel: {
                    Text(wholeNumber(snapshot.kcalLeftOrOver))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                }
            } else {
                Gauge(value: 0) {
                    Text("Hedefini belirle", tableName: widgetStringTable)
                } currentValueLabel: {
                    Text(verbatim: "--")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
        }
        .gaugeStyle(.accessoryCircular)
        .tint(renderingMode == .fullColor ? WidgetPalette.accent : Color.primary)
        .widgetAccentable()
    }
}
