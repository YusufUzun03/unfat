import SwiftData
import SwiftUI

/// Number and detail text for food rows. Units ("g", "kcal") are symbols, not prose.
enum FoodFormat {
    static func number(_ value: Double, fractionDigits: Int = 0) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }

    static func number(_ value: Double, fractionDigits: ClosedRange<Int>) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }

    /// Secondary line of a timeline row: "1,5 kase · 375 g", "250 g"; nil for quick-kcal entries.
    static func entryDetail(_ entry: FoodEntry) -> String? {
        guard entry.source != .quickAdd else { return nil }
        let grams = number(entry.grams, fractionDigits: 0...1)
        if let label = entry.servingLabel, !label.isEmpty, let count = entry.servingCount {
            return "\(number(count, fractionDigits: 0...2)) \(label) · \(grams) g"
        }
        return "\(grams) g"
    }

    /// Secondary line of a food in a list: "1 kase · 158 kcal" (first serving, or 100 g).
    static func defaultPortionDetail(_ food: LoggableFood) -> String {
        let unit = food.portionUnits[0]
        let kcal = number(food.nutrients(forGrams: unit.gramsPerUnit).kcal)
        let kcalText = String(localized: "\(kcal) kcal")
        return "\(unit.chipTitle) · \(kcalText)"
    }
}

/// Row of a food in the add sheet: name, and kcal per default serving as secondary text.
struct FoodChoiceRow: View {
    let food: LoggableFood

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(food.name)
                .lineLimit(2)
            Text(FoodFormat.defaultPortionDetail(food))
                .font(.footnote)
                .foregroundStyle(Palette.secondaryLabel)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Label of an action row (icon in the accent color, text in the primary label color).
struct AddActionLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(Palette.label)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.accent)
        }
    }
}

/// "Saat" row with a compact time picker; the day part of the bound date is kept.
struct EntryTimeRow: View {
    @Binding var date: Date

    var body: some View {
        DatePicker("Saat", selection: $date, displayedComponents: .hourAndMinute)
            .frame(minHeight: 44)
    }
}

/// Rounded container for rows on the editor screens (grouped background look).
struct EditorCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.container, style: .continuous)
                    .fill(Palette.secondaryGroupedBackground)
            )
    }
}

/// Whether an editor creates a new entry or edits an existing one.
enum EntryEditMode {
    case add
    case edit(FoodEntry)

    var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }
}

/// Rewrites the widget snapshot after the day's entries changed.
@MainActor
func refreshWidgetSnapshot(_ context: ModelContext) {
    WidgetSnapshotWriter.update(context: context)
}
