//
//  PASPurchases.swift
//  PASKitPurchases
//
//  Thin concrete facade over the RevenueCat SDK — a convenience wrapper,
//  not a vendor abstraction. RevenueCat types (`Offering`, `Package`,
//  `CustomerInfo`, `StoreProduct`) pass through unwrapped; PASKit owns the
//  mechanism (configure, observe, purchase, restore, identity), each app
//  owns its vocabulary (entitlement IDs, product IDs, paywall UI).
//

import Foundation
import PASKitCore
import RevenueCat

/// RevenueCat facade. `PASPurchases.shared.configure(...)` once at launch,
/// then observe `customerInfo` / `isEntitled` for gating and call
/// `offerings` / `purchase` / `restore` from the app's paywall and shop.
///
/// Entitlement checks accept any `String`-backed enum, so apps keep their
/// entitlement vocabulary typed:
/// ```swift
/// enum Entitlement: String { case premium }
/// if PASPurchases.shared.isEntitled(Entitlement.premium) { … }
/// ```
@MainActor
@Observable
public final class PASPurchases {

    public static let shared = PASPurchases()

    /// Latest customer info from RevenueCat. Kept current by the SDK's
    /// customer-info stream from `configure` onward — purchases, renewals,
    /// refunds, restores, and other-device changes all land here. Observable;
    /// gate features on it rather than caching booleans.
    public private(set) var customerInfo: CustomerInfo?

    public private(set) var isConfigured = false

    private let log = PASLogger.make(category: "purchases")
    @ObservationIgnored private var customerInfoTask: Task<Void, Never>?

    private init() {}

    // MARK: - Setup

    /// Configure the RevenueCat SDK and start observing customer info.
    /// Call once, early at launch, before any paywall or purchase UI.
    /// Subsequent calls log a warning and no-op.
    public func configure(_ config: PASPurchasesConfig) {
        guard !isConfigured else {
            log.warning("PASPurchases.configure called twice — ignoring the second call.")
            return
        }
        Purchases.logLevel = config.debugLogs ? .debug : .warn
        Purchases.configure(withAPIKey: config.apiKey, appUserID: config.appUserID)
        isConfigured = true
        customerInfoTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.customerInfo = info
            }
        }
        log.info("RevenueCat configured.")
    }

    // MARK: - Entitlements

    /// Whether the entitlement is currently active. `false` until the first
    /// customer info arrives — treat as "not entitled yet", not as an error.
    public func isEntitled(_ entitlementID: String) -> Bool {
        customerInfo?.entitlements[entitlementID]?.isActive == true
    }

    /// Typed variant for the app's `String`-backed entitlement enum.
    public func isEntitled<E: RawRepresentable>(_ entitlement: E) -> Bool where E.RawValue == String {
        isEntitled(entitlement.rawValue)
    }

    // MARK: - Offerings & products

    /// All offerings configured in the RevenueCat dashboard.
    public func offerings() async throws -> Offerings {
        try ensureConfigured()
        return try await Purchases.shared.offerings()
    }

    /// The dashboard's current offering, or `nil` if none is set.
    public func currentOffering() async throws -> Offering? {
        try await offerings().current
    }

    /// A specific offering by identifier, or `nil` if it doesn't exist.
    public func offering(identifier: String) async throws -> Offering? {
        try await offerings().offering(identifier: identifier)
    }

    /// Store products by product ID — for products purchased outside an
    /// offering (e.g. consumable credit packs addressed directly).
    public func products(_ productIDs: [String]) async throws -> [StoreProduct] {
        try ensureConfigured()
        return await Purchases.shared.products(productIDs)
    }

    // MARK: - Purchase

    /// Purchase a package from an offering. Inspect `userCancelled` before
    /// treating a thrown-free return as success, and derive access from the
    /// entitlement — not from the absence of an error.
    @discardableResult
    public func purchase(_ package: Package) async throws -> PASPurchaseResult {
        try ensureConfigured()
        let (transaction, info, userCancelled) = try await Purchases.shared.purchase(package: package)
        customerInfo = info
        return PASPurchaseResult(customerInfo: info, transaction: transaction, userCancelled: userCancelled)
    }

    /// Purchase a store product directly (offering-less consumables).
    @discardableResult
    public func purchase(_ product: StoreProduct) async throws -> PASPurchaseResult {
        try ensureConfigured()
        let (transaction, info, userCancelled) = try await Purchases.shared.purchase(product: product)
        customerInfo = info
        return PASPurchaseResult(customerInfo: info, transaction: transaction, userCancelled: userCancelled)
    }

    /// Restore previous purchases — wire to an explicit "Restore Purchases"
    /// control (App Review requires one).
    @discardableResult
    public func restorePurchases() async throws -> CustomerInfo {
        try ensureConfigured()
        let info = try await Purchases.shared.restorePurchases()
        customerInfo = info
        return info
    }

    // MARK: - Identity

    /// Associate purchases with a known user. Use the same ID passed to
    /// `PASAnalytics.identify` so revenue and analytics join on one key.
    @discardableResult
    public func logIn(userId: String) async throws -> CustomerInfo {
        try ensureConfigured()
        let (info, _) = try await Purchases.shared.logIn(userId)
        customerInfo = info
        return info
    }

    /// Reset to a new anonymous user — call on logout.
    @discardableResult
    public func logOut() async throws -> CustomerInfo {
        try ensureConfigured()
        let info = try await Purchases.shared.logOut()
        customerInfo = info
        return info
    }

    // MARK: - Private

    private func ensureConfigured() throws {
        guard isConfigured else {
            log.error("PASPurchases used before configure — call configure(_:) at launch.")
            throw PASError.unexpected(description: "PASPurchases.configure(_:) was not called.")
        }
    }
}
