// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Forma",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Forma", targets: ["Forma"])
    ],
    dependencies: [
        .package(path: "../Ligature")
    ],
    targets: [
        .target(name: "Forma",
                dependencies: ["Ligature"],
                path: "Sources/Forma",
                resources: [.process("Resources")]),
        .testTarget(name: "FormaTests",
                    dependencies: ["Forma"],
                    path: "Tests/FormaTests")
    ]
)
