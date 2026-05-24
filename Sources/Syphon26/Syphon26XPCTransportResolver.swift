import Foundation
import IOSurface
import Metal

struct Syphon26XPCResolvedSlot {
    var descriptor: Syphon26XPCIOSurfaceSlotDescriptor
    var surface: IOSurfaceRef
    var texture: any MTLTexture
}

enum Syphon26XPCTransportResolver {
    static func makeTextures(
        from slots: [Syphon26XPCIOSurfaceSlot],
        device: any MTLDevice
    ) throws -> [Syphon26XPCResolvedSlot] {
        try slots.map { slot in
            guard let pixelFormat = MTLPixelFormat(rawValue: slot.descriptor.pixelFormatRawValue),
                  Syphon26PixelFormatSupport.isSupported(pixelFormat) else {
                throw Syphon26Error.unsupportedPixelFormat
            }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: pixelFormat,
                width: slot.descriptor.width,
                height: slot.descriptor.height,
                mipmapped: false
            )
            descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
            descriptor.storageMode = .shared
            guard let texture = device.makeTexture(descriptor: descriptor, iosurface: slot.surface, plane: 0) else {
                throw Syphon26Error.ioSurfaceHandoffFailed
            }
            return Syphon26XPCResolvedSlot(
                descriptor: slot.descriptor,
                surface: slot.surface,
                texture: texture
            )
        }
    }

    static func makeSharedEvent(
        from handle: MTLSharedEventHandle?,
        device: any MTLDevice
    ) throws -> (any MTLSharedEvent)? {
        guard let handle else {
            return nil
        }
        guard let event = device.makeSharedEvent(handle: handle) else {
            throw Syphon26Error.sharedEventUnavailable
        }
        return event
    }
}
