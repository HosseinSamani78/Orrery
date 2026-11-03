import Foundation

/// What the running copy is allowed to do. `pro` comes from the StoreKit 2 entitlement.
public enum Tier: Sendable {
    case free
    case pro
}

/// The free tier's ceilings. Pro has none.
public enum FreeLimits {
    public static let boards = 1
    public static let timers = 3
}

/// Decides whether one more Board or Timer may be added. The app and any future surface
/// share these rules so a limit cannot drift between entry points.
public struct AccessPolicy: Sendable, Equatable {
    public let tier: Tier

    public init(tier: Tier) {
        self.tier = tier
    }

    public static let free = AccessPolicy(tier: .free)
    public static let pro = AccessPolicy(tier: .pro)

    /// Widgets are the Pro feature; the free tier is the app alone.
    public var widgetsEnabled: Bool { tier == .pro }

    public func canAddBoard(existing: Int) -> Bool {
        tier == .pro || existing < FreeLimits.boards
    }

    public func canAddTimer(existing: Int) -> Bool {
        tier == .pro || existing < FreeLimits.timers
    }
}

extension SharedStore {
    /// Mirror of the StoreKit entitlement for the widget process, which cannot present a
    /// purchase. The app's entitlement check stays authoritative; this only unlocks widget UI.
    public static var isPro: Bool {
        get { defaults.bool(forKey: "OrreryPro") }
        set { defaults.set(newValue, forKey: "OrreryPro") }
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
