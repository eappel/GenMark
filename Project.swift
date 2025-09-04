import ProjectDescription

let project = Project(
    name: "GenMark",
    options: .options(
        automaticSchemesOptions: .enabled()
    ),
    targets: [
        // Library target (the SDK)
        .target(
            name: "GenMark",
            destinations: [.iPhone, .iPad],
            product: .framework,
            bundleId: "com.genmark",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["Sources/GenMark/**"],
            resources: [],
            dependencies: [],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
                "CODE_SIGNING_ALLOWED": "NO",
                "CODE_SIGN_IDENTITY": ""
            ])
        ),
        // Minimal example application to demo SDKView
        .target(
            name: "GenMarkExample",
            destinations: [.iPhone],
            product: .app,
            bundleId: "com.genmark.example",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchStoryboardName": "LaunchScreen"
            ]),
            sources: ["Examples/GenMarkExample/**"],
            resources: [
                "Examples/GenMarkExample/Resources/**",
                "Examples/GenMarkExample/Assets.xcassets"
            ],
            dependencies: [
                .target(name: "GenMark")
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "CODE_SIGNING_ALLOWED": "NO",
                "CODE_SIGN_IDENTITY": "",
                "DEVELOPMENT_TEAM": ""
            ])
        )
    ]
)
