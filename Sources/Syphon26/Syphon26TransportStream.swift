import Foundation
import Metal

final class Syphon26TransportStream: @unchecked Sendable {
    struct Slot {
        var texture: any MTLTexture
        var sequence: Syphon26Sequence = 0
        var timestamp: Syphon26HostTime = 0
        var metadata: [String: Syphon26MetadataValue] = [:]
    }

    private let lock = NSLock()
    private var slots: [Slot]
    private var nextSlotIndex = 0
    private var currentSlotIndex: Int?
    private var sequence: Syphon26Sequence = 0
    private var activeClients: Set<UUID> = []
    private var serverDiagnostics: Syphon26DiagnosticsSnapshot

    private(set) var description: Syphon26StreamDescription

    init(description: Syphon26StreamDescription, slots: [any MTLTexture], diagnostics: Syphon26DiagnosticsSnapshot) {
        self.description = description
        self.slots = slots.map { Slot(texture: $0) }
        self.serverDiagnostics = diagnostics
    }

    func acquireDrawable() throws -> Syphon26ServerDrawable {
        lock.lock()
        let slotIndex = nextSlotIndex
        nextSlotIndex = (nextSlotIndex + 1) % slots.count
        let drawableSequence = sequence + 1
        let texture = slots[slotIndex].texture
        let streamDescription = description
        lock.unlock()

        return Syphon26ServerDrawable(
            texture: texture,
            sequence: drawableSequence,
            slotIndex: slotIndex,
            streamDescription: streamDescription
        )
    }

    func presentDrawable(
        _ drawable: Syphon26ServerDrawable,
        commandBuffer: any MTLCommandBuffer,
        timestamp: Syphon26HostTime,
        metadata: [String: Syphon26MetadataValue]
    ) throws {
        guard drawable.slotIndex >= 0 && drawable.slotIndex < slots.count else {
            throw Syphon26Error.internalInconsistency
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

    func latestFrame(after lastSequence: Syphon26Sequence) -> Syphon26Frame? {
        lock.lock()
        guard let currentSlotIndex, slots[currentSlotIndex].sequence > lastSequence else {
            lock.unlock()
            return nil
        }
        let slot = slots[currentSlotIndex]
        let streamDescription = description
        lock.unlock()

        return Syphon26Frame(
            texture: slot.texture,
            sequence: slot.sequence,
            timestamp: slot.timestamp,
            streamDescription: streamDescription,
            metadata: slot.metadata,
            requiresGPUWait: false
        )
    }

    func registerClient() -> UUID {
        let id = UUID()
        lock.lock()
        activeClients.insert(id)
        serverDiagnostics.activeClientCount = activeClients.count
        lock.unlock()
        return id
    }

    func unregisterClient(_ id: UUID?) {
        guard let id else { return }
        lock.lock()
        activeClients.remove(id)
        serverDiagnostics.activeClientCount = activeClients.count
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
        lock.unlock()
    }

    private func publishCompletedDrawable(
        slotIndex: Int,
        timestamp: Syphon26HostTime,
        metadata: [String: Syphon26MetadataValue]
    ) {
        lock.lock()
        sequence += 1
        slots[slotIndex].sequence = sequence
        slots[slotIndex].timestamp = timestamp
        slots[slotIndex].metadata = metadata
        currentSlotIndex = slotIndex
        serverDiagnostics.publishedFrames += 1
        serverDiagnostics.activeClientCount = activeClients.count
        lock.unlock()
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

