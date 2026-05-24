import Foundation
import Metal

public final class Syphon26Frame: @unchecked Sendable {
    public let texture: any MTLTexture
    public let sequence: Syphon26Sequence
    public let timestamp: Syphon26HostTime
    public let width: Int
    public let height: Int
    public let pixelFormat: MTLPixelFormat
    public let colorPrimaries: Syphon26ColorPrimaries
    public let transferFunction: Syphon26TransferFunction
    public let alphaMode: Syphon26AlphaMode
    public let metadata: [String: Syphon26MetadataValue]
    public let streamDescription: Syphon26StreamDescription
    public let requiresGPUWait: Bool

    public init(
        texture: any MTLTexture,
        sequence: Syphon26Sequence,
        timestamp: Syphon26HostTime,
        streamDescription: Syphon26StreamDescription,
        metadata: [String: Syphon26MetadataValue] = [:],
        requiresGPUWait: Bool = false
    ) {
        self.texture = texture
        self.sequence = sequence
        self.timestamp = timestamp
        self.width = streamDescription.width
        self.height = streamDescription.height
        self.pixelFormat = streamDescription.pixelFormat
        self.colorPrimaries = streamDescription.colorPrimaries
        self.transferFunction = streamDescription.transferFunction
        self.alphaMode = streamDescription.alphaMode
        self.metadata = metadata
        self.streamDescription = streamDescription
        self.requiresGPUWait = requiresGPUWait
    }

    public func encodeWait(on commandBuffer: any MTLCommandBuffer) throws {
    }

    public func markConsumed(commandBuffer: (any MTLCommandBuffer)? = nil) {
    }

    public func close() {
    }
}

