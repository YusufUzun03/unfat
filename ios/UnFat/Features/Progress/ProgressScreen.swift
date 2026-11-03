import Charts
import SwiftData
import SwiftUI
import UnFatCore

// Named ProgressScreen to avoid clashing with SwiftUI.ProgressView.
struct ProgressScreen: View {
    @State private var range: ProgressRange

    init(initialRange: ProgressRange = .days30) {
        _range = State(initialValue: initialRange)
    }

    var body: some View {
        NavigationStack {
            // The content view rebuilds its bounded queries whenever the range changes.
            ProgressContent(range: $range)
                .navigationTitle("İlerleme")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Formatting shared by the Progress views

/// "12 Eki" style short date.
func progressShortDay(_ date: Date) -> String {
    date.formatted(.dateTime.day().month(.abbreviated))
}

/// Locale aware number with a fixed number of decimals.
func progressNumber(_ value: Double, digits: Int = 0) -> String {
    value.formatted(.number.precision(.fractionLength(digits)))
}

/// "82,4 kg" with one decimal, always shown.
func progressKg(_ value: Double) -> String {
    String(localized: "\(progressNumber(value, digits: 1)) kg")
}

/// Small floating callout used by chart selections.
struct ProgressCallout: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(index == 0 ? .caption.weight(.semibold) : .caption)
                    .foregroundStyle(index == 0 ? Palette.label : Palette.secondaryLabel)
            }
        }
        .roundedNumbers()
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs + 2)
        .background(Palette.secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.separator, lineWidth: 0.5))
    }
}

// MARK: - Content

private struct ProgressContent: View {
    @Binding var range: ProgressRange
    @Query private var weightRows: [WeightEntry]
    @Query private var foodRows: [FoodEntry]
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context

    @State private var showWeightSheet = false
    @State private var selectedDay: Date?
    @State private var selectedWeekDate: Date?
    @State private var acceptTick = 0

    init(range: Binding<ProgressRange>) {
        _range = range
        let start = ProgressData.dataStart(range: range.wrappedValue, now: .now)
        _weightRows = Query(
            filter: #Predicate<WeightEntry> { $0.date >= start },
            sort: \WeightEntry.date
        )
        _foodRows = Query(
            filter: #Predicate<FoodEntry> { $0.loggedAt >= start },
            sort: \FoodEntry.loggedAt
        )
    }

    private var profile: UserProfile? { profiles.first }

    private var snapshot: ProgressSnapshot {
        ProgressData.snapshot(
            weights: ProgressData.coreWeights(weightRows),
            intakes: ProgressData.intakes(foodRows),
            profile: profile.map(ProfileInputs.init),
            range: range,
            now: .now
        )
    }

    var body: some View {
        let snap = snapshot
        let rows = ProgressData.exerciseRows(sessions: sessions)
        List {
            Section {
                Picker("Aralık", selection: $range) {
                    Text("30 gün").tag(ProgressRange.days30)
                    Text("90 gün").tag(ProgressRange.days90)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            weightSection(snap)
            caloriesSection(snap)
            energySection(snap)
            recordsSection(rows)
        }
        .motion(.standard, value: range)
        .sheet(isPresented: $showWeightSheet) {
            WeightEntrySheet()
                .presentationDetents([.medium])
        }
        .sensoryFeedback(.success, trigger: acceptTick)
    }

    // MARK: Weight

    @ViewBuilder
    private func weightSection(_ snap: ProgressSnapshot) -> some View {
        Section("Kilo") {
            if let trendNow = snap.trendNowKg {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(progressKg(trendNow))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if let change = snap.trendChangeKg {
                        Text("\(snap.range.days) günde \(signedKg(change))")
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondaryLabel)
                            .contentTransition(.numericText())
                    }
                }
                .roundedNumbers()
                .accessibilityElement(children: .combine)
                weightChart(snap)
            } else {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Henüz tartı yok")
                        .font(.headline)
                    Text("İlk tartını ekleyince kilo eğilimin burada görünür.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryLabel)
                }
            }
            Button {
                showWeightSheet = true
            } label: {
                Label("Kilo ekle", systemImage: "plus")
                    .foregroundStyle(Palette.accent)
            }
        }
    }

    private func signedKg(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()))
            .replacingOccurrences(of: "-", with: "\u{2212}")
        return String(localized: "\(number) kg")
    }

    private func weightChart(_ snap: ProgressSnapshot) -> some View {
        let selected = selectedDay.flatMap { snap.nearestPoint(to: $0) }
        return Chart {
            ForEach(snap.points, id: \.day) { point in
                if let measured = point.weightKg {
                    PointMark(
                        x: .value("Gün", point.day, unit: .day),
                        y: .value("Ölçüm", measured)
                    )
                    .symbolSize(30)
                    .foregroundStyle(Palette.tertiaryLabel)
                    .accessibilityLabel(progressShortDay(point.day))
                    .accessibilityValue(progressKg(measured))
                }
                LineMark(
                    x: .value("Gün", point.day, unit: .day),
                    y: .value("Eğilim", point.trendKg)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            }
            if let selected {
                RuleMark(x: .value("Seçili", selected.day, unit: .day))
                    .foregroundStyle(Palette.separator)
                    .annotation(
                        position: .top,
                        spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        ProgressCallout(lines: weightCalloutLines(selected))
                    }
            }
        }
        .chartYScale(domain: snap.weightDomain ?? 0...1)
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartLegend(.hidden)
        .chartXSelection(value: $selectedDay)
        .frame(height: 180)
        .accessibilityLabel(Text("Kilo grafiği"))
        .accessibilityValue(weightChartSummary(snap))
    }

    private func weightCalloutLines(_ point: TrendPoint) -> [String] {
        var lines = [progressShortDay(point.day), String(localized: "Eğilim \(progressKg(point.trendKg))")]
        if let measured = point.weightKg {
            lines.append(String(localized: "Ölçüm \(progressKg(measured))"))
        }
        return lines
    }

    private func weightChartSummary(_ snap: ProgressSnapshot) -> Text {
        guard let now = snap.trendNowKg else { return Text("") }
        if let change = snap.trendChangeKg {
            return Text("Eğilim \(progressKg(now)), \(snap.range.days) günde \(signedKg(change))")
        }
        return Text("Eğilim \(progressKg(now))")
    }

    // MARK: Weekly calories

    @ViewBuilder
    private func caloriesSection(_ snap: ProgressSnapshot) -> some View {
        Section {
            if snap.weeks.isEmpty {
                Text("Henüz kayıt yok")
                    .foregroundStyle(Palette.secondaryLabel)
            } else {
                caloriesChart(snap)
            }
        } header: {
            Text("Haftalık kalori")
        } footer: {
            Text("Günlük ortalama, sadece kayıt girilen günler.")
        }
    }

    private func caloriesChart(_ snap: ProgressSnapshot) -> some View {
        let target = profile?.targetKcal ?? 0
        let selected = selectedWeekDate.flatMap { snap.week(containing: $0) }
        let top = max(target, snap.weeks.map { $0.meanKcal }.max() ?? 0) * 1.1
        return Chart {
            ForEach(snap.weeks, id: \.weekStart) { week in
                BarMark(
                    x: .value("Hafta", week.weekStart, unit: .weekOfYear),
                    y: .value("Ortalama", week.meanKcal)
                )
                .cornerRadius(4)
                .foregroundStyle(Palette.accent)
                .opacity(selected == nil || selected?.weekStart == week.weekStart ? 1 : 0.4)
                .accessibilityLabel(progressShortDay(week.weekStart))
                .accessibilityValue(WorkoutFormat.kcal(week.meanKcal))
            }
            if target > 0 {
                RuleMark(y: .value("Hedef", target))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Palette.secondaryLabel)
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        Text("Hedef")
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryLabel)
                    }
            }
            if let selected {
                RuleMark(x: .value("Seçili", selected.weekStart, unit: .weekOfYear))
                    .foregroundStyle(Color.clear)
                    .annotation(
                        position: .top,
                        spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        ProgressCallout(lines: [
                            String(localized: "\(progressShortDay(selected.weekStart)) haftası"),
                            WorkoutFormat.kcal(selected.meanKcal),
                        ])
                    }
            }
        }
        .chartYScale(domain: 0...max(top, 1))
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) {
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartLegend(.hidden)
        .chartXSelection(value: $selectedWeekDate)
        .frame(height: 180)
        .accessibilityLabel(Text("Haftalık kalori grafiği"))
        .accessibilityValue(Text("\(snap.weeks.count) hafta"))
    }

    // MARK: Energy

    @ViewBuilder
    private func energySection(_ snap: ProgressSnapshot) -> some View {
        Section("Enerji ihtiyacı") {
            switch snap.energy {
            case .needsData(let weighInDays, let loggedDays, let spanDays):
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Tahmin için en az 14 gün, 10 tartı ve 10 kayıtlı gün gerekli.")
                    Text("Şu an: \(spanDays) gün, \(weighInDays) tartı, \(loggedDays) kayıtlı gün")
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryLabel)
                }
            case .ready(let tdee, let weighIns, let loggedDays, let suggestion):
                LabeledContent("Tahmini TDEE") {
                    Text(WorkoutFormat.kcal(tdee))
                        .foregroundStyle(Palette.label)
                        .roundedNumbers()
                        .contentTransition(.numericText())
                }
                Text("Son 28 gün: \(weighIns) tartı, \(loggedDays) kayıtlı gün")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryLabel)
                if suggestion.isSignificant {
                    Text("Önerilen hedef: \(progressNumber(suggestion.suggestedKcal)) kcal")
                        .roundedNumbers()
                    Button {
                        accept(suggestion.suggestedKcal, snap: snap)
                    } label: {
                        Text("Hedefi güncelle")
                            .foregroundStyle(Palette.accent)
                    }
                } else {
                    Text("Hedefin güncel.")
                        .foregroundStyle(Palette.secondaryLabel)
                }
            }
        }
    }

    private func accept(_ kcal: Double, snap: ProgressSnapshot) {
        guard let profile, let weight = snap.trendNowKg else { return }
        do {
            try ProgressData.acceptSuggestion(kcal: kcal, weightKg: weight, profile: profile, in: context)
            refreshWidgetSnapshot(context)
            acceptTick += 1
        } catch {
            assertionFailure("Could not save the new target: \(error)")
        }
    }

    // MARK: Records

    @ViewBuilder
    private func recordsSection(_ rows: [ExerciseRow]) -> some View {
        Section("Rekorlar") {
            if rows.isEmpty {
                Text("Antrenman bitirince rekorların burada görünür.")
                    .foregroundStyle(Palette.secondaryLabel)
            } else {
                ForEach(rows) { row in
                    NavigationLink {
                        ExerciseProgressView(ref: row.ref)
                    } label: {
                        exerciseRow(row)
                    }
                }
            }
        }
    }

    private func exerciseRow(_ row: ExerciseRow) -> some View {
        let summary = row.summary
        let best = summary.bestSet
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                Text("En iyi: \(WorkoutFormat.kg(best.weightKg)) × \(best.reps) · \(progressShortDay(best.date))")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            Spacer()
            if let estimate = summary.bestEstimate {
                Text("≈ \(WorkoutFormat.kg(DisplayRounding.halfKilogram(estimate)))")
                    .font(.rowNumber)
                    .monospacedDigit()
                    .foregroundStyle(Palette.label)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
