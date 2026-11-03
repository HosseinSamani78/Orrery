import XCTest
import OrreryCore

final class WidgetTimelineTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000)

    private func timer(
        id: UUID = UUID(),
        status: TimerStatus = .running,
        endsAt: Date? = nil,
        startedAt: Date? = nil
    ) -> WidgetTimer {
        WidgetTimer(
            id: id,
            name: "Timer",
            type: .countdown,
            status: status,
            endsAt: endsAt,
            startedAt: startedAt
        )
    }

    func testTimelineHasOneEntryNowAndOnePerUpcomingDeadline() {
        let tea = timer(endsAt: now.addingTimeInterval(300))
        let eggs = timer(endsAt: now.addingTimeInterval(120))

        let entries = WidgetTimeline.entries(for: [tea, eggs], from: now)

        XCTAssertEqual(entries.map(\.date), [
            now,
            now.addingTimeInterval(120),
            now.addingTimeInterval(300),
        ])
        XCTAssertEqual(entries[0].timers.map(\.status), [.running, .running])
        XCTAssertEqual(entries[1].timers.map(\.status), [.running, .completed])
        XCTAssertEqual(entries[2].timers.map(\.status), [.completed, .completed])
    }

    func testPastDeadlinesAndNonRunningTimersAddNoEntries() {
        let finished = timer(status: .completed, endsAt: now.addingTimeInterval(-60))
        let idle = timer(status: .idle, endsAt: now.addingTimeInterval(60))
        let paused = timer(status: .paused, endsAt: now.addingTimeInterval(120))

        let entries = WidgetTimeline.entries(for: [finished, idle, paused], from: now)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].timers.map(\.status), [.completed, .idle, .paused])
    }

    func testOpenEndedRunningTimerAddsNoDeadlineEntry() {
        let stopwatch = timer(startedAt: now.addingTimeInterval(-30))

        let entries = WidgetTimeline.entries(for: [stopwatch], from: now)

        XCTAssertEqual(entries, [WidgetTimelineEntry(date: now, timers: [stopwatch])])
    }
}
