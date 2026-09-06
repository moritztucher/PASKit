// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PASKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        // Umbrella — one dependency line gives access to every module.
        // The PASKit target re-exports the others and owns the DocC catalog.
        .library(
            name: "PASKit",
            targets: ["PASKit"]
        ),
        // Per-module — for surgical dependencies (e.g. an extension target that
        // must not link a vendor SDK).
        .library(name: "PASKitCore", targets: ["PASKitCore"]),
        .library(name: "PASKitLifecycle", targets: ["PASKitLifecycle"]),
        .library(name: "PASKitAnalytics", targets: ["PASKitAnalytics"]),
        .library(name: "PASKitPurchases", targets: ["PASKitPurchases"]),
        .library(name: "PASKitNotifications", targets: ["PASKitNotifications"]),
        .library(name: "PASKitSharing", targets: ["PASKitSharing"]),
        .library(name: "PASKitHealth", targets: ["PASKitHealth"]),
        .library(name: "PASKitAuth", targets: ["PASKitAuth"]),
    ],
    dependencies: [
        // Foundational
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
        // PostHog — pinned to the studio's known-good major.
        .package(url: "https://github.com/PostHog/posthog-ios", from: "3.48.3"),
        // Tooling — SimplyDanny/SwiftLintPlugins is the plugin-only distribution
        // of SwiftLint; avoids pulling swift-syntax into the dependency graph.
        // Deliberately NOT attached to targets as a build-tool plugin: that
        // would run lint (and require plugin trust) in every consumer's build.
        // Lint locally via the command plugin: `swift package plugin swiftlint`.
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.59.0"),
        // DocC — enables `swift package generate-documentation`. No catalog
        // shipped; inline `///` comments drive the docs.
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        // RevenueCat — committed vendor for PASKitPurchases.
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.67.0"),
        // Firebase — committed vendor for PASKitAuth. Pinned to the studio's
        // known-good major: 11.x is what XueTang ships the donor implementation
        // of these flows against, so the behaviour PASKitAuth inherits is
        // verified there. Only FirebaseAuth is taken; Firestore and Analytics
        // stay the app's own dependency.
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.15.0"),
    ],
    targets: [
        // PASKitHealth and PASKitAuth are deliberately not re-exported here.
        // Linking HealthKit makes App Store upload validation demand
        // NSHealthShareUsageDescription from every consumer, even one with no
        // Health feature — see
        // docs/adr/ADR-0004-paskithealth-umbrella-exclusion.md. PASKitAuth pulls
        // the Firebase SDK into every consumer's binary and expects a bundled
        // GoogleService-Info.plist, which an account-less app has no reason to
        // carry — see
        // docs/adr/ADR-0005-paskitauth-scope-and-umbrella-exclusion.md. Apps
        // that use either take that product explicitly.
        .target(
            name: "PASKit",
            dependencies: [
                "PASKitCore",
                "PASKitLifecycle",
                "PASKitAnalytics",
                "PASKitPurchases",
                "PASKitNotifications",
                "PASKitSharing",
            ]
        ),
        .target(
            name: "PASKitCore",
            dependencies: [
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ]
        ),
        .target(
            name: "PASKitLifecycle",
            dependencies: ["PASKitCore"]
        ),
        .target(
            name: "PASKitAnalytics",
            dependencies: [
                "PASKitCore",
                .product(name: "PostHog", package: "posthog-ios"),
            ]
        ),
        .target(
            name: "PASKitNotifications",
            dependencies: ["PASKitCore"]
        ),
        .target(
            name: "PASKitSharing",
            dependencies: ["PASKitCore"]
        ),
        .target(
            name: "PASKitHealth",
            dependencies: ["PASKitCore"]
        ),
        .target(
            name: "PASKitAuth",
            dependencies: [
                "PASKitCore",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
            ]
        ),
        .target(
            name: "PASKitPurchases",
            dependencies: [
                "PASKitCore",
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
            ]
        ),
        // Tests cover PASKitCore's pure, deterministic logic — streak engine,
        // calendar math, duration formatting, cURL rendering, settings
        // round-trips, error domain. All Foundation-only, so they run on the
        // macOS CI host without a simulator.
        .testTarget(
            name: "PASKitCoreTests",
            dependencies: ["PASKitCore"]
        ),
        // Covers PASKitLifecycle's non-UI logic — the What's New cadence gate and
        // the release-note authoring conveniences. Foundation-only, so these run
        // on the macOS CI host without a simulator.
        .testTarget(
            name: "PASKitLifecycleTests",
            dependencies: ["PASKitLifecycle"]
        ),
        // Covers PASKitNotifications' pure value types — the sound mapping and the
        // Bool-literal shim. Never touches UNUserNotificationCenter (which aborts on a
        // bundle-less macOS test host), so it runs on the CI host without a simulator.
        .testTarget(
            name: "PASKitNotificationsTests",
            dependencies: ["PASKitNotifications"]
        ),
        // Covers PASKitHealth's pure logic — the write-authorization derivation
        // and the permission descriptor. Never touches HKHealthStore (which
        // aborts on a bundle-less macOS test host and is unavailable there
        // regardless), so it runs on CI without a simulator.
        .testTarget(
            name: "PASKitHealthTests",
            dependencies: ["PASKitHealth"]
        ),
        // Covers PASKitAuth's pure logic — nonce generation and hashing, and the
        // value types crossing the delegate boundary. Never touches
        // Auth.auth() (which needs a configured FirebaseApp and a real bundle),
        // so it runs on the CI host without a simulator.
        .testTarget(
            name: "PASKitAuthTests",
            dependencies: ["PASKitAuth"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
