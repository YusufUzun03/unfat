import SwiftData
import SwiftUI

/// Creates a `CustomFood` (name, per-100 g values, optional serving). Decimal fields accept the
/// Turkish comma. Calls `onCreated` with the saved food (the add sheet then opens the amount editor).
/// A prefilled draft (from a scan) may carry a barcode, which is shown read-only and saved with the food.
struct CustomFoodForm: View {
    let onCreated: (CustomFood) -> Void

    @Environment(\.modelContext) private var context
    @State private var draft: CustomFoodDraft
    @State private var saveFailed = false

    init(prefill: CustomFoodDraft = CustomFoodDraft(), onCreated: @escaping (CustomFood) -> Void) {
        self.onCreated = onCreated
        _draft = State(initialValue: prefill)
    }

    var body: some View {
        Form {
            Section {
                TextField("Yemek adı", text: $draft.name)
                    .textInputAutocapitalization(.sentences)
            } header: {
                Text("Ad")
            }

            if let barcode = draft.barcode {
                Section {
                    LabeledContent("Barkod") {
                        Text(verbatim: barcode)
                            .monospacedDigit()
                    }
                } footer: {
                    Text("Bu özel yemek bu barkoda bağlanır.")
                }
            }

            Section {
                valueRow("Kalori", text: $draft.kcalText, unit: "kcal")
                valueRow("Protein", text: $draft.proteinText, unit: "g")
                valueRow("Karbonhidrat", text: $draft.carbsText, unit: "g")
                valueRow("Yağ", text: $draft.fatText, unit: "g")
            } header: {
                Text("100 g başına")
            }

            Section {
                TextField("Porsiyon adı", text: $draft.servingLabel)
                valueRow("Porsiyon (g)", text: $draft.servingGramsText, unit: "g")
            } header: {
                Text("Porsiyon (isteğe bağlı)")
            } footer: {
                Text("Örnek: 1 kase = 200 g.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Özel yemek")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Kaydet", action: save)
                    .disabled(!draft.isValid)
            }
        }
        .alert("Kaydedilemedi", isPresented: $saveFailed) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Bilgilerin kaydedilirken bir hata oluştu. Tekrar dene.")
        }
    }

    private func valueRow(_ title: LocalizedStringKey, text: Binding<String>, unit: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(title)
            TextField(title, text: text, prompt: Text(verbatim: "0"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
            Text(verbatim: unit)
                .foregroundStyle(Palette.secondaryLabel)
                .frame(minWidth: 32, alignment: .leading)
        }
    }

    private func save() {
        do {
            let food = try FoodLogService.createCustomFood(draft, in: context)
            onCreated(food)
        } catch {
            saveFailed = true
        }
    }
}
