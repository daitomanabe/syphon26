import Foundation
import Metal

public struct Syphon26StreamDescription: Sendable, Equatable {
    public var streamID: Syphon26StreamID
    public var name: String
    public var appName: String?
    public var processIdentifier: Int32
    public var width: Int
    public var height: Int
    public var pixelFormat: MTLPixelFormat
    public var colorPrimaries: Syphon26ColorPrimaries
    public var transferFunction: Syphon26TransferFunction
    public var alphaMode: Syphon26AlphaMode
    public var slotCount: Int
    public var syncMode: Syphon26SyncMode
    public var deliveryMode: Syphon26DeliveryMode
    public var capabilities: Set<String>
    public var metadata: [String: Syphon26MetadataValue]
    public var descriptionVersion: UInt64
    public var createdAtHostTime: Syphon26HostTime

    public init(
        streamID: Syphon26StreamID,
        name: String,
        appName: String?,
        processIdentifier: Int32,
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat,
        colorPrimaries: Syphon26ColorPrimaries,
        transferFunction: Syphon26TransferFunction,
        alphaMode: Syphon26AlphaMode,
        slotCount: Int,
        syncMode: Syphon26SyncMode,
        deliveryMode: Syphon26DeliveryMode,
        capabilities: Set<String> = [],
        metadata: [String: Syphon26MetadataValue] = [:],
        descriptionVersion: UInt64 = 1,
        createdAtHostTime: Syphon26HostTime = Syphon26Clock.hostTime()
    ) {
        self.streamID = streamID
        self.name = name
        self.appName = appName
        self.processIdentifier = processIdentifier
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.colorPrimaries = colorPrimaries
        self.transferFunction = transferFunction
        self.alphaMode = alphaMode
        self.slotCount = slotCount
        self.syncMode = syncMode
        self.deliveryMode = deliveryMode
        self.capabilities = capabilities
        self.metadata = metadata
        self.descriptionVersion = descriptionVersion
        self.createdAtHostTime = createdAtHostTime
    }
}

