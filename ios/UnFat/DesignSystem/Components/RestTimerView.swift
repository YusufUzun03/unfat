import SwiftUI

/// In-app rest block: countdown in accent, progress bar, and -15 / +15 / skip buttons.
/// The countdown and bar are driven by the system from `interval`, so no timer runs in the view.
struct RestTimerView: View {
    /// Rest start ... rest end.
    let interval: ClosedRange<Date>
    let onSubtract15: (() -> Void)?
    let onAdd15: () -> Void
    let onSkip: () -> Void

    init(
        interval: ClosedRange<Date>,
        onSubtract15: (() -> Void)? = nil,
        onAdd15: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.interval = interval
        self.onSubtract15 = onSubtract15
        self.onAdd15 = onAdd15
        self.onSkip = onSkip
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(timerInterval: interval, countsDown: true, showsHours: false)
                .font(.heroNumber)
                .monospacedDigit()
                .foregroundStyle(Palette.accent)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            ProgressView(timerInterval: interval, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(Palette.accent)

            HStack(spacing: Spacing.xs) {
                if let onSubtract15 {
                    button("−15 sn", action: onSubtract15)
                }
                button("+15 sn", action: onAdd15)
                button("Geç", action: onSkip)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
    }

    private func button(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .roundedNumbers()
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    @Previewable @State var interval = Date.now...Date.now.addingTimeInterval(90)
    RestTimerView(
        interval: interval,
        onSubtract15: {
            let end = max(interval.lowerBound, interval.upperBound.addingTimeInterval(-15))
            interval = interval.lowerBound...end
        },
        onAdd15: { interval = interval.lowerBound...interval.upperBound.addingTimeInterval(15) },
        onSkip: { interval = Date.now...Date.now.addingTimeInterval(90) }
    )
    .padding(Spacing.sideMargin)
}
