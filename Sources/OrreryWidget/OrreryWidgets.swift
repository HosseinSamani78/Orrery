import OrreryCore
import SwiftUI
import WidgetKit

extension WidgetTimelineEntry: TimelineEntry {}

struct OrreryTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetTimelineEntry {
        WidgetTimelineEntry(
            date: .now,
            timers: [
                WidgetTimer(
                    id: UUID(),
                    name: "Tea",
                    type: .countdown,
                    status: .running,
                    endsAt: .now.addingTimeInterval(300),
                    startedAt: .now
                )
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetTimelineEntry) -> Void) {
        completion(WidgetTimelineEntry(date: .now, timers: loadTimers()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetTimelineEntry>) -> Void) {
        let now = Date()
        let entries = WidgetTimeline.entries(for: loadTimers(), from: now)
        // Reload after the last deadline, and periodically, to pick up board edits made in the app.
        let refresh = (entries.last?.date ?? now).addingTimeInterval(15 * 60)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func loadTimers() -> [WidgetTimer] {
        guard let store = try? BoardStore(),
              let board = try? store.boards().first else { return [] }
        // The app owns one board; showing others would surface timers the app never updates.
        return board.timers.map(WidgetTimer.init)
    }
}

struct OrreryWidgetView: View {
    let entry: WidgetTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.timers.isEmpty {
                Label("No timers", systemImage: "timer")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.timers.prefix(4)) { timer in
                    HStack(spacing: 6) {
                        Image(systemName: timer.type.symbolName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(timer.name)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        clock(timer)
                            .monospacedDigit()
                            .foregroundStyle(timer.status == .completed ? .secondary : .primary)
                    }
                    .font(.callout)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private func clock(_ timer: WidgetTimer) -> some View {
        if timer.status == .running, let endsAt = timer.endsAt {
            // The OS ticks this in place, so the widget needs no per-second reload.
            Text(endsAt, style: .timer)
        } else if timer.status == .running, let startedAt = timer.startedAt {
            Text(startedAt, style: .timer)
        } else {
            Text(timer.status.label)
        }
    }
}

struct OrreryWidget: Widget {
    static let kind = "OrreryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: OrreryTimelineProvider()) { entry in
            OrreryWidgetView(entry: entry)
        }
        .configurationDisplayName("Orrery")
        .description("Running timers at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct OrreryWidgets: WidgetBundle {
    var body: some Widget {
        OrreryWidget()
    }
}
