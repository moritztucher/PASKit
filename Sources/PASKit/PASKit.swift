//
//  PASKit.swift
//  PASKit
//
//  Umbrella module — re-exports every PASKit submodule so apps that take
//  the umbrella product can `import PASKit` once. Apps that depend only on
//  individual products (e.g. `PASKitCore`) import those directly instead.
//

@_exported import PASKitCore
@_exported import PASKitLifecycle
@_exported import PASKitAnalytics
@_exported import PASKitPurchases
@_exported import PASKitNotifications
@_exported import PASKitSharing

// PASKitHealth is deliberately NOT re-exported here. Its authorization API
// statically links HealthKit, and App Store upload validation demands
// NSHealthShareUsageDescription from any linked binary that references it —
// even a consumer with no Health feature. Apps that use Health add the
// PASKitHealth product explicitly. See
// docs/adr/ADR-0004-paskithealth-umbrella-exclusion.md.
//
// PASKitAuth is excluded for the same reason in a different costume: it links
// the Firebase iOS SDK and its transitive graph into every consumer's binary,
// and expects a bundled GoogleService-Info.plist that an account-less app has
// no reason to carry. Apps with accounts add the PASKitAuth product
// explicitly. See
// docs/adr/ADR-0005-paskitauth-scope-and-umbrella-exclusion.md.
//
// The rule these two share: the umbrella re-exports every module that does not
// force a vendor SDK or a platform capability onto apps that do not use it.
