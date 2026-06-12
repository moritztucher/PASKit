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
        // CI lints via the command plugin: `swift package plugin swiftlint`.
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.59.0"),
        // DocC — enables `swift package generate-documentation`. No catalog
        // shipped; inline `///` comments drive the docs.
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        // RevenueCat — committed vendor for PASKitPurchases.
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.67.0"),
    ],
    targets: [
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
            name: "PASKitPurchases",
            dependencies: [
                "PASKitCore",
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
