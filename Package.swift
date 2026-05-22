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
    ],
    targets: [
        .target(name: "PASKitCore"),
    ]
)
