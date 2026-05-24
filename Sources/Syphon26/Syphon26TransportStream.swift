import Foundation
import IOSurface
import Metal

final class Syphon26SlotResource: @unchecked Sendable {
    let texture: any MTLTexture
    let surface: IOSurfaceRef?

    init(texture: any MTLTexture, surface: IOSurfaceRef?) {
        self.texture = texture
        self.surface = surface
    }
}

final class Syphon26TransportStream: @unchecked Sendable {
    struct Slot {
        var resource: Syphon26SlotResource
        var sequence: Syphon26Sequence = 0
        var timestamp: Syphon26HostTime = 0
        var metadata: [String: Syphon26MetadataValue] = [:]
        var slotMetadata: Syphon26RingSlotMetadata
    }

    private let lock = NSLock()
    private var slots: [Slot]
    private var nextSlotIndex = 0
    private var currentSlotIndex: Int?
    private var sequence: Syphon26Sequence = 0
    private var activeClients: Set<UUID> = []
    private var activeClientSequences: [UUID: Syphon26Sequence] = [:]
    private var retired = false
    private var serverDiagnostics: Syphon26DiagnosticsSnapshot
    private let sharedEvent: (any MTLSharedEvent)?
    private var sharedState: Syphon26SharedState
    private let maximumProducerWaitNanoseconds: UInt64

    private(set) var description: Syphon26StreamDescription

    init(
        description: Syphon26StreamDescription,
        slots: [Syphon26SlotResource],
        diagnostics: Syphon26DiagnosticsSnapshot,
        maximumProducerWaitNanoseconds: UInt64 = 0,
        sharedEvent: (any MTLSharedEvent)? = nil
    ) {
        self.description = description
        self.slots = slots.enumerated().map { index, resource in
            Slot(
                resource: resource,
                slotMetadata: Syphon26RingSlotMetadata(
                    slotIndex: index,
                    ioSurfaceID: resource.surface.map { UInt32(IOSurfaceGetID($0)) },
                    width: description.width,
                    height: description.height,
                    pixelFormatRawValue: UInt64(description.pixelFormat.rawValue)
                )
            )
        }
        self.serverDiagnostics = diagnostics
        self.sharedEvent = sharedEvent
        self.sharedState = Syphon26SharedState(description: description)
        self.maximumProducerWaitNanoseconds = maximumProducerWaitNanoseconds
    }

    func acquireDrawable() throws -> Syphon26ServerDrawable {
        Syphon26Signposts.acquire()
        let stallStart = Syphon26Clock.hostTimeNanoseconds()
        var didWait = false

        while true {
            lock.lock()
            guard !retired else {
                lock.unlock()
                throw Syphon26Error.streamRetired
            }
            if let slotIndex = selectSlotIndexLocked() {
                if didWait {
                    serverDiagnostics.producerStallNanoseconds += Syphon26Clock.hostTimeNanoseconds() - stallStart
                }
                let drawableSequence = sequence + 1
                let texture = slots[slotIndex].resource.texture
                let streamDescription = description
                lock.unlock()

                return Syphon26ServerDrawable(
                    texture: texture,
                    sequence: drawableSequence,
                    slotIndex: slotIndex,
                    streamDescription: streamDescription
                )
            }

            guard maximumProducerWaitNanoseconds > 0 else {
                lock.unlock()
                throw Syphon26Error.noAvailableSlot
            }
            let elapsed = Syphon26Clock.hostTimeNanoseconds() - stallStart
            guard elapsed < maximumProducerWaitNanoseconds else {
                serverDiagnostics.producerStallNanoseconds += elapsed
                lock.unlock()
                throw Syphon26Error.timeout
            }
            lock.unlock()

            didWait = true
            let remainingNanoseconds = maximumProducerWaitNanoseconds - elapsed
            let sleepNanoseconds = min(remainingNanoseconds, 100_000)
            Thread.sleep(forTimeInterval: Double(sleepNanoseconds) / 1_000_000_000.0)
        }
    }

    func presentDrawable(
        _ drawable: Syphon26ServerDrawable,
        commandBuffer: any MTLCommandBuffer,
        timestamp: Syphon26HostTime,
        metadata: [String: Syphon26MetadataValue]
    ) throws {
        lock.lock()
        let isRetired = retired
        lock.unlock()
        guard !isRetired else {
            throw Syphon26Error.streamRetired
        }
        guard drawable.slotIndex >= 0 && drawable.slotIndex < slots.count else {
            throw Syphon26Error.internalInconsistency
        }

        if let sharedEvent {
            commandBuffer.encodeSignalEvent(sharedEvent, value: drawable.sequence)
            lock.lock()
            serverDiagnostics.sharedEventSignals += 1
            lock.unlock()
        }

        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.publishCompletedDrawable(slotIndex: drawable.slotIndex, timestamp: timestamp, metadata: metadata)
        }
    }

    func publishTexture(
        _ sourceTexture: any MTLTexture,
        commandBuffer: any MTLCommandBuffer,
        timestamp: Syphon26HostTime,
        metadata: [String: Syphon26MetadataValue]
    ) throws {
        let drawable = try acquireDrawable()
        guard sourceTexture.width == drawable.texture.width,
              sourceTexture.height == drawable.texture.height,
              sourceTexture.pixelFormat == drawable.texture.pixelFormat
        else {
            throw Syphon26Error.invalidConfiguration
        }

        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw Syphon26Error.internalInconsistency
        }
        blit.copy(
            from: sourceTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: sourceTexture.width, height: sourceTexture.height, depth: 1),
            to: drawable.texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()
        try presentDrawable(drawable, commandBuffer: commandBuffer, timestamp: timestamp, metadata: metadata)
    }

    func latestFrame(
        after lastSequence: Syphon26Sequence,
        clientID: UUID?,
        waitDidEncode: (@Sendable () -> Void)? = nil,
        waitDidComplete: (@Sendable (UInt64) -> Void)? = nil
    ) throws -> Syphon26Frame? {
        lock.lock()
        guard !retired else {
            lock.unlock()
            throw Syphon26Error.streamRetired
        }
        guard let currentSlotIndex, slots[currentSlotIndex].sequence > lastSequence else {
            lock.unlock()
            return nil
        }
        Syphon26Signposts.consume()
        let slot = slots[currentSlotIndex]
        let streamDescription = description
        if let clientID, activeClientSequences[clientID] != nil {
            activeClientSequences[clientID] = slot.sequence
            updateConsumerLagLocked()
        }
        lock.unlock()

        return Syphon26Frame(
            texture: slot.resource.texture,
            sequence: slot.sequence,
            timestamp: slot.timestamp,
            streamDescription: streamDescription,
            metadata: slot.metadata,
            requiresGPUWait: sharedEvent != nil,
            sharedEvent: sharedEvent,
            sharedEventValue: slot.sequence,
            waitDidEncode: waitDidEncode,
            waitDidComplete: waitDidComplete
        )
    }

    func registerClient() -> UUID {
        let id = UUID()
        lock.lock()
        activeClients.insert(id)
        activeClientSequences[id] = 0
        sharedState.activeClientCount = UInt32(activeClients.count)
        serverDiagnostics.activeClientCount = activeClients.count
        updateConsumerLagLocked()
        lock.unlock()
        return id
    }

    func unregisterClient(_ id: UUID?) {
        guard let id else { return }
        lock.lock()
        activeClients.remove(id)
        activeClientSequences.removeValue(forKey: id)
        sharedState.activeClientCount = UInt32(activeClients.count)
        serverDiagnostics.activeClientCount = activeClients.count
        updateConsumerLagLocked()
        lock.unlock()
    }

    func diagnosticsSnapshot() -> Syphon26DiagnosticsSnapshot {
        lock.lock()
        let snapshot = serverDiagnostics
        lock.unlock()
        return snapshot
    }

    func resetDiagnostics(_ diagnostics: Syphon26DiagnosticsSnapshot) {
        lock.lock()
        serverDiagnostics = diagnostics
        updateConsumerLagLocked()
        serverDiagnostics.activeClientCount = activeClients.count
        lock.unlock()
    }

    func retire() {
        lock.lock()
        retired = true
        lock.unlock()
    }

    func slotMetadataSnapshot() -> [Syphon26RingSlotMetadata] {
        lock.lock()
        let metadata = slots.map(\.slotMetadata)
        lock.unlock()
        return metadata
    }

    private func publishCompletedDrawable(
        slotIndex: Int,
        timestamp: Syphon26HostTime,
        metadata: [String: Syphon26MetadataValue]
    ) {
        lock.lock()
        guard !retired else {
            lock.unlock()
            return
        }
        Syphon26Signposts.publish()
        let overwrittenSequence = slots[slotIndex].sequence
        if overwrittenSequence > 0,
           activeClientSequences.values.contains(where: { $0 < overwrittenSequence }) {
            serverDiagnostics.overwrittenFrames += 1
        }
        sequence += 1
        sharedState.sequence = sequence
        sharedState.currentSlot = UInt32(slotIndex)
        slots[slotIndex].sequence = sequence
        slots[slotIndex].timestamp = timestamp
        slots[slotIndex].metadata = metadata
        slots[slotIndex].slotMetadata.sequence = sequence
        slots[slotIndex].slotMetadata.readySequence = sequence
        slots[slotIndex].slotMetadata.timestamp = timestamp
        currentSlotIndex = slotIndex
        serverDiagnostics.publishedFrames += 1
        serverDiagnostics.activeClientCount = activeClients.count
        updateConsumerLagLocked()
        lock.unlock()
    }

    private func selectSlotIndexLocked() -> Int? {
        let startIndex = nextSlotIndex
        for offset in 0..<slots.count {
            let candidate = (startIndex + offset) % slots.count
            if isSlotReusableLocked(candidate) {
                nextSlotIndex = (candidate + 1) % slots.count
                return candidate
            }
        }

        guard description.deliveryMode == .latest else {
            return nil
        }
        let overwriteIndex = nextSlotIndex
        nextSlotIndex = (nextSlotIndex + 1) % slots.count
        return overwriteIndex
    }

    private func isSlotReusableLocked(_ slotIndex: Int) -> Bool {
        let slotSequence = slots[slotIndex].sequence
        guard slotSequence > 0, !activeClientSequences.isEmpty else {
            return true
        }
        return !activeClientSequences.values.contains { $0 < slotSequence }
    }

    private func updateConsumerLagLocked() {
        guard !activeClientSequences.isEmpty else {
            serverDiagnostics.currentConsumerLagFrames = 0
            return
        }
        let oldestObservedSequence = activeClientSequences.values.min() ?? sequence
        let currentLag = sequence > oldestObservedSequence ? sequence - oldestObservedSequence : 0
        serverDiagnostics.currentConsumerLagFrames = currentLag
        serverDiagnostics.maxConsumerLagFrames = max(serverDiagnostics.maxConsumerLagFrames, currentLag)
    }
}

final class Syphon26TransportRegistry: @unchecked Sendable {
    static let shared = Syphon26TransportRegistry()

    private let lock = NSLock()
    private var streams: [Syphon26StreamID: Syphon26TransportStream] = [:]

    private init() {
    }

    func register(_ stream: Syphon26TransportStream) {
        lock.lock()
        streams[stream.description.streamID] = stream
        lock.unlock()
    }

    func unregister(streamID: Syphon26StreamID) {
        lock.lock()
        streams.removeValue(forKey: streamID)
        lock.unlock()
    }

    func stream(withID streamID: Syphon26StreamID) -> Syphon26TransportStream? {
        lock.lock()
        let stream = streams[streamID]
        lock.unlock()
        return stream
    }

    func descriptions() -> [Syphon26StreamDescription] {
        lock.lock()
        let descriptions = streams.values.map(\.description).sorted { $0.name < $1.name }
        lock.unlock()
        return descriptions
    }
}
