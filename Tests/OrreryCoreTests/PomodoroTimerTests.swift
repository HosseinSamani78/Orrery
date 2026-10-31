import XCTest
import OrreryCore

final class PomodoroTimerTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    // Defaults: 25 min work, 5 min short break, 15 min long break, long break every 4th work phase.
    private let workEnd: TimeInterval = 25 * 60
    private let shortBreakEnd = 30 * 60.0
    private let work2End = 55 * 60.0
    private let shortBreak2End = 60 * 60.0
    private let work3End = 85 * 60.0
    private let shortBreak3End = 90 * 60.0
    private let work4End = 115 * 60.0
    private let longBreakEnd = 130 * 60.0

    func testStartsIdleInTheWorkPhase() {
        let timer = PomodoroTimer(name: "Focus")

        XCTAssertEqual(timer.type, .pomodoro)
        XCTAssertEqual(timer.status, .idle)
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.completedWorkPhases, 0)
        XCTAssertEqual(timer.remaining(at: later(60)), 25 * 60)
    }

    func testWorkPhaseCountsDownAndAutoTransitionsToShortBreak() {
        let timer = PomodoroTimer(name: "Focus")
        timer.start(at: t0)

        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.remaining(at: later(10 * 60)), 15 * 60, accuracy: 0.001)

        let entries = timer.update(at: later(workEnd))
        XCTAssertEqual(entries.map(\.phase), ["Work"])
        XCTAssertEqual(timer.status, .running, "a Pomodoro keeps cycling until reset")
        XCTAssertEqual(timer.phase, .shortBreak)
        XCTAssertEqual(timer.completedWorkPhases, 1)
        XCTAssertEqual(timer.remaining(at: later(workEnd)), 5 * 60, accuracy: 0.001)
    }

    func testBreakAutoTransitionsBackToWork() {
        let timer = PomodoroTimer()
        timer.start(at: t0)
        _ = timer.update(at: later(workEnd))

        let entries = timer.update(at: later(shortBreakEnd))
        XCTAssertEqual(entries.map(\.phase), ["Short break"])
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.remaining(at: later(shortBreakEnd)), 25 * 60, accuracy: 0.001)
    }

    func testFourthWorkPhaseIsFollowedByALongBreak() {
        let timer = PomodoroTimer()
        timer.start(at: t0)

        XCTAssertEqual(timer.update(at: later(workEnd)).map(\.phase), ["Work"])
        XCTAssertEqual(timer.update(at: later(shortBreakEnd)).map(\.phase), ["Short break"])
        XCTAssertEqual(timer.update(at: later(work2End)).map(\.phase), ["Work"])
        XCTAssertEqual(timer.update(at: later(shortBreak2End)).map(\.phase), ["Short break"])
        XCTAssertEqual(timer.update(at: later(work3End)).map(\.phase), ["Work"])
        XCTAssertEqual(timer.update(at: later(shortBreak3End)).map(\.phase), ["Short break"])

        XCTAssertEqual(timer.update(at: later(work4End)).map(\.phase), ["Work"])
        XCTAssertEqual(timer.phase, .longBreak)
        XCTAssertEqual(timer.completedWorkPhases, 4)
        XCTAssertEqual(timer.remaining(at: later(work4End)), 15 * 60, accuracy: 0.001)

        XCTAssertEqual(timer.update(at: later(longBreakEnd)).map(\.phase), ["Long break"])
        XCTAssertEqual(timer.phase, .work)
    }

    func testLateUpdateCatchesUpThroughEveryElapsedPhase() {
        let timer = PomodoroTimer()
        timer.start(at: t0)

        // Exactly two work phases and two breaks have ended; the third work phase is live.
        let entries = timer.update(at: later(shortBreak2End))

        XCTAssertEqual(entries.map(\.phase), ["Work", "Short break", "Work", "Short break"])
        XCTAssertEqual(entries.map(\.completedAt), [
            later(workEnd), later(shortBreakEnd), later(work2End), later(shortBreak2End),
        ])
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.completedWorkPhases, 2)
        XCTAssertEqual(timer.remaining(at: later(shortBreak2End)), 25 * 60, accuracy: 0.001)
        XCTAssertEqual(timer.remaining(at: later(shortBreak2End + 600)), 15 * 60, accuracy: 0.001)
    }

    func testHistoryEntryDescribesTheCompletedPhase() {
        let timer = PomodoroTimer(id: UUID(), name: "Focus")
        timer.start(at: t0)

        let entry = timer.update(at: later(workEnd)).first
        XCTAssertEqual(entry?.timerID, timer.id)
        XCTAssertEqual(entry?.timerName, "Focus")
        XCTAssertEqual(entry?.timerType, .pomodoro)
        XCTAssertEqual(entry?.startedAt, t0)
        XCTAssertEqual(entry?.completedAt, later(workEnd))
        XCTAssertEqual(entry?.plannedDuration, 25 * 60)
        XCTAssertEqual(entry?.elapsed, 25 * 60)
        XCTAssertEqual(entry?.phase, "Work")

        XCTAssertTrue(timer.update(at: later(workEnd)).isEmpty, "a phase records history exactly once")
    }

    func testPauseFreezesThePhaseAndResumeShiftsTheDeadline() {
        let timer = PomodoroTimer()
        timer.start(at: t0)
        timer.pause(at: later(10 * 60))

        XCTAssertEqual(timer.status, .paused)
        XCTAssertEqual(timer.remaining(at: later(100 * 60)), 15 * 60, accuracy: 0.001)

        timer.resume(at: later(100 * 60))
        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.remaining(at: later(100 * 60)), 15 * 60, accuracy: 0.001)

        let deadline: TimeInterval = 100 * 60 + 15 * 60
        XCTAssertTrue(timer.update(at: later(deadline - 1)).isEmpty)
        XCTAssertEqual(timer.update(at: later(deadline)).map(\.phase), ["Work"])
        XCTAssertEqual(timer.phase, .shortBreak)
    }

    func testPauseAfterTheDeadlineIsIgnored() {
        let timer = PomodoroTimer()
        timer.start(at: t0)
        timer.pause(at: later(workEnd + 1))

        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.update(at: later(workEnd + 1)).map(\.phase), ["Work"])
    }

    func testResetReturnsToTheFirstWorkPhase() {
        let timer = PomodoroTimer()
        timer.start(at: t0)
        _ = timer.update(at: later(longBreakEnd - 1))
        XCTAssertEqual(timer.phase, .longBreak)
        XCTAssertEqual(timer.completedWorkPhases, 4)

        timer.reset()

        XCTAssertEqual(timer.status, .idle)
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.completedWorkPhases, 0)
        XCTAssertEqual(timer.remaining(at: later(longBreakEnd)), 25 * 60)

        timer.start(at: later(longBreakEnd))
        XCTAssertEqual(timer.remaining(at: later(longBreakEnd + 60)), 24 * 60, accuracy: 0.001)
    }

    func testCustomSettingsDriveTheCycle() {
        let settings = PomodoroSettings(
            workDuration: 50 * 60,
            shortBreakDuration: 10 * 60,
            longBreakDuration: 30 * 60,
            workPhasesPerLongBreak: 2
        )
        let timer = PomodoroTimer(settings: settings)
        timer.start(at: t0)

        XCTAssertEqual(timer.remaining(at: t0), 50 * 60)
        XCTAssertEqual(timer.update(at: later(50 * 60)).map(\.phase), ["Work"])
        XCTAssertEqual(timer.phase, .shortBreak)
        XCTAssertEqual(timer.update(at: later(60 * 60)).map(\.phase), ["Short break"])
        XCTAssertEqual(timer.update(at: later(110 * 60)).map(\.phase), ["Work"])
        XCTAssertEqual(timer.phase, .longBreak, "two work phases is the configured cadence")
    }
}

final class TimerStorePomodoroTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testStoreRecordsEveryCompletedPhase() {
        let store = TimerStore()
        let pomodoro = PomodoroTimer(name: "Focus")
        store.add(pomodoro)
        pomodoro.start(at: t0)

        store.update(at: later(30 * 60))

        XCTAssertEqual(store.history.map(\.phase), ["Work", "Short break"])
        XCTAssertEqual(store.history.map(\.timerName), ["Focus", "Focus"])
        XCTAssertEqual(store.timers.first?.status, .running)
    }

    func testPomodoroRunsAlongsideACountdown() {
        let store = TimerStore()
        let countdown = CountdownTimer(name: "Tea", duration: 60)
        let pomodoro = PomodoroTimer(name: "Focus")
        store.add(countdown)
        store.add(pomodoro)
        countdown.start(at: t0)
        pomodoro.start(at: t0)

        store.update(at: later(25 * 60))

        XCTAssertEqual(store.history.map(\.timerName), ["Tea", "Focus"])
        XCTAssertEqual(store.history.map(\.phase), [nil, "Work"])
        XCTAssertEqual(store.timers.map(\.status), [.completed, .running])
    }
}
