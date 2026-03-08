// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Athenaeum",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "Ligature")
    ],
    targets: [
        .executableTarget(
            name: "Octavo",
            dependencies: ["Ligature"],
            path: "Octavo",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Athenaeum",
            dependencies: ["Ligature"],
            path: "Athenaeum",
            resources: [.process("Resources")]
        )
    ]
)
