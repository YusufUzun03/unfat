#if DEBUG
import SwiftUI

/// DEBUG sheet with sliders for motion and ring tokens. Changes apply live to every view that
/// reads `\.designValues` below the gallery (shown at the medium detent with the gallery behind it).
struct TuningPanel: View {
    @Bindable var tuning: DesignTuning
    let onReplay: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phase = false

    init(tuning: DesignTuning, onReplay: @escaping () -> Void = {}) {
        _tuning = Bindable(tuning)
        self.onReplay = onReplay
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: Spacing.lg) {
                        CalorieRing(value: phase ? 1650 : 600, target: 2000)
                        MacroBar(title: "Protein", eaten: phase ? 96 : 30, target: 120)
                    }
                    .padding(.vertical, Spacing.xs)
                    Button(String("Replay animations")) {
                        phase.toggle()
                        onReplay()
                    }
                }

                Section {
                    TuningSlider(title: "Duration", value: $tuning.springDuration, range: 0.1...1.5, step: 0.05)
                    TuningSlider(title: "Bounce", value: $tuning.springBounce, range: 0...0.6, step: 0.01)
                } header: {
                    Text(verbatim: "Standard spring")
                }

                Section {
                    TuningSlider(title: "Duration", value: $tuning.ringSpringDuration, range: 0.1...2, step: 0.05)
                    TuningSlider(title: "Bounce", value: $tuning.ringSpringBounce, range: 0...0.6, step: 0.01)
                } header: {
                    Text(verbatim: "Ring spring")
                }

                Section {
                    TuningSlider(title: "Stroke (pt at 110 pt)", value: $tuning.ringStroke, range: 4...20, step: 0.5)
                } header: {
                    Text(verbatim: "Ring")
                }

                Section {
                    Button(String("Reset to tokens")) { tuning.reset() }
                }
            }
            .environment(\.designValues, tuning.values)
            .navigationTitle(Text(verbatim: "Tuning"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TuningSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text(verbatim: title)
                Spacer()
                Text(value, format: .number.precision(.fractionLength(2)))
                    .monospacedDigit()
                    .foregroundStyle(Palette.secondaryLabel)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

#Preview {
    @Previewable @State var tuning = DesignTuning()
    TuningPanel(tuning: tuning)
}
#endif
