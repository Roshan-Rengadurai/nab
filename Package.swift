// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Snip",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Snip", targets: ["Snip"]),
        .library(name: "SnipCore", targets: ["SnipCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.1"),
    ],
    targets: [
        .target(name: "SnipCore"),
        .executableTarget(
            name: "Snip",
            dependencies: [
                "SnipCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
        .testTarget(name: "SnipCoreTests", dependencies: ["SnipCore"]),
    ]
)
