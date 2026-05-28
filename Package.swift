// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PASKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        // Umbrella — one dependency line gives access to every module.
        .library(
            name: "PASKit",
            targets: ["PASKitCore", "PASKitLifecycle", "PASKitPurchases", "PASKitAnalytics"]
        ),
        // Per-module — for surgical dependencies (e.g. an extension target that
        // must not link a vendor SDK).
        .library(name: "PASKitCore", targets: ["PASKitCore"]),
        .library(name: "PASKitLifecycle", targets: ["PASKitLifecycle"]),
        .library(name: "PASKitPurchases", targets: ["PASKitPurchases"]),
        .library(name: "PASKitAnalytics", targets: ["PASKitAnalytics"]),
    ],
    dependencies: [
        // Foundational
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
        // RevenueCat — SPM-optimised mirror, pinned to the studio's known-good major.
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.67.0"),
        // PostHog — pinned to the studio's known-good major.
        .package(url: "https://github.com/PostHog/posthog-ios", from: "3.48.3"),
        // Tooling — SimplyDanny/SwiftLintPlugins is the plugin-only distribution
        // of SwiftLint; avoids pulling swift-syntax into the dependency graph.
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.59.0"),
        // DocC — enables `swift package generate-documentation`. No catalog
        // shipped; inline `///` comments drive the docs.
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "PASKitCore",
            dependencies: [
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .target(
            name: "PASKitLifecycle",
            dependencies: ["PASKitCore"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .target(
            name: "PASKitPurchases",
            dependencies: [
                "PASKitCore",
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .target(
            name: "PASKitAnalytics",
            dependencies: [
                "PASKitCore",
                .product(name: "PostHog", package: "posthog-ios"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
