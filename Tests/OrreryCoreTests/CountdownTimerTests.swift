import XCTest
import OrreryCore

final class CountdownTimerTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testStartsIdleWithFullDuration() {
        let timer = CountdownTimer(name: "Tea", duration: 300)
        XCTAssertEqual(timer.status, .idle)
        XCTAssertNil(timer.startedAt)
        XCTAssertEqual(timer.remaining(at: later(60)), 300)
    }

    func testRunningCountsDown() {
        let timer = CountdownTimer(duration: 300)
        timer.start(at: t0)

        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.startedAt, t0)
        XCTAssertEqual(timer.remaining(at: later(100)), 200, accuracy: 0.001)
        XCTAssertEqual(timer.remaining(at: later(1000)), 0, accuracy: 0.001)
    }

    func testPauseFreezesRemainingAndResumeContinuesFromTheFrozenPoint() {
        let timer = CountdownTimer(duration: 300)
        timer.start(at: t0)

        timer.pause(at: later(100))
        XCTAssertEqual(timer.status, .paused)
        XCTAssertEqual(timer.remaining(at: later(150)), 200, accuracy: 0.001)
        XCTAssertEqual(timer.remaining(at: later(10_000)), 200, accuracy: 0.001)

        timer.resume(at: later(10_000))
        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.remaining(at: later(10_050)), 150, accuracy: 0.001)
    }

    func testPauseAfterDeadlineIsIgnoredAndUpdateCompletesTheRun() {
        let timer = CountdownTimer(duration: 60)
        timer.start(at: t0)
        timer.pause(at: later(90))
        XCTAssertEqual(timer.status, .running)

        XCTAssertEqual(timer.update(at: later(90)).count, 1)
        XCTAssertEqual(timer.status, .completed)
    }

    func testPauseExactlyAtDeadlineIsIgnored() {
        let timer = CountdownTimer(duration: 60)
        timer.start(at: t0)
        timer.pause(at: later(60))

        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.remaining(at: later(60)), 0, accuracy: 0.001)
        XCTAssertEqual(timer.update(at: later(60)).count, 1)
    }

    func testResumeWithoutPauseIsANoOp() {
        let timer = CountdownTimer(duration: 300)
        timer.resume(at: t0)
        XCTAssertEqual(timer.status, .idle)

        timer.start(at: t0)
        timer.resume(at: later(10))
        XCTAssertEqual(timer.remaining(at: later(10)), 290, accuracy: 0.001)
    }

    func testResetReturnsToIdleAndAllowsRestarting() {
        let timer = CountdownTimer(duration: 300)
        timer.start(at: t0)
        timer.pause(at: later(100))
        timer.reset()

        XCTAssertEqual(timer.status, .idle)
        XCTAssertNil(timer.startedAt)
        XCTAssertEqual(timer.remaining(at: t0), 300)

        timer.start(at: later(500))
        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.startedAt, later(500))
    }

    func testCompletedTimerStaysCompletedUntilReset() {
        let timer = CountdownTimer(duration: 60)
        timer.start(at: t0)
        _ = timer.update(at: later(60))

        timer.start(at: later(120))
        XCTAssertEqual(timer.status, .completed)
        XCTAssertEqual(timer.startedAt, t0)

        timer.reset()
        XCTAssertEqual(timer.status, .idle)
        XCTAssertEqual(timer.remaining(at: later(120)), 60, accuracy: 0.001)
        timer.start(at: later(120))
        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.startedAt, later(120))
    }

    func testCompletionRecordsOneHistoryEntry() {
        let timer = CountdownTimer(id: UUID(), name: "Tea", duration: 300)
        timer.start(at: t0)
        timer.pause(at: later(100))
        timer.resume(at: later(400))

        XCTAssertTrue(timer.update(at: later(599)).isEmpty)
        XCTAssertEqual(timer.status, .running)

        let entry = timer.update(at: later(600)).first
        XCTAssertEqual(entry?.timerID, timer.id)
        XCTAssertEqual(entry?.timerName, "Tea")
        XCTAssertEqual(entry?.timerType, .countdown)
        XCTAssertEqual(entry?.startedAt, t0)
        XCTAssertEqual(entry?.completedAt, later(600))
        XCTAssertEqual(entry?.plannedDuration, 300)
        XCTAssertEqual(entry?.elapsed, 300)

        XCTAssertTrue(timer.update(at: later(700)).isEmpty, "a run records history exactly once")
    }

    func testUpdateBeforeStartDoesNothing() {
        let timer = CountdownTimer(duration: 60)
        XCTAssertTrue(timer.update(at: later(600)).isEmpty)
        XCTAssertEqual(timer.status, .idle)
    }
}

final class TimerStoreTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testAddAndDelete() {
        let store = TimerStore()
        let timer = CountdownTimer(duration: 60)
        store.add(timer)

        XCTAssertEqual(store.timer(id: timer.id)?.id, timer.id)

        store.delete(id: timer.id)
        XCTAssertTrue(store.timers.isEmpty)
        XCTAssertNil(store.timer(id: timer.id))
    }

    func testUpdateRecordsHistoryForEachCompletedRunOnlyOnce() {
        let store = TimerStore()
        let short = CountdownTimer(name: "Short", duration: 60)
        let long = CountdownTimer(name: "Long", duration: 600)
        store.add(short)
        store.add(long)
        short.start(at: t0)
        long.start(at: t0)

        store.update(at: later(30))
        XCTAssertTrue(store.history.isEmpty)

        store.update(at: later(60))
        XCTAssertEqual(store.history.map(\.timerName), ["Short"])
        XCTAssertEqual(store.timers.map(\.status), [.completed, .running])

        store.update(at: later(600))
        store.update(at: later(900))
        XCTAssertEqual(store.history.map(\.timerName), ["Short", "Long"])
    }
}
