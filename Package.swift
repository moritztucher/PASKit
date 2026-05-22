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
    ],
    dependencies: [
        // RevenueCat — SPM-optimised mirror, pinned to the studio's known-good
        // major (XueTang ships 5.67.0). RevenueCatUI is added with the
        // hosted-paywall code, not the scaffold.
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.67.0"),
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
    ]
)
