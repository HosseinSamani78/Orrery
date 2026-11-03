import XCTest
import OrreryCore

final class IntervalTimerTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    // "Work" 10 min then "Rest" 5 min, repeating every 15 min.
    private func makeTimer() -> IntervalTimer {
        IntervalTimer(name: "Sprints", phases: [
            IntervalPhase(name: "Work", duration: 10 * 60),
            IntervalPhase(name: "Rest", duration: 5 * 60),
        ])
    }

    func testStartsIdleInTheFirstPhase() {
        let timer = makeTimer()

        XCTAssertEqual(timer.type, .interval)
        XCTAssertEqual(timer.status, .idle)
        XCTAssertEqual(timer.phase.name, "Work")
        XCTAssertEqual(timer.phaseIndex, 0)
        XCTAssertEqual(timer.remaining(at: later(60)), 10 * 60)
    }

    func testPhasesAdvanceInOrderAndWrapAround() {
        let timer = makeTimer()
        timer.start(at: t0)

        XCTAssertEqual(timer.remaining(at: later(60)), 9 * 60, accuracy: 0.001)

        XCTAssertEqual(timer.update(at: later(600)).map(\.phase), ["Work"])
        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.phase.name, "Rest")
        XCTAssertEqual(timer.remaining(at: later(600)), 5 * 60, accuracy: 0.001)

        XCTAssertEqual(timer.update(at: later(900)).map(\.phase), ["Rest"])
        XCTAssertEqual(timer.phase.name, "Work", "the cycle repeats")
    }

    func testLateUpdateCatchesUpThroughEveryElapsedPhase() {
        let timer = makeTimer()
        timer.start(at: t0)

        // Five phases have ended and a sixth ends exactly at 45 min; the first phase is live again.
        let entries = timer.update(at: later(45 * 60))

        XCTAssertEqual(entries.map(\.phase), ["Work", "Rest", "Work", "Rest", "Work", "Rest"])
        XCTAssertEqual(entries.map(\.completedAt), [
            later(600), later(900), later(1500), later(1800), later(2400), later(2700),
        ])
        XCTAssertEqual(timer.phase.name, "Work")
        XCTAssertEqual(timer.remaining(at: later(45 * 60)), 10 * 60, accuracy: 0.001)
    }

    func testHistoryEntryDescribesTheCompletedPhase() {
        let timer = makeTimer()
        timer.start(at: t0)

        let entry = timer.update(at: later(600)).first
        XCTAssertEqual(entry?.timerID, timer.id)
        XCTAssertEqual(entry?.timerName, "Sprints")
        XCTAssertEqual(entry?.timerType, .interval)
        XCTAssertEqual(entry?.startedAt, t0)
        XCTAssertEqual(entry?.completedAt, later(600))
        XCTAssertEqual(entry?.plannedDuration, 10 * 60)
        XCTAssertEqual(entry?.elapsed, 10 * 60)
        XCTAssertEqual(entry?.phase, "Work")

        XCTAssertTrue(timer.update(at: later(600)).isEmpty, "a phase records history exactly once")
    }

    func testPauseFreezesThePhaseAndResumeShiftsTheDeadline() {
        let timer = makeTimer()
        timer.start(at: t0)
        timer.pause(at: later(300))

        XCTAssertEqual(timer.status, .paused)
        XCTAssertEqual(timer.remaining(at: later(1000)), 5 * 60, accuracy: 0.001)

        timer.resume(at: later(1000))
        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.remaining(at: later(1000)), 5 * 60, accuracy: 0.001)

        XCTAssertTrue(timer.update(at: later(1299)).isEmpty)
        XCTAssertEqual(timer.update(at: later(1300)).map(\.phase), ["Work"])
        XCTAssertEqual(timer.phase.name, "Rest")
    }

    func testPauseAfterTheDeadlineIsIgnored() {
        let timer = makeTimer()
        timer.start(at: t0)
        timer.pause(at: later(601))

        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.update(at: later(601)).map(\.phase), ["Work"])
    }

    func testResetReturnsToTheFirstPhase() {
        let timer = makeTimer()
        timer.start(at: t0)
        _ = timer.update(at: later(900))
        XCTAssertEqual(timer.phase.name, "Work")
        XCTAssertEqual(timer.phaseIndex, 0)

        _ = timer.update(at: later(1500))
        XCTAssertEqual(timer.phase.name, "Rest")
        XCTAssertEqual(timer.phaseIndex, 1)

        timer.reset()

        XCTAssertEqual(timer.status, .idle)
        XCTAssertEqual(timer.phase.name, "Work")
        XCTAssertEqual(timer.phaseIndex, 0)
        XCTAssertEqual(timer.remaining(at: later(1500)), 10 * 60)

        timer.start(at: later(1500))
        XCTAssertEqual(timer.update(at: later(1500 + 600)).map(\.phase), ["Work"])
    }

    func testASinglePhaseRepeatsItself() {
        let timer = IntervalTimer(phases: [IntervalPhase(name: "Breathe", duration: 60)])
        timer.start(at: t0)

        let entries = timer.update(at: later(180))
        XCTAssertEqual(entries.map(\.phase), ["Breathe", "Breathe", "Breathe"])
        XCTAssertEqual(timer.remaining(at: later(180)), 60, accuracy: 0.001)
    }
}

final class TimerStoreIntervalTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testStoreRecordsEveryCompletedPhase() {
        let store = TimerStore()
        let interval = IntervalTimer(name: "Sprints", phases: [
            IntervalPhase(name: "Work", duration: 10 * 60),
            IntervalPhase(name: "Rest", duration: 5 * 60),
        ])
        store.add(interval)
        interval.start(at: t0)

        store.update(at: later(15 * 60))

        XCTAssertEqual(store.history.map(\.phase), ["Work", "Rest"])
        XCTAssertEqual(store.history.map(\.timerType), [.interval, .interval])
        XCTAssertEqual(store.timers.first?.status, .running)
    }
}
