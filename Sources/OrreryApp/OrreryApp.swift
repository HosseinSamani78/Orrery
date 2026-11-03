import SwiftUI
import OrreryCore

@main
@MainActor
struct OrreryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = BoardController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller)
        } label: {
            MenuBarLabel(controller: controller)
        }
        .menuBarExtraStyle(.window)

        Window("Orrery", id: BoardWindow.id) {
            BoardView(controller: controller)
        }
        .defaultSize(width: 380, height: 440)
        .commands { TimerCommands(controller: controller) }
    }
}

enum BoardWindow {
    static let id = "board"
}

/// Menu-bar-first: no Dock icon, the menu-bar extra is the entry point.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    /// Finder double-click on a `.orreryboard` file reaches the app through here.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.pathExtension == BoardDocument.fileExtension {
            NotificationCenter.default.post(name: .openBoardDocument, object: url)
        }
    }
}

extension Notification.Name {
    static let openBoardDocument = Notification.Name("OrreryOpenBoardDocument")
}

struct MenuBarLabel: View {
    @ObservedObject var controller: BoardController

    var body: some View {
        let running = controller.timers.filter { $0.status == .running }.count
        Label(running == 0 ? "Orrery" : "Orrery \(running)", systemImage: "circle.dashed")
    }
}

/// Menu commands share the core's default shortcuts, so the window, the menu bar and the
/// keyboard all drive timers through the same `TimerAction` path.
struct TimerCommands: Commands {
    let controller: BoardController

    var body: some Commands {
        CommandMenu("Timer") {
            ForEach(TimerShortcut.defaults, id: \.action) { shortcut in
                Button(shortcut.action.menuTitle) {
                    controller.perform(shortcut.action)
                }
                .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers.eventModifiers)
            }
        }
        CommandGroup(replacing: .appTermination) {
            Button("Quit Orrery") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        CommandGroup(replacing: .importExport) {
            Button("Export Board…") { controller.exportBoard() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
}

extension ShortcutModifiers {
    var eventModifiers: EventModifiers {
        var modifiers: EventModifiers = []
        if contains(.command) { modifiers.insert(.command) }
        if contains(.shift) { modifiers.insert(.shift) }
        if contains(.option) { modifiers.insert(.option) }
        if contains(.control) { modifiers.insert(.control) }
        return modifiers
    }
}

extension TimerShortcut {
    var keyEquivalent: KeyEquivalent { KeyEquivalent(key) }
}

extension TimerAction {
    var menuTitle: String {
        switch self {
        case .start: "Start"
        case .pause: "Pause"
        case .resume: "Resume"
        case .toggle: "Start / Pause"
        case .reset: "Reset Timer"
        case .delete: "Delete Timer"
        case .quickStart: "Quick Start"
        }
    }
}
