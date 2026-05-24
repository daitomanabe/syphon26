import Foundation
import Metal

public final class Syphon26Client: @unchecked Sendable {
    public private(set) var configuration: Syphon26ClientConfiguration
    public private(set) var streamID: Syphon26StreamID?
    public private(set) var streamDescription: Syphon26StreamDescription?
    public var device: any MTLDevice { configuration.device }
    public private(set) var isRunning = false
    public private(set) var isValid = true
    public private(set) var hasNewFrame = false
    public private(set) var latestSequence: Syphon26Sequence = 0
    public private(set) var lastPresentedSequence: Syphon26Sequence = 0
    public private(set) var diagnostics: Syphon26DiagnosticsSnapshot

    public init(configuration: Syphon26ClientConfiguration) throws {
        if let streamDescription = configuration.streamDescription,
           streamDescription.pixelFormat != .invalid,
           !configuration.preferredPixelFormats.isEmpty,
           !configuration.preferredPixelFormats.contains(streamDescription.pixelFormat) {
            throw Syphon26Error.unsupportedPixelFormat
        }
        self.configuration = configuration
        self.streamID = configuration.streamID ?? configuration.streamDescription?.streamID
        self.streamDescription = configuration.streamDescription
        self.diagnostics = Syphon26DiagnosticsSnapshot(
            role: .client,
            streamID: self.streamID,
            syncMode: configuration.syncMode
        )
    }

    public convenience init(streamDescription: Syphon26StreamDescription, device: any MTLDevice) throws {
        try self.init(configuration: Syphon26ClientConfiguration(device: device, streamDescription: streamDescription))
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
        isValid = false
        stop()
    }

    public func copyLatestFrame() throws -> Syphon26Frame? {
        nil
    }

    public func copyLatestFrame(timeoutNanoseconds: UInt64) throws -> Syphon26Frame? {
        try copyLatestFrame()
    }

    public func copyLatestFrame(for commandBuffer: any MTLCommandBuffer) throws -> Syphon26Frame? {
        try copyLatestFrame()
    }

    public func releaseFrame(_ frame: Syphon26Frame) {
        frame.close()
    }

    public func diagnosticsSnapshot() -> Syphon26DiagnosticsSnapshot {
        diagnostics
    }

    public func resetDiagnostics() {
        diagnostics = Syphon26DiagnosticsSnapshot(
            role: .client,
            streamID: streamID,
            syncMode: configuration.syncMode
        )
    }
}

