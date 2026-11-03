import Foundation

/// The SwiftData store shared by the app and its widget. Both processes open the same file and
/// each owns its own `ModelContext`; changes are signalled with `StoreChangeSignal`.
public enum SharedStore {
    /// Must match the App Group entitlement on the app and widget targets.
    public static let appGroupIdentifier = "group.com.orrery.app"

    /// The shared store file, or the app's own store when the App Group container is unavailable
    /// (unsigned builds and tests).
    public static var storeURL: URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return BoardStore.defaultStoreURL
        }
        return container.appending(path: "Orrery.store")
    }
}
