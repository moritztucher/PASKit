//
//  PASPurchaseResult.swift
//  PASKitPurchases
//
//  Outcome of a purchase call. Mirrors RevenueCat's tuple return as a
//  named type so call sites read clearly.
//

import RevenueCat

/// Result of `PASPurchases.purchase`. A non-throwing return is **not**
/// success by itself — check `userCancelled`, then gate on the entitlement
/// in `customerInfo`.
public struct PASPurchaseResult: Sendable {

    /// Customer info as of this purchase — entitlements already reflect it.
    public let customerInfo: CustomerInfo

    /// The completed store transaction, when one occurred.
    public let transaction: StoreTransaction?

    /// `true` when the user dismissed the system purchase sheet.
    public let userCancelled: Bool

    public init(customerInfo: CustomerInfo, transaction: StoreTransaction?, userCancelled: Bool) {
        self.customerInfo = customerInfo
        self.transaction = transaction
        self.userCancelled = userCancelled
    }
}
