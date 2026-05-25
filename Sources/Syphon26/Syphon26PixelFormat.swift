import Metal

public struct Syphon26PixelFormatMetadata: Equatable, Sendable {
    public let format: Syphon26PixelFormat
    public let metalPixelFormatRawValue: UInt
    public let bytesPerPixel: Int
    public let channelCount: Int
    public let bitsPerComponent: Int
    public let isFloat: Bool
    public let fixtureName: String

    public var metalPixelFormat: MTLPixelFormat {
        MTLPixelFormat(rawValue: metalPixelFormatRawValue) ?? .invalid
    }
}

public extension Syphon26PixelFormat {
    static let baselineFormats: [Syphon26PixelFormat] = [.bgra8Unorm, .rgba16Float]

    var metalPixelFormat: MTLPixelFormat {
        get throws {
            switch self {
            case .bgra8Unorm:
                .bgra8Unorm
            case .rgba16Float:
                .rgba16Float
            case .unsupported:
                throw Syphon26Validation.validation(
                    .unsupportedPixelFormat,
                    field: "pixelFormat",
                    reason: "\(rawName) has no Metal validation mapping"
                )
            }
        }
    }

    var metadata: Syphon26PixelFormatMetadata {
        get throws {
            switch self {
            case .bgra8Unorm:
                Syphon26PixelFormatMetadata(
                    format: self,
                    metalPixelFormatRawValue: MTLPixelFormat.bgra8Unorm.rawValue,
                    bytesPerPixel: 4,
                    channelCount: 4,
                    bitsPerComponent: 8,
                    isFloat: false,
                    fixtureName: Syphon26MetalFixture.bgra8ColorBars.rawValue
                )
            case .rgba16Float:
                Syphon26PixelFormatMetadata(
                    format: self,
                    metalPixelFormatRawValue: MTLPixelFormat.rgba16Float.rawValue,
                    bytesPerPixel: 8,
                    channelCount: 4,
                    bitsPerComponent: 16,
                    isFloat: true,
                    fixtureName: Syphon26MetalFixture.rgba16FloatGradient.rawValue
                )
            case .unsupported:
                throw Syphon26Validation.validation(
                    .unsupportedPixelFormat,
                    field: "pixelFormat",
                    reason: "\(rawName) has no metadata"
                )
            }
        }
    }
}

public enum Syphon26MetalFixture: String, CaseIterable, Sendable {
    case bgra8ColorBars
    case rgba16FloatGradient

    var identifier: UInt32 {
        switch self {
        case .bgra8ColorBars:
            0
        case .rgba16FloatGradient:
            1
        }
    }

    public static func defaultFixture(for pixelFormat: Syphon26PixelFormat) throws -> Syphon26MetalFixture {
        switch pixelFormat {
        case .bgra8Unorm:
            .bgra8ColorBars
        case .rgba16Float:
            .rgba16FloatGradient
        case .unsupported:
            throw Syphon26Validation.validation(
                .unsupportedPixelFormat,
                field: "pixelFormat",
                reason: "\(pixelFormat.rawName) has no deterministic Metal fixture"
            )
        }
    }

    public func expectedChecksum(width: Int, height: Int) -> UInt32 {
        var checksum: UInt32 = 0
        for y in 0..<height {
            for x in 0..<width {
                let component = quantizedComponents(x: x, y: y, width: width)
                checksum = checksum &+ contribution(
                    x: UInt32(x),
                    y: UInt32(y),
                    r: component.r,
                    g: component.g,
                    b: component.b,
                    a: component.a
                )
            }
        }
        return checksum
    }

    func quantizedComponents(x: Int, y: Int, width: Int) -> (r: UInt32, g: UInt32, b: UInt32, a: UInt32) {
        switch self {
        case .bgra8ColorBars:
            let clampedWidth = max(width, 1)
            let bar = min((x * 4) / clampedWidth, 3)
            switch bar {
            case 0:
                return (1_024, 0, 0, 1_024)
            case 1:
                return (0, 1_024, 0, 1_024)
            case 2:
                return (0, 0, 1_024, 1_024)
            default:
                return (1_024, 1_024, 1_024, 1_024)
            }
        case .rgba16FloatGradient:
            return (
                UInt32(x & 3) * 256,
                UInt32(y & 3) * 256,
                UInt32((x + y) & 3) * 256,
                1_024
            )
        }
    }

    func contribution(x: UInt32, y: UInt32, r: UInt32, g: UInt32, b: UInt32, a: UInt32) -> UInt32 {
        ((x &+ 1) &* 3)
            &+ ((y &+ 1) &* 5)
            &+ (r &* 11)
            &+ (g &* 17)
            &+ (b &* 23)
            &+ (a &* 29)
    }
}
