import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: .init(
        dependencies: [
            // Use GFM-enabled branch exposing products cmark-gfm and cmark-gfm-extensions
            .remote(
                url: "https://github.com/swiftlang/swift-cmark",
                requirement: .branch("release/5.7-gfm")
            )
        ],
        productTypes: [
            // Map SPM products for GFM parsing
            "cmark-gfm": .staticFramework,
            "cmark-gfm-extensions": .staticFramework
        ]
    ),
    platforms: [.iOS]
)
