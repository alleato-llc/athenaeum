// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ligature",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Ligature", targets: ["Ligature"])
    ],
    targets: [
        .target(name: "Ligature", path: "Sources/Ligature",
                resources: [.process("Resources")],
                linkerSettings: [.linkedLibrary("sqlite3")])
    ]
)
