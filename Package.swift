// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HotkeyService",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "HotkeyServiceKit",
            targets: ["HotkeyServiceKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/iwasrobbed/Down", from: "0.11.0")
    ],
    targets: [
        .target(
            name: "HotkeyServiceKit",
            dependencies: [
                .product(name: "Down", package: "Down")
            ],
            path: "Sources/HotkeyServiceKit",
            resources: []
        ),
        .testTarget(
            name: "HotkeyServiceKitTests",
            dependencies: ["HotkeyServiceKit"],
            path: "Tests/HotkeyServiceKitTests"
        )
    ]
)
