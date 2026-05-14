// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexPetNest",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexPetNest", targets: ["CodexPetNest"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "CodexPetNest",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/CodexPetNest",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        )
    ]
)
