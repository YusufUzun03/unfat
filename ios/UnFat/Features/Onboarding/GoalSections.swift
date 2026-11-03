import SwiftUI

/// Goal direction (Ver / Koru / Al) and, unless maintaining, the weekly rate chips.
/// Returns list `Section`s: embed it in a `List`.
struct GoalSections: View {
    @Bindable var model: OnboardingModel
    @State private var rateID: String?

    init(model: OnboardingModel) {
        self.model = model
        _rateID = State(initialValue: Self.id(for: model.weeklyRateKg))
    }

    var body: some View {
        Section {
            Picker("Hedef", selection: $model.goal) {
                ForEach(WeightGoal.allCases, id: \.self) { goal in
                    Text(goal.title).tag(goal)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } footer: {
            if model.goal == .maintain {
                Text("Günlük hedefin, harcadığın enerjiye eşit olur.")
            }
        }

        if model.goal != .maintain {
            Section {
                ServingChips(options: Self.options, selection: $rateID)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Haftalık hız")
            } footer: {
                if model.isRateCapped {
                    Text("Haftalık en fazla \(Self.format(model.maxWeeklyRateKg)) kg önerilir")
                }
            }
            .onChange(of: rateID) { _, newValue in
                if let newValue, let rate = Double(newValue) {
                    model.weeklyRateKg = rate
                }
            }
        }
    }

    private static var options: [ServingOption] {
        OnboardingModel.rateOptions.map { rate in
            ServingOption(id: id(for: rate), title: "\(format(rate)) kg")
        }
    }

    private static func id(for rate: Double) -> String {
        String(rate)
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

/// Hero kcal, the three macro rows and the floor warning. Each value opens the keypad sheet
/// (attach `.targetEditSheet(model)` to the enclosing view). Returns list `Section`s.
struct TargetSections: View {
    @Bindable var model: OnboardingModel

    private static let macroFields: [TargetField] = [.protein, .carbs, .fat]

    var body: some View {
        Section {
            Button {
                model.editingField = .kcal
            } label: {
                VStack(spacing: Spacing.xxs) {
                    NumberRoll(value: model.kcal)
                        .font(.heroNumber)
                        .foregroundStyle(Palette.label)
                    Text("kcal / gün")
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }

        Section {
            ForEach(Self.macroFields) { field in
                Button {
                    model.editingField = field
                } label: {
                    HStack {
                        Text(field.title)
                            .foregroundStyle(Palette.label)
                        Spacer(minLength: Spacing.xs)
                        Text("\(Int(model.value(for: field).rounded())) g")
                            .roundedNumbers()
                            .foregroundStyle(Palette.label)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        } footer: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Değerlere dokunarak düzenleyebilirsin.")
                if model.floor?.hasWarning == true {
                    Label {
                        Text("Bu hedef, genel olarak önerilen en düşük alımın ya da bazal metabolizma hızının altında. İstersen yine de kullanabilirsin.")
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                    }
                    .foregroundStyle(Palette.secondaryLabel)
                }
            }
        }
    }
}

/// Keypad sheet for one target value. Editing kcal recomputes the macros; editing a macro keeps the rest.
struct TargetEditSheet: View {
    let model: OnboardingModel
    let field: TargetField

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(model: OnboardingModel, field: TargetField) {
        self.model = model
        self.field = field
        _text = State(initialValue: String(Int(model.value(for: field).rounded())))
    }

    private var value: Int? { Int(text) }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(verbatim: text.isEmpty ? "0" : text)
                        .font(.heroNumber)
                        .roundedNumbers()
                    Text(field == .kcal ? "kcal" : "g")
                        .font(.title3)
                        .foregroundStyle(Palette.secondaryLabel)
                }
                Spacer(minLength: 0)
                Keypad(text: $text, maxIntegerDigits: field == .kcal ? 5 : 4, maxFractionDigits: 0)
                PrimaryActionButton(title: "Tamam") {
                    if let value {
                        model.setValue(Double(value), for: field)
                        dismiss()
                    }
                }
                .disabled(value == nil)
            }
            .padding(Spacing.sideMargin)
            .background(Palette.groupedBackground)
            .navigationTitle(field.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }
}

private struct TargetEditSheetModifier: ViewModifier {
    @Bindable var model: OnboardingModel

    func body(content: Content) -> some View {
        content.sheet(item: $model.editingField) { field in
            TargetEditSheet(model: model, field: field)
        }
    }
}

extension View {
    /// Presents the keypad sheet when a target row sets `model.editingField`.
    func targetEditSheet(_ model: OnboardingModel) -> some View {
        modifier(TargetEditSheetModifier(model: model))
    }
}
