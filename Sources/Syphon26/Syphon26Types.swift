import Foundation

public enum Syphon26PixelFormat: Hashable, Sendable, CustomStringConvertible {
    case bgra8Unorm
    case rgba16Float
    case unsupported(String)

    public init(rawName: String) {
        switch rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "bgra8unorm", "bgra8":
            self = .bgra8Unorm
        case "rgba16float", "rgba16f":
            self = .rgba16Float
        default:
            self = .unsupported(rawName)
        }
    }

    public var rawName: String {
        switch self {
        case .bgra8Unorm:
            "bgra8Unorm"
        case .rgba16Float:
            "rgba16Float"
        case .unsupported(let rawName):
            rawName
        }
    }

    public var isSupported: Bool {
        switch self {
        case .bgra8Unorm, .rgba16Float:
            true
        case .unsupported:
            false
        }
    }

    public var description: String {
        rawName
    }
}

public enum Syphon26SyncMode: String, CaseIterable, Sendable {
    case automatic
    case sharedEvent
    case sequenceCounter
}

public enum Syphon26AlphaMode: String, CaseIterable, Sendable {
    case premultiplied
    case straight
    case opaque
    case unknown
}

public enum Syphon26ColorPrimaries: String, CaseIterable, Sendable {
    case srgb
    case displayP3
    case rec2020
    case unknown
}

public enum Syphon26TransferFunction: String, CaseIterable, Sendable {
    case srgb
    case linear
    case pq
    case hlg
    case unknown
}

public enum Syphon26LifecycleState: String, CaseIterable, Sendable {
    case initialized
    case stopped
    case starting
    case running
    case stopping
    case failed
}

public struct Syphon26FrameSize: Equatable, Hashable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) throws {
        try Syphon26Validation.validateDimensions(width: width, height: height)
        self.width = width
        self.height = height
    }
}

public struct Syphon26StreamID: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let value: String

    public init(_ value: String) throws {
        self.value = try Syphon26Validation.validateIdentifier(value, field: "streamID")
    }

    public static func unchecked(_ value: String) -> Syphon26StreamID {
        Syphon26StreamID(value: value)
    }

    private init(value: String) {
        self.value = value
    }

    public var description: String {
        value
    }
}
