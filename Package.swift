// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BallastEngine",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "BallastEngine", targets: ["BallastEngine"])
    ],
    targets: [
        .target(name: "BallastEngine"),
        .testTarget(name: "BallastEngineTests", dependencies: ["BallastEngine"]),
    ]
)
