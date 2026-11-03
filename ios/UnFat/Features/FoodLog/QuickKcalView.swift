import SwiftData
import SwiftUI

/// Quick calorie entry: keypad for kcal, optional name (default "Hızlı kcal"), time.
/// Stored as a `quick` entry (100 g of a food with the typed kcal per 100 g, no macros).
struct QuickKcalView: View {
    let mode: EntryEditMode
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @State private var kcalText: String
    @State private var name: String
    @State private var loggedAt: Date
    @State private var timeTouched = false
    @State private var saveFailed = false

    init(mode: EntryEditMode = .add, onSaved: @escaping () -> Void) {
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .add:
            _kcalText = State(initialValue: "")
            _name = State(initialValue: "")
            _loggedAt = State(initialValue: .now)
        case .edit(let entry):
            _kcalText = State(initialValue: FoodLogService.canonicalAmount(entry.kcal, maxFractionDigits: 0))
            _name = State(initialValue: entry.name)
            _loggedAt = State(initialValue: entry.loggedAt)
        }
    }

    private var kcal: Double { FoodLogService.amount(from: kcalText) ?? 0 }
    private var canSave: Bool { kcal > 0 }
    private var saveTitle: LocalizedStringKey { mode.isEditing ? "Kaydet" : "Ekle" }

    private var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Hızlı kcal") : trimmed
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(verbatim: KeypadInput.displayText(kcalText.isEmpty ? "0" : kcalText))
                        .font(.heroNumber)
                        .monospacedDigit()
                    Text("kcal")
                        .font(.title3)
                        .foregroundStyle(Palette.secondaryLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.sm)
                .accessibilityElement(children: .combine)

                EditorCard {
                    VStack(spacing: 0) {
                        TextField("Ad", text: $name, prompt: Text("Hızlı kcal"))
                            .frame(minHeight: 44)
                            .submitLabel(.done)
                        Divider()
                        EntryTimeRow(date: $loggedAt)
                    }
                }
                .padding(.horizontal, Spacing.sideMargin)

                Keypad(text: $kcalText, maxIntegerDigits: 5, maxFractionDigits: 0)
                    .padding(.horizontal, Spacing.sideMargin)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.groupedBackground)
        .navigationTitle("Hızlı kcal")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryActionButton(title: saveTitle, action: save)
                .disabled(!canSave)
                .padding(.horizontal, Spacing.sideMargin)
                .padding(.vertical, Spacing.sm)
                .background(.bar)
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

    private func save() {
        guard canSave else { return }
        do {
            switch mode {
            case .add:
                try FoodLogService.logQuick(
                    name: resolvedName,
                    kcal: kcal,
                    loggedAt: timeTouched ? loggedAt : .now,
                    in: context
                )
            case .edit(let entry):
                try FoodLogService.updateQuick(entry, name: resolvedName, kcal: kcal, loggedAt: loggedAt, in: context)
            }
            onSaved()
        } catch {
            saveFailed = true
        }
    }
}
