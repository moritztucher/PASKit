//
//  PASDistribution.swift
//  PASKitCore
//
//  How this install reached the device, read at runtime from StoreKit 2's
//  `AppTransaction`. A runtime check (not a build flag) because the same
//  binary is promoted from TestFlight to the App Store.
//

import Foundation
import StoreKit

/// How this install reached the device, from StoreKit 2's `AppTransaction`.
///
/// | `AppTransaction.environment` | Value |
/// |---|---|
/// | `.production` | `.appStore` |
/// | `.sandbox` (TestFlight; also a device run without a StoreKit config) | `.testFlight` |
/// | `.xcode` | `.development` |
/// | probe threw / timed out / unrecognised | `.unknown` in Release, `.development` in DEBUG builds |
///
/// Treat `.unknown` as "not App Store" — fail closed.
public enum PASDistribution: String, Sendable, Codable, CaseIterable {
    case appStore, testFlight, development, unknown

    /// Only `.appStore`. Gate anything that must not run on tester/dev installs on this.
    public var isAppStore: Bool { self == .appStore }

    /// Lower-case analytics-property value: `"appstore"` / `"testflight"` / `"development"` / `"unknown"`.
    public var analyticsValue: String { rawValue.lowercased() }

    /// PASKit's own `DEBUG` compile condition, not the app's flag. Xcode builds package
    /// dependencies in the app's configuration, so in practice it follows the app's
    /// Debug/Release, but apps that need certainty should gate on their own `#if DEBUG`.
    /// Only used to map an unresolved probe to `.development` instead of `.unknown`.
    static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// Verified and unverified alike yield their `environment`: verification fails on
    /// clock skew or jailbroken devices, and the field is not what an attacker would forge
    /// to *receive* analytics. Pure, test seam.
    static func environment(of check: AppTransactionCheck) -> AppStore.Environment {
        switch check {
        case .verified(let environment), .unverified(let environment): environment
        }
    }

    /// Pure mapping, test seam. `nil` environment = probe failed or timed out.
    static func classify(_ environment: AppStore.Environment?,
                         debugBuild: Bool = isDebugBuild) -> PASDistribution {
        switch environment {
        case .some(.production): return .appStore
        case .some(.sandbox): return .testFlight
        case .some(.xcode): return .development
        default: return debugBuild ? .development : .unknown
        }
    }
}

/// StoreKit's `VerificationResult<AppTransaction>` reduced to what classification needs,
/// so the verified/unverified rule is testable without a real transaction.
enum AppTransactionCheck: Sendable, Equatable {
    case verified(AppStore.Environment)
    case unverified(AppStore.Environment)
}
