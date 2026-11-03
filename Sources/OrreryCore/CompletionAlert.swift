import Foundation

/// What a completed Run announces: the banner title and body, shared by the notification,
/// the sound cue and the VoiceOver announcement so all three say the same thing.
public struct CompletionAlert: Equatable, Sendable {
    public let title: String
    public let body: String

    /// A finished phase names itself, so a Pomodoro break is not announced as the whole timer.
    public init(_ entry: HistoryEntry) {
        if let phase = entry.phase {
            title = "\(entry.timerName) — \(phase) done"
        } else {
            title = "\(entry.timerName) done"
        }
        body = "Finished after \(ClockText.format(entry.elapsed))."
    }
}
