import Foundation
import OrreryCore

/// Time left for a ringing timer, elapsed time for open-ended ones.
func clockText(for timer: any TimerModel, at now: Date) -> String {
    if let ring = timer as? any RingTimer {
        return clockText(ring.remaining(at: now), roundingUp: true)
    }
    if let countUp = timer as? CountUpTimer {
        return clockText(countUp.elapsed(at: now))
    }
    if let stopwatch = timer as? StopwatchTimer {
        return clockText(stopwatch.elapsed(at: now))
    }
    return "--:--"
}

private func clockText(_ seconds: TimeInterval, roundingUp: Bool = false) -> String {
    let total = Int(roundingUp ? seconds.rounded(.up) : seconds.rounded(.down))
    let hours = total / 3600
    let minutes = total % 3600 / 60
    let remaining = total % 60
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, minutes, remaining)
        : String(format: "%d:%02d", minutes, remaining)
}

extension TimerModel {
    var statusLabel: String {
        switch status {
        case .idle: "Idle"
        case .running: "Running"
        case .paused: "Paused"
        case .completed: "Done"
        }
    }

    var symbolName: String {
        switch type {
        case .countdown: "hourglass"
        case .quickStart: "bolt"
        case .countUp: "arrow.up"
        case .pomodoro: "circle.dotted"
        case .interval: "repeat"
        case .stopwatch: "stopwatch"
        }
    }
}

extension TimerStatus {
    /// The lifecycle button in a row: start, pause or resume; completed timers reset.
    var actionSymbol: String {
        switch self {
        case .idle: "play.fill"
        case .running: "pause.fill"
        case .paused: "play.fill"
        case .completed: "arrow.counterclockwise"
        }
    }

    var action: TimerAction {
        switch self {
        case .idle, .paused: .toggle
        case .running: .pause
        case .completed: .reset
        }
    }
}
