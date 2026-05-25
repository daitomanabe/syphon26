public enum Syphon26ErrorCategory: String, CaseIterable, Sendable {
    case validation
    case metal
    case ioSurface
    case controlPlane
    case xpcConnection
    case synchronization
    case lifecycle
}

public enum Syphon26ValidationCode: String, CaseIterable, Sendable {
    case invalidStreamName
    case invalidStreamID
    case invalidDimensions
    case unsupportedPixelFormat
    case invalidBufferCount
    case invalidControlPlaneServiceName
    case emptyPreferredPixelFormats
}

public struct Syphon26ValidationIssue: Error, Equatable, Sendable, CustomStringConvertible {
    public let code: Syphon26ValidationCode
    public let field: String
    public let reason: String

    public init(code: Syphon26ValidationCode, field: String, reason: String) {
        self.code = code
        self.field = field
        self.reason = reason
    }

    public var description: String {
        "\(code.rawValue) field=\(field) reason=\(reason)"
    }
}

public enum Syphon26ControlPlaneFailureCode: String, CaseIterable, Sendable {
    case missingService
    case staleService
    case permissionMismatch
    case schemaMismatch
    case registrationFailed
    case unavailable
}

public struct Syphon26ControlPlaneIssue: Error, Equatable, Sendable, CustomStringConvertible {
    public let code: Syphon26ControlPlaneFailureCode
    public let serviceName: String
    public let reason: String

    public init(code: Syphon26ControlPlaneFailureCode, serviceName: String, reason: String) {
        self.code = code
        self.serviceName = serviceName
        self.reason = reason
    }

    public var description: String {
        "\(code.rawValue) service=\(serviceName) reason=\(reason)"
    }
}

public enum Syphon26XPCConnectionFailureCode: String, CaseIterable, Sendable {
    case connectionFailed
    case interrupted
    case invalidReply
    case serviceUnavailable
}

public struct Syphon26XPCConnectionIssue: Error, Equatable, Sendable, CustomStringConvertible {
    public let code: Syphon26XPCConnectionFailureCode
    public let serviceName: String
    public let reason: String

    public init(code: Syphon26XPCConnectionFailureCode, serviceName: String, reason: String) {
        self.code = code
        self.serviceName = serviceName
        self.reason = reason
    }

    public var description: String {
        "\(code.rawValue) service=\(serviceName) reason=\(reason)"
    }
}

public enum Syphon26LifecycleFailureCode: String, CaseIterable, Sendable {
    case alreadyStarted
    case notStarted
    case alreadyStopped
    case invalidState
}

public struct Syphon26LifecycleIssue: Error, Equatable, Sendable, CustomStringConvertible {
    public let code: Syphon26LifecycleFailureCode
    public let state: Syphon26LifecycleState
    public let reason: String

    public init(code: Syphon26LifecycleFailureCode, state: Syphon26LifecycleState, reason: String) {
        self.code = code
        self.state = state
        self.reason = reason
    }

    public var description: String {
        "\(code.rawValue) state=\(state.rawValue) reason=\(reason)"
    }
}

public struct Syphon26RuntimeIssue: Error, Equatable, Sendable, CustomStringConvertible {
    public let operation: String
    public let reason: String

    public init(operation: String, reason: String) {
        self.operation = operation
        self.reason = reason
    }

    public var description: String {
        "\(operation) failed: \(reason)"
    }
}

public enum Syphon26Error: Error, Equatable, Sendable, CustomStringConvertible {
    case validation(Syphon26ValidationIssue)
    case metal(Syphon26RuntimeIssue)
    case ioSurface(Syphon26RuntimeIssue)
    case controlPlane(Syphon26ControlPlaneIssue)
    case xpcConnection(Syphon26XPCConnectionIssue)
    case synchronization(Syphon26RuntimeIssue)
    case lifecycle(Syphon26LifecycleIssue)

    public var category: Syphon26ErrorCategory {
        switch self {
        case .validation:
            .validation
        case .metal:
            .metal
        case .ioSurface:
            .ioSurface
        case .controlPlane:
            .controlPlane
        case .xpcConnection:
            .xpcConnection
        case .synchronization:
            .synchronization
        case .lifecycle:
            .lifecycle
        }
    }

    public var validationCode: Syphon26ValidationCode? {
        if case .validation(let issue) = self {
            issue.code
        } else {
            nil
        }
    }

    public var description: String {
        switch self {
        case .validation(let issue):
            "validation: \(issue)"
        case .metal(let issue):
            "metal: \(issue)"
        case .ioSurface(let issue):
            "ioSurface: \(issue)"
        case .controlPlane(let issue):
            "controlPlane: \(issue)"
        case .xpcConnection(let issue):
            "xpcConnection: \(issue)"
        case .synchronization(let issue):
            "synchronization: \(issue)"
        case .lifecycle(let issue):
            "lifecycle: \(issue)"
        }
    }
}
