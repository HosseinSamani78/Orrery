import Foundation

/// Which timer keyboard navigation is acting on. A value type so the window and the menu bar
/// share one selection without owning each other's state.
public struct TimerFocus: Equatable, Sendable {
    public private(set) var selectedID: UUID?

    public init(selectedID: UUID? = nil) {
        self.selectedID = selectedID
    }

    public mutating func select(_ id: UUID?) {
        selectedID = id
    }

    /// Moves `step` places through `ids`, wrapping at either end. A selection that is absent
    /// or no longer on the board (deleted timer) falls back to the first timer, or the last
    /// when moving backwards.
    public mutating func move(by step: Int, through ids: [UUID]) {
        guard let first = ids.first else {
            selectedID = nil
            return
        }
        guard let index = selectedID.flatMap(ids.firstIndex(of:)) else {
            selectedID = step < 0 ? ids.last : first
            return
        }
        let count = ids.count
        selectedID = ids[((index + step) % count + count) % count]
    }
}
