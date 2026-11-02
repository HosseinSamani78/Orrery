import Foundation

/// Cross-process "the store changed, go re-read it" ping. Darwin notifications carry no payload,
/// so the store file stays the source of truth and this only avoids polling.
public enum StoreChangeSignal {
    public static let name = "com.orrery.storeDidChange"

    public static func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }

    public static func observe(_ handler: @escaping @Sendable () -> Void) -> Observation {
        Observation(handler: handler)
    }

    /// Keeps the Darwin observer alive; cancelling (or releasing it) stops delivery.
    public final class Observation: @unchecked Sendable {
        private let handler: @Sendable () -> Void
        private let lock = NSLock()
        private var isObserving = true

        public init(handler: @escaping @Sendable () -> Void) {
            self.handler = handler
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                Unmanaged.passUnretained(self).toOpaque(),
                { _, observer, _, _, _ in
                    guard let observer else { return }
                    Unmanaged<Observation>.fromOpaque(observer).takeUnretainedValue().handler()
                },
                StoreChangeSignal.name as CFString,
                nil,
                .deliverImmediately
            )
        }

        deinit {
            cancel()
        }

        public func cancel() {
            lock.lock()
            defer { lock.unlock() }
            guard isObserving else { return }
            isObserving = false
            CFNotificationCenterRemoveObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                Unmanaged.passUnretained(self).toOpaque(),
                CFNotificationName(StoreChangeSignal.name as CFString),
                nil
            )
        }
    }
}
