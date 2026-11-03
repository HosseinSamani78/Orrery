import AppKit
import OrreryCore
import UserNotifications

/// Announces finished Runs: a system sound, a VoiceOver announcement, and a notification banner.
/// The banner needs a bundled, signed app — `swift run` has no bundle identifier, and asking
/// `UNUserNotificationCenter.current()` for one aborts the process — so there it is skipped.
@MainActor
final class CompletionNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter?

    override init() {
        center = Bundle.main.bundleIdentifier == nil ? nil : .current()
        super.init()
        center?.delegate = self
    }

    /// Asked for once at launch; a denial only silences the banners, never the sound.
    func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func announce(_ entries: [HistoryEntry]) {
        for entry in entries {
            let alert = CompletionAlert(entry)
            NSSound(named: "Glass")?.play()
            announceToVoiceOver("\(alert.title). \(alert.body)")
            guard let center else { continue }
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            center.add(UNNotificationRequest(identifier: entry.id.uuidString, content: content, trigger: nil))
        }
    }

    /// A menu-bar app is usually not frontmost, but the board window may be; VoiceOver users
    /// need the completion spoken wherever they are.
    private func announceToVoiceOver(_ text: String) {
        guard NSWorkspace.shared.isVoiceOverEnabled else { return }
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }

    /// Without this the banner is swallowed while Orrery is the active app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}
