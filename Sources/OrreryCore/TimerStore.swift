import Foundation

/// In-memory owner of timers and completed-run history. Delete and history recording live here;
/// persistence (#14) can back the same API without touching the state machines.
public final class TimerStore {
    public private(set) var timers: [any TimerModel]
    public private(set) var history: [HistoryEntry] = []

    public init(timers: [any TimerModel] = []) {
        self.timers = timers
    }

    public func add(_ timer: any TimerModel) {
        timers.append(timer)
    }

    public func timer(id: UUID) -> (any TimerModel)? {
        timers.first { $0.id == id }
    }

    public func delete(id: UUID) {
        timers.removeAll { $0.id == id }
    }

    /// Drives every timer to `now`; appends a History entry for each run that just completed.
    public func update(at now: Date) {
        for timer in timers {
            if let entry = timer.update(at: now) {
                history.append(entry)
            }
        }
    }
}
