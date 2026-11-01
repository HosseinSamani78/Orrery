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

    /// Starts and adds a quick-start countdown in one call.
    @discardableResult
    public func quickStart(
        at now: Date,
        duration: TimeInterval = QuickStartTimer.defaultDuration
    ) -> CountdownTimer {
        let timer = QuickStartTimer.start(duration: duration, at: now)
        add(timer)
        return timer
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
            history.append(contentsOf: timer.update(at: now))
        }
    }

    /// Applies a keyboard action to one timer, so shortcuts and menu items share one path.
    /// `quickStart` adds a new timer and ignores `id`. Returns false when the timer is unknown
    /// or the action does not apply (e.g. toggle on a completed timer).
    @discardableResult
    public func perform(_ action: TimerAction, on id: UUID, at now: Date) -> Bool {
        if action == .quickStart {
            quickStart(at: now)
            return true
        }
        guard let timer = timer(id: id) else { return false }

        switch action {
        case .start:
            timer.start(at: now)
        case .pause:
            timer.pause(at: now)
        case .resume:
            timer.resume(at: now)
        case .toggle:
            switch timer.status {
            case .idle: timer.start(at: now)
            case .running: timer.pause(at: now)
            case .paused: timer.resume(at: now)
            case .completed: return false
            }
        case .reset:
            timer.reset()
        case .delete:
            delete(id: id)
        case .quickStart:
            break
        }
        return true
    }
}
