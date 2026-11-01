import Combine
import Foundation
import OrreryCore

/// Owns the live timers and the keyboard focus for both surfaces. SwiftUI re-reads `store`
/// whenever a published value changes; timer types stay plain, non-observable state machines.
@MainActor
final class BoardController: ObservableObject {
    let store: TimerStore
    @Published private(set) var focus: TimerFocus
    @Published private(set) var now: Date = .now

    init(store: TimerStore = TimerStore()) {
        self.store = store
        self.focus = TimerFocus(selectedID: store.timers.first?.id)
    }

    var timers: [any TimerModel] { store.timers }
    var selectedID: UUID? { focus.selectedID }

    /// Advances every timer and republishes the clock so the views redraw.
    func advance(to date: Date) {
        store.update(at: date)
        now = date
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
        return performed
    }
}
