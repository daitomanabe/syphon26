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
    private var xpcConsumerID: String?
    private var xpcResolvedSlots: [Syphon26XPCResolvedSlot] = []
    private var xpcSharedEvent: (any MTLSharedEvent)?
    private let diagnosticsLock = NSLock()

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
        if let controlPlane = configuration.controlPlane {
            try startWithControlPlane(controlPlane)
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
        if let controlPlane = configuration.controlPlane,
           let streamID,
           let xpcConsumerID {
            try? controlPlane.retireConsumer(streamID: streamID, consumerID: xpcConsumerID)
        }
        transportStream?.unregisterClient(clientRegistrationID)
        clientRegistrationID = nil
        xpcConsumerID = nil
        xpcResolvedSlots.removeAll()
        xpcSharedEvent = nil
        transportStream = nil
        isRunning = false
    }

    public func invalidate() {
        isValid = false
        stop()
    }

    public func copyLatestFrame() throws -> Syphon26Frame? {
        if let controlPlane = configuration.controlPlane {
            return try copyLatestFrameFromControlPlane(controlPlane)
        }
        guard isRunning, let transportStream else {
            throw Syphon26Error.transportUnavailable
        }
        guard let frame = try transportStream.latestFrame(
            after: lastPresentedSequence,
            clientID: clientRegistrationID,
            waitDidEncode: { [weak self] in
                self?.updateDiagnostics { diagnostics in
                    diagnostics.sharedEventWaits += 1
                }
            },
            waitDidComplete: { [weak self] elapsedNanoseconds in
                self?.updateDiagnostics { diagnostics in
                    diagnostics.gpuWaitNanoseconds += elapsedNanoseconds
                }
            }
        ) else {
            updateDiagnostics { diagnostics in
                diagnostics.repeatedReads += 1
            }
            hasNewFrame = false
            return nil
        }
        if lastPresentedSequence > 0, frame.sequence > lastPresentedSequence + 1 {
            let missedFrames = frame.sequence - lastPresentedSequence - 1
            updateDiagnostics { diagnostics in
                diagnostics.missedFrames += missedFrames
            }
        }
        lastPresentedSequence = frame.sequence
        latestSequence = frame.sequence
        hasNewFrame = false
        updateDiagnostics { diagnostics in
            diagnostics.observedFrames += 1
            diagnostics.currentConsumerLagFrames = 0
        }
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
        diagnosticsLock.lock()
        let snapshot = diagnostics
        diagnosticsLock.unlock()
        return snapshot
    }

    public func resetDiagnostics() {
        diagnosticsLock.lock()
        diagnostics = Syphon26DiagnosticsSnapshot(
            role: .client,
            streamID: streamID,
            syncMode: configuration.syncMode
        )
        diagnosticsLock.unlock()
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

    private func startWithControlPlane(_ controlPlane: Syphon26ControlPlane) throws {
        let resolvedStreamID = try resolveStreamIDForControlPlane(controlPlane)
        let consumer = try controlPlane.registerConsumer(streamID: resolvedStreamID)
        let description = consumer.stream.makeDescription()
        if !configuration.preferredPixelFormats.isEmpty,
           !configuration.preferredPixelFormats.contains(description.pixelFormat) {
            throw Syphon26Error.unsupportedPixelFormat
        }
        let slots = try controlPlane.copyIOSurfaceSlots(streamID: resolvedStreamID, device: device)
        let sharedEvent = try controlPlane.copySharedEvent(streamID: resolvedStreamID, device: device)

        streamID = resolvedStreamID
        streamDescription = description
        xpcConsumerID = consumer.consumerID
        xpcResolvedSlots = slots
        xpcSharedEvent = sharedEvent
        updateDiagnostics { diagnostics in
            diagnostics.streamID = resolvedStreamID
            diagnostics.syncMode = description.syncMode
            diagnostics.fallbackReason = description.transportCapabilities.fallbackReason
            diagnostics.slotDepthFrames = UInt64(slots.count)
            diagnostics.xpcMessagesSent += 3
            diagnostics.xpcMessagesReceived += 3
        }
        isRunning = true
    }

    private func resolveStreamIDForControlPlane(_ controlPlane: Syphon26ControlPlane) throws -> Syphon26StreamID {
        if let streamID {
            return streamID
        }
        if let streamDescription {
            return streamDescription.streamID
        }
        if let firstStream = try controlPlane.listStreams().first {
            return firstStream.streamID
        }
        throw Syphon26Error.streamNotFound
    }

    private func copyLatestFrameFromControlPlane(_ controlPlane: Syphon26ControlPlane) throws -> Syphon26Frame? {
        guard isRunning, let streamID, let streamDescription else {
            throw Syphon26Error.transportUnavailable
        }
        let state = try controlPlane.copySharedState(streamID: streamID)
        try state.validate()
        guard state.sequence > lastPresentedSequence else {
            updateDiagnostics { diagnostics in
                diagnostics.repeatedReads += 1
                diagnostics.xpcMessagesSent += 1
                diagnostics.xpcMessagesReceived += 1
            }
            hasNewFrame = false
            return nil
        }
        guard let slot = xpcResolvedSlots.first(where: { $0.descriptor.slotIndex == Int(state.currentSlot) }) else {
            throw Syphon26Error.ioSurfaceHandoffFailed
        }
        let frame = Syphon26Frame(
            texture: slot.texture,
            sequence: state.sequence,
            timestamp: 0,
            streamDescription: streamDescription,
            requiresGPUWait: xpcSharedEvent != nil,
            sharedEvent: xpcSharedEvent,
            sharedEventValue: state.sequence,
            waitDidEncode: { [weak self] in
                self?.updateDiagnostics { diagnostics in
                    diagnostics.sharedEventWaits += 1
                }
            },
            waitDidComplete: { [weak self] elapsedNanoseconds in
                self?.updateDiagnostics { diagnostics in
                    diagnostics.gpuWaitNanoseconds += elapsedNanoseconds
                }
            }
        )
        if lastPresentedSequence > 0, frame.sequence > lastPresentedSequence + 1 {
            let missedFrames = frame.sequence - lastPresentedSequence - 1
            updateDiagnostics { diagnostics in
                diagnostics.missedFrames += missedFrames
            }
        }
        lastPresentedSequence = frame.sequence
        latestSequence = frame.sequence
        hasNewFrame = false
        updateDiagnostics { diagnostics in
            diagnostics.observedFrames += 1
            diagnostics.currentConsumerLagFrames = 0
            diagnostics.xpcMessagesSent += 1
            diagnostics.xpcMessagesReceived += 1
        }
        return frame
    }

    private func updateDiagnostics(_ body: (inout Syphon26DiagnosticsSnapshot) -> Void) {
        diagnosticsLock.lock()
        body(&diagnostics)
        diagnosticsLock.unlock()
    }
}
