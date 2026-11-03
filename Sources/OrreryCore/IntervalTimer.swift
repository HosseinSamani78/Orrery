import Foundation

/// One named step of an interval cycle.
public struct IntervalPhase: Equatable, Sendable {
    public var name: String
    public var duration: TimeInterval

    public init(name: String, duration: TimeInterval) {
        precondition(duration > 0, "An interval phase needs a positive duration")
        self.name = name
        self.duration = duration
    }
}

/// Named phases that repeat in order until reset.
/// Like Pomodoro, each phase boundary chains from the previous deadline, so a late `update`
/// catches up through every phase that elapsed and lands on the phase that is live now.
public final class IntervalTimer: TimerModel {
    public let id: UUID
    public var name: String
    public let type: TimerType = .interval
    public let phases: [IntervalPhase]

    public private(set) var status: TimerStatus = .idle
    public private(set) var startedAt: Date?
    public private(set) var phaseIndex = 0

    private var endsAt: Date?
    private var pausedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String = "Interval",
        phases: [IntervalPhase]
    ) {
        precondition(!phases.isEmpty, "An interval timer needs at least one phase")
        self.id = id
        self.name = name
        self.phases = phases
    }

    public var phase: IntervalPhase { phases[phaseIndex] }
    public var phaseDuration: TimeInterval { phase.duration }

    /// Time left in the current phase at `now`, frozen while paused.
    public func remaining(at now: Date) -> TimeInterval {
        switch status {
        case .idle: phaseDuration
        case .completed: 0
        case .running: max(0, endsAt!.timeIntervalSince(now))
        case .paused: max(0, endsAt!.timeIntervalSince(pausedAt!))
        }
    }

    public func start(at now: Date) {
        guard status == .idle else { return }
        status = .running
        startedAt = now
        endsAt = now.addingTimeInterval(phaseDuration)
    }

    /// Ignored once the deadline has passed; `update(at:)` transitions instead.
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
        phaseIndex = 0
    }

    /// Records every phase that ended by `now`, then leaves the timer running in the live phase.
    public func update(at now: Date) -> [HistoryEntry] {
        guard status == .running else { return [] }
        var entries: [HistoryEntry] = []
        while let endsAt, now >= endsAt {
            entries.append(HistoryEntry(
                timerID: id,
                timerName: name,
                timerType: type,
                startedAt: endsAt.addingTimeInterval(-phaseDuration),
                completedAt: endsAt,
                plannedDuration: phaseDuration,
                elapsed: phaseDuration,
                phase: phase.name
            ))
            phaseIndex = (phaseIndex + 1) % phases.count
            self.endsAt = endsAt.addingTimeInterval(phaseDuration)
        }
        return entries
    }
}
