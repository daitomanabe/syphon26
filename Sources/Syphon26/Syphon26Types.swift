import Foundation
import Metal

public typealias Syphon26StreamID = String
public typealias Syphon26Sequence = UInt64
public typealias Syphon26HostTime = UInt64

public enum Syphon26ColorPrimaries: String, Sendable, Codable, Equatable {
    case sRGB
    case displayP3
    case rec2020
    case unspecified
}

public enum Syphon26TransferFunction: String, Sendable, Codable, Equatable {
    case sRGB
    case linear
    case pq
    case hlg
    case unspecified
}

public enum Syphon26AlphaMode: String, Sendable, Codable, Equatable {
    case opaque
    case premultiplied
    case straight
    case unspecified
}

public enum Syphon26SyncMode: String, Sendable, Codable, Equatable {
    case automatic
    case sharedEvent
    case sequencePolling
}

public enum Syphon26DeliveryMode: String, Sendable, Codable, Equatable {
    case latest
    case boundedLatency
}

public enum Syphon26FallbackReason: String, Sendable, Codable, Equatable {
    case none
    case sharedEventUnavailable
    case sharedEventHandoffFailed
    case ioSurfaceSecureHandoffUnavailable
    case unsupportedPixelFormat
    case deviceMismatch
}

public enum Syphon26Role: String, Sendable, Codable, Equatable {
    case server
    case client
}

public struct Syphon26MetadataValue: Sendable, Codable, Equatable {
    public var stringValue: String

    public init(_ stringValue: String) {
        self.stringValue = stringValue
    }
}

