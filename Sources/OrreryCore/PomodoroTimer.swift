import Foundation

/// The kind of phase a Pomodoro cycle is in.
public enum PomodoroPhase: String, Codable, Sendable {
    case work, shortBreak, longBreak

    public var label: String {
        switch self {
        case .work: "Work"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }
}

/// Durations and long-break cadence for a Pomodoro cycle.
public struct PomodoroSettings: Equatable, Sendable {
    public var workDuration: TimeInterval
    public var shortBreakDuration: TimeInterval
    public var longBreakDuration: TimeInterval
    public var workPhasesPerLongBreak: Int

    public init(
        workDuration: TimeInterval = 25 * 60,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 15 * 60,
        workPhasesPerLongBreak: Int = 4
    ) {
        precondition(
            workDuration > 0 && shortBreakDuration > 0 && longBreakDuration > 0
                && workPhasesPerLongBreak > 0,
            "Pomodoro durations and the long-break cadence must be positive"
        )
        self.workDuration = workDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.workPhasesPerLongBreak = workPhasesPerLongBreak
    }

    public func duration(of phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .work: workDuration
        case .shortBreak: shortBreakDuration
        case .longBreak: longBreakDuration
        }
    }
}

/// Work and break phases that advance on their own until reset.
/// Phase boundaries chain from the previous deadline, so a late `update` catches up through
/// every phase that elapsed and lands on the phase that is live now.
public final class PomodoroTimer: TimerModel {
    public let id: UUID
    public var name: String
    public let type: TimerType = .pomodoro
    public let settings: PomodoroSettings

    public private(set) var status: TimerStatus = .idle
    public private(set) var startedAt: Date?
    public private(set) var phase: PomodoroPhase = .work
    public private(set) var completedWorkPhases = 0

    private var endsAt: Date?
    private var pausedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String = "Pomodoro",
        settings: PomodoroSettings = PomodoroSettings()
    ) {
        self.id = id
        self.name = name
        self.settings = settings
    }

    public var phaseDuration: TimeInterval { settings.duration(of: phase) }

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
        phase = .work
        completedWorkPhases = 0
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
                phase: phase.label
            ))
            advance()
            self.endsAt = endsAt.addingTimeInterval(phaseDuration)
        }
        return entries
    }

    private func advance() {
        switch phase {
        case .work:
            completedWorkPhases += 1
            phase = completedWorkPhases % settings.workPhasesPerLongBreak == 0 ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .work
        }
    }
}
