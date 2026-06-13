//
//  PASPaywallFlow.swift
//  PASKitPurchases
//
//  Purchase/restore state machine for app-owned paywall UI: busy state,
//  error surface with alert-friendly binding, user-cancel swallowed
//  silently, "no purchase found" on clean-but-unentitled restores. Writes
//  no app state — gate features on the observable customerInfo as always;
//  the returned Bool exists for dismissal flow only.
//

import Foundation
import Observation
import RevenueCat

/// Drives a paywall's subscribe and restore buttons.
///
/// ```swift
/// @State private var flow = PASPaywallFlow()
///
/// Button(ctaTitle) {
///     Task { if await flow.purchase(selectedPackage, entitlement: "premium") { dismiss() } }
/// }
/// .disabled(flow.isPurchasing)
/// .alert("Error", isPresented: $flow.isShowingError) { Button("OK") {} } message: {
///     Text(flow.errorMessage ?? "")
/// }
/// ```
@Observable
@MainActor
public final class PASPaywallFlow {
    public private(set) var isPurchasing = false
    public var errorMessage: String?

    /// Alert-friendly binding — dismissing the alert clears the message.
    public var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    private let unreachableMessage: String
    private let nothingToRestoreMessage: String

    /// - Parameters:
    ///   - unreachableMessage: Shown when `purchase` receives a `nil`
    ///     package (offering never loaded — cold sheet, flaky network).
    ///   - nothingToRestoreMessage: Shown when restore succeeds but the
    ///     entitlement is still inactive.
    public init(
        unreachableMessage: String = "The App Store is unreachable right now. Please try again.",
        nothingToRestoreMessage: String = "No previous purchase was found for this Apple Account."
    ) {
        self.unreachableMessage = unreachableMessage
        self.nothingToRestoreMessage = nothingToRestoreMessage
    }

    /// Purchases the package and reports whether `entitlement` is active
    /// afterwards. User cancellation returns `false` with no error; a
    /// `nil` package surfaces the unreachable message (retry your offering
    /// load before calling, or just pass the optional).
    public func purchase(_ package: Package?, entitlement: String) async -> Bool {
        guard let package else {
            errorMessage = unreachableMessage
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await PASPurchases.shared.purchase(package)
            guard !result.userCancelled else { return false }
            return result.customerInfo.entitlements[entitlement]?.isActive == true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Restores purchases and reports whether `entitlement` came back.
    /// A clean restore that yields no entitlement surfaces the
    /// nothing-to-restore message.
    public func restore(entitlement: String) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let info = try await PASPurchases.shared.restorePurchases()
            let entitled = info.entitlements[entitlement]?.isActive == true
            if !entitled {
                errorMessage = nothingToRestoreMessage
            }
            return entitled
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

public extension PASPaywallFlow {
    /// Typed-entitlement overloads, matching `PASPurchases.isEntitled`.
    func purchase<E: RawRepresentable>(_ package: Package?, entitlement: E) async -> Bool
    where E.RawValue == String {
        await purchase(package, entitlement: entitlement.rawValue)
    }

    func restore<E: RawRepresentable>(entitlement: E) async -> Bool where E.RawValue == String {
        await restore(entitlement: entitlement.rawValue)
    }
}
