import SwiftData
import SwiftUI

/// "Kilo ekle" sheet: a date (not in the future) and a weight in kg. A second entry on the same day is allowed.
struct WeightEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var text: String
    @FocusState private var focused: Bool

    init(initialText: String = "") {
        _text = State(initialValue: initialText)
    }

    private var canSave: Bool {
        WeightInput.canSave(text: text, date: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Tarih", selection: $date, in: ...Date.now, displayedComponents: .date)
                    LabeledContent("Kilo") {
                        HStack(spacing: Spacing.xxs) {
                            TextField("0,0", text: $text)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focused)
                                .roundedNumbers()
                            Text("kg")
                                .foregroundStyle(Palette.secondaryLabel)
                        }
                    }
                } footer: {
                    Text("30 ile 300 kg arasında bir değer gir.")
                }
            }
            .navigationTitle("Kilo ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear { focused = text.isEmpty }
    }

    private func save() {
        guard let kg = WeightInput.parseKg(text), WeightInput.isDateAllowed(date) else { return }
        do {
            try ProgressData.addWeight(kg: kg, date: date, in: context)
            dismiss()
        } catch {
            assertionFailure("Could not save the weigh-in: \(error)")
        }
    }
}
