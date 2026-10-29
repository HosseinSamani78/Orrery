import Foundation

public final class CountdownTimer: TimerModel {
    public let id: UUID
    public var name: String
    public let duration: TimeInterval
    public let type: TimerType = .countdown

    public private(set) var status: TimerStatus = .idle
    public private(set) var startedAt: Date?

    // Set while running and paused; only cleared by reset(), so non-nil whenever the run is live.
    private var endsAt: Date?
    private var pausedAt: Date?

    public init(id: UUID = UUID(), name: String = "Countdown", duration: TimeInterval) {
        precondition(duration > 0, "A countdown needs a positive duration")
        self.id = id
        self.name = name
        self.duration = duration
    }

    /// Time left at `now`, frozen while paused. Pauses shift the end anchor, so wall-clock time
    /// spent paused never counts against the countdown.
    public func remaining(at now: Date) -> TimeInterval {
        switch status {
        case .idle: duration
        case .completed: 0
        case .running: max(0, endsAt!.timeIntervalSince(now))
        case .paused: max(0, endsAt!.timeIntervalSince(pausedAt!))
        }
    }

    public func start(at now: Date) {
        guard status == .idle else { return }
        status = .running
        startedAt = now
        endsAt = now.addingTimeInterval(duration)
    }

    /// Ignored once the deadline has passed; `update(at:)` completes the run instead.
    public func pause(at now: Date) {
        guard status == .running, let endsAt, now < endsAt else { return }
        status = .paused
        pausedAt = now
    }

    public func resume(at now: Date) {
        guard status == .paused, let endsAt, let pausedAt else { return }
        self.endsAt = endsAt.addingTimeInterval(now.timeIntervalSince(pausedAt))
        self.pausedAt = nil
        status = .running
    }

    public func reset() {
        status = .idle
        startedAt = nil
        endsAt = nil
        pausedAt = nil
    }

    public func update(at now: Date) -> HistoryEntry? {
        guard status == .running, let endsAt, let startedAt, now >= endsAt else { return nil }
        status = .completed
        pausedAt = nil
        return HistoryEntry(
            timerID: id,
            timerName: name,
            timerType: type,
            startedAt: startedAt,
            completedAt: endsAt,
            plannedDuration: duration,
            elapsed: duration
        )
    }
}
