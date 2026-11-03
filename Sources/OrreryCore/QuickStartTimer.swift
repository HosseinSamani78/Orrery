import Foundation

/// Quick start: a countdown that begins the moment it is created, using a default duration.
public enum QuickStartTimer {
    public static let defaultDuration: TimeInterval = 300

    /// A running countdown at `now`, so one keystroke is enough to start timing.
    public static func start(
        id: UUID = UUID(),
        name: String = "Quick start",
        duration: TimeInterval = defaultDuration,
        at now: Date
    ) -> CountdownTimer {
        let timer = CountdownTimer(id: id, name: name, duration: duration, type: .quickStart)
        timer.start(at: now)
        return timer
    }
}
