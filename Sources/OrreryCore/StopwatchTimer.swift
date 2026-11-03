import Foundation

/// One recorded lap: `lap` is the time since the previous lap, `split` the elapsed time at the marker.
public struct StopwatchLap: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let index: Int
    public let lap: TimeInterval
    public let split: TimeInterval

    public init(id: UUID = UUID(), index: Int, lap: TimeInterval, split: TimeInterval) {
        self.id = id
        self.index = index
        self.lap = lap
        self.split = split
    }
}

/// Stopwatch: elapsed time plus laps/splits, like `CountUpTimer` with markers.
/// Wall-clock anchored, so time spent paused is excluded from both the run and the current lap.
public final class StopwatchTimer: TimerModel {
    public let id: UUID
    public var name: String
    public let type: TimerType = .stopwatch

    public private(set) var status: TimerStatus = .idle
    public private(set) var startedAt: Date?
    public private(set) var pausedAt: Date?
    public private(set) var laps: [StopwatchLap] = []

    // Paused time already discounted from the run; resumed segments add to it.
    private var pausedTotal: TimeInterval = 0

    public init(id: UUID = UUID(), name: String = "Stopwatch") {
        self.id = id
        self.name = name
    }

    /// Time counted since the run started at `now`, frozen while paused.
    public func elapsed(at now: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        return max(0, (pausedAt ?? now).timeIntervalSince(startedAt) - pausedTotal)
    }

    public func start(at now: Date) {
        guard status == .idle else { return }
        status = .running
        startedAt = now
    }

    public func pause(at now: Date) {
        guard status == .running else { return }
        status = .paused
        pausedAt = now
    }

    public func resume(at now: Date) {
        guard status == .paused, let pausedAt else { return }
        pausedTotal += now.timeIntervalSince(pausedAt)
        self.pausedAt = nil
        status = .running
    }

    public func reset() {
        status = .idle
        startedAt = nil
        pausedAt = nil
        pausedTotal = 0
        laps = []
    }

    /// Records a lap at `now`; ignored unless the stopwatch is running.
    @discardableResult
    public func recordLap(at now: Date) -> StopwatchLap? {
        guard status == .running else { return nil }
        let split = elapsed(at: now)
        let lap = StopwatchLap(
            index: laps.count + 1,
            lap: split - (laps.last?.split ?? 0),
            split: split
        )
        laps.append(lap)
        return lap
    }

    /// A stopwatch has no deadline, so it never completes on its own.
    public func update(at now: Date) -> [HistoryEntry] {
        []
    }
}
