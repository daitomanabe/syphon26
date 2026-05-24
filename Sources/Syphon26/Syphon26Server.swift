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
    public var activeClientCount: Int { diagnostics.activeClientCount }
    public private(set) var diagnostics: Syphon26DiagnosticsSnapshot

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
        isRunning = true
    }

    public func stop() {
        isRunning = false
    }

    public func invalidate() {
        stop()
    }

    public func diagnosticsSnapshot() -> Syphon26DiagnosticsSnapshot {
        diagnostics
    }

    public func resetDiagnostics() {
        diagnostics = Syphon26DiagnosticsSnapshot(
            role: .server,
            streamID: streamID,
            syncMode: configuration.syncMode,
            slotDepthFrames: UInt64(configuration.slotCount)
        )
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
}

