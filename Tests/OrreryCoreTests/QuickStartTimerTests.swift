import XCTest
import OrreryCore

final class QuickStartTimerTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testStartsImmediatelyWithDefaultDuration() {
        let timer = QuickStartTimer.start(at: t0)

        XCTAssertEqual(timer.type, .quickStart)
        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.startedAt, t0)
        XCTAssertEqual(timer.duration, QuickStartTimer.defaultDuration)
        XCTAssertEqual(
            timer.remaining(at: later(60)),
            QuickStartTimer.defaultDuration - 60,
            accuracy: 0.001
        )
    }

    func testAcceptsCustomDuration() {
        let timer = QuickStartTimer.start(duration: 60, at: t0)

        XCTAssertEqual(timer.duration, 60)
        XCTAssertEqual(timer.remaining(at: later(15)), 45, accuracy: 0.001)
    }

    func testCompletionRecordsHistoryAsQuickStart() {
        let store = TimerStore()
        let timer = store.quickStart(at: t0, duration: 60)

        XCTAssertEqual(store.timers.count, 1)
        store.update(at: later(60))

        let entry = store.history.first
        XCTAssertEqual(entry?.timerID, timer.id)
        XCTAssertEqual(entry?.timerType, .quickStart)
        XCTAssertEqual(entry?.elapsed, 60)
    }

    func testTypeSurvivesPersistenceRoundTrip() throws {
        let store = try BoardStore(isStoredInMemoryOnly: true)
        let board = try store.createBoard(named: "Kitchen")
        board.record(QuickStartTimer.start(duration: 60, at: t0))
        try store.save()

        XCTAssertEqual(board.liveTimers.first?.type, .quickStart)
    }
}
