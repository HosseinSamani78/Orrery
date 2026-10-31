import Foundation

/// Created once per completed Run, for later review.
public struct HistoryEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let timerID: UUID
    public let timerName: String
    public let timerType: TimerType
    public let startedAt: Date
    public let completedAt: Date
    public let plannedDuration: TimeInterval
    public let elapsed: TimeInterval
    /// Label of the completed phase for phase-cycling timers (Pomodoro, interval); `nil` otherwise.
    public let phase: String?

    public init(
        id: UUID = UUID(),
        timerID: UUID,
        timerName: String,
        timerType: TimerType,
        startedAt: Date,
        completedAt: Date,
        plannedDuration: TimeInterval,
        elapsed: TimeInterval,
        phase: String? = nil
    ) {
        self.id = id
        self.timerID = timerID
        self.timerName = timerName
        self.timerType = timerType
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.plannedDuration = plannedDuration
        self.elapsed = elapsed
        self.phase = phase
    }
}
