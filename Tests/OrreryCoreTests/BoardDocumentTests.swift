import XCTest
import OrreryCore

final class BoardDocumentTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "OrreryTests-\(UUID().uuidString)/Orrery.store")
    }

    func testExportingABoardWritesItsSetupAsJSON() throws {
        let store = try BoardStore(isStoredInMemoryOnly: true)
        let board = try store.createBoard(named: "Kitchen")
        board.addPhase(named: "Steep")
        board.addPhase(named: "Rest")
        let tea = CountdownTimer(name: "Tea", duration: 300)
        tea.start(at: t0)
        board.record(tea)
        board.record(CountdownTimer(name: "Eggs", duration: 420, type: .quickStart))
        try store.save()

        let data = try store.exportData(for: board)
        let document = try JSONDecoder().decode(BoardDocument.self, from: data)

        XCTAssertEqual(document.version, BoardDocument.currentVersion)
        XCTAssertEqual(document.name, "Kitchen")
        XCTAssertEqual(document.phases, ["Steep", "Rest"])
        XCTAssertEqual(document.timers.sorted { $0.name < $1.name }, [
            PresetTimer(name: "Eggs", type: .quickStart, duration: 420),
            PresetTimer(name: "Tea", type: .countdown, duration: 300),
        ])
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testImportingADocumentCreatesANewIdleBoard() throws {
        let store = try BoardStore(isStoredInMemoryOnly: true)
        let source = try store.createBoard(named: "Kitchen")
        source.addPhase(named: "Steep")
        source.record(CountdownTimer(name: "Tea", duration: 300))
        try store.save()

        let imported = try store.importBoard(from: store.exportData(for: source))

        XCTAssertEqual(try store.boards().count, 2)
        XCTAssertEqual(try store.currentBoard()?.name, "Kitchen")
        XCTAssertEqual(imported.phases.map(\.name), ["Steep"])
        let timer = try XCTUnwrap(imported.liveTimers.first)
        XCTAssertEqual(timer.name, "Tea")
        XCTAssertEqual(timer.duration, 300)
        XCTAssertEqual(timer.status, .idle)
        XCTAssertNotEqual(timer.id, source.liveTimers.first?.id)
    }

    func testDocumentSurvivesWritingAndReadingAFile() throws {
        let url = temporaryStoreURL().appendingPathExtension(BoardDocument.fileExtension)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let store = try BoardStore(isStoredInMemoryOnly: true)
        let board = try store.createBoard(named: "Lesson")
        board.addPhase(named: "Warm up")
        board.record(CountdownTimer(name: "Intro", duration: 60))
        try store.save()
        try store.exportData(for: board).write(to: url)

        let reopened = try BoardStore(isStoredInMemoryOnly: true)
        let imported = try reopened.importBoard(from: Data(contentsOf: url))
        XCTAssertEqual(imported.name, "Lesson")
        XCTAssertEqual(imported.liveTimers.map(\.name), ["Intro"])
    }

    func testImportingRejectsAnUnknownVersionBeforeBuildingTimers() throws {
        let store = try BoardStore(isStoredInMemoryOnly: true)
        let document = BoardDocument(
            name: "Future",
            timers: [PresetTimer(name: "Tea", type: .countdown, duration: 300)]
        )
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as! [String: Any]
        json["version"] = BoardDocument.currentVersion + 1

        XCTAssertThrowsError(
            try store.importBoard(from: JSONSerialization.data(withJSONObject: json))
        ) { error in
            XCTAssertEqual(error as? BoardDocumentError, .unsupportedVersion(BoardDocument.currentVersion + 1))
        }
        XCTAssertTrue(try store.boards().isEmpty)
    }

    func testImportingRejectsAnInvalidDurationInsteadOfTrapping() throws {
        let store = try BoardStore(isStoredInMemoryOnly: true)
        let document = BoardDocument(
            name: "Bad",
            timers: [PresetTimer(name: "Tea", type: .countdown, duration: 0)]
        )

        XCTAssertThrowsError(try store.importBoard(from: JSONEncoder().encode(document))) { error in
            XCTAssertEqual(error as? BoardDocumentError, .invalidTimerDuration)
        }
        XCTAssertTrue(try store.boards().isEmpty)
    }
}
