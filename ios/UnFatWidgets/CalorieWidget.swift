import SwiftUI
import WidgetKit

/// One entry per moment the widget changes: the snapshot is already rollover-adjusted for `date`.
struct CalorieEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Reads the App Group snapshot (never the database). The timeline holds the current state and a
/// second entry at the next midnight, so a new day shows zero eaten even if the app never runs.
struct CalorieProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalorieEntry {
        CalorieEntry(date: .now, snapshot: .sample())
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorieEntry) -> Void) {
        if context.isPreview {
            completion(CalorieEntry(date: .now, snapshot: .sample()))
        } else {
            completion(Self.entry(at: .now, stored: WidgetSnapshotStore.read()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorieEntry>) -> Void) {
        let now = Date.now
        let stored = WidgetSnapshotStore.read()
        let midnight = WidgetSnapshotDisplay.nextMidnight(after: now)
        let entries = [
            Self.entry(at: now, stored: stored),
            Self.entry(at: midnight, stored: stored),
        ]
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private static func entry(at date: Date, stored: WidgetSnapshot?) -> CalorieEntry {
        CalorieEntry(date: date, snapshot: WidgetSnapshotDisplay.snapshot(stored: stored, now: date))
    }
}

struct CalorieWidgetEntryView: View {
    let entry: CalorieEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularCalorieWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .systemMedium:
            MediumCalorieWidgetView(snapshot: entry.snapshot)
                .containerBackground(.background, for: .widget)
        default:
            SmallCalorieWidgetView(snapshot: entry.snapshot)
                .containerBackground(.background, for: .widget)
        }
    }
}

struct CalorieWidget: Widget {
    static let kind = "CalorieWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CalorieProvider()) { entry in
            CalorieWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("Kalori", table: widgetStringTable))
        .description(LocalizedStringResource("Bugünkü kalori ve makroların.", table: widgetStringTable))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
