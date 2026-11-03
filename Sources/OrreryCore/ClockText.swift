import Foundation

/// The clock style shared by the rows, the menu bar and completion alerts: `5:00`, or `1:05:00`
/// once an hour is in play.
public enum ClockText {
    public static func format(_ seconds: TimeInterval, roundingUp: Bool = false) -> String {
        let total = Int(roundingUp ? seconds.rounded(.up) : seconds.rounded(.down))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let remainder = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%d:%02d", minutes, remainder)
    }
}
