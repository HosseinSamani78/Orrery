import Foundation
import SwiftData

/// A named collection of timers, optionally organized into phases.
@Model
public final class Board {
    public var name: String
    public var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \BoardPhase.board)
    public var phases: [BoardPhase] = []

    @Relationship(deleteRule: .cascade, inverse: \TimerRecord.board)
    public var timers: [TimerRecord] = []

    public init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }

    /// Appends a phase; phases are kept in insertion order.
    @discardableResult
    public func addPhase(named name: String) -> BoardPhase {
        let phase = BoardPhase(name: name, order: phases.count)
        phases.append(phase)
        return phase
    }

    /// Inserts or refreshes the persisted snapshot for `timer`, so the board reflects its current run.
    @discardableResult
    public func record(_ timer: CountdownTimer) -> TimerRecord {
        if let record = timers.first(where: { $0.timerID == timer.id }) {
            record.update(from: timer)
            return record
        }
        let record = TimerRecord(timer)
        timers.append(record)
        return record
    }

    /// Drops the snapshot for a timer that no longer exists on the board.
    public func removeRecord(id: UUID) {
        timers.removeAll { $0.timerID == id }
    }

    /// Timers rebuilt from their snapshots.
    public var liveTimers: [CountdownTimer] {
        timers.map(\.timer)
    }
}

/// A named step within a Board, ordered by its position.
@Model
public final class BoardPhase {
    public var name: String
    public var order: Int
    public var board: Board?

    public init(name: String, order: Int) {
        self.name = name
        self.order = order
    }
}

/// Persisted snapshot of one timer and its run state.
@Model
public final class TimerRecord {
    public var timerID: UUID
    public var name: String
    public var type: TimerType
    public var status: TimerStatus
    public var duration: TimeInterval
    public var startedAt: Date?
    public var endsAt: Date?
    public var pausedAt: Date?
    public var board: Board?

    public init(_ timer: CountdownTimer) {
        timerID = timer.id
        name = timer.name
        type = timer.type
        status = timer.status
        duration = timer.duration
        startedAt = timer.startedAt
        endsAt = timer.endsAt
        pausedAt = timer.pausedAt
    }

    public func update(from timer: CountdownTimer) {
        name = timer.name
        status = timer.status
        startedAt = timer.startedAt
        endsAt = timer.endsAt
        pausedAt = timer.pausedAt
    }

    public var timer: CountdownTimer {
        CountdownTimer(
            id: timerID,
            name: name,
            duration: duration,
            type: type,
            status: status,
            startedAt: startedAt,
            endsAt: endsAt,
            pausedAt: pausedAt
        )
    }
}

/// Owns the SwiftData container for Boards and their timers.
public final class BoardStore {
    let context: ModelContext

    public static var defaultStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "Orrery/Orrery.store")
    }

    /// `storeURL: nil` uses the App Group store shared with the widget.
    public init(storeURL: URL? = nil) throws {
        let url = storeURL ?? SharedStore.storeURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let container = try ModelContainer(
            for: Board.self, Preset.self,
            configurations: ModelConfiguration(url: url)
        )
        context = ModelContext(container)
    }

    /// In-memory store, for tests and previews.
    public init(isStoredInMemoryOnly: Bool) throws {
        let container = try ModelContainer(
            for: Board.self, Preset.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
        )
        context = ModelContext(container)
    }

    public func boards() throws -> [Board] {
        try context.fetch(FetchDescriptor<Board>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    @discardableResult
    public func createBoard(named name: String) throws -> Board {
        let board = Board(name: name)
        context.insert(board)
        try save()
        return board
    }

    public func delete(_ board: Board) throws {
        context.delete(board)
        try save()
    }

    /// Starts or pauses one persisted timer, settling a passed deadline first. Returns its new
    /// status, or `nil` when the board has no timer with this id. Shared by widget intents.
    @discardableResult
    public func toggleTimer(id: UUID, at now: Date = .now) throws -> TimerStatus? {
        guard let board = try boards().first,
              let record = board.timers.first(where: { $0.timerID == id }) else { return nil }
        let timer = record.timer
        _ = timer.update(at: now)
        _ = TimerStore(timers: [timer]).perform(.toggle, on: id, at: now)
        record.update(from: timer)
        try save()
        return timer.status
    }

    public func save() throws {
        try context.save()
    }
}
