import Foundation
import UniformTypeIdentifiers

/// A Board as shared in a `.orreryboard` file: setup only, no run state, so the recipient
/// starts from a clean board.
public struct BoardDocument: Codable, Equatable, Sendable {
    public static let fileExtension = "orreryboard"
    public static let contentType = UTType(exportedAs: "com.orrery.board", conformingTo: .json)
    public static let currentVersion = 1

    public var version: Int
    public var name: String
    public var phases: [String]
    public var timers: [PresetTimer]

    public init(name: String, phases: [String] = [], timers: [PresetTimer] = []) {
        version = Self.currentVersion
        self.name = name
        self.phases = phases
        self.timers = timers
    }

    public init(board: Board) {
        self.init(
            name: board.name,
            phases: board.phases.sorted { $0.order < $1.order }.map(\.name),
            timers: board.timers.map {
                PresetTimer(name: $0.name, type: $0.type, duration: $0.duration)
            }
        )
    }
}

public enum BoardDocumentError: Error, Equatable {
    case unsupportedVersion(Int)
    case invalidTimerDuration
}

extension BoardStore {
    public func exportData(for board: Board) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(BoardDocument(board: board))
    }

    /// Imports a shared Board as a new idle Board. Unknown versions and invalid durations are
    /// rejected before a timer is built, so a bad file cannot trap the app.
    @discardableResult
    public func importBoard(from data: Data) throws -> Board {
        let document = try JSONDecoder().decode(BoardDocument.self, from: data)
        guard document.version == BoardDocument.currentVersion else {
            throw BoardDocumentError.unsupportedVersion(document.version)
        }
        guard document.timers.allSatisfy({ $0.duration > 0 }) else {
            throw BoardDocumentError.invalidTimerDuration
        }
        return try createBoard(named: document.name, phases: document.phases, timers: document.timers)
    }
}

extension BoardDocumentError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "This board was made with a newer version of Orrery (file version \(version))."
        case .invalidTimerDuration:
            "This board file contains a timer with an invalid duration."
        }
    }
}
