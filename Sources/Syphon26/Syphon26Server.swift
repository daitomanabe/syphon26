import Foundation
import Metal

public final class Syphon26Server: @unchecked Sendable {
    public private(set) var streamID: Syphon26StreamID
    public private(set) var configuration: Syphon26ServerConfiguration
    public var name: String { configuration.name }
    public var appName: String? { configuration.appName }
    public var device: any MTLDevice { configuration.device }
    public private(set) var streamDescription: Syphon26StreamDescription
    public private(set) var isRunning = false
    public var activeClientCount: Int { diagnosticsSnapshot().activeClientCount }
    public private(set) var diagnostics: Syphon26DiagnosticsSnapshot
    private var transportStream: Syphon26TransportStream?

    public init(configuration: Syphon26ServerConfiguration) throws {
        try Self.validate(configuration)
        let streamID = UUID().uuidString
        self.streamID = streamID
        self.configuration = configuration
        self.streamDescription = Syphon26StreamDescription(
            streamID: streamID,
            name: configuration.name,
            appName: configuration.appName,
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            width: configuration.width,
            height: configuration.height,
            pixelFormat: configuration.pixelFormat,
            colorPrimaries: configuration.colorPrimaries,
            transferFunction: configuration.transferFunction,
            alphaMode: configuration.alphaMode,
            slotCount: configuration.slotCount,
            syncMode: configuration.syncMode,
            deliveryMode: configuration.deliveryMode,
            capabilities: ["sequence-polling"],
            metadata: configuration.metadata
        )
        self.diagnostics = Syphon26DiagnosticsSnapshot(
            role: .server,
            streamID: streamID,
            syncMode: configuration.syncMode,
            slotDepthFrames: UInt64(configuration.slotCount)
        )
    }

    public static func isSupported(on device: any MTLDevice) -> Bool {
        device.supportsFamily(.apple1) || device.supportsFamily(.mac2) || device.supportsFamily(.common1)
    }

    public func start() throws {
        if isRunning {
            return
        }
        let textures = try Self.makeTextures(configuration: configuration)
        let stream = Syphon26TransportStream(
            description: streamDescription,
            slots: textures,
            diagnostics: diagnostics
        )
        Syphon26TransportRegistry.shared.register(stream)
        transportStream = stream
        isRunning = true
    }

    public func stop() {
        guard isRunning else {
            return
        }
        Syphon26TransportRegistry.shared.unregister(streamID: streamID)
        transportStream = nil
        isRunning = false
    }

    public func invalidate() {
        stop()
    }

    public func diagnosticsSnapshot() -> Syphon26DiagnosticsSnapshot {
        transportStream?.diagnosticsSnapshot() ?? diagnostics
    }

    public func resetDiagnostics() {
        diagnostics = Syphon26DiagnosticsSnapshot(
            role: .server,
            streamID: streamID,
            syncMode: configuration.syncMode,
            slotDepthFrames: UInt64(configuration.slotCount)
        )
        transportStream?.resetDiagnostics(diagnostics)
    }

    public func acquireDrawable(timeoutNanoseconds: UInt64 = 0) throws -> Syphon26ServerDrawable {
        guard isRunning, let transportStream else {
            throw Syphon26Error.transportUnavailable
        }
        return try transportStream.acquireDrawable()
    }

    public func presentDrawable(
        _ drawable: Syphon26ServerDrawable,
        commandBuffer: any MTLCommandBuffer,
        timestamp: Syphon26HostTime = Syphon26Clock.hostTime(),
        metadata: [String: Syphon26MetadataValue] = [:]
    ) throws {
        guard isRunning, let transportStream else {
            throw Syphon26Error.transportUnavailable
        }
        try transportStream.presentDrawable(drawable, commandBuffer: commandBuffer, timestamp: timestamp, metadata: metadata)
    }

    public func discardDrawable(_ drawable: Syphon26ServerDrawable) {
    }

    public func publishTexture(
        _ texture: any MTLTexture,
        commandBuffer: any MTLCommandBuffer,
        timestamp: Syphon26HostTime = Syphon26Clock.hostTime(),
        metadata: [String: Syphon26MetadataValue] = [:]
    ) throws {
        guard isRunning, let transportStream else {
            throw Syphon26Error.transportUnavailable
        }
        try transportStream.publishTexture(texture, commandBuffer: commandBuffer, timestamp: timestamp, metadata: metadata)
    }

    private static func validate(_ configuration: Syphon26ServerConfiguration) throws {
        guard !configuration.name.isEmpty,
              configuration.width > 0,
              configuration.height > 0,
              (2...16).contains(configuration.slotCount)
        else {
            throw Syphon26Error.invalidConfiguration
        }
        guard Syphon26PixelFormatSupport.isSupported(configuration.pixelFormat) else {
            throw Syphon26Error.unsupportedPixelFormat
        }
    }

    private static func makeTextures(configuration: Syphon26ServerConfiguration) throws -> [any MTLTexture] {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: configuration.pixelFormat,
            width: configuration.width,
            height: configuration.height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        descriptor.storageMode = .private

        var textures: [any MTLTexture] = []
        textures.reserveCapacity(configuration.slotCount)
        for _ in 0..<configuration.slotCount {
            guard let texture = configuration.device.makeTexture(descriptor: descriptor) else {
                throw Syphon26Error.transportUnavailable
            }
            textures.append(texture)
        }
        return textures
    }
}
