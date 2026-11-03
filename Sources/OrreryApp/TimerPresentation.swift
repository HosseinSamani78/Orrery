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
    ClockText.format(seconds, roundingUp: roundingUp)
}

/// What VoiceOver reads for a timer row: name, state, then the clock, so the visual layout
/// does not have to be mirrored in separate labels.
func spokenDescription(for timer: any TimerModel, at now: Date) -> String {
    "\(timer.name), \(timer.status.label), \(clockText(for: timer, at: now))"
}

extension TimerModel {
    var statusLabel: String { status.label }

    var symbolName: String { type.symbolName }
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

    /// What VoiceOver reads for the lifecycle button, whose SF Symbol carries no text.
    var actionLabel: String {
        switch self {
        case .idle: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        case .completed: "Reset"
        }
    }
}
