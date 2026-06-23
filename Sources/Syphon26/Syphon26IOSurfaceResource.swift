import CoreVideo
import IOSurface
import Metal

public struct Syphon26IOSurfaceResourceDescriptor: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixelFormat: Syphon26PixelFormat
    public let metalPixelFormatRawValue: UInt
    public let ioSurfacePixelFormat: UInt32
    public let bytesPerPixel: Int
    public let bytesPerRow: Int
    public let textureUsageRawValue: UInt

    public init(
        width: Int,
        height: Int,
        pixelFormat: Syphon26PixelFormat,
        textureUsage: MTLTextureUsage = [.shaderRead, .shaderWrite, .renderTarget]
    ) throws {
        try Syphon26Validation.validateDimensions(width: width, height: height)
        try Syphon26Validation.validatePixelFormat(pixelFormat)

        let metadata = try pixelFormat.metadata
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.metalPixelFormatRawValue = metadata.metalPixelFormatRawValue
        self.ioSurfacePixelFormat = try pixelFormat.ioSurfacePixelFormat
        self.bytesPerPixel = metadata.bytesPerPixel
        self.bytesPerRow = Self.alignedBytesPerRow(width: width, bytesPerPixel: metadata.bytesPerPixel)
        self.textureUsageRawValue = textureUsage.rawValue
    }

    public var metalPixelFormat: MTLPixelFormat {
        MTLPixelFormat(rawValue: metalPixelFormatRawValue) ?? .invalid
    }

    public var textureUsage: MTLTextureUsage {
        MTLTextureUsage(rawValue: textureUsageRawValue)
    }

    private static func alignedBytesPerRow(width: Int, bytesPerPixel: Int) -> Int {
        let unaligned = width * bytesPerPixel
        let alignment = 64
        return ((unaligned + alignment - 1) / alignment) * alignment
    }
}

public final class Syphon26IOSurfaceResource {
    public let descriptor: Syphon26IOSurfaceResourceDescriptor
    public let texture: any MTLTexture

    let surface: IOSurfaceRef

    var ioSurfaceID: UInt32 {
        IOSurfaceGetID(surface)
    }

    public init(descriptor: Syphon26IOSurfaceResourceDescriptor, device: any MTLDevice) throws {
        let properties: [String: Any] = [
            kIOSurfaceWidth as String: descriptor.width,
            kIOSurfaceHeight as String: descriptor.height,
            kIOSurfaceBytesPerElement as String: descriptor.bytesPerPixel,
            kIOSurfaceBytesPerRow as String: descriptor.bytesPerRow,
            kIOSurfacePixelFormat as String: descriptor.ioSurfacePixelFormat,
            "IOSurfaceIsGlobal": true
        ]

        guard let surface = IOSurfaceCreate(properties as CFDictionary) else {
            throw Syphon26Error.ioSurface(
                Syphon26RuntimeIssue(operation: "IOSurfaceCreate", reason: "IOSurface returned nil")
            )
        }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: descriptor.metalPixelFormat,
            width: descriptor.width,
            height: descriptor.height,
            mipmapped: false
        )
        textureDescriptor.usage = descriptor.textureUsage
        textureDescriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: textureDescriptor, iosurface: surface, plane: 0) else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(
                    operation: "makeTextureFromIOSurface",
                    reason: "Metal returned nil IOSurface-backed texture"
                )
            )
        }

        self.descriptor = descriptor
        self.surface = surface
        self.texture = texture
    }
}

private extension Syphon26PixelFormat {
    var ioSurfacePixelFormat: UInt32 {
        get throws {
            switch self {
            case .bgra8Unorm:
                kCVPixelFormatType_32BGRA
            case .rgba16Float:
                kCVPixelFormatType_64RGBAHalf
            case .unsupported:
                throw Syphon26Validation.validation(
                    .unsupportedPixelFormat,
                    field: "pixelFormat",
                    reason: "\(rawName) has no IOSurface pixel format mapping"
                )
            }
        }
    }
}
