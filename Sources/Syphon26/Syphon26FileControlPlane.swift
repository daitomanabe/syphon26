import Foundation
import IOSurface
import Metal

public struct Syphon26FileControlPlaneMetadata: Equatable, Sendable {
    public let streamDescription: Syphon26StreamDescription
    public let frameID: UInt64
    public let publishedFrames: UInt64
    public let processID: Int32
    public let publishedNanoseconds: UInt64
}

public final class Syphon26FileControlPlaneFrame {
    public let metadata: Syphon26FileControlPlaneMetadata
    public let texture: any MTLTexture

    init(metadata: Syphon26FileControlPlaneMetadata, texture: any MTLTexture) {
        self.metadata = metadata
        self.texture = texture
    }
}

public final class Syphon26FileControlPlane {
    public let stateURL: URL

    public init(stateURL: URL) {
        self.stateURL = stateURL
    }

    public func reset() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: stateURL.path) {
            try fileManager.removeItem(at: stateURL)
        }
    }

    public func publish(
        resource: Syphon26IOSurfaceResource,
        streamDescription: Syphon26StreamDescription,
        frameID: UInt64,
        publishedFrames: UInt64,
        processID: Int32 = getpid()
    ) throws {
        let state = State(
            schemaVersion: 1,
            serviceName: streamDescription.controlPlaneServiceName,
            streamID: streamDescription.streamID.value,
            name: streamDescription.name,
            appName: streamDescription.appName,
            width: streamDescription.width,
            height: streamDescription.height,
            pixelFormat: streamDescription.pixelFormat.rawName,
            ioSurfaceID: resource.ioSurfaceID,
            frameID: frameID,
            publishedFrames: publishedFrames,
            processID: processID,
            publishedNanoseconds: DispatchTime.now().uptimeNanoseconds
        )
        try FileManager.default.createDirectory(
            at: stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        let temporaryURL = stateURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: .atomic)
        if FileManager.default.fileExists(atPath: stateURL.path) {
            try FileManager.default.removeItem(at: stateURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: stateURL)
    }

    public func metadata() throws -> Syphon26FileControlPlaneMetadata {
        let state = try loadState()
        return try state.metadata()
    }

    public func waitForMetadata(timeoutSeconds: Double = 5.0, pollIntervalSeconds: Double = 0.05) throws -> Syphon26FileControlPlaneMetadata {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var lastError: (any Error)?
        while Date() < deadline {
            do {
                return try metadata()
            } catch {
                lastError = error
                Thread.sleep(forTimeInterval: pollIntervalSeconds)
            }
        }
        throw Syphon26Error.controlPlane(
            Syphon26ControlPlaneIssue(
                code: .missingService,
                serviceName: Syphon26.defaultControlPlaneServiceName,
                reason: "file control-plane state unavailable at \(stateURL.path): \(String(describing: lastError))"
            )
        )
    }

    public func openLatestFrame(device: any MTLDevice) throws -> Syphon26FileControlPlaneFrame {
        let state = try loadState()
        guard let surface = IOSurfaceLookup(state.ioSurfaceID) else {
            throw Syphon26Error.ioSurface(
                Syphon26RuntimeIssue(operation: "IOSurfaceLookup", reason: "published IOSurface is not available")
            )
        }
        let metadata = try state.metadata()
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: try metadata.streamDescription.pixelFormat.metalPixelFormat,
            width: metadata.streamDescription.width,
            height: metadata.streamDescription.height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        textureDescriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: textureDescriptor, iosurface: surface, plane: 0) else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "makeTextureFromFileControlPlaneSurface", reason: "Metal returned nil texture")
            )
        }
        return Syphon26FileControlPlaneFrame(metadata: metadata, texture: texture)
    }

    private func loadState() throws -> State {
        let data = try Data(contentsOf: stateURL)
        let state = try JSONDecoder().decode(State.self, from: data)
        guard state.schemaVersion == 1 else {
            throw Syphon26Error.controlPlane(
                Syphon26ControlPlaneIssue(
                    code: .schemaMismatch,
                    serviceName: state.serviceName,
                    reason: "expected schema 1, got \(state.schemaVersion)"
                )
            )
        }
        return state
    }

    private struct State: Codable {
        let schemaVersion: UInt32
        let serviceName: String
        let streamID: String
        let name: String
        let appName: String?
        let width: Int
        let height: Int
        let pixelFormat: String
        let ioSurfaceID: UInt32
        let frameID: UInt64
        let publishedFrames: UInt64
        let processID: Int32
        let publishedNanoseconds: UInt64

        func metadata() throws -> Syphon26FileControlPlaneMetadata {
            let pixelFormat = Syphon26PixelFormat(rawName: pixelFormat)
            let streamDescription = try Syphon26StreamDescription(
                streamID: Syphon26StreamID.unchecked(streamID),
                name: name,
                appName: appName,
                width: width,
                height: height,
                pixelFormat: pixelFormat,
                controlPlaneServiceName: serviceName
            )
            return Syphon26FileControlPlaneMetadata(
                streamDescription: streamDescription,
                frameID: frameID,
                publishedFrames: publishedFrames,
                processID: processID,
                publishedNanoseconds: publishedNanoseconds
            )
        }
    }
}
