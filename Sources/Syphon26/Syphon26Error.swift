import Foundation

public let Syphon26ErrorDomain = "Syphon26ErrorDomain"

public enum Syphon26Error: Int, Error, Sendable, Equatable {
    case unsupportedDevice = 1
    case unsupportedPixelFormat
    case invalidConfiguration
    case transportUnavailable
    case xpcConnectionFailed
    case sharedEventUnavailable
    case ioSurfaceHandoffFailed
    case streamNotFound
    case streamRetired
    case timeout
    case noAvailableSlot
    case commandBufferRequired
    case internalInconsistency
    case invalidSharedState
    case unsupportedSharedStateVersion
}

extension Syphon26Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            "The Metal device is not supported."
        case .unsupportedPixelFormat:
            "The pixel format is not supported."
        case .invalidConfiguration:
            "The Syphon26 configuration is invalid."
        case .transportUnavailable:
            "The Syphon26 transport is unavailable."
        case .xpcConnectionFailed:
            "The XPC connection failed."
        case .sharedEventUnavailable:
            "MTLSharedEvent is unavailable."
        case .ioSurfaceHandoffFailed:
            "IOSurface handoff failed."
        case .streamNotFound:
            "The stream was not found."
        case .streamRetired:
            "The stream has retired."
        case .timeout:
            "The operation timed out."
        case .noAvailableSlot:
            "No frame slot is currently available."
        case .commandBufferRequired:
            "A Metal command buffer is required."
        case .internalInconsistency:
            "Syphon26 reached an internal inconsistent state."
        case .invalidSharedState:
            "The shared stream state is invalid."
        case .unsupportedSharedStateVersion:
            "The shared stream state version is unsupported."
        }
    }
}
