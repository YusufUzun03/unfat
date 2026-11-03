import SwiftData
import SwiftUI

/// Reusable goal + targets editor for an existing profile (the future settings screen embeds it
/// in its own navigation stack).
struct GoalEditorView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var model: OnboardingModel
    @State private var saveFailed = false

    init(profile: UserProfile, weightKg: Double) {
        self.profile = profile
        _model = State(initialValue: OnboardingModel(profile: profile, weightKg: weightKg))
    }

    var body: some View {
        List {
            GoalSections(model: model)
            TargetSections(model: model)
        }
        .navigationTitle("Hedefler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Kaydet", action: save)
            }
        }
        .onChange(of: model.input) { _, _ in model.refreshTargets() }
        .targetEditSheet(model)
        .alert("Kaydedilemedi", isPresented: $saveFailed) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Bilgilerin kaydedilirken bir hata oluştu. Tekrar dene.")
        }
    }

    private func save() {
        do {
            try model.saveGoal(to: profile, in: context)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}
