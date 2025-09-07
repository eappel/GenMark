// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GenMark",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "GenMarkCore", targets: ["GenMarkCore"]),
        .library(name: "GenMarkUI", targets: ["GenMarkUI"]),
    ],
    dependencies: [
        // Swift cmark fork with GFM products (cmark-gfm, cmark-gfm-extensions)
        .package(url: "https://github.com/swiftlang/swift-cmark", branch: "release/5.7-gfm"),
    ],
    targets: [
        .target(
            name: "GenMarkCore",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark")
            ],
            path: "Sources/GenMarkCore"
        ),
        .target(
            name: "GenMarkUI",
            dependencies: ["GenMarkCore"],
            path: "Sources/GenMarkUI",
            resources: [
                // Used by Previews to load sample fixtures visually
                .process("Resources/Fixtures")
            ]
        ),
        .testTarget(
            name: "GenMarkCoreTests",
            dependencies: ["GenMarkCore"],
            path: "Tests/GenMarkCoreTests",
            resources: [
                // Test-only copies of fixtures
                .process("Fixtures")
            ]
        ),
    ]
)
