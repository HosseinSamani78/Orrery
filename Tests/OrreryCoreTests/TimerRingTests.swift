import XCTest
import OrreryCore

final class TimerRingTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testCountdownRingShrinksAsTimePassesAndFreezesWhilePaused() {
        let timer = CountdownTimer(duration: 100)

        XCTAssertEqual(timer.ring(at: later(0)).fraction, 1, accuracy: 0.001)

        timer.start(at: t0)
        let ring = timer.ring(at: later(25))
        XCTAssertEqual(ring.fraction, 0.75, accuracy: 0.001)
        XCTAssertEqual(ring.remaining, 75, accuracy: 0.001)

        timer.pause(at: later(50))
        XCTAssertEqual(timer.ring(at: later(90)).fraction, 0.5, accuracy: 0.001)
    }

    func testCompletedCountdownRingIsEmptyAndLateReadsStayClamped() {
        let timer = CountdownTimer(duration: 60)
        timer.start(at: t0)

        // Read before `update` resolves the transition.
        XCTAssertEqual(timer.ring(at: later(120)).fraction, 0, accuracy: 0.001)

        _ = timer.update(at: later(60))
        XCTAssertEqual(timer.ring(at: later(60)), TimerRing(fraction: 0, remaining: 0))
    }

    func testPomodoroRingTracksTheLivePhaseAndRefillsOnTransition() {
        let timer = PomodoroTimer(settings: PomodoroSettings(workDuration: 100, shortBreakDuration: 20))
        timer.start(at: t0)

        XCTAssertEqual(timer.ring(at: later(25)).fraction, 0.75, accuracy: 0.001)

        _ = timer.update(at: later(100))
        XCTAssertEqual(timer.phase, .shortBreak)
        XCTAssertEqual(timer.ring(at: later(100)).fraction, 1, accuracy: 0.001)
        XCTAssertEqual(timer.ring(at: later(110)).fraction, 0.5, accuracy: 0.001)
    }

    func testIntervalRingTracksTheLivePhase() {
        let timer = IntervalTimer(phases: [
            IntervalPhase(name: "Work", duration: 10),
            IntervalPhase(name: "Rest", duration: 20),
        ])
        timer.start(at: t0)

        XCTAssertEqual(timer.ring(at: later(5)).fraction, 0.5, accuracy: 0.001)

        _ = timer.update(at: later(10))
        XCTAssertEqual(timer.phase.name, "Rest")
        XCTAssertEqual(timer.ring(at: later(10)).fraction, 1, accuracy: 0.001)
        XCTAssertEqual(timer.ring(at: later(20)).fraction, 0.5, accuracy: 0.001)
    }

    func testTimersRunConcurrentlyAndEachRecordsItsOwnCompletion() {
        let store = TimerStore()
        let short = CountdownTimer(name: "Short", duration: 10)
        let long = CountdownTimer(name: "Long", duration: 20)
        let pomodoro = PomodoroTimer(
            name: "Focus",
            settings: PomodoroSettings(workDuration: 30, shortBreakDuration: 5)
        )
        let timers: [any TimerModel] = [short, long, pomodoro]
        timers.forEach {
            store.add($0)
            $0.start(at: t0)
        }

        store.update(at: later(10))
        XCTAssertEqual(store.history.map(\.timerName), ["Short"])
        XCTAssertEqual(short.status, .completed)
        XCTAssertEqual(long.status, .running)
        XCTAssertEqual(long.ring(at: later(10)).fraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(pomodoro.ring(at: later(10)).fraction, 20.0 / 30, accuracy: 0.001)

        store.update(at: later(20))
        XCTAssertEqual(store.history.map(\.timerName), ["Short", "Long"])
        XCTAssertEqual(long.status, .completed)
        XCTAssertEqual(pomodoro.status, .running)
        XCTAssertEqual(pomodoro.ring(at: later(20)).fraction, 10.0 / 30, accuracy: 0.001)
    }
}
