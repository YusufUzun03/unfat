import SwiftData
import SwiftUI
import UIKit

/// The onboarding `NavigationStack`: six pushed steps, saved on the last one.
struct OnboardingFlow: View {
    @State private var model: OnboardingModel
    @State private var path: [OnboardingStep]
    private let onFinish: () -> Void

    /// `step` opens the flow at that step (DEBUG routes); back navigation still works.
    init(model: OnboardingModel, startingAt step: OnboardingStep = .sex, onFinish: @escaping () -> Void) {
        _model = State(initialValue: model)
        _path = State(initialValue: OnboardingStep.allCases.filter { $0.rawValue > 0 && $0.rawValue <= step.rawValue })
        self.onFinish = onFinish
    }

    /// Fresh flow for first launch; the root gate dismisses it once the profile is saved.
    init() {
        self.init(model: OnboardingModel(), onFinish: {})
    }

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingStepView(step: .sex, model: model, advance: advance, finish: onFinish)
                .navigationDestination(for: OnboardingStep.self) { step in
                    OnboardingStepView(step: step, model: model, advance: advance, finish: onFinish)
                }
        }
        .interactiveDismissDisabled()
    }

    private func advance(from step: OnboardingStep) {
        if let next = OnboardingStep(rawValue: step.rawValue + 1) {
            path.append(next)
        }
    }
}

private struct OnboardingStepView: View {
    let step: OnboardingStep
    let model: OnboardingModel
    let advance: (OnboardingStep) -> Void
    let finish: () -> Void

    var body: some View {
        switch step {
        case .sex: SexStep(model: model) { advance(step) }
        case .body: BodyStep(model: model) { advance(step) }
        case .weight: WeightStep(model: model) { advance(step) }
        case .activity: ActivityStep(model: model) { advance(step) }
        case .goal: GoalStep(model: model) { advance(step) }
        case .targets: TargetsStep(model: model, finish: finish)
        }
    }
}

private struct SexStep: View {
    let model: OnboardingModel
    let next: () -> Void

    var body: some View {
        StepScaffold(step: .sex, title: "Cinsiyet", isEnabled: model.sex != nil, action: next) {
            List {
                Section {
                    ForEach(Sex.allCases, id: \.self) { option in
                        SelectionRow(title: option.title, isSelected: model.sex == option) {
                            model.sex = option
                        }
                    }
                } footer: {
                    Text("Bazal metabolizma hızını hesaplamak için kullanılır (Mifflin-St Jeor denklemi).")
                }
            }
        }
    }
}

private struct BodyStep: View {
    @Bindable var model: OnboardingModel
    let next: () -> Void

    var body: some View {
        StepScaffold(step: .body, title: "Doğum yılı ve boy", isEnabled: true, action: next) {
            List {
                Section {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        VStack(spacing: Spacing.xxs) {
                            Text("Doğum yılı")
                                .font(.footnote)
                                .foregroundStyle(Palette.secondaryLabel)
                            Picker("Doğum yılı", selection: $model.birthYear) {
                                ForEach(model.birthYearRange, id: \.self) { year in
                                    Text(verbatim: String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()
                        }
                        VStack(spacing: Spacing.xxs) {
                            Text("Boy")
                                .font(.footnote)
                                .foregroundStyle(Palette.secondaryLabel)
                            Picker("Boy", selection: $model.heightCm) {
                                ForEach(OnboardingModel.heightRange, id: \.self) { height in
                                    Text(verbatim: "\(height) cm").tag(height)
                                }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()
                        }
                    }
                }
            }
        }
    }
}

private struct WeightStep: View {
    @Bindable var model: OnboardingModel
    let next: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 64

    var body: some View {
        StepScaffold(step: .weight, title: "Kilo", isEnabled: model.weightKg != nil, action: next) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(verbatim: KeypadInput.displayText(model.weightText.isEmpty ? "0" : model.weightText))
                            .font(.system(size: numberSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text("kg")
                            .font(.title2)
                            .foregroundStyle(Palette.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.lg)

                    Keypad(text: $model.weightText, maxIntegerDigits: 3, maxFractionDigits: 1)

                    Text("Günlük hedefini ve protein miktarını hesaplamak için kullanılır.")
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryLabel)
                }
                .padding(.horizontal, Spacing.sideMargin)
            }
        }
    }
}

private struct ActivityStep: View {
    let model: OnboardingModel
    let next: () -> Void

    var body: some View {
        StepScaffold(step: .activity, title: "Aktivite", isEnabled: model.activity != nil, action: next) {
            List {
                Section {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        SelectionRow(title: level.title, subtitle: level.detail, isSelected: model.activity == level) {
                            model.activity = level
                        }
                    }
                } footer: {
                    Text("Seçimin antrenmanlarını da kapsar.")
                }
            }
        }
    }
}

private struct GoalStep: View {
    let model: OnboardingModel
    let next: () -> Void

    var body: some View {
        StepScaffold(step: .goal, title: "Hedef", isEnabled: true, action: next) {
            List {
                GoalSections(model: model)
            }
        }
    }
}

private struct TargetsStep: View {
    let model: OnboardingModel
    let finish: () -> Void

    @Environment(\.modelContext) private var context
    @State private var saveFailed = false

    var body: some View {
        StepScaffold(
            step: .targets,
            title: "Hedeflerin",
            buttonTitle: "Başla",
            isEnabled: model.input != nil && model.kcal > 0,
            action: save
        ) {
            List {
                TargetSections(model: model)
            }
            .onAppear { model.refreshTargets() }
            .onChange(of: model.input) { _, _ in model.refreshTargets() }
            .targetEditSheet(model)
        }
        .alert("Kaydedilemedi", isPresented: $saveFailed) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Bilgilerin kaydedilirken bir hata oluştu. Tekrar dene.")
        }
    }

    private func save() {
        do {
            try model.save(in: context)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            finish()
        } catch {
            saveFailed = true
        }
    }
}
