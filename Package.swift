// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Syphon26",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Syphon26", targets: ["Syphon26"]),
        .executable(name: "Syphon26Benchmark", targets: ["Syphon26Benchmark"])
    ],
    targets: [
        .target(
            name: "Syphon26",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "Syphon26Benchmark",
            dependencies: ["Syphon26"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "Syphon26Tests",
            dependencies: ["Syphon26"]
        )
    ]
)
