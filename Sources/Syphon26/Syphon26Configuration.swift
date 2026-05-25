import Foundation

public enum Syphon26Validation {
    public static func validateStreamName(_ rawName: String, field: String = "name") throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw validation(.invalidStreamName, field: field, reason: "stream name must not be empty")
        }
        guard name.count <= 255 else {
            throw validation(.invalidStreamName, field: field, reason: "stream name must be 255 characters or fewer")
        }
        guard !containsControlCharacter(name) else {
            throw validation(.invalidStreamName, field: field, reason: "stream name must not contain control characters")
        }
        return name
    }

    public static func validateIdentifier(_ rawValue: String, field: String) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw validation(.invalidStreamID, field: field, reason: "identifier must not be empty")
        }
        guard value.count <= 255 else {
            throw validation(.invalidStreamID, field: field, reason: "identifier must be 255 characters or fewer")
        }
        guard !containsControlCharacter(value) else {
            throw validation(.invalidStreamID, field: field, reason: "identifier must not contain control characters")
        }
        return value
    }

    public static func validateDimensions(width: Int, height: Int) throws {
        let maxDimension = Syphon26.maximumTextureDimension
        guard width > 0, height > 0, width <= maxDimension, height <= maxDimension else {
            throw validation(
                .invalidDimensions,
                field: "size",
                reason: "dimensions must be within 1...\(maxDimension)"
            )
        }
    }

    public static func validatePixelFormat(_ pixelFormat: Syphon26PixelFormat, field: String = "pixelFormat") throws {
        guard pixelFormat.isSupported else {
            throw validation(
                .unsupportedPixelFormat,
                field: field,
                reason: "\(pixelFormat.rawName) is not supported by the Phase 1 contract"
            )
        }
    }

    public static func validateBufferCount(_ bufferCount: Int) throws {
        guard bufferCount >= Syphon26.minimumBufferCount, bufferCount <= Syphon26.maximumBufferCount else {
            throw validation(
                .invalidBufferCount,
                field: "bufferCount",
                reason: "buffer count must be within \(Syphon26.minimumBufferCount)...\(Syphon26.maximumBufferCount)"
            )
        }
    }

    public static func validatePreferredPixelFormats(_ pixelFormats: [Syphon26PixelFormat]) throws {
        guard !pixelFormats.isEmpty else {
            throw validation(
                .emptyPreferredPixelFormats,
                field: "preferredPixelFormats",
                reason: "at least one preferred pixel format is required"
            )
        }
        for pixelFormat in pixelFormats {
            try validatePixelFormat(pixelFormat, field: "preferredPixelFormats")
        }
    }

    public static func validateControlPlaneServiceName(_ rawName: String) throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw validation(
                .invalidControlPlaneServiceName,
                field: "controlPlaneServiceName",
                reason: "service name must not be empty"
            )
        }
        guard name.count <= 255 else {
            throw validation(
                .invalidControlPlaneServiceName,
                field: "controlPlaneServiceName",
                reason: "service name must be 255 characters or fewer"
            )
        }
        guard name.contains("."),
              !name.hasPrefix("."),
              !name.hasSuffix("."),
              !name.contains("..") else {
            throw validation(
                .invalidControlPlaneServiceName,
                field: "controlPlaneServiceName",
                reason: "service name must use reverse-DNS style components"
            )
        }
        guard name.unicodeScalars.allSatisfy(isAllowedServiceNameScalar) else {
            throw validation(
                .invalidControlPlaneServiceName,
                field: "controlPlaneServiceName",
                reason: "service name may contain only ASCII letters, digits, dot, dash, and underscore"
            )
        }
        return name
    }

    static func validation(_ code: Syphon26ValidationCode, field: String, reason: String) -> Syphon26Error {
        .validation(Syphon26ValidationIssue(code: code, field: field, reason: reason))
    }

    private static func containsControlCharacter(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            scalar.value < 0x20 || scalar.value == 0x7f
        }
    }

    private static func isAllowedServiceNameScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 45, 46, 48...57, 65...90, 95, 97...122:
            true
        default:
            false
        }
    }
}

public struct Syphon26ServerConfiguration: Equatable, Sendable {
    public let name: String
    public let appName: String?
    public let width: Int
    public let height: Int
    public let pixelFormat: Syphon26PixelFormat
    public let bufferCount: Int
    public let syncMode: Syphon26SyncMode
    public let controlPlaneServiceName: String

    public init(
        name: String,
        appName: String? = nil,
        width: Int,
        height: Int,
        pixelFormat: Syphon26PixelFormat = .bgra8Unorm,
        bufferCount: Int = 3,
        syncMode: Syphon26SyncMode = .automatic,
        controlPlaneServiceName: String = Syphon26.defaultControlPlaneServiceName
    ) throws {
        self.name = try Syphon26Validation.validateStreamName(name)
        if let appName {
            self.appName = try Syphon26Validation.validateStreamName(appName, field: "appName")
        } else {
            self.appName = nil
        }
        try Syphon26Validation.validateDimensions(width: width, height: height)
        try Syphon26Validation.validatePixelFormat(pixelFormat)
        try Syphon26Validation.validateBufferCount(bufferCount)
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.bufferCount = bufferCount
        self.syncMode = syncMode
        self.controlPlaneServiceName = try Syphon26Validation.validateControlPlaneServiceName(controlPlaneServiceName)
    }

    public var size: Syphon26FrameSize {
        get throws {
            try Syphon26FrameSize(width: width, height: height)
        }
    }
}

public struct Syphon26ClientConfiguration: Equatable, Sendable {
    public let streamID: Syphon26StreamID
    public let preferredPixelFormats: [Syphon26PixelFormat]
    public let controlPlaneServiceName: String

    public init(
        streamID: Syphon26StreamID,
        preferredPixelFormats: [Syphon26PixelFormat] = [.bgra8Unorm, .rgba16Float],
        controlPlaneServiceName: String = Syphon26.defaultControlPlaneServiceName
    ) throws {
        try Syphon26Validation.validatePreferredPixelFormats(preferredPixelFormats)
        self.streamID = streamID
        self.preferredPixelFormats = preferredPixelFormats
        self.controlPlaneServiceName = try Syphon26Validation.validateControlPlaneServiceName(controlPlaneServiceName)
    }
}
