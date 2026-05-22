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
            targets: ["PASKitCore", "PASKitUI", "PASKitPurchases", "PASKitAnalytics"]
        ),
        // Per-module — for surgical dependencies (e.g. an extension target that
        // must not link a vendor SDK).
        .library(name: "PASKitCore", targets: ["PASKitCore"]),
        .library(name: "PASKitUI", targets: ["PASKitUI"]),
        .library(name: "PASKitPurchases", targets: ["PASKitPurchases"]),
        .library(name: "PASKitAnalytics", targets: ["PASKitAnalytics"]),
    ],
    dependencies: [
        // Foundational
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
        // RevenueCat — SPM-optimised mirror, pinned to the studio's known-good major.
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.67.0"),
        // PostHog — pinned to the studio's known-good major.
        .package(url: "https://github.com/PostHog/posthog-ios", from: "3.48.3"),
    ],
    targets: [
        .target(
            name: "PASKitCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ]
        ),
        .target(name: "PASKitUI"),
        .target(
            name: "PASKitPurchases",
            dependencies: [
                "PASKitCore",
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
            ]
        ),
        .target(
            name: "PASKitAnalytics",
            dependencies: [
                "PASKitCore",
                .product(name: "PostHog", package: "posthog-ios"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
