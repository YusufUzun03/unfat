import Charts
import SwiftData
import SwiftUI
import UnFatCore

/// All-time progress of one exercise: e1RM per session, records and session history.
struct ExerciseProgressView: View {
    let ref: String
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]
    @State private var selectedDay: Date?

    var body: some View {
        let detail = ProgressData.exerciseDetail(ref: ref, sessions: sessions)
        List {
            if !detail.estimates.isEmpty {
                Section("Tahmini 1TM") {
                    estimateChart(detail)
                }
            }
            if !detail.records.isEmpty {
                Section("Rekorlar") {
                    ForEach(detail.records, id: \.kind) { record in
                        LabeledContent {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(WorkoutFormat.kg(DisplayRounding.halfKilogram(record.valueKg)))
                                    .font(.rowNumber)
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.label)
                                Text(progressShortDay(record.set.date))
                                    .font(.footnote)
                                    .foregroundStyle(Palette.secondaryLabel)
                            }
                        } label: {
                            Text(record.kind.title)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            Section("Geçmiş") {
                ForEach(detail.sessions.reversed(), id: \.day) { session in
                    LabeledContent {
                        Text("\(WorkoutFormat.kg(session.topSet.weightKg)) × \(session.topSet.reps)")
                            .font(.rowNumber)
                            .monospacedDigit()
                            .foregroundStyle(Palette.label)
                    } label: {
                        Text(progressShortDay(session.day))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle(detail.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func estimateChart(_ detail: ExerciseDetail) -> some View {
        let selected = selectedDay.flatMap { detail.nearestEstimate(to: $0) }
        return Chart {
            ForEach(detail.estimates) { item in
                LineMark(
                    x: .value("Gün", item.day, unit: .day),
                    y: .value("1TM", item.estimateKg)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
                PointMark(
                    x: .value("Gün", item.day, unit: .day),
                    y: .value("1TM", item.estimateKg)
                )
                .symbolSize(40)
                .foregroundStyle(Palette.accent)
                .accessibilityLabel(progressShortDay(item.day))
                .accessibilityValue(WorkoutFormat.kg(DisplayRounding.halfKilogram(item.estimateKg)))
            }
            if let selected {
                RuleMark(x: .value("Seçili", selected.day, unit: .day))
                    .foregroundStyle(Palette.separator)
                    .annotation(
                        position: .top,
                        spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        ProgressCallout(lines: [
                            progressShortDay(selected.day),
                            "≈ \(WorkoutFormat.kg(DisplayRounding.halfKilogram(selected.estimateKg)))",
                        ])
                    }
            }
        }
        .chartYScale(domain: detail.estimateDomain ?? 0...1)
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartLegend(.hidden)
        .chartXSelection(value: $selectedDay)
        .frame(height: 180)
        .accessibilityLabel(Text("Tahmini 1TM grafiği"))
        .accessibilityValue(Text("\(detail.estimates.count) antrenman"))
    }
}
