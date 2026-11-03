#if DEBUG
import SwiftUI

/// DEBUG screen for the `gallery-widgets` route: the real widget views from `Shared/Widgets` at their
/// Home Screen / Lock Screen point sizes, in normal, over-target and no-target states.
struct WidgetGalleryView: View {
    @Environment(\.dismiss) private var dismiss

    private static let normal = WidgetSnapshot.sample()
    private static let over: WidgetSnapshot = {
        var snapshot = WidgetSnapshot.sample()
        snapshot.kcalEaten = 2260
        snapshot.proteinEaten = 162
        snapshot.carbsEaten = 241
        snapshot.fatEaten = 58
        return snapshot
    }()
    private static let noTarget = WidgetSnapshot(date: Calendar.current.startOfDay(for: .now))

    private let states: [(String, WidgetSnapshot)] = [
        ("Normal", Self.normal),
        ("Over target", Self.over),
        ("No target", Self.noTarget),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    ForEach(states, id: \.0) { name, snapshot in
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text(verbatim: name)
                                .font(.headline)
                            HStack(alignment: .top, spacing: Spacing.md) {
                                homeWidget(width: 170) { SmallCalorieWidgetView(snapshot: snapshot) }
                                circular(snapshot, dark: false)
                            }
                            homeWidget(width: 364) { MediumCalorieWidgetView(snapshot: snapshot) }
                        }
                    }
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text(verbatim: "Lock Screen mock")
                            .font(.headline)
                        HStack(spacing: Spacing.md) {
                            circular(Self.normal, dark: true)
                            circular(Self.over, dark: true)
                            circular(Self.noTarget, dark: true)
                        }
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Palette.groupedBackground)
            .navigationTitle(Text(verbatim: "Widgets"))
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

    /// Home Screen widget: 170 pt tall, 16 pt content margins, rounded rect background.
    private func homeWidget<Content: View>(width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(width: width, height: 170)
            .background(Palette.secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// 76 pt circular accessory widget; `dark` mocks the Lock Screen over a dark wallpaper.
    @ViewBuilder
    private func circular(_ snapshot: WidgetSnapshot, dark: Bool) -> some View {
        let widget = CircularCalorieWidgetView(snapshot: snapshot)
        if dark {
            // Lock Screen mock: always dark, whatever the app's appearance.
            widget
                .frame(width: 76, height: 76)
                .background(Color.white.opacity(0.18), in: Circle())
                .padding(Spacing.md)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .environment(\.colorScheme, .dark)
        } else {
            widget
                .frame(width: 76, height: 76)
                .background(Color.primary.opacity(0.08), in: Circle())
                .padding(Spacing.md)
        }
    }
}
#endif
