public enum Syphon26RingSlotState: String, CaseIterable, Sendable {
    case empty
    case acquiredForWrite
    case published
    case retired
}

public struct Syphon26RingSlotMetadata: Equatable, Sendable {
    public static let currentABIVersion: UInt32 = 1

    public let abiVersion: UInt32
    public let slotIndex: Int
    public let generation: UInt64
    public let frameID: UInt64?
    public let state: Syphon26RingSlotState
    public let publishedNanoseconds: UInt64?

    public init(
        abiVersion: UInt32 = Syphon26RingSlotMetadata.currentABIVersion,
        slotIndex: Int,
        generation: UInt64 = 0,
        frameID: UInt64? = nil,
        state: Syphon26RingSlotState = .empty,
        publishedNanoseconds: UInt64? = nil
    ) throws {
        try Self.validateABIVersion(abiVersion)
        guard slotIndex >= 0 else {
            throw Syphon26Error.ioSurface(
                Syphon26RuntimeIssue(operation: "validateRingSlotMetadata", reason: "slot index must be non-negative")
            )
        }

        self.abiVersion = abiVersion
        self.slotIndex = slotIndex
        self.generation = generation
        self.frameID = frameID
        self.state = state
        self.publishedNanoseconds = publishedNanoseconds
    }

    public static func validateABIVersion(_ abiVersion: UInt32) throws {
        guard abiVersion == currentABIVersion else {
            throw Syphon26Error.ioSurface(
                Syphon26RuntimeIssue(
                    operation: "validateRingSlotMetadataABI",
                    reason: "expected ABI \(currentABIVersion), got \(abiVersion)"
                )
            )
        }
    }

    public func acquiredForWrite(nextGeneration: UInt64) throws -> Syphon26RingSlotMetadata {
        try Syphon26RingSlotMetadata(
            abiVersion: abiVersion,
            slotIndex: slotIndex,
            generation: nextGeneration,
            frameID: nil,
            state: .acquiredForWrite,
            publishedNanoseconds: nil
        )
    }

    public func published(frameID: UInt64, publishedNanoseconds: UInt64) throws -> Syphon26RingSlotMetadata {
        try Syphon26RingSlotMetadata(
            abiVersion: abiVersion,
            slotIndex: slotIndex,
            generation: generation,
            frameID: frameID,
            state: .published,
            publishedNanoseconds: publishedNanoseconds
        )
    }

    public func retired() throws -> Syphon26RingSlotMetadata {
        try Syphon26RingSlotMetadata(
            abiVersion: abiVersion,
            slotIndex: slotIndex,
            generation: generation,
            frameID: frameID,
            state: .retired,
            publishedNanoseconds: publishedNanoseconds
        )
    }
}
