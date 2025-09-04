// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GenMark",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "GenMark",
            targets: ["GenMark"]
        )
    ],
    targets: [
        .target(
            name: "GenMark",
            path: "Sources/GenMark",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
