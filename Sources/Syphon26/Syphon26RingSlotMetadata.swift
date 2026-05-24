import Foundation

struct Syphon26RingSlotMetadata: Sendable, Equatable {
    var slotIndex: Int
    var ioSurfaceID: UInt32?
    var sequence: Syphon26Sequence
    var readySequence: Syphon26Sequence
    var width: Int
    var height: Int
    var pixelFormatRawValue: UInt64
    var timestamp: Syphon26HostTime

    init(
        slotIndex: Int,
        ioSurfaceID: UInt32?,
        width: Int,
        height: Int,
        pixelFormatRawValue: UInt64
    ) {
        self.slotIndex = slotIndex
        self.ioSurfaceID = ioSurfaceID
        self.sequence = 0
        self.readySequence = 0
        self.width = width
        self.height = height
        self.pixelFormatRawValue = pixelFormatRawValue
        self.timestamp = 0
    }
}
