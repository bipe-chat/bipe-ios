// swift-tools-version: 6.2

import PackageDescription

// Proseio-specific code. Registries and strings in Sources/ProseioKit/Generated
// come from proseio-shared (node tools/gen.mjs). Do not edit them by hand.
let package = Package(
    name: "ProseioKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "ProseioKit", targets: ["ProseioKit"])
    ],
    targets: [
        .target(name: "ProseioKit",
                swiftSettings: [
                    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                    .enableUpcomingFeature("InferIsolatedConformances")
                ])
    ]
)
