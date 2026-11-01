import XCTest
import OrreryCore

final class StopwatchTimerTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testStartsIdleWithNoLaps() {
        let timer = StopwatchTimer(name: "Race")
        XCTAssertEqual(timer.status, .idle)
        XCTAssertEqual(timer.type, .stopwatch)
        XCTAssertNil(timer.startedAt)
        XCTAssertTrue(timer.laps.isEmpty)
        XCTAssertEqual(timer.elapsed(at: later(600)), 0)
    }

    func testRunningCountsUp() {
        let timer = StopwatchTimer()
        timer.start(at: t0)

        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.startedAt, t0)
        XCTAssertEqual(timer.elapsed(at: later(100)), 100, accuracy: 0.001)
    }

    func testLapsRecordLapDurationAndCumulativeSplit() {
        let timer = StopwatchTimer()
        timer.start(at: t0)

        let first = timer.recordLap(at: later(30))
        XCTAssertEqual(first?.index, 1)
        XCTAssertEqual(first?.lap, 30)
        XCTAssertEqual(first?.split, 30)

        let second = timer.recordLap(at: later(75))
        XCTAssertEqual(second?.index, 2)
        XCTAssertEqual(second?.lap, 45)
        XCTAssertEqual(second?.split, 75)

        XCTAssertEqual(timer.laps.map(\.lap), [30, 45])
        XCTAssertEqual(timer.laps.map(\.split), [30, 75])
    }

    func testLapIsIgnoredUnlessRunning() {
        let timer = StopwatchTimer()
        XCTAssertNil(timer.recordLap(at: t0))

        timer.start(at: t0)
        timer.pause(at: later(10))
        XCTAssertNil(timer.recordLap(at: later(20)))
        XCTAssertTrue(timer.laps.isEmpty)
    }

    func testPausedTimeIsExcludedFromElapsedAndLaps() throws {
        let timer = StopwatchTimer()
        timer.start(at: t0)
        _ = timer.recordLap(at: later(10))

        timer.pause(at: later(20))
        XCTAssertEqual(timer.elapsed(at: later(1000)), 20, accuracy: 0.001)

        timer.resume(at: later(1000))
        let lap = try XCTUnwrap(timer.recordLap(at: later(1030)))
        XCTAssertEqual(lap.split, 50, accuracy: 0.001)
        XCTAssertEqual(lap.lap, 40, accuracy: 0.001)
    }

    func testResetClearsLapsAndAllowsRestarting() throws {
        let timer = StopwatchTimer()
        timer.start(at: t0)
        _ = timer.recordLap(at: later(10))
        timer.reset()

        XCTAssertEqual(timer.status, .idle)
        XCTAssertNil(timer.startedAt)
        XCTAssertTrue(timer.laps.isEmpty)
        XCTAssertEqual(timer.elapsed(at: later(20)), 0)

        timer.start(at: later(100))
        let lap = try XCTUnwrap(timer.recordLap(at: later(140)))
        XCTAssertEqual(lap.index, 1)
        XCTAssertEqual(lap.split, 40, accuracy: 0.001)
    }

    func testNeverCompletesOnItsOwn() {
        let timer = StopwatchTimer()
        timer.start(at: t0)

        XCTAssertTrue(timer.update(at: later(60)).isEmpty)
        XCTAssertEqual(timer.status, .running)
    }
}

final class TimerStoreStopwatchTests: XCTestCase {
    func testStoreDoesNotRecordHistoryForAStopwatch() {
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        let store = TimerStore()
        let stopwatch = StopwatchTimer()
        store.add(stopwatch)
        stopwatch.start(at: t0)
        stopwatch.recordLap(at: t0.addingTimeInterval(10))

        store.update(at: t0.addingTimeInterval(60))

        XCTAssertTrue(store.history.isEmpty)
        XCTAssertEqual(store.timers.first?.status, .running)
    }
}
