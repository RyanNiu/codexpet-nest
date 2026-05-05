// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexPetNest",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "CodexPetNest",
            path: "Sources/CodexPetNest"
        )
    ]
)
