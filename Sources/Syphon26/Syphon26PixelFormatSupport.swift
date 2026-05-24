import CoreVideo
import Metal

enum Syphon26PixelFormatSupport {
    static func isSupported(_ pixelFormat: MTLPixelFormat) -> Bool {
        switch pixelFormat {
        case .bgra8Unorm, .bgra8Unorm_srgb, .rgba16Float:
            true
        default:
            false
        }
    }

    static func cvPixelFormat(for pixelFormat: MTLPixelFormat) -> OSType {
        switch pixelFormat {
        case .bgra8Unorm, .bgra8Unorm_srgb:
            kCVPixelFormatType_32BGRA
        case .rgba16Float:
            kCVPixelFormatType_64RGBAHalf
        default:
            kCVPixelFormatType_32BGRA
        }
    }

    static func bytesPerElement(for pixelFormat: MTLPixelFormat) -> Int {
        switch pixelFormat {
        case .bgra8Unorm, .bgra8Unorm_srgb:
            4
        case .rgba16Float:
            8
        default:
            4
        }
    }
}
