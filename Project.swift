import ProjectDescription

let project = Project(
    name: "GenMark",
    options: .options(
        automaticSchemesOptions: .enabled(
            targetSchemesGrouping: .notGrouped,
            codeCoverageEnabled: true,
            testingOptions: []
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
            name: "GenMarkUIKit",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.genmark.uikit",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["Sources/GenMarkUIKit/**"],
            resources: [],
            dependencies: [
                .target(name: "GenMarkCore")
            ]
        ),
        .target(
            name: "GenMarkUI",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.genmark.ui",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["Sources/GenMarkUI/**"],
            resources: ["Sources/GenMarkUI/Resources/**"],
            dependencies: [
                .target(name: "GenMarkCore"),
                .target(name: "GenMarkUIKit")
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
            sources: ["App/**"],
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
            sources: ["Tests/GenMarkCoreTests/**"],
            resources: [
                "Tests/GenMarkCoreTests/Fixtures/**"
            ],
            dependencies: [
                .target(name: "GenMarkCore"),
                .xctest
            ]
        )
    ],
    schemes: [
        .scheme(
            name: "Debug",
            shared: true,
            buildAction: .buildAction(targets: ["GenMarkCore", "GenMarkUI", "GenMarkUIKit", "GenMarkExample"]),
            testAction: .targets(["GenMarkCoreTests"]),
            runAction: .runAction(executable: "GenMarkExample")
        ),
        .scheme(
            name: "Release",
            shared: true,
            buildAction: .buildAction(targets: ["GenMarkCore", "GenMarkUI", "GenMarkUIKit", "GenMarkExample"]),
            runAction: .runAction(executable: "GenMarkExample")
        )
    ]
)
