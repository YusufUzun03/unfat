import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity of a running workout: Lock Screen banner and Dynamic Island. The views live in
/// `Shared/LiveActivity`; the app starts and updates the activity (`WorkoutLiveActivityController`).
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLiveActivityBanner(
                attributes: context.attributes,
                state: context.state,
                isStale: context.isStale
            )
            .activitySystemActionForegroundColor(WidgetPalette.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WorkoutIslandExpandedLeading(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WorkoutIslandExpandedTrailing(
                        workoutName: context.attributes.workoutName,
                        state: context.state,
                        isStale: context.isStale
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WorkoutIslandExpandedBottom(state: context.state, isStale: context.isStale)
                }
            } compactLeading: {
                WorkoutIslandCompactLeading()
            } compactTrailing: {
                WorkoutIslandCompactTrailing(state: context.state, isStale: context.isStale)
            } minimal: {
                WorkoutIslandMinimal()
            }
            .keylineTint(WidgetPalette.accent)
        }
    }
}
