import Foundation

/// Elapsed-time timer with no deadline: counts up from zero until paused or reset.
/// Wall-clock anchored like `CountdownTimer`, so time spent paused or backgrounded is excluded.
public final class CountUpTimer: TimerModel {
    public let id: UUID
    public var name: String
    public let type: TimerType = .countUp

    public private(set) var status: TimerStatus = .idle
    public private(set) var startedAt: Date?
    public private(set) var pausedAt: Date?

    // Paused time already discounted from the run; resumed segments add to it.
    private var pausedTotal: TimeInterval = 0

    public init(id: UUID = UUID(), name: String = "Count up") {
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
    }

    /// A count-up run has no deadline, so it never completes on its own.
    public func update(at now: Date) -> [HistoryEntry] {
        []
    }
}
