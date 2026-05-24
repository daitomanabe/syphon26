import CoreVideo
import Foundation
import IOSurface
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
        let syncResolution = try Self.resolveSyncMode(configuration: configuration)
        streamDescription.syncMode = syncResolution.syncMode
        diagnostics.syncMode = syncResolution.syncMode
        diagnostics.fallbackReason = syncResolution.fallbackReason

        let textures = try Self.makeSlotResources(configuration: configuration)
        let stream = Syphon26TransportStream(
            description: streamDescription,
            slots: textures,
            diagnostics: diagnostics,
            sharedEvent: syncResolution.sharedEvent
        )
        Syphon26TransportRegistry.shared.register(stream)
        transportStream = stream
        isRunning = true
    }

    public func stop() {
        guard isRunning else {
            return
        }
        Syphon26Signposts.retire()
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

    private static func makeSlotResources(configuration: Syphon26ServerConfiguration) throws -> [Syphon26SlotResource] {
        var resources: [Syphon26SlotResource] = []
        resources.reserveCapacity(configuration.slotCount)
        for _ in 0..<configuration.slotCount {
            resources.append(try makeIOSurfaceBackedResource(configuration: configuration))
        }
        return resources
    }

    private static func makeIOSurfaceBackedResource(configuration: Syphon26ServerConfiguration) throws -> Syphon26SlotResource {
        let attributes: [CFString: Any] = [
            kIOSurfaceWidth: configuration.width,
            kIOSurfaceHeight: configuration.height,
            kIOSurfacePixelFormat: Syphon26PixelFormatSupport.cvPixelFormat(for: configuration.pixelFormat),
            kIOSurfaceBytesPerElement: Syphon26PixelFormatSupport.bytesPerElement(for: configuration.pixelFormat)
        ]
        guard let surface = IOSurfaceCreate(attributes as CFDictionary) else {
            throw Syphon26Error.transportUnavailable
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: configuration.pixelFormat,
            width: configuration.width,
            height: configuration.height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        descriptor.storageMode = .shared

        guard let texture = configuration.device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0) else {
            throw Syphon26Error.transportUnavailable
        }
        return Syphon26SlotResource(texture: texture, surface: surface)
    }

    private static func resolveSyncMode(configuration: Syphon26ServerConfiguration) throws -> (
        syncMode: Syphon26SyncMode,
        fallbackReason: Syphon26FallbackReason,
        sharedEvent: (any MTLSharedEvent)?
    ) {
        switch configuration.syncMode {
        case .sequencePolling:
            return (.sequencePolling, .none, nil)
        case .automatic, .sharedEvent:
            if let sharedEvent = configuration.device.makeSharedEvent() {
                return (.sharedEvent, .none, sharedEvent)
            }
            if configuration.syncMode == .sharedEvent, !configuration.allowsFallbacks {
                throw Syphon26Error.sharedEventUnavailable
            }
            return (.sequencePolling, .sharedEventUnavailable, nil)
        }
    }
}
