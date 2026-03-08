// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Athenaeum",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "Forma")
    ],
    targets: [
        .executableTarget(
            name: "Octavo",
            dependencies: ["Forma"],
            path: "Octavo",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Athenaeum",
            dependencies: ["Forma"],
            path: "Athenaeum",
            resources: [.process("Resources")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "AthenaeumTests",
            dependencies: ["Athenaeum"],
            path: "Tests/AthenaeumTests",
            resources: [.copy("Resources")]
        )
    ]
)
