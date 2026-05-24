import Foundation
import Metal

public final class Syphon26ServerDrawable: @unchecked Sendable {
    public let texture: any MTLTexture
    public let sequence: Syphon26Sequence
    public let slotIndex: Int
    public let width: Int
    public let height: Int
    public let pixelFormat: MTLPixelFormat
    public let streamDescription: Syphon26StreamDescription

    init(
        texture: any MTLTexture,
        sequence: Syphon26Sequence,
        slotIndex: Int,
        streamDescription: Syphon26StreamDescription
    ) {
        self.texture = texture
        self.sequence = sequence
        self.slotIndex = slotIndex
        self.width = streamDescription.width
        self.height = streamDescription.height
        self.pixelFormat = streamDescription.pixelFormat
        self.streamDescription = streamDescription
    }
}

