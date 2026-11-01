import Foundation

public enum TimerStatus: String, Codable, Sendable {
    case idle, running, paused, completed
}

public enum TimerType: String, Codable, Sendable {
    case countdown
    case quickStart
    case countUp
    case pomodoro
    case interval
    case stopwatch
}

/// Shared lifecycle for every timer type. Callers pass `now` explicitly so the state
/// machine stays testable and derives its state from wall-clock anchors rather than ticks.
public protocol TimerModel: AnyObject, Identifiable {
    var id: UUID { get }
    var name: String { get set }
    var type: TimerType { get }
    var status: TimerStatus { get }
    var startedAt: Date? { get }

    func start(at now: Date)
    func pause(at now: Date)
    func resume(at now: Date)
    func reset()

    /// Resolves time-dependent transitions, returning a History entry for each run that completed.
    /// A plain timer returns zero or one entry; a phase-cycling timer can catch up on several.
    func update(at now: Date) -> [HistoryEntry]
}
