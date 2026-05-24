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
    private var transportStream: Syphon26TransportStream?
    private var clientRegistrationID: UUID?

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
        if isRunning {
            return
        }
        let resolvedStreamID = try resolveStreamID()
        guard let stream = Syphon26TransportRegistry.shared.stream(withID: resolvedStreamID) else {
            throw Syphon26Error.streamNotFound
        }
        transportStream = stream
        streamID = resolvedStreamID
        streamDescription = stream.description
        clientRegistrationID = stream.registerClient()
        diagnostics.streamID = resolvedStreamID
        isRunning = true
    }

    public func stop() {
        transportStream?.unregisterClient(clientRegistrationID)
        clientRegistrationID = nil
        transportStream = nil
        isRunning = false
    }

    public func invalidate() {
        isValid = false
        stop()
    }

    public func copyLatestFrame() throws -> Syphon26Frame? {
        guard isRunning, let transportStream else {
            throw Syphon26Error.transportUnavailable
        }
        guard let frame = transportStream.latestFrame(
            after: lastPresentedSequence,
            clientID: clientRegistrationID,
            waitDidEncode: { [weak self] in
                self?.diagnostics.sharedEventWaits += 1
            }
        ) else {
            diagnostics.repeatedReads += 1
            hasNewFrame = false
            return nil
        }
        if lastPresentedSequence > 0, frame.sequence > lastPresentedSequence + 1 {
            diagnostics.missedFrames += frame.sequence - lastPresentedSequence - 1
        }
        lastPresentedSequence = frame.sequence
        latestSequence = frame.sequence
        hasNewFrame = false
        diagnostics.observedFrames += 1
        diagnostics.currentConsumerLagFrames = 0
        return frame
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

    private func resolveStreamID() throws -> Syphon26StreamID {
        if let streamID {
            return streamID
        }
        if let streamDescription {
            return streamDescription.streamID
        }
        if let firstStream = Syphon26TransportRegistry.shared.descriptions().first {
            return firstStream.streamID
        }
        throw Syphon26Error.streamNotFound
    }
}
