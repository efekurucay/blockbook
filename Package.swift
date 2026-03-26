// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let blockBookVersion = "1.0.0"

let package = Package(
    name: "BlockBook",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "BlockBook",
            targets: ["BlockBook"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "BlockBook"
        ),
        .testTarget(
            name: "BlockBookTests",
            dependencies: ["BlockBook"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
