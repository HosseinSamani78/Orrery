import Foundation

/// One timer as the widget sees it, snapshotted from the shared store.
public struct WidgetTimer: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let type: TimerType
    public let status: TimerStatus
    /// Deadline of a running countdown-style timer; `nil` for open-ended, idle or completed timers.
    public let endsAt: Date?
    public let startedAt: Date?

    public init(
        id: UUID,
        name: String,
        type: TimerType,
        status: TimerStatus,
        endsAt: Date?,
        startedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.status = status
        self.endsAt = endsAt
        self.startedAt = startedAt
    }

    public init(_ record: TimerRecord) {
        self.init(
            id: record.timerID,
            name: record.name,
            type: record.type,
            status: record.status,
            endsAt: record.endsAt,
            startedAt: record.startedAt
        )
    }

    /// The same timer with its run finished, as it looks after its deadline passes.
    public func completed() -> WidgetTimer {
        WidgetTimer(
            id: id,
            name: name,
            type: type,
            status: .completed,
            endsAt: endsAt,
            startedAt: startedAt
        )
    }
}

/// What the widget renders at one point on its timeline.
public struct WidgetTimelineEntry: Equatable, Sendable {
    public let date: Date
    public let timers: [WidgetTimer]

    public init(date: Date, timers: [WidgetTimer]) {
        self.date = date
        self.timers = timers
    }
}

public enum WidgetTimeline {
    /// One entry now, plus one entry per upcoming deadline. WidgetKit switches entries without a
    /// reload, so a finished timer flips to completed exactly when its `Text(_, style: .timer)` hits zero.
    public static func entries(for timers: [WidgetTimer], from now: Date) -> [WidgetTimelineEntry] {
        let deadlines = Set(
            timers.compactMap { timer -> Date? in
                guard timer.status == .running, let endsAt = timer.endsAt, endsAt > now else { return nil }
                return endsAt
            }
        ).sorted()

        var entries = [WidgetTimelineEntry(date: now, timers: timers)]
        for deadline in deadlines {
            let settled = timers.map { timer in
                guard timer.status == .running, let endsAt = timer.endsAt, endsAt <= deadline else { return timer }
                return timer.completed()
            }
            entries.append(WidgetTimelineEntry(date: deadline, timers: settled))
        }
        return entries
    }
}
