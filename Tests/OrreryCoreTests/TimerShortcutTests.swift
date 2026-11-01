import XCTest
import OrreryCore

final class TimerShortcutTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testDefaultShortcutsMapToTheirActions() {
        XCTAssertEqual(TimerShortcut.action(forKey: " "), .toggle)
        XCTAssertEqual(TimerShortcut.action(forKey: "n", modifiers: .command), .quickStart)
        XCTAssertEqual(TimerShortcut.action(forKey: "r", modifiers: .command), .reset)
        XCTAssertEqual(TimerShortcut.action(forKey: "\u{7F}", modifiers: .command), .delete)
    }

    func testUnboundKeyCombinationsHaveNoAction() {
        XCTAssertNil(TimerShortcut.action(forKey: "n"))
        XCTAssertNil(TimerShortcut.action(forKey: " ", modifiers: .shift))
    }

    func testToggleWalksTheLifecycleAndIgnoresCompletedTimers() {
        let store = TimerStore()
        let timer = CountdownTimer(duration: 60)
        store.add(timer)

        XCTAssertTrue(store.perform(.toggle, on: timer.id, at: t0))
        XCTAssertEqual(timer.status, .running)

        XCTAssertTrue(store.perform(.toggle, on: timer.id, at: later(10)))
        XCTAssertEqual(timer.status, .paused)

        XCTAssertTrue(store.perform(.toggle, on: timer.id, at: later(20)))
        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.remaining(at: later(20)), 50, accuracy: 0.001)

        _ = timer.update(at: later(80))
        XCTAssertEqual(timer.status, .completed)
        XCTAssertFalse(store.perform(.toggle, on: timer.id, at: later(80)))
    }

    func testResetReturnsTheTimerToIdle() {
        let store = TimerStore()
        let timer = CountdownTimer(duration: 60)
        store.add(timer)
        timer.start(at: t0)

        XCTAssertTrue(store.perform(.reset, on: timer.id, at: later(10)))
        XCTAssertEqual(timer.status, .idle)
        XCTAssertEqual(timer.remaining(at: later(10)), 60, accuracy: 0.001)
    }

    func testDeleteRemovesTheTimerAndUnknownIDsAreRejected() {
        let store = TimerStore()
        let timer = CountdownTimer(duration: 60)
        store.add(timer)

        XCTAssertTrue(store.perform(.delete, on: timer.id, at: t0))
        XCTAssertTrue(store.timers.isEmpty)
        XCTAssertFalse(store.perform(.delete, on: timer.id, at: t0))
        XCTAssertFalse(store.perform(.reset, on: UUID(), at: t0))
    }

    func testQuickStartAddsARunningTimer() {
        let store = TimerStore()

        XCTAssertTrue(store.perform(.quickStart, on: UUID(), at: t0))

        let timer = store.timers.first as? CountdownTimer
        XCTAssertEqual(store.timers.count, 1)
        XCTAssertEqual(timer?.type, .quickStart)
        XCTAssertEqual(timer?.status, .running)
        XCTAssertEqual(timer?.remaining(at: t0), QuickStartTimer.defaultDuration)
    }
}
