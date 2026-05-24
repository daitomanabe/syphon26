// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Syphon26",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Syphon26", targets: ["Syphon26"]),
        .executable(name: "Syphon26Benchmark", targets: ["Syphon26Benchmark"]),
        .executable(name: "Syphon26ControlPlaneService", targets: ["Syphon26ControlPlaneService"]),
        .executable(name: "Syphon26SampleProducer", targets: ["Syphon26SampleProducer"]),
        .executable(name: "Syphon26SampleConsumer", targets: ["Syphon26SampleConsumer"])
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
        .executableTarget(
            name: "Syphon26ControlPlaneService",
            dependencies: ["Syphon26"],
            path: "Samples/Syphon26ControlPlaneService",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "Syphon26SampleProducer",
            dependencies: ["Syphon26"],
            path: "Samples/Syphon26SampleProducer",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "Syphon26SampleConsumer",
            dependencies: ["Syphon26"],
            path: "Samples/Syphon26SampleConsumer",
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
