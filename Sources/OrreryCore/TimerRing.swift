import Foundation

/// What the circular ring draws at a moment in time. `fraction` is the part of the current
/// run still left, so the arc shrinks as time passes; open-ended timers (count up, stopwatch)
/// have no total and therefore no ring.
public struct TimerRing: Equatable, Sendable {
    public let fraction: Double
    public let remaining: TimeInterval

    public init(fraction: Double, remaining: TimeInterval) {
        self.fraction = fraction
        self.remaining = remaining
    }
}

/// A timer with a known total for its current run, so it can draw a shrinking ring.
public protocol RingTimer: TimerModel {
    var ringDuration: TimeInterval { get }
    func remaining(at now: Date) -> TimeInterval
}

public extension RingTimer {
    /// Ring state at `now`; clamped so a late `update` never draws past the ends.
    func ring(at now: Date) -> TimerRing {
        let remaining = remaining(at: now)
        return TimerRing(
            fraction: min(1, max(0, remaining / ringDuration)),
            remaining: remaining
        )
    }
}

extension CountdownTimer: RingTimer {
    public var ringDuration: TimeInterval { duration }
}

extension PomodoroTimer: RingTimer {
    /// The ring tracks the live phase, not the whole cycle.
    public var ringDuration: TimeInterval { phaseDuration }
}

extension IntervalTimer: RingTimer {
    /// The ring tracks the live phase, not the whole cycle.
    public var ringDuration: TimeInterval { phaseDuration }
}
