#if DEBUG
import SwiftData
import SwiftUI

extension OnboardingModel {
    /// Sample input for screenshot routes. Female, 50 kg, losing 0.5 kg/week: the target lands
    /// below both the 1,200 kcal floor and BMR, so the floor footnote shows.
    static func sample() -> OnboardingModel {
        let model = OnboardingModel()
        model.sex = .female
        model.birthYear = model.currentYear - 30
        model.heightCm = 160
        model.weightText = "50"
        model.activity = .light
        model.goal = .lose
        model.weeklyRateKg = 0.5
        return model
    }
}

/// Onboarding opened at a given step with sample input.
struct OnboardingDebugView: View {
    let step: OnboardingStep
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        OnboardingFlow(model: .sample(), startingAt: step) { dismiss() }
    }
}

/// Goal editor on the fixture profile.
struct GoalEditorDebugView: View {
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    var body: some View {
        NavigationStack {
            if let profile = profiles.first {
                GoalEditorView(profile: profile, weightKg: weights.first?.kg ?? 70)
            }
        }
    }
}
#endif
