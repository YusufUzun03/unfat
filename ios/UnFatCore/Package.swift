// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UnFatCore",
    platforms: [
        // String form: the `.v26` enum case needs PackageDescription 6.2.
        .iOS("26.0"),
        // Lets `swift test` run on the macOS CI runner.
        .macOS(.v15),
    ],
    products: [
        .library(name: "UnFatCore", targets: ["UnFatCore"]),
    ],
    targets: [
        .target(name: "UnFatCore"),
        .testTarget(name: "UnFatCoreTests", dependencies: ["UnFatCore"]),
    ]
)
