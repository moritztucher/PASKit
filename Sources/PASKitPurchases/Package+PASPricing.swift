//
//  Package+PASPricing.swift
//  PASKitPurchases
//
//  Pricing math every paywall recomputes: honest savings-% against the
//  live monthly price (stays correct per storefront and after price
//  changes), free-trial detection, and the offering fallback chain.
//

import Foundation
import RevenueCat

/// Pure pricing computations — public so they're testable and reusable
/// outside RevenueCat types.
public enum PASPricingMath {
    /// Percentage saved paying `perMonth` instead of `monthlyPrice`,
    /// rounded. `nil` when inputs are non-positive or there is no real
    /// saving — so a "save X%" badge never shows 0 or negative.
    public static func savingsPercent(perMonth: Double, monthlyPrice: Double) -> Int? {
        guard perMonth > 0, monthlyPrice > 0 else { return nil }
        let savings = Int(((1 - perMonth / monthlyPrice) * 100).rounded())
        return savings > 0 ? savings : nil
    }
}

public extension StoreProduct {
    /// Savings of this (typically yearly) product's per-month price against
    /// the live monthly product. `nil` when either price is unavailable or
    /// there is no real saving.
    ///
    /// ```swift
    /// let savings = offering.annual?.storeProduct
    ///     .pasSavingsPercent(comparedToMonthly: offering.monthly?.storeProduct)
    /// // → "save \(savings)%"
    /// ```
    func pasSavingsPercent(comparedToMonthly monthly: StoreProduct?) -> Int? {
        guard let perMonth = pricePerMonth?.doubleValue, let monthly else { return nil }
        let monthlyPrice = NSDecimalNumber(decimal: monthly.price).doubleValue
        return PASPricingMath.savingsPercent(perMonth: perMonth, monthlyPrice: monthlyPrice)
    }

    /// Whether the product's introductory offer is a free trial — drives
    /// "Start N-day free trial" CTAs and trial fine print.
    var pasHasFreeTrial: Bool {
        introductoryDiscount?.paymentMode == .freeTrial
    }
}

public extension Package {
    /// `storeProduct.pasHasFreeTrial`.
    var pasHasFreeTrial: Bool {
        storeProduct.pasHasFreeTrial
    }
}

public extension PASPurchases {
    /// The first offering that exists, by identifier, falling back to the
    /// current offering — the "try the campaign offering, else default"
    /// chain.
    ///
    /// ```swift
    /// let offering = try await PASPurchases.shared.offering(firstOf: ["subscriptions", "default"])
    /// ```
    func offering(firstOf identifiers: [String]) async throws -> Offering? {
        for identifier in identifiers {
            if let offering = try await offering(identifier: identifier) {
                return offering
            }
        }
        return try await currentOffering()
    }
}
