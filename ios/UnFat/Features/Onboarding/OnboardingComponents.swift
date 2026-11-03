import SwiftUI

// Turkish titles of the model enums, for the onboarding lists.

extension Sex {
    var title: LocalizedStringKey {
        switch self {
        case .female: "Kadın"
        case .male: "Erkek"
        }
    }
}

extension ActivityLevel {
    var title: LocalizedStringKey {
        switch self {
        case .sedentary: "Hareketsiz"
        case .light: "Hafif aktif"
        case .moderate: "Orta aktif"
        case .active: "Çok aktif"
        case .veryActive: "Aşırı aktif"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .sedentary: "Masa başı iş, çok az egzersiz"
        case .light: "Haftada 1-3 gün hafif egzersiz"
        case .moderate: "Haftada 3-5 gün egzersiz"
        case .active: "Haftada 6-7 gün yoğun egzersiz"
        case .veryActive: "Fiziksel iş ve düzenli antrenman"
        }
    }
}

extension WeightGoal {
    var title: LocalizedStringKey {
        switch self {
        case .lose: "Ver"
        case .maintain: "Koru"
        case .gain: "Al"
        }
    }
}

/// List row with a title, optional one-line description and an accent checkmark when selected.
struct SelectionRow: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .foregroundStyle(Palette.label)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Palette.secondaryLabel)
                    }
                }
                Spacer(minLength: Spacing.xs)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Shared chrome of the onboarding steps: large title, "n / 7" indicator, full-width primary button.
struct StepScaffold<Content: View>: View {
    let step: OnboardingStep
    let title: LocalizedStringKey
    var buttonTitle: LocalizedStringKey = "Devam"
    let isEnabled: Bool
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(Palette.groupedBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(verbatim: "\(step.number) / \(OnboardingStep.count)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Palette.secondaryLabel)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryActionButton(title: buttonTitle, action: action)
                    .disabled(!isEnabled)
                    .padding(.horizontal, Spacing.sideMargin)
                    .padding(.vertical, Spacing.xs)
                    .background(Palette.groupedBackground)
            }
    }
}

/// Permission list row: accent symbol, title with a one-line detail, and a small button that turns into
/// a secondary "done" label with a checkmark once the request ran.
struct PermissionRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let actionTitle: LocalizedStringKey
    let doneTitle: LocalizedStringKey
    let isDone: Bool
    let action: @MainActor () async -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            Spacer(minLength: Spacing.xs)
            if isDone {
                Label(doneTitle, systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryLabel)
            } else {
                Button(actionTitle) {
                    Task { await action() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Palette.accent)
            }
        }
    }
}
