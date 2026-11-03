import XCTest
import OrreryCore

final class CompletionAlertTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    private func entry(name: String = "Tea", elapsed: TimeInterval = 300, phase: String? = nil) -> HistoryEntry {
        HistoryEntry(
            timerID: UUID(),
            timerName: name,
            timerType: .countdown,
            startedAt: t0,
            completedAt: t0.addingTimeInterval(elapsed),
            plannedDuration: elapsed,
            elapsed: elapsed,
            phase: phase
        )
    }

    func testPlainTimerNamesItselfAndReadsTheRunTime() {
        let alert = CompletionAlert(entry())
        XCTAssertEqual(alert.title, "Tea done")
        XCTAssertEqual(alert.body, "Finished after 5:00.")
    }

    func testPhaseNamesTheFinishedPhaseNotTheWholeTimer() {
        let alert = CompletionAlert(entry(name: "Focus", elapsed: 1500, phase: "Work"))
        XCTAssertEqual(alert.title, "Focus — Work done")
        XCTAssertEqual(alert.body, "Finished after 25:00.")
    }
}

final class ClockTextTests: XCTestCase {
    func testMinutesAndSecondsPadButHoursOnlyAppearWhenNeeded() {
        XCTAssertEqual(ClockText.format(59.9), "0:59")
        XCTAssertEqual(ClockText.format(3900), "1:05:00")
    }

    func testRoundingUpKeepsTheLastSecondOnScreen() {
        XCTAssertEqual(ClockText.format(0.2, roundingUp: true), "0:01")
        XCTAssertEqual(ClockText.format(0, roundingUp: true), "0:00")
    }
}
