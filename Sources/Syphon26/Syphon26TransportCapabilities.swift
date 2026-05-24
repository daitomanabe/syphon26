import Foundation
import Metal

public struct Syphon26TransportCapabilities: Sendable, Equatable {
    public var syncMode: Syphon26SyncMode
    public var pixelFormat: MTLPixelFormat
    public var colorPrimaries: Syphon26ColorPrimaries
    public var transferFunction: Syphon26TransferFunction
    public var alphaMode: Syphon26AlphaMode
    public var ringSlotCount: Int
    public var fallbackReason: Syphon26FallbackReason

    public init(
        syncMode: Syphon26SyncMode,
        pixelFormat: MTLPixelFormat,
        colorPrimaries: Syphon26ColorPrimaries,
        transferFunction: Syphon26TransferFunction,
        alphaMode: Syphon26AlphaMode,
        ringSlotCount: Int,
        fallbackReason: Syphon26FallbackReason = .none
    ) {
        self.syncMode = syncMode
        self.pixelFormat = pixelFormat
        self.colorPrimaries = colorPrimaries
        self.transferFunction = transferFunction
        self.alphaMode = alphaMode
        self.ringSlotCount = ringSlotCount
        self.fallbackReason = fallbackReason
    }
}
