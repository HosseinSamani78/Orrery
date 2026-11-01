import Foundation

/// What a keyboard shortcut asks of a timer. `toggle` is the single-key lifecycle action:
/// start when idle, pause when running, resume when paused.
public enum TimerAction: String, CaseIterable, Codable, Sendable {
    case start, pause, resume, toggle, reset, delete, quickStart
}

/// Modifier keys of a shortcut, mirroring the platform's key equivalents.
public struct ShortcutModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = ShortcutModifiers(rawValue: 1 << 0)
    public static let shift = ShortcutModifiers(rawValue: 1 << 1)
    public static let option = ShortcutModifiers(rawValue: 1 << 2)
    public static let control = ShortcutModifiers(rawValue: 1 << 3)
}

/// One keyboard binding for a timer action.
public struct TimerShortcut: Equatable, Sendable {
    public let action: TimerAction
    public let key: Character
    public let modifiers: ShortcutModifiers

    public init(action: TimerAction, key: Character, modifiers: ShortcutModifiers = []) {
        self.action = action
        self.key = key
        self.modifiers = modifiers
    }

    /// Space toggles the focused timer, ⌘N quick-starts, ⌘R resets, ⌘⌫ deletes.
    public static let defaults: [TimerShortcut] = [
        TimerShortcut(action: .toggle, key: " "),
        TimerShortcut(action: .quickStart, key: "n", modifiers: .command),
        TimerShortcut(action: .reset, key: "r", modifiers: .command),
        TimerShortcut(action: .delete, key: "\u{7F}", modifiers: .command),
    ]

    public static func action(
        forKey key: Character,
        modifiers: ShortcutModifiers = []
    ) -> TimerAction? {
        defaults.first { $0.key == key && $0.modifiers == modifiers }?.action
    }
}
