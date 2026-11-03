import AppIntents
import SwiftUI

// Views of the workout Live Activity. They live in Shared so the widget extension renders them and
// the debug gallery (`gallery-live-activity`) shows the very same views. Nothing here reads the
// database or the rest timer: every view gets the `ContentState` and `ActivityViewContext.isStale`.

private typealias WorkoutState = WorkoutActivityAttributes.ContentState

// MARK: - Building blocks

/// "Set 3 / 4"; nothing while the workout has no sets.
private struct WorkoutSetLabel: View {
    let state: WorkoutState

    var body: some View {
        if state.setCount > 0 {
            Text("Set \(state.setNumber) / \(state.setCount)", tableName: widgetStringTable)
                .fontDesign(.rounded)
                .monospacedDigit()
        }
    }
}

/// Line above the exercise name: the workout while idle, "Dinlenme" while resting, "Dinlenme bitti"
/// (in accent) once the rest ran out.
private struct WorkoutPhaseCaption: View {
    let phase: WorkoutRestPhase
    let workoutName: String

    var body: some View {
        switch phase {
        case .notResting:
            Text(verbatim: workoutName)
                .foregroundStyle(.secondary)
        case .resting:
            Text("Dinlenme", tableName: widgetStringTable)
                .foregroundStyle(.secondary)
        case .over:
            Text("Dinlenme bitti", tableName: widgetStringTable)
                .foregroundStyle(WidgetPalette.accent)
        }
    }
}

/// Self-updating countdown: the system redraws it, the app never wakes up for it.
private struct WorkoutRestCountdown: View {
    let interval: ClosedRange<Date>
    let font: Font

    var body: some View {
        Text(timerInterval: interval, countsDown: true, showsHours: false)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(WidgetPalette.accent)
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

private struct WorkoutRestProgress: View {
    let interval: ClosedRange<Date>

    var body: some View {
        ProgressView(timerInterval: interval, countsDown: true) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(WidgetPalette.accent)
    }
}

/// Capsule label of an intent button: accent text on a light accent fill, or white on accent for the
/// one prominent action ("Set tamam").
private struct WorkoutButtonLabel: View {
    let title: LocalizedStringKey
    let isProminent: Bool

    var body: some View {
        Text(title, tableName: widgetStringTable)
            .font(.subheadline.weight(.semibold))
            .fontDesign(.rounded)
            .lineLimit(1)
            .foregroundStyle(isProminent ? Color.white : WidgetPalette.accent)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
                isProminent ? WidgetPalette.accent : WidgetPalette.accent.opacity(0.16),
                in: Capsule()
            )
    }
}

/// The buttons under the banner and in the expanded island: "+15 sn" and "Geç" while a rest runs,
/// "Set tamam" otherwise (hidden once every set is done).
private struct WorkoutActionRow: View {
    let phase: WorkoutRestPhase
    let canCompleteSet: Bool

    var body: some View {
        HStack(spacing: 8) {
            switch phase {
            case .resting:
                Button(intent: AddRestTimeIntent()) {
                    WorkoutButtonLabel(title: "+15 sn", isProminent: false)
                }
                Button(intent: SkipRestIntent()) {
                    WorkoutButtonLabel(title: "Geç", isProminent: false)
                }
            case .notResting, .over:
                if canCompleteSet {
                    Button(intent: CompleteSetIntent()) {
                        WorkoutButtonLabel(title: "Set tamam", isProminent: true)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lock Screen banner

/// Lock Screen / notification banner of the workout Live Activity.
struct WorkoutLiveActivityBanner: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let phase = state.restPhase(isStale: isStale)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    WorkoutPhaseCaption(phase: phase, workoutName: attributes.workoutName)
                        .font(.footnote)
                    Text(verbatim: state.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                    WorkoutSetLabel(state: state)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if case .resting(let interval) = phase {
                    WorkoutRestCountdown(
                        interval: interval,
                        font: .system(.largeTitle, design: .rounded, weight: .semibold)
                    )
                    .frame(maxWidth: 140, alignment: .trailing)
                }
            }
            if case .resting(let interval) = phase {
                WorkoutRestProgress(interval: interval)
            }
            WorkoutActionRow(phase: phase, canCompleteSet: state.canCompleteSet)
        }
        .padding(16)
    }
}

// MARK: - Dynamic Island

/// Compact leading: the app mark, in accent.
struct WorkoutIslandCompactLeading: View {
    var body: some View {
        Image(systemName: "dumbbell.fill")
            .foregroundStyle(WidgetPalette.accent)
    }
}

/// Compact trailing: the countdown while resting, "0:00" once it ran out, otherwise "2/4".
struct WorkoutIslandCompactTrailing: View {
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        switch state.restPhase(isStale: isStale) {
        case .resting(let interval):
            WorkoutRestCountdown(interval: interval, font: .system(.subheadline, design: .rounded, weight: .semibold))
                .frame(maxWidth: 52, alignment: .trailing)
        case .over:
            Text(verbatim: "0:00")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(WidgetPalette.accent)
        case .notResting:
            Text(verbatim: "\(state.setNumber)/\(state.setCount)")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(WidgetPalette.accent)
        }
    }
}

/// Minimal (another activity owns the island): just the mark.
struct WorkoutIslandMinimal: View {
    var body: some View {
        Image(systemName: "dumbbell.fill")
            .foregroundStyle(WidgetPalette.accent)
    }
}

/// Expanded leading: exercise name and set.
struct WorkoutIslandExpandedLeading: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: state.exerciseName)
                .font(.headline)
                .lineLimit(1)
            WorkoutSetLabel(state: state)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// Expanded trailing: the countdown while resting, "Dinlenme bitti" once it ran out, otherwise the
/// workout name.
struct WorkoutIslandExpandedTrailing: View {
    let workoutName: String
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let phase = state.restPhase(isStale: isStale)
        switch phase {
        case .resting(let interval):
            WorkoutRestCountdown(interval: interval, font: .system(.title, design: .rounded, weight: .semibold))
                .frame(maxWidth: 110, alignment: .trailing)
        case .over, .notResting:
            WorkoutPhaseCaption(phase: phase, workoutName: workoutName)
                .font(.subheadline)
                .lineLimit(1)
        }
    }
}

/// Expanded bottom: the progress bar while resting, then the buttons.
struct WorkoutIslandExpandedBottom: View {
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let phase = state.restPhase(isStale: isStale)
        VStack(spacing: 10) {
            if case .resting(let interval) = phase {
                WorkoutRestProgress(interval: interval)
            }
            WorkoutActionRow(phase: phase, canCompleteSet: state.canCompleteSet)
        }
    }
}
