import Foundation
import SwiftData

/// One timer's configuration inside a Preset; a Preset stores setup, not a run.
public struct PresetTimer: Codable, Equatable, Sendable {
    public var name: String
    public var type: TimerType
    public var duration: TimeInterval

    public init(name: String, type: TimerType, duration: TimeInterval) {
        self.name = name
        self.type = type
        self.duration = duration
    }
}

/// A saved Board configuration that can be applied to create a new Board.
@Model
public final class Preset {
    public var name: String
    public var createdAt: Date
    /// Phase names in board order.
    public var phases: [String]
    public var timers: [PresetTimer]

    public init(
        name: String,
        createdAt: Date = .now,
        phases: [String] = [],
        timers: [PresetTimer] = []
    ) {
        self.name = name
        self.createdAt = createdAt
        self.phases = phases
        self.timers = timers
    }
}

extension BoardStore {
    public func presets() throws -> [Preset] {
        try context.fetch(FetchDescriptor<Preset>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    /// Snapshots `board`'s configuration (phases and timer setup, not run state) as a new Preset.
    @discardableResult
    public func savePreset(from board: Board, named name: String? = nil) throws -> Preset {
        let preset = Preset(
            name: name ?? board.name,
            phases: board.phases.sorted { $0.order < $1.order }.map(\.name),
            timers: board.timers.map {
                PresetTimer(name: $0.name, type: $0.type, duration: $0.duration)
            }
        )
        context.insert(preset)
        try save()
        return preset
    }

    /// Applies `preset` as a new Board whose timers are all idle and ready to run.
    @discardableResult
    public func createBoard(from preset: Preset, named name: String? = nil) throws -> Board {
        let board = Board(name: name ?? preset.name)
        context.insert(board)
        for phase in preset.phases {
            board.addPhase(named: phase)
        }
        for template in preset.timers {
            let timer = CountdownTimer(name: template.name, duration: template.duration, type: template.type)
            board.record(timer)
        }
        try save()
        return board
    }

    public func delete(_ preset: Preset) throws {
        context.delete(preset)
        try save()
    }
}
