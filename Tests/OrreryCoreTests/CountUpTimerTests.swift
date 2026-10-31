import XCTest
import OrreryCore

final class CountUpTimerTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testStartsIdleAtZero() {
        let timer = CountUpTimer(name: "Brew")
        XCTAssertEqual(timer.status, .idle)
        XCTAssertEqual(timer.type, .countUp)
        XCTAssertNil(timer.startedAt)
        XCTAssertEqual(timer.elapsed(at: later(600)), 0)
    }

    func testRunningCountsUp() {
        let timer = CountUpTimer()
        timer.start(at: t0)

        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.startedAt, t0)
        XCTAssertEqual(timer.elapsed(at: later(100)), 100, accuracy: 0.001)
        XCTAssertEqual(timer.elapsed(at: later(10_000)), 10_000, accuracy: 0.001)
    }

    func testPauseFreezesElapsedAndResumeExcludesThePausedSpan() {
        let timer = CountUpTimer()
        timer.start(at: t0)

        timer.pause(at: later(100))
        XCTAssertEqual(timer.status, .paused)
        XCTAssertEqual(timer.elapsed(at: later(150)), 100, accuracy: 0.001)
        XCTAssertEqual(timer.elapsed(at: later(10_000)), 100, accuracy: 0.001)

        timer.resume(at: later(10_000))
        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.elapsed(at: later(10_050)), 150, accuracy: 0.001)
    }

    func testPausingTwiceOrResumingWhileRunningIsANoOp() {
        let timer = CountUpTimer()
        timer.pause(at: t0)
        XCTAssertEqual(timer.status, .idle)

        timer.start(at: t0)
        timer.pause(at: later(10))
        timer.pause(at: later(20))
        XCTAssertEqual(timer.elapsed(at: later(30)), 10, accuracy: 0.001)

        timer.resume(at: later(30))
        timer.resume(at: later(40))
        XCTAssertEqual(timer.elapsed(at: later(50)), 30, accuracy: 0.001)
    }

    func testResetReturnsToZeroAndAllowsRestarting() {
        let timer = CountUpTimer()
        timer.start(at: t0)
        timer.pause(at: later(100))
        timer.resume(at: later(200))
        timer.reset()

        XCTAssertEqual(timer.status, .idle)
        XCTAssertNil(timer.startedAt)
        XCTAssertEqual(timer.elapsed(at: later(300)), 0)

        timer.start(at: later(500))
        XCTAssertEqual(timer.elapsed(at: later(540)), 40, accuracy: 0.001)
    }

    func testNeverCompletesOnItsOwn() {
        let timer = CountUpTimer()
        timer.start(at: t0)

        XCTAssertTrue(timer.update(at: later(60)).isEmpty)
        XCTAssertTrue(timer.update(at: later(86_400)).isEmpty)
        XCTAssertEqual(timer.status, .running)
    }
}

final class TimerStoreMixedTypeTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testCountUpRunsAlongsideCountdownWithoutRecordingHistory() throws {
        let store = TimerStore()
        let countdown = CountdownTimer(name: "Tea", duration: 60)
        let countUp = CountUpTimer(name: "Brew")
        store.add(countdown)
        store.add(countUp)
        countdown.start(at: t0)
        countUp.start(at: t0)

        store.update(at: later(60))

        XCTAssertEqual(store.history.map(\.timerName), ["Tea"])
        XCTAssertEqual(store.timers.map(\.status), [.completed, .running])
        let stored = try XCTUnwrap(store.timer(id: countUp.id) as? CountUpTimer)
        XCTAssertEqual(stored.elapsed(at: later(90)), 90, accuracy: 0.001)
    }
}
