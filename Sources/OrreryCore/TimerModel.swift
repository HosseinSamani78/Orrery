import Foundation

public enum TimerStatus: String, Codable, Sendable {
    case idle, running, paused, completed
}

public enum TimerType: String, Codable, Sendable {
    case countdown
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

    /// Resolves time-dependent transitions. Returns a History entry the one time the run completes.
    func update(at now: Date) -> HistoryEntry?
}
