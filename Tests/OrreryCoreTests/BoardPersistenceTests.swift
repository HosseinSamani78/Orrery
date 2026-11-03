import XCTest
import OrreryCore

final class BoardPersistenceTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "OrreryTests-\(UUID().uuidString)/Orrery.store")
    }

    func testBoardPhasesAndTimersSurviveReopeningTheStore() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let timer = CountdownTimer(name: "Tea", duration: 300)
        timer.start(at: t0)

        do {
            let store = try BoardStore(storeURL: url)
            let board = try store.createBoard(named: "Kitchen")
            board.addPhase(named: "Steep")
            board.addPhase(named: "Rest")
            board.record(timer)
            try store.save()
        }

        let reopened = try BoardStore(storeURL: url)
        let board = try XCTUnwrap(reopened.boards().first)
        XCTAssertEqual(board.name, "Kitchen")
        XCTAssertEqual(board.phases.sorted { $0.order < $1.order }.map(\.name), ["Steep", "Rest"])

        let restored = try XCTUnwrap(board.liveTimers.first)
        XCTAssertEqual(board.timers.first?.type, .countdown)
        XCTAssertEqual(restored.id, timer.id)
        XCTAssertEqual(restored.name, "Tea")
        XCTAssertEqual(restored.duration, 300)
        XCTAssertEqual(restored.status, .running)
        XCTAssertEqual(restored.startedAt, t0)
        XCTAssertEqual(restored.remaining(at: t0.addingTimeInterval(100)), 200, accuracy: 0.001)
    }

    func testRecordingAPausedTimerAgainUpdatesTheExistingSnapshot() throws {
        let store = try BoardStore(isStoredInMemoryOnly: true)
        let board = try store.createBoard(named: "Kitchen")
        let timer = CountdownTimer(duration: 300)

        timer.start(at: t0)
        board.record(timer)
        timer.pause(at: t0.addingTimeInterval(100))
        board.record(timer)
        try store.save()

        XCTAssertEqual(board.timers.count, 1)
        XCTAssertEqual(board.liveTimers.first?.status, .paused)
        XCTAssertEqual(board.liveTimers.first?.remaining(at: t0.addingTimeInterval(10_000)), 200)
    }

    func testTogglingAPersistedTimerStartsThenPausesIt() throws {
        let store = try BoardStore(isStoredInMemoryOnly: true)
        let board = try store.createBoard(named: "Kitchen")
        let timer = CountdownTimer(duration: 300)
        board.record(timer)
        try store.save()

        XCTAssertEqual(try store.toggleTimer(id: timer.id, at: t0), .running)
        XCTAssertEqual(
            try store.toggleTimer(id: timer.id, at: t0.addingTimeInterval(100)),
            .paused
        )
        XCTAssertEqual(
            try XCTUnwrap(board.liveTimers.first).remaining(at: t0.addingTimeInterval(10_000)),
            200,
            accuracy: 0.001
        )
        XCTAssertNil(try store.toggleTimer(id: UUID(), at: t0))
    }

    func testTogglingATimerWhoseDeadlinePassedLeavesItCompleted() throws {
        let store = try BoardStore(isStoredInMemoryOnly: true)
        let board = try store.createBoard(named: "Kitchen")
        let timer = CountdownTimer(duration: 60)
        board.record(timer)
        try store.save()

        XCTAssertEqual(try store.toggleTimer(id: timer.id, at: t0), .running)
        XCTAssertEqual(
            try store.toggleTimer(id: timer.id, at: t0.addingTimeInterval(120)),
            .completed
        )
    }

    func testDeletingABoardRemovesItFromTheStore() throws {
        let store = try BoardStore(isStoredInMemoryOnly: true)
        let board = try store.createBoard(named: "Kitchen")
        board.addPhase(named: "Steep")
        board.record(CountdownTimer(duration: 60))
        try store.save()

        try store.delete(board)

        XCTAssertTrue(try store.boards().isEmpty)
    }
}
