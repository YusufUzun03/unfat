#if DEBUG
import SwiftUI

/// DEBUG screen for the `gallery-live-activity` route: the real views from `Shared/LiveActivity` in the
/// three states (resting, not resting, rest over), as a Dynamic Island (compact, minimal, expanded) and
/// as the Lock Screen banner. The island and Lock Screen frames are mocks: black, always dark.
struct LiveActivityGalleryView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Sample: Identifiable {
        let name: String
        let state: WorkoutActivityAttributes.ContentState
        var id: String { name }
    }

    private static let now = Date.now
    private static let attributes = WorkoutActivityAttributes.sample

    private let samples: [Sample] = [
        Sample(name: "Resting", state: WorkoutActivityAttributes.ContentState.sampleResting(now: LiveActivityGalleryView.now)),
        Sample(name: "Not resting", state: WorkoutActivityAttributes.ContentState.sampleNotResting()),
        Sample(name: "Rest over", state: WorkoutActivityAttributes.ContentState.sampleRestOver()),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    section("Dynamic Island, compact and minimal") {
                        ForEach(samples) { sample in
                            captioned(sample.name) {
                                HStack(spacing: Spacing.sm) {
                                    compactIsland(sample.state)
                                    minimalIsland
                                }
                            }
                        }
                    }
                    section("Lock Screen") {
                        ForEach(samples) { sample in
                            captioned(sample.name) { lockScreen(sample.state) }
                        }
                    }
                    section("Dynamic Island, expanded") {
                        ForEach(samples) { sample in
                            captioned(sample.name) { expandedIsland(sample.state) }
                        }
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Palette.groupedBackground)
            .navigationTitle(Text(verbatim: "Live Activity"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Layout helpers

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(verbatim: title)
                .font(.headline)
            content()
        }
    }

    private func captioned<Content: View>(_ name: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: name)
                .font(.footnote)
                .foregroundStyle(Palette.secondaryLabel)
            content()
        }
    }

    // MARK: - Mocks

    /// Compact island: leading mark and trailing value either side of the camera cut-out.
    private func compactIsland(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        HStack {
            WorkoutIslandCompactLeading()
            Spacer(minLength: 96)
            WorkoutIslandCompactTrailing(state: state, isStale: false)
        }
        .padding(.horizontal, Spacing.sm)
        .frame(width: 250, height: 37)
        .background(Color.black, in: Capsule())
        .environment(\.colorScheme, .dark)
    }

    private var minimalIsland: some View {
        WorkoutIslandMinimal()
            .frame(width: 37, height: 37)
            .background(Color.black, in: Circle())
            .environment(\.colorScheme, .dark)
    }

    /// Lock Screen banner on a dark wallpaper, inside the translucent card the system draws.
    private func lockScreen(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        WorkoutLiveActivityBanner(attributes: Self.attributes, state: state, isStale: false)
            .background(Color(white: 0.17), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(Spacing.xs)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .environment(\.colorScheme, .dark)
    }

    private func expandedIsland(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        VStack(spacing: Spacing.sm) {
            HStack(alignment: .top) {
                WorkoutIslandExpandedLeading(state: state)
                Spacer(minLength: Spacing.sm)
                WorkoutIslandExpandedTrailing(
                    workoutName: Self.attributes.workoutName,
                    state: state,
                    isStale: false
                )
            }
            WorkoutIslandExpandedBottom(state: state, isStale: false)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: 370)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 44, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}
#endif
