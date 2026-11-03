import SwiftUI
import OrreryCore

struct BoardView: View {
    @ObservedObject var controller: BoardController
    @FocusState private var hasFocus: Bool

    var body: some View {
        Group {
            if controller.timers.isEmpty {
                ContentUnavailableView {
                    Label("No timers", systemImage: "timer")
                } description: {
                    Text("Press ⌘N to quick-start a timer.")
                }
            } else {
                List {
                    ForEach(controller.timers, id: \.id) { timer in
                        TimerRow(
                            timer: timer,
                            now: controller.now,
                            focused: timer.id == controller.selectedID,
                            toggle: { controller.perform(timer.status.action) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            controller.select(timer.id)
                            hasFocus = true
                        }
                        .listRowBackground(
                            timer.id == controller.selectedID
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 320, minHeight: 260)
        .focusable()
        .focused($hasFocus)
        .focusEffectDisabled()
        .onAppear { hasFocus = true }
        .onKeyPress(.upArrow) {
            controller.moveFocus(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            controller.moveFocus(by: 1)
            return .handled
        }
        .onKeyPress(.space) {
            controller.perform(.toggle)
            return .handled
        }
        .sheet(item: $controller.upgradeReason) { reason in
            UpgradeView(pro: controller.pro, reason: reason)
        }
    }
}

private struct TimerRow: View {
    let timer: any TimerModel
    let now: Date
    let focused: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RingBadge(timer: timer, now: now)

            VStack(alignment: .leading, spacing: 2) {
                Text(timer.name)
                    .font(.headline)
                Text(timer.statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(clockText(for: timer, at: now))
                .font(.title3.monospacedDigit())
                .foregroundStyle(focused ? .primary : .secondary)

            Button(action: toggle) {
                Image(systemName: timer.status.actionSymbol)
            }
            .buttonStyle(.borderless)
            .help(timer.status.action.menuTitle)
            .accessibilityLabel("\(timer.status.actionLabel) \(timer.name)")
        }
        .padding(.vertical, 4)
        // One VoiceOver stop per row; the row's button becomes a named action on it.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenDescription(for: timer, at: now))
        .accessibilityAddTraits(focused ? .isSelected : [])
    }
}

private struct RingBadge: View {
    let timer: any TimerModel
    let now: Date

    var body: some View {
        let fraction = (timer as? any RingTimer)?.ring(at: now).fraction
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 3)
            if let fraction {
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Image(systemName: timer.symbolName)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(width: 28, height: 28)
        // Decorative: the row's spoken description already carries the time.
        .accessibilityHidden(true)
    }
}
