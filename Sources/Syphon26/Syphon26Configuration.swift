import Foundation
import Metal

public struct Syphon26ServerConfiguration: Sendable {
    public var name: String
    public var appName: String?
    public var device: any MTLDevice
    public var width: Int
    public var height: Int
    public var pixelFormat: MTLPixelFormat
    public var slotCount: Int
    public var syncMode: Syphon26SyncMode
    public var deliveryMode: Syphon26DeliveryMode
    public var colorPrimaries: Syphon26ColorPrimaries
    public var transferFunction: Syphon26TransferFunction
    public var alphaMode: Syphon26AlphaMode
    public var privateStream: Bool
    public var metadata: [String: Syphon26MetadataValue]
    public var allowsFallbacks: Bool
    public var maximumProducerWaitNanoseconds: UInt64

    public init(
        name: String,
        appName: String? = nil,
        device: any MTLDevice,
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat = .bgra8Unorm,
        slotCount: Int = 3,
        syncMode: Syphon26SyncMode = .automatic,
        deliveryMode: Syphon26DeliveryMode = .latest,
        colorPrimaries: Syphon26ColorPrimaries = .sRGB,
        transferFunction: Syphon26TransferFunction = .sRGB,
        alphaMode: Syphon26AlphaMode = .opaque,
        privateStream: Bool = false,
        metadata: [String: Syphon26MetadataValue] = [:],
        allowsFallbacks: Bool = true,
        maximumProducerWaitNanoseconds: UInt64 = 0
    ) {
        self.name = name
        self.appName = appName
        self.device = device
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.slotCount = slotCount
        self.syncMode = syncMode
        self.deliveryMode = deliveryMode
        self.colorPrimaries = colorPrimaries
        self.transferFunction = transferFunction
        self.alphaMode = alphaMode
        self.privateStream = privateStream
        self.metadata = metadata
        self.allowsFallbacks = allowsFallbacks
        self.maximumProducerWaitNanoseconds = maximumProducerWaitNanoseconds
    }
}

public struct Syphon26ClientConfiguration: Sendable {
    public var device: any MTLDevice
    public var streamID: Syphon26StreamID?
    public var streamDescription: Syphon26StreamDescription?
    public var syncMode: Syphon26SyncMode
    public var deliveryMode: Syphon26DeliveryMode
    public var preferredPixelFormats: [MTLPixelFormat]
    public var allowsFallbacks: Bool
    public var maximumFrameWaitNanoseconds: UInt64

    public init(
        device: any MTLDevice,
        streamID: Syphon26StreamID? = nil,
        streamDescription: Syphon26StreamDescription? = nil,
        syncMode: Syphon26SyncMode = .automatic,
        deliveryMode: Syphon26DeliveryMode = .latest,
        preferredPixelFormats: [MTLPixelFormat] = [.bgra8Unorm, .bgra8Unorm_srgb],
        allowsFallbacks: Bool = true,
        maximumFrameWaitNanoseconds: UInt64 = 0
    ) {
        self.device = device
        self.streamID = streamID
        self.streamDescription = streamDescription
        self.syncMode = syncMode
        self.deliveryMode = deliveryMode
        self.preferredPixelFormats = preferredPixelFormats
        self.allowsFallbacks = allowsFallbacks
        self.maximumFrameWaitNanoseconds = maximumFrameWaitNanoseconds
    }
}

