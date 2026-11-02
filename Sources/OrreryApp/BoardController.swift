import Combine
import Foundation
import OrreryCore
import WidgetKit

/// Owns the live timers and the keyboard focus for both surfaces. SwiftUI re-reads `store`
/// whenever a published value changes; timer types stay plain, non-observable state machines.
@MainActor
final class BoardController: ObservableObject {
    let store: TimerStore
    private let boardStore: BoardStore?
    @Published private(set) var focus: TimerFocus
    @Published private(set) var now: Date = .now

    init(store: TimerStore = TimerStore(), boardStore: BoardStore? = try? BoardStore()) {
        self.store = store
        self.boardStore = boardStore
        // Restore the shared store so the app opens with what the widget was showing.
        if let boardStore, let board = try? boardStore.boards().first {
            for timer in board.liveTimers where store.timer(id: timer.id) == nil {
                store.add(timer)
            }
        }
        self.focus = TimerFocus(selectedID: store.timers.first?.id)
    }

    var timers: [any TimerModel] { store.timers }
    var selectedID: UUID? { focus.selectedID }

    /// Advances every timer and republishes the clock so the views redraw.
    func advance(to date: Date) {
        let completed = store.update(at: date)
        now = date
        if !completed.isEmpty {
            persist()
        }
    }

    func select(_ id: UUID) {
        focus.select(id)
    }

    func moveFocus(by step: Int) {
        focus.move(by: step, through: timers.map(\.id))
    }

    @discardableResult
    func perform(_ action: TimerAction) -> Bool {
        if action == .quickStart {
            let timer = store.quickStart(at: now)
            focus.select(timer.id)
            persist()
            return true
        }
        // Nothing focused yet: pick the first timer so a shortcut still does something.
        if focus.selectedID == nil {
            focus.move(by: 0, through: timers.map(\.id))
        }
        guard let id = focus.selectedID else { return false }
        let performed = store.perform(action, on: id, at: now)
        // A delete leaves the old id behind; zero-step navigation repairs the selection.
        focus.move(by: 0, through: timers.map(\.id))
        if performed {
            persist()
        }
        return performed
    }

    /// Writes the countdown timers to the shared store, then tells the widget to re-read it.
    /// Only called when a run starts, pauses, completes or disappears, never on every tick.
    private func persist() {
        guard let boardStore else { return }
        do {
            let board: Board
            if let existing = try boardStore.boards().first {
                board = existing
            } else {
                board = try boardStore.createBoard(named: "Orrery")
            }
            let live = store.timers.compactMap { $0 as? CountdownTimer }
            for timer in live {
                board.record(timer)
            }
            for record in board.timers where !live.contains(where: { $0.id == record.timerID }) {
                board.removeRecord(id: record.timerID)
            }
            try boardStore.save()
            StoreChangeSignal.post()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // The widget keeps the last saved state; the next change retries.
        }
    }
}
