import Foundation
import Metal
import Syphon26

public struct Syphon26SampleRunResult: Codable, Equatable, Sendable {
    public let role: String
    public let transportScope: String
    public let controlPlaneState: String
    public let streamID: String
    public let width: Int
    public let height: Int
    public let pixelFormat: String
    public let expectedFrames: Int
    public let publishedFrames: UInt64
    public let receivedFrames: UInt64
    public let missedFrames: UInt64
    public let repeatedReads: UInt64
    public let overwrittenFrames: UInt64
    public let registeredStreamCount: Int
    public let registeredConsumerCount: Int
    public let textureOpened: Bool
}

public enum Syphon26SampleRuntime {
    private static let heldResources = Syphon26SampleResourceStore()

    public static func runServerSmoke(frames: Int, width: Int, height: Int) throws -> Syphon26SampleRunResult {
        try runPair(role: "simple-server", frames: frames, width: width, height: height, copyFrames: false)
    }

    public static func runClientPairSmoke(frames: Int, width: Int, height: Int) throws -> Syphon26SampleRunResult {
        try runPair(role: "simple-client", frames: frames, width: width, height: height, copyFrames: true)
    }

    public static func encodeJSONLine(_ result: Syphon26SampleRunResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(result)
        return String(decoding: data, as: UTF8.self)
    }

    private static func runPair(
        role: String,
        frames: Int,
        width: Int,
        height: Int,
        copyFrames: Bool
    ) throws -> Syphon26SampleRunResult {
        guard frames > 0 else {
            throw Syphon26Error.validation(
                Syphon26ValidationIssue(code: .invalidDimensions, field: "frames", reason: "frame count must be positive")
            )
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "createSampleDevice", reason: "no default Metal device")
            )
        }

        let controlPlane = try Syphon26InProcessControlPlane(serviceName: Syphon26.defaultControlPlaneServiceName)
        let configuration = try Syphon26ServerConfiguration(
            name: "Syphon26 Simple Stream",
            appName: role,
            width: width,
            height: height,
            pixelFormat: .bgra8Unorm,
            bufferCount: 3,
            controlPlaneServiceName: Syphon26.defaultControlPlaneServiceName
        )
        let stream = try Syphon26TransportStream(configuration: configuration, device: device)
        try controlPlane.registerProducer(stream.streamDescription, processID: getpid())
        if copyFrames {
            try controlPlane.registerConsumer(
                streamID: stream.streamDescription.streamID,
                consumerID: "simple-client",
                processID: getpid()
            )
        }

        for _ in 0..<frames {
            let drawable = try stream.acquireDrawable()
            try stream.presentDrawable(drawable)
            if copyFrames {
                _ = try stream.copyLatestFrame(consumerID: "simple-client")
            }
        }

        let diagnostics = stream.diagnosticsSnapshot()
        let health = controlPlane.health()
        return Syphon26SampleRunResult(
            role: role,
            transportScope: "in-process",
            controlPlaneState: health.state.description,
            streamID: stream.streamDescription.streamID.value,
            width: width,
            height: height,
            pixelFormat: stream.streamDescription.pixelFormat.rawName,
            expectedFrames: frames,
            publishedFrames: diagnostics.publishedFrames,
            receivedFrames: diagnostics.receivedFrames,
            missedFrames: diagnostics.missedFrames,
            repeatedReads: diagnostics.repeatedReads,
            overwrittenFrames: diagnostics.overwrittenFrames,
            registeredStreamCount: health.registeredStreamCount,
            registeredConsumerCount: health.registeredConsumerCount,
            textureOpened: true
        )
    }

    public static func publishFileBackedServerState(
        stateURL: URL,
        frames: Int,
        width: Int,
        height: Int
    ) throws -> Syphon26SampleRunResult {
        guard frames > 0 else {
            throw Syphon26Error.validation(
                Syphon26ValidationIssue(code: .invalidDimensions, field: "frames", reason: "frame count must be positive")
            )
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "createSampleDevice", reason: "no default Metal device")
            )
        }

        let configuration = try Syphon26ServerConfiguration(
            name: "Syphon26 File Backed Stream",
            appName: "simple-server",
            width: width,
            height: height,
            pixelFormat: .bgra8Unorm,
            bufferCount: 3,
            controlPlaneServiceName: Syphon26.defaultControlPlaneServiceName
        )
        let descriptor = try Syphon26IOSurfaceResourceDescriptor(
            width: configuration.width,
            height: configuration.height,
            pixelFormat: configuration.pixelFormat
        )
        let resource = try Syphon26IOSurfaceResource(descriptor: descriptor, device: device)
        heldResources.append(resource)
        let streamDescription = try Syphon26StreamDescription(
            streamID: Syphon26StreamID.unchecked("file-backed-\(configuration.name)"),
            name: configuration.name,
            appName: configuration.appName,
            width: configuration.width,
            height: configuration.height,
            pixelFormat: configuration.pixelFormat,
            controlPlaneServiceName: configuration.controlPlaneServiceName
        )
        let controlPlane = Syphon26FileControlPlane(stateURL: stateURL)
        try controlPlane.publish(
            resource: resource,
            streamDescription: streamDescription,
            frameID: UInt64(frames),
            publishedFrames: UInt64(frames)
        )

        return Syphon26SampleRunResult(
            role: "simple-server",
            transportScope: "cross-process-iosurface-file-control-plane",
            controlPlaneState: "fileStatePublished",
            streamID: streamDescription.streamID.value,
            width: streamDescription.width,
            height: streamDescription.height,
            pixelFormat: streamDescription.pixelFormat.rawName,
            expectedFrames: frames,
            publishedFrames: UInt64(frames),
            receivedFrames: 0,
            missedFrames: 0,
            repeatedReads: 0,
            overwrittenFrames: 0,
            registeredStreamCount: 1,
            registeredConsumerCount: 0,
            textureOpened: true
        )
    }

    public static func openFileBackedClientFrame(stateURL: URL, timeoutSeconds: Double) throws -> Syphon26SampleRunResult {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "createSampleDevice", reason: "no default Metal device")
            )
        }
        let controlPlane = Syphon26FileControlPlane(stateURL: stateURL)
        _ = try controlPlane.waitForMetadata(timeoutSeconds: timeoutSeconds)
        let frame = try controlPlane.openLatestFrame(device: device)
        let stream = frame.metadata.streamDescription

        return Syphon26SampleRunResult(
            role: "simple-client",
            transportScope: "cross-process-iosurface-file-control-plane",
            controlPlaneState: "fileStateConnected",
            streamID: stream.streamID.value,
            width: frame.texture.width,
            height: frame.texture.height,
            pixelFormat: stream.pixelFormat.rawName,
            expectedFrames: Int(frame.metadata.publishedFrames),
            publishedFrames: frame.metadata.publishedFrames,
            receivedFrames: 1,
            missedFrames: 0,
            repeatedReads: 0,
            overwrittenFrames: 0,
            registeredStreamCount: 1,
            registeredConsumerCount: 1,
            textureOpened: frame.texture.width == stream.width && frame.texture.height == stream.height
        )
    }
}

private final class Syphon26SampleResourceStore: @unchecked Sendable {
    private let lock = NSLock()
    private var resources: [Syphon26IOSurfaceResource] = []

    func append(_ resource: Syphon26IOSurfaceResource) {
        lock.lock()
        resources.append(resource)
        lock.unlock()
    }
}

public struct Syphon26SampleArguments {
    public let frames: Int
    public let width: Int
    public let height: Int
    public let json: Bool
    public let smoke: Bool
    public let stateURL: URL?
    public let holdSeconds: Double
    public let timeoutSeconds: Double

    public init(arguments: [String]) {
        self.frames = Self.value(after: "--frames", in: arguments).flatMap(Int.init) ?? 6
        self.width = Self.value(after: "--width", in: arguments).flatMap(Int.init) ?? 640
        self.height = Self.value(after: "--height", in: arguments).flatMap(Int.init) ?? 360
        self.json = arguments.contains("--json")
        self.smoke = arguments.contains("--smoke")
        self.stateURL = Self.value(after: "--state-file", in: arguments).map { URL(fileURLWithPath: $0) }
        self.holdSeconds = Self.value(after: "--hold-seconds", in: arguments).flatMap(Double.init) ?? 0
        self.timeoutSeconds = Self.value(after: "--timeout-seconds", in: arguments).flatMap(Double.init) ?? 5
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}
