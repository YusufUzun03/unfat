import SwiftUI

/// Timeline row for a logged food: time (secondary, monospaced digits) · name · kcal right-aligned.
struct FoodEntryRow: View {
    let time: Date
    let name: String
    var detail: String?
    let kcal: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(time, format: .dateTime.hour().minute())
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Palette.secondaryLabel)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(name)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryLabel)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.xs)

            Text("\(kcal.formatted(.number.precision(.fractionLength(0)))) kcal")
                .roundedNumbers()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Column widths shared by `SetRowHeader` and `SetRow`.
private enum SetColumns {
    static let set: CGFloat = 36
    static let check: CGFloat = 32
}

/// Column titles above a list of `SetRow`s: Set · kg · Tekrar.
struct SetRowHeader: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("Set")
                .frame(width: SetColumns.set, alignment: .leading)
            Text("kg")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Tekrar")
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear
                .frame(width: SetColumns.check, height: 1)
        }
        .font(.footnote)
        .foregroundStyle(Palette.secondaryLabel)
        .accessibilityHidden(true)
    }
}

/// Workout set row: Set · kg · Reps · check circle (done = accent). Light impact on check.
/// With `onEditWeight` / `onEditReps` the kg and reps values become tap targets (keypad sheet).
struct SetRow: View {
    let number: Int
    let weightKg: Double
    let reps: Int
    let isDone: Bool
    let onEditWeight: (() -> Void)?
    let onEditReps: (() -> Void)?
    let onToggle: () -> Void

    init(
        number: Int,
        weightKg: Double,
        reps: Int,
        isDone: Bool,
        onEditWeight: (() -> Void)? = nil,
        onEditReps: (() -> Void)? = nil,
        onToggle: @escaping () -> Void
    ) {
        self.number = number
        self.weightKg = weightKg
        self.reps = reps
        self.isDone = isDone
        self.onEditWeight = onEditWeight
        self.onEditReps = onEditReps
        self.onToggle = onToggle
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(number, format: .number)
                .foregroundStyle(Palette.secondaryLabel)
                .frame(width: SetColumns.set, alignment: .leading)
            valueCell(action: onEditWeight) {
                Text(weightKg, format: .number.precision(.fractionLength(0...1)))
            }
            valueCell(action: onEditReps) {
                Text(reps, format: .number)
            }
            Button(action: onToggle) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? Palette.accent : Palette.tertiaryLabel)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: SetColumns.check)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Set tamam"))
            .accessibilityAddTraits(isDone ? .isSelected : [])
        }
        .font(.rowNumber)
        .monospacedDigit()
        .sensoryFeedback(Haptics.setChecked, trigger: isDone) { oldValue, newValue in
            !oldValue && newValue
        }
        .motion(.standard, value: isDone)
    }

    @ViewBuilder
    private func valueCell<Content: View>(action: (() -> Void)?, @ViewBuilder content: () -> Content) -> some View {
        if let action {
            Button(action: action) {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        } else {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    @Previewable @State var done = [true, false, false]
    List {
        Section {
            FoodEntryRow(time: .now, name: "Menemen", detail: "1 porsiyon · 250 g", kcal: 310)
            FoodEntryRow(time: .now, name: "Ayran", kcal: 76)
        }
        Section {
            SetRowHeader()
            ForEach(done.indices, id: \.self) { index in
                SetRow(number: index + 1, weightKg: 62.5, reps: 8, isDone: done[index]) {
                    done[index].toggle()
                }
            }
        }
    }
}
