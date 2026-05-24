import Foundation
import Metal

struct Syphon26SharedState: Sendable, Codable, Equatable {
    static let magic: UInt64 = 0x535950484F4E3236
    static let version: UInt32 = 1
    static let headerSize: UInt32 = 128
    static let maxSlots = 16
    static let maxClients = 64

    var magic: UInt64 = Self.magic
    var version: UInt32 = Self.version
    var headerSize: UInt32 = Self.headerSize
    var width: UInt32
    var height: UInt32
    var pixelFormatRawValue: UInt64
    var slotCount: UInt32
    var colorPrimaries: Syphon26ColorPrimaries
    var transferFunction: Syphon26TransferFunction
    var alphaMode: Syphon26AlphaMode
    var flags: UInt64
    var sequence: Syphon26Sequence
    var currentSlot: UInt32
    var activeClientCount: UInt32

    init(description: Syphon26StreamDescription) {
        self.width = UInt32(description.width)
        self.height = UInt32(description.height)
        self.pixelFormatRawValue = UInt64(description.pixelFormat.rawValue)
        self.slotCount = UInt32(description.slotCount)
        self.colorPrimaries = description.colorPrimaries
        self.transferFunction = description.transferFunction
        self.alphaMode = description.alphaMode
        self.flags = 0
        self.sequence = 0
        self.currentSlot = 0
        self.activeClientCount = 0
    }

    func validate() throws {
        guard magic == Self.magic else {
            throw Syphon26Error.invalidSharedState
        }
        guard version == Self.version else {
            throw Syphon26Error.unsupportedSharedStateVersion
        }
        guard headerSize >= Self.headerSize else {
            throw Syphon26Error.invalidSharedState
        }
        guard width > 0, height > 0 else {
            throw Syphon26Error.invalidSharedState
        }
        guard (2...UInt32(Self.maxSlots)).contains(slotCount) else {
            throw Syphon26Error.invalidSharedState
        }
        guard let pixelFormat = MTLPixelFormat(rawValue: UInt(pixelFormatRawValue)) else {
            throw Syphon26Error.unsupportedPixelFormat
        }
        guard Syphon26PixelFormatSupport.isSupported(pixelFormat) else {
            throw Syphon26Error.unsupportedPixelFormat
        }
        guard activeClientCount <= UInt32(Self.maxClients) else {
            throw Syphon26Error.invalidSharedState
        }
    }
}
