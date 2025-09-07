import ProjectDescription

let project = Project(
    name: "GenMark",
    options: .options(
        automaticSchemesOptions: .enabled(
            targetSchemesGrouping: .notGrouped,
            codeCoverageEnabled: true,
            testingOptions: [.parallelizable]
        )
    ),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0"
        ]
    ),
    targets: [
        // MARK: Libraries mirroring SPM targets
        .target(
            name: "GenMarkCore",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.genmark.core",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["Sources/GenMarkCore/**"],
            resources: [],
            dependencies: [
                // Link the GitHub Flavored Markdown products from swift-cmark
                .external(name: "cmark-gfm"),
                .external(name: "cmark-gfm-extensions")
            ]
        ),
        .target(
            name: "GenMarkUI",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.genmark.ui",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["Sources/GenMarkUI/Sources/**"],
            resources: ["Sources/GenMarkUI/Resources/**"],
            dependencies: [
                .target(name: "GenMarkCore")
            ]
        ),

        // MARK: Example App
        .target(
            name: "GenMarkExample",
            destinations: .iOS,
            product: .app,
            bundleId: "com.genmark.example",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:]
            ]),
            sources: ["App/Sources/**"],
            resources: ["App/Resources/**"],
            dependencies: [
                .target(name: "GenMarkUI")
            ]
        ),
        // MARK: Unit Tests
        .target(
            name: "GenMarkCoreTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.genmark.coreTests",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["Tests/GenMarkCoreTests/Tests/**"],
            resources: [
                "Tests/GenMarkCoreTests/Fixtures/**"
            ],
            dependencies: [
                .target(name: "GenMarkCore"),
                .target(name: "GenMarkUI"),
                .xctest
            ]
        )
    ],
    schemes: [
        .scheme(
            name: "Debug",
            shared: true,
            buildAction: .buildAction(targets: ["GenMarkCore", "GenMarkUI", "GenMarkExample", "GenMarkCoreTests"]),
            testAction: .targets(["GenMarkCoreTests"]),
            runAction: .runAction(executable: "GenMarkExample")
        ),
        .scheme(
            name: "Release",
            shared: true,
            buildAction: .buildAction(targets: ["GenMarkCore", "GenMarkUI", "GenMarkExample"]),
            runAction: .runAction(executable: "GenMarkExample")
        )
    ]
)
