import SwiftData
import SwiftUI

/// Amount editor for one food: kcal and macro summary, serving chips, keypad, time. Adds a new
/// entry or edits an existing one. Calls `onSaved` after the entry was written (the owner shows the
/// haptic, refreshes widgets and dismisses).
struct EntryEditorView: View {
    let food: LoggableFood
    let mode: EntryEditMode
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @State private var unitID: String?
    @State private var amountText: String
    @State private var loggedAt: Date
    @State private var timeTouched = false
    @State private var saveFailed = false

    init(food: LoggableFood, mode: EntryEditMode = .add, initialUnitID: String? = nil, onSaved: @escaping () -> Void) {
        self.food = food
        self.mode = mode
        self.onSaved = onSaved

        let units = food.portionUnits
        var unit = units.first(where: { $0.kind == .serving }) ?? PortionUnit.grams
        var amount = Self.defaultAmount(for: unit)
        var time = Date.now
        switch mode {
        case .add:
            if let initialUnitID, let found = units.first(where: { $0.id == initialUnitID }) {
                unit = found
                amount = Self.defaultAmount(for: found)
            }
        case .edit(let entry):
            time = entry.loggedAt
            if let label = entry.servingLabel, let count = entry.servingCount,
               let found = units.first(where: { $0.kind == .serving && $0.label == label }) {
                unit = found
                amount = FoodLogService.canonicalAmount(count, maxFractionDigits: found.maxFractionDigits)
            } else {
                unit = .grams
                amount = FoodLogService.canonicalAmount(entry.grams, maxFractionDigits: PortionUnit.grams.maxFractionDigits)
            }
        }
        _unitID = State<String?>(initialValue: unit.id)
        _amountText = State(initialValue: amount)
        _loggedAt = State(initialValue: time)
    }

    private static func defaultAmount(for unit: PortionUnit) -> String {
        unit.kind == .grams ? "100" : "1"
    }

    private var units: [PortionUnit] { food.portionUnits }
    private var unit: PortionUnit { units.first(where: { $0.id == unitID }) ?? .grams }
    private var amount: Double { FoodLogService.amount(from: amountText) ?? 0 }
    private var grams: Double { FoodLogService.grams(amount: amount, unit: unit) }
    private var nutrients: DayTotals { food.nutrients(forGrams: grams) }
    private var canSave: Bool { amount > 0 }
    private var saveTitle: LocalizedStringKey { mode.isEditing ? "Kaydet" : "Ekle" }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                summary
                ServingChips(options: units.map(\.option), selection: $unitID)
                amountDisplay
                EditorCard {
                    EntryTimeRow(date: $loggedAt)
                }
                .padding(.horizontal, Spacing.sideMargin)
                Keypad(
                    text: $amountText,
                    maxIntegerDigits: unit.kind == .grams ? 4 : 3,
                    maxFractionDigits: unit.maxFractionDigits
                )
                .padding(.horizontal, Spacing.sideMargin)
            }
            .padding(.top, Spacing.xs)
        }
        .background(Palette.groupedBackground)
        .navigationTitle(food.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryActionButton(title: saveTitle, action: save)
                .disabled(!canSave)
                .padding(.horizontal, Spacing.sideMargin)
                .padding(.vertical, Spacing.sm)
                .background(.bar)
        }
        .onChange(of: unitID) { oldValue, newValue in
            convertAmount(from: oldValue, to: newValue)
        }
        .onChange(of: loggedAt) {
            timeTouched = true
        }
        .alert("Kaydedilemedi", isPresented: $saveFailed) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Bilgilerin kaydedilirken bir hata oluştu. Tekrar dene.")
        }
    }

    // MARK: - Pieces

    private var summary: some View {
        VStack(spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                NumberRoll(value: nutrients.kcal)
                    .font(.heroNumber)
                Text("kcal")
                    .font(.title3)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: Spacing.md) {
                macro("Protein", nutrients.protein)
                macro("Karbonhidrat", nutrients.carbs)
                macro("Yağ", nutrients.fat)
            }
            .padding(.horizontal, Spacing.sideMargin)
        }
    }

    private func macro(_ title: LocalizedStringKey, _ value: Double) -> some View {
        VStack(spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                NumberRoll(value: value, fractionDigits: 1)
                Text("g")
            }
            .font(.rowNumber)
            Text(title)
                .font(.footnote)
                .foregroundStyle(Palette.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var amountDisplay: some View {
        VStack(spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(verbatim: KeypadInput.displayText(amountText.isEmpty ? "0" : amountText))
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                Text(verbatim: unit.amountSuffix)
                    .font(.title3)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            if unit.kind != .grams {
                Text(verbatim: "= \(FoodFormat.number(grams, fractionDigits: 0...1)) g")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Palette.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    /// Keeps the total weight when the unit changes (1 kase -> 250 g).
    private func convertAmount(from oldID: String?, to newID: String?) {
        guard let old = units.first(where: { $0.id == oldID }),
              let new = units.first(where: { $0.id == newID }),
              new.gramsPerUnit > 0
        else { return }
        let totalGrams = (FoodLogService.amount(from: amountText) ?? 0) * old.gramsPerUnit
        amountText = totalGrams > 0
            ? FoodLogService.canonicalAmount(totalGrams / new.gramsPerUnit, maxFractionDigits: new.maxFractionDigits)
            : ""
    }

    private func save() {
        guard canSave else { return }
        do {
            switch mode {
            case .add:
                try FoodLogService.log(
                    food: food,
                    unit: unit,
                    amount: amount,
                    loggedAt: timeTouched ? loggedAt : .now,
                    in: context
                )
            case .edit(let entry):
                try FoodLogService.update(entry, unit: unit, amount: amount, loggedAt: loggedAt, in: context)
            }
            onSaved()
        } catch {
            saveFailed = true
        }
    }
}

/// Sheet wrapper for editing an existing entry from the timeline. Quick-kcal entries open the
/// quick-kcal editor; everything else opens the amount editor.
struct EntryEditSheet: View {
    let entry: FoodEntry
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var customFoods: [CustomFood]

    var body: some View {
        NavigationStack {
            Group {
                if entry.source == .quickAdd {
                    QuickKcalView(mode: .edit(entry), onSaved: finish)
                } else {
                    EntryEditorView(
                        food: FoodLogService.editableFood(for: entry, customFoods: customFoods),
                        mode: .edit(entry),
                        onSaved: finish
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }

    private func finish() {
        onSaved()
        dismiss()
    }
}
