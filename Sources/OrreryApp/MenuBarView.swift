import SwiftUI
import OrreryCore

struct MenuBarView: View {
    @ObservedObject var controller: BoardController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if controller.timers.isEmpty {
                Text("No timers")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(controller.timers, id: \.id) { timer in
                    HStack(spacing: 8) {
                        Image(systemName: timer.symbolName)
                            .frame(width: 16)
                        Text(timer.name)
                            .lineLimit(1)
                        Spacer()
                        Text(clockText(for: timer, at: controller.now))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Button {
                            controller.select(timer.id)
                            controller.perform(timer.status.action)
                        } label: {
                            Image(systemName: timer.status.actionSymbol)
                        }
                        .buttonStyle(.borderless)
                        .help(timer.status.action.menuTitle)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { controller.select(timer.id) }
                }
            }

            Divider()

            Button("Quick Start") { controller.perform(.quickStart) }
                .keyboardShortcut("n")
            Button("Open Orrery") {
                openWindow(id: BoardWindow.id)
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("o")
            Divider()
            Button("Quit Orrery") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 280)
    }
}
