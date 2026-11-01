import XCTest
import OrreryCore

final class PresetTests: XCTestCase {
    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "OrreryTests-\(UUID().uuidString)/Orrery.store")
    }

    func testSavingABoardAsPresetCapturesItsConfiguration() throws {
        let store = try BoardStore(isStoredInMemoryOnly: true)
        let board = try store.createBoard(named: "Kitchen")
        board.addPhase(named: "Steep")
        board.addPhase(named: "Rest")
        let tea = CountdownTimer(name: "Tea", duration: 300)
        tea.start(at: .now)
        board.record(tea)
        board.record(CountdownTimer(name: "Eggs", duration: 420, type: .quickStart))
        try store.save()

        let preset = try store.savePreset(from: board)

        XCTAssertEqual(preset.name, "Kitchen")
        XCTAssertEqual(preset.phases, ["Steep", "Rest"])
        XCTAssertEqual(preset.timers, [
            PresetTimer(name: "Tea", type: .countdown, duration: 300),
            PresetTimer(name: "Eggs", type: .quickStart, duration: 420),
        ])
    }

    func testApplyingAPresetCreatesAnIdleBoardWithFreshTimers() throws {
        let store = try BoardStore(isStoredInMemoryOnly: true)
        let source = try store.createBoard(named: "Kitchen")
        source.addPhase(named: "Steep")
        source.record(CountdownTimer(name: "Tea", duration: 300))
        let preset = try store.savePreset(from: source)

        let applied = try store.createBoard(from: preset, named: "Tea for two")

        XCTAssertEqual(applied.name, "Tea for two")
        XCTAssertEqual(applied.phases.map(\.name), ["Steep"])
        let timer = try XCTUnwrap(applied.liveTimers.first)
        XCTAssertEqual(timer.name, "Tea")
        XCTAssertEqual(timer.type, .countdown)
        XCTAssertEqual(timer.duration, 300)
        XCTAssertEqual(timer.status, .idle)
        XCTAssertNotEqual(timer.id, source.liveTimers.first?.id)
        XCTAssertEqual(try store.boards().count, 2)
    }

    func testPresetSurvivesReopeningTheStore() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        do {
            let store = try BoardStore(storeURL: url)
            let board = try store.createBoard(named: "Kitchen")
            board.addPhase(named: "Steep")
            board.record(CountdownTimer(name: "Tea", duration: 300))
            try store.savePreset(from: board, named: "Tea timer")
        }

        let reopened = try BoardStore(storeURL: url)
        let preset = try XCTUnwrap(reopened.presets().first)
        XCTAssertEqual(preset.name, "Tea timer")
        XCTAssertEqual(preset.phases, ["Steep"])
        XCTAssertEqual(preset.timers.map(\.name), ["Tea"])

        let applied = try reopened.createBoard(from: preset)
        XCTAssertEqual(applied.name, "Tea timer")
        XCTAssertEqual(applied.liveTimers.map(\.duration), [300])
    }

    func testDeletingAPresetLeavesBoardsIntact() throws {
        let store = try BoardStore(isStoredInMemoryOnly: true)
        let board = try store.createBoard(named: "Kitchen")
        let preset = try store.savePreset(from: board)

        try store.delete(preset)

        XCTAssertTrue(try store.presets().isEmpty)
        XCTAssertEqual(try store.boards().count, 1)
    }
}
