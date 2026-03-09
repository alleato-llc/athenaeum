// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ligature",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Ligature", targets: ["Ligature"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .target(name: "Ligature",
                dependencies: ["ZIPFoundation"],
                path: "Sources/Ligature"),
        .testTarget(
            name: "LigatureTests",
            dependencies: ["Ligature"],
            path: "Tests/LigatureTests",
            resources: [.copy("Resources")]
        )
    ]
)
