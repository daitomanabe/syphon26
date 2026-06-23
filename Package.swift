// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Syphon26",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Syphon26", targets: ["Syphon26"]),
        .executable(name: "Syphon26ControlPlaneService", targets: ["Syphon26ControlPlaneService"]),
        .executable(name: "Syphon26SimpleServer", targets: ["Syphon26SimpleServer"]),
        .executable(name: "Syphon26SimpleClient", targets: ["Syphon26SimpleClient"]),
        .executable(name: "Syphon26SimpleServerApp", targets: ["Syphon26SimpleServerApp"]),
        .executable(name: "Syphon26SimpleClientApp", targets: ["Syphon26SimpleClientApp"]),
        .executable(name: "Syphon26Benchmark", targets: ["Syphon26Benchmark"]),
        .executable(name: "Syphon26AppToAppBenchmark", targets: ["Syphon26AppToAppBenchmark"]),
        .executable(name: "Syphon26ProductionXPCBenchmark", targets: ["Syphon26ProductionXPCBenchmark"])
    ],
    targets: [
        .target(
            name: "Syphon26",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "Syphon26ControlPlaneService",
            dependencies: ["Syphon26"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .target(
            name: "Syphon26SimpleUIShared",
            dependencies: ["Syphon26"],
            path: "Examples/SimpleUIShared",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "Syphon26SimpleServer",
            dependencies: ["Syphon26SimpleUIShared"],
            path: "Examples/SimpleServer",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "Syphon26SimpleClient",
            dependencies: ["Syphon26SimpleUIShared"],
            path: "Examples/SimpleClient",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "Syphon26SimpleServerApp",
            dependencies: ["Syphon26SimpleUIShared"],
            path: "Examples/SimpleServerApp",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "Syphon26SimpleClientApp",
            dependencies: ["Syphon26SimpleUIShared"],
            path: "Examples/SimpleClientApp",
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
            name: "Syphon26AppToAppBenchmark",
            dependencies: ["Syphon26"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "Syphon26ProductionXPCBenchmark",
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
