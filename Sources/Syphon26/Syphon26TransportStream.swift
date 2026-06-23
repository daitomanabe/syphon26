import Foundation
import Metal

public struct Syphon26TransportFrameSnapshot: Equatable, Sendable {
    public let streamID: Syphon26StreamID
    public let frameID: UInt64
    public let slotIndex: Int
    public let generation: UInt64
    public let width: Int
    public let height: Int
    public let pixelFormat: Syphon26PixelFormat
    public let publishedNanoseconds: UInt64
    public let repeatedForConsumer: Bool
    public let missedFrameCount: UInt64
}

public final class Syphon26TransportDrawable {
    public let streamID: Syphon26StreamID
    public let slotIndex: Int
    public let generation: UInt64
    public let texture: any MTLTexture

    init(streamID: Syphon26StreamID, slotIndex: Int, generation: UInt64, texture: any MTLTexture) {
        self.streamID = streamID
        self.slotIndex = slotIndex
        self.generation = generation
        self.texture = texture
    }
}

public final class Syphon26TransportFrame {
    public let snapshot: Syphon26TransportFrameSnapshot
    public let texture: any MTLTexture

    init(snapshot: Syphon26TransportFrameSnapshot, texture: any MTLTexture) {
        self.snapshot = snapshot
        self.texture = texture
    }
}

public final class Syphon26TransportStream {
    public let streamDescription: Syphon26StreamDescription

    private let lock = NSLock()
    private var slots: [Slot]
    private var nextSlotIndex = 0
    private var nextFrameID: UInt64 = 0
    private var latestSnapshot: Syphon26TransportFrameSnapshot?
    private var consumerCursors: [String: UInt64] = [:]
    private var publishedFrames: UInt64 = 0
    private var receivedFrames: UInt64 = 0
    private var missedFrames: UInt64 = 0
    private var repeatedReads: UInt64 = 0
    private var overwrittenFrames: UInt64 = 0

    public init(configuration: Syphon26ServerConfiguration, device: any MTLDevice) throws {
        let descriptor = try Syphon26IOSurfaceResourceDescriptor(
            width: configuration.width,
            height: configuration.height,
            pixelFormat: configuration.pixelFormat
        )
        let streamID = Syphon26StreamID.unchecked("in-process-\(configuration.name)")
        var slots: [Slot] = []
        slots.reserveCapacity(configuration.bufferCount)

        for slotIndex in 0..<configuration.bufferCount {
            let resource = try Syphon26IOSurfaceResource(descriptor: descriptor, device: device)
            let metadata = try Syphon26RingSlotMetadata(slotIndex: slotIndex)
            slots.append(Slot(resource: resource, metadata: metadata))
        }

        self.streamDescription = try Syphon26StreamDescription(
            streamID: streamID,
            name: configuration.name,
            appName: configuration.appName,
            width: configuration.width,
            height: configuration.height,
            pixelFormat: configuration.pixelFormat,
            controlPlaneServiceName: configuration.controlPlaneServiceName
        )
        self.slots = slots
    }

    public func acquireDrawable() throws -> Syphon26TransportDrawable {
        lock.lock()
        defer { lock.unlock() }

        let slotIndex = nextSlotIndex
        nextSlotIndex = (nextSlotIndex + 1) % slots.count

        if slots[slotIndex].metadata.state == .published {
            overwrittenFrames += 1
        }

        let generation = slots[slotIndex].metadata.generation + 1
        slots[slotIndex].metadata = try slots[slotIndex].metadata.acquiredForWrite(nextGeneration: generation)

        return Syphon26TransportDrawable(
            streamID: streamDescription.streamID,
            slotIndex: slotIndex,
            generation: generation,
            texture: slots[slotIndex].resource.texture
        )
    }

    @discardableResult
    public func presentDrawable(_ drawable: Syphon26TransportDrawable) throws -> Syphon26TransportFrameSnapshot {
        lock.lock()
        defer { lock.unlock() }

        guard drawable.streamID == streamDescription.streamID,
              slots.indices.contains(drawable.slotIndex) else {
            throw lifecycleFailure("drawable does not belong to this stream")
        }

        let metadata = slots[drawable.slotIndex].metadata
        guard metadata.state == .acquiredForWrite,
              metadata.generation == drawable.generation else {
            throw lifecycleFailure("drawable is not the currently acquired generation")
        }

        nextFrameID += 1
        let frameID = nextFrameID
        let publishedNanoseconds = DispatchTime.now().uptimeNanoseconds
        slots[drawable.slotIndex].metadata = try metadata.published(
            frameID: frameID,
            publishedNanoseconds: publishedNanoseconds
        )
        publishedFrames += 1

        let snapshot = Syphon26TransportFrameSnapshot(
            streamID: streamDescription.streamID,
            frameID: frameID,
            slotIndex: drawable.slotIndex,
            generation: drawable.generation,
            width: streamDescription.width,
            height: streamDescription.height,
            pixelFormat: streamDescription.pixelFormat,
            publishedNanoseconds: publishedNanoseconds,
            repeatedForConsumer: false,
            missedFrameCount: 0
        )
        latestSnapshot = snapshot
        return snapshot
    }

    public func copyLatestFrame(consumerID rawConsumerID: String = "default") throws -> Syphon26TransportFrame? {
        let consumerID = try Syphon26Validation.validateIdentifier(rawConsumerID, field: "consumerID")

        lock.lock()
        defer { lock.unlock() }

        guard let latestSnapshot else {
            return nil
        }

        let previousFrameID = consumerCursors[consumerID]
        let repeatedForConsumer = previousFrameID == latestSnapshot.frameID
        let missedFrameCount: UInt64

        if repeatedForConsumer {
            repeatedReads += 1
            missedFrameCount = 0
        } else {
            missedFrameCount = Self.missedFrameCount(previousFrameID: previousFrameID, latestFrameID: latestSnapshot.frameID)
            missedFrames += missedFrameCount
            consumerCursors[consumerID] = latestSnapshot.frameID
        }
        receivedFrames += 1

        let consumerSnapshot = Syphon26TransportFrameSnapshot(
            streamID: latestSnapshot.streamID,
            frameID: latestSnapshot.frameID,
            slotIndex: latestSnapshot.slotIndex,
            generation: latestSnapshot.generation,
            width: latestSnapshot.width,
            height: latestSnapshot.height,
            pixelFormat: latestSnapshot.pixelFormat,
            publishedNanoseconds: latestSnapshot.publishedNanoseconds,
            repeatedForConsumer: repeatedForConsumer,
            missedFrameCount: missedFrameCount
        )

        return Syphon26TransportFrame(
            snapshot: consumerSnapshot,
            texture: slots[latestSnapshot.slotIndex].resource.texture
        )
    }

    public func diagnosticsSnapshot() -> Syphon26DiagnosticsSnapshot {
        lock.lock()
        defer { lock.unlock() }

        return Syphon26DiagnosticsSnapshot(
            lifecycleState: .running,
            controlPlaneState: .notConfigured,
            syncMode: .automatic,
            syncFallbackReason: .none,
            publishedFrames: publishedFrames,
            receivedFrames: receivedFrames,
            missedFrames: missedFrames,
            repeatedReads: repeatedReads,
            overwrittenFrames: overwrittenFrames,
            consumerCount: consumerCursors.count
        )
    }

    public func metadataSnapshot() -> [Syphon26RingSlotMetadata] {
        lock.lock()
        defer { lock.unlock() }
        return slots.map(\.metadata)
    }

    private static func missedFrameCount(previousFrameID: UInt64?, latestFrameID: UInt64) -> UInt64 {
        guard let previousFrameID else {
            return latestFrameID > 1 ? latestFrameID - 1 : 0
        }
        return latestFrameID > previousFrameID + 1 ? latestFrameID - previousFrameID - 1 : 0
    }

    private func lifecycleFailure(_ reason: String) -> Syphon26Error {
        Syphon26Error.lifecycle(
            Syphon26LifecycleIssue(code: .invalidState, state: .running, reason: reason)
        )
    }

    private struct Slot {
        let resource: Syphon26IOSurfaceResource
        var metadata: Syphon26RingSlotMetadata
    }
}
