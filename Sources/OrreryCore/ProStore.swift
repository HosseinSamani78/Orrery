import StoreKit

/// StoreKit 2 owner of the Pro unlock: one non-consumable. Entitlements are the source of
/// truth, so Pro bought on another Mac restores by signing in with the same Apple ID.
@MainActor
public final class ProStore: ObservableObject {
    public static let productID = "com.orrery.pro"

    @Published public private(set) var tier: Tier = .free
    @Published public private(set) var product: Product?
    @Published public private(set) var isPurchasing = false

    private var updates: Task<Void, Never>?
    private var hasLoaded = false

    public init() {
        updates = Task { await listenForTransactions() }
    }

    deinit {
        updates?.cancel()
    }

    public var policy: AccessPolicy { AccessPolicy(tier: tier) }

    /// Loads the product for its price and reads any entitlement already on this Apple ID.
    /// Safe to call from several views; the work happens once.
    public func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        product = try? await Product.products(for: [Self.productID]).first
        await refreshEntitlements()
    }

    /// Buys Pro. Returns false when the user cancels or the purchase stays pending.
    @discardableResult
    public func purchase() async throws -> Bool {
        guard let product else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        switch try await product.purchase() {
        case .success(let result):
            let transaction = try verified(result)
            await transaction.finish()
            await refreshEntitlements()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Re-reads the entitlement, e.g. on launch or after "Restore Purchases".
    public func refreshEntitlements() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result) else { continue }
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                pro = true
            }
        }
        setTier(pro ? .pro : .free)
    }

    /// Asks the App Store for this Apple ID's purchases, then re-reads the entitlement.
    public func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? verified(result) else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    /// An unverified transaction (e.g. tampered receipt) is treated as no purchase at all.
    private func verified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction): transaction
        case .unverified(_, let error): throw error
        }
    }

    private func setTier(_ tier: Tier) {
        self.tier = tier
        SharedStore.isPro = tier == .pro
    }
}
