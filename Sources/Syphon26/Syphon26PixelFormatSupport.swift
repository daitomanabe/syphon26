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
}

