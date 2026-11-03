#if DEBUG
import SwiftUI

/// Gallery sections in display order. Screenshot routes start the list at a given section so every
/// component lands on some screenshot (`gallery`, `gallery-2`, `gallery-3`).
enum GallerySection: Int, CaseIterable, Hashable, Sendable {
    case ring
    case macros
    case numbers
    case chips
    case keypad
    case restTimer
    case foodRows
    case setRows

    var title: String {
        switch self {
        case .ring: "Calorie ring"
        case .macros: "Macro bars"
        case .numbers: "Number roll"
        case .chips: "Serving chips"
        case .keypad: "Keypad + primary button"
        case .restTimer: "Rest timer"
        case .foodRows: "Food entry rows"
        case .setRows: "Set rows"
        }
    }
}

/// DEBUG catalog of every design-system component in its main states, with fixture values.
/// The play button flips the demo values to show the springs; the slider button opens `TuningPanel`.
struct GalleryView: View {
    let firstSection: GallerySection
    let showsTuningOnAppear: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var tuning = DesignTuning()
    @State private var isTuningPresented = false
    @State private var phase = false
    @State private var chipSelection: String? = "kase"
    @State private var keypadText = "125"
    @State private var restInterval = Date.now...Date.now.addingTimeInterval(90)
    @State private var setsDone = [true, true, false]

    init(firstSection: GallerySection = .ring, showsTuning: Bool = false) {
        self.firstSection = firstSection
        self.showsTuningOnAppear = showsTuning
    }

    private var visibleSections: [GallerySection] {
        GallerySection.allCases.filter { $0.rawValue >= firstSection.rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleSections, id: \.self) { section in
                    Section {
                        content(for: section)
                    } header: {
                        Text(verbatim: section.title)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(verbatim: "Gallery"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        phase.toggle()
                    } label: {
                        Image(systemName: "play")
                    }
                    .accessibilityLabel(Text(verbatim: "Animate"))
                    Button {
                        isTuningPresented = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel(Text(verbatim: "Tuning"))
                }
            }
            .sheet(isPresented: $isTuningPresented) {
                TuningPanel(tuning: tuning) { phase.toggle() }
                    .presentationDetents([.medium, .large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
        }
        .environment(\.designValues, tuning.values)
        .task {
            if showsTuningOnAppear {
                isTuningPresented = true
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func content(for section: GallerySection) -> some View {
        switch section {
        case .ring: ringSection
        case .macros: macroSection
        case .numbers: numberSection
        case .chips: chipSection
        case .keypad: keypadSection
        case .restTimer: restTimerSection
        case .foodRows: foodRowSection
        case .setRows: setRowSection
        }
    }

    private var ringSection: some View {
        VStack(spacing: Spacing.lg) {
            Grid(horizontalSpacing: Spacing.xl, verticalSpacing: Spacing.md) {
                GridRow {
                    ringCell("Empty 0 / 2000", value: 0)
                    ringCell("Partial", value: phase ? 1450 : 820)
                }
                GridRow {
                    ringCell("Full 2000 / 2000", value: 2000)
                    ringCell("Over", value: phase ? 2600 : 2120)
                }
            }
            HStack(alignment: .bottom, spacing: Spacing.xl) {
                ringCell("56 pt", value: phase ? 1450 : 820, diameter: 56)
                ringCell("80 pt", value: phase ? 2600 : 2120, diameter: 80)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
    }

    private func ringCell(_ caption: String, value: Double, diameter: CGFloat = 110) -> some View {
        VStack(spacing: Spacing.xs) {
            CalorieRing(value: value, target: 2000, diameter: diameter)
            Text(verbatim: caption)
                .font(.caption)
                .foregroundStyle(Palette.secondaryLabel)
        }
    }

    @ViewBuilder
    private var macroSection: some View {
        MacroBar(title: "Protein", eaten: phase ? 96 : 52, target: 120)
        MacroBar(title: "Karbonhidrat", eaten: phase ? 205 : 180, target: 220)
        MacroBar(title: "Yağ", eaten: 70, target: 65)
        MacroBar(title: "Protein", eaten: 0, target: 120)
    }

    @ViewBuilder
    private var numberSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            NumberRoll(value: phase ? 1840 : 1265)
                .font(.heroNumber)
            Text(verbatim: "kcal")
                .foregroundStyle(Palette.secondaryLabel)
        }
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            NumberRoll(value: phase ? 64.8 : 62.5, fractionDigits: 1)
                .font(.title2)
            Text(verbatim: "kg")
                .foregroundStyle(Palette.secondaryLabel)
        }
    }

    private var chipSection: some View {
        ServingChips(
            options: [
                ServingOption(id: "g100", title: "100 g"),
                ServingOption(id: "kase", title: "1 kase"),
                ServingOption(id: "kepce", title: "1 kepçe"),
                ServingOption(id: "porsiyon", title: "1 porsiyon"),
                ServingOption(id: "dilim", title: "1 dilim"),
            ],
            selection: $chipSelection
        )
        .listRowInsets(EdgeInsets(top: Spacing.sm, leading: 0, bottom: Spacing.sm, trailing: 0))
    }

    @ViewBuilder
    private var keypadSection: some View {
        VStack(spacing: Spacing.md) {
            Text(verbatim: KeypadInput.displayText(keypadText.isEmpty ? "0" : keypadText) + " g")
                .font(.heroNumber)
                .roundedNumbers()
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .motion(.standard, value: keypadText)
            Keypad(text: $keypadText)
            PrimaryActionButton(title: "Ekle") {}
        }
        .padding(.vertical, Spacing.xs)
    }

    private var restTimerSection: some View {
        RestTimerView(
            interval: restInterval,
            onSubtract15: {
                let end = max(restInterval.lowerBound, restInterval.upperBound.addingTimeInterval(-15))
                restInterval = restInterval.lowerBound...end
            },
            onAdd15: {
                restInterval = restInterval.lowerBound...restInterval.upperBound.addingTimeInterval(15)
            },
            onSkip: {
                restInterval = Date.now...Date.now.addingTimeInterval(90)
            }
        )
        .padding(.vertical, Spacing.xs)
    }

    @ViewBuilder
    private var foodRowSection: some View {
        FoodEntryRow(time: Self.today(hour: 8, minute: 15), name: "Menemen", detail: "1 porsiyon · 250 g", kcal: 310)
        FoodEntryRow(time: Self.today(hour: 12, minute: 40), name: "Mercimek çorbası", detail: "1 kase", kcal: 182)
        FoodEntryRow(time: Self.today(hour: 12, minute: 45), name: "Ayran", kcal: 76)
        FoodEntryRow(
            time: Self.today(hour: 19, minute: 30),
            name: "Izgara tavuk, bulgur pilavı ve mevsim salata",
            detail: "1 porsiyon · 420 g",
            kcal: 1240
        )
    }

    @ViewBuilder
    private var setRowSection: some View {
        SetRowHeader()
        ForEach(setsDone.indices, id: \.self) { index in
            SetRow(number: index + 1, weightKg: index == 0 ? 60 : 62.5, reps: 8, isDone: setsDone[index]) {
                setsDone[index].toggle()
            }
        }
    }

    private static func today(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }
}

#Preview {
    GalleryView()
}
#endif
