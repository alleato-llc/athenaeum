// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Athenaeum",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "Forma"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
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
            dependencies: [
                "Forma",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Athenaeum",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AthenaeumTests",
            dependencies: ["Athenaeum"],
            path: "Tests/AthenaeumTests",
            resources: [.copy("Resources")]
        )
    ]
)
