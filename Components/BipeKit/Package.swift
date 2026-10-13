// swift-tools-version: 6.2

import PackageDescription

// Bipe-specific code. Registries and strings in Sources/BipeKit/Generated
// come from bipe-shared (node tools/gen.mjs). Do not edit them by hand.
let package = Package(
    name: "BipeKit",
    defaultLocalization: "pt-BR",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "BipeKit", targets: ["BipeKit"])
    ],
    targets: [
        .target(name: "BipeKit",
                resources: [.process("Resources")],
                swiftSettings: [
                    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                    .enableUpcomingFeature("InferIsolatedConformances")
                ]),
        // Reads ../../../bipe-shared/test-vectors directly (ADR 0031 rule 4). Run: swift test
        .testTarget(name: "BipeKitTests",
                    dependencies: ["BipeKit"])
    ]
)
