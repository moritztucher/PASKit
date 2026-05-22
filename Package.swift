// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PASKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PASKitCore", targets: ["PASKitCore"]),
        .library(name: "PASKitPurchases", targets: ["PASKitPurchases"]),
        .library(name: "PASKitAnalytics", targets: ["PASKitAnalytics"]),
    ],
    dependencies: [
        // RevenueCat — SPM-optimised mirror, pinned to the studio's known-good
        // major (XueTang ships 5.67.0). RevenueCatUI is added with the
        // hosted-paywall code, not the scaffold.
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.67.0"),
        // PostHog — pinned to the studio's known-good major (XueTang ships 3.48.3).
        .package(url: "https://github.com/PostHog/posthog-ios", from: "3.48.3"),
    ],
    targets: [
        .target(name: "PASKitCore"),
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
    ]
)
