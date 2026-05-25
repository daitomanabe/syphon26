public enum Syphon26SyncFallbackReason: String, CaseIterable, Sendable {
    case none
    case sharedEventUnavailable
    case sharedEventHandleMissing
    case consumerUnsupported
    case waitTimedOut
}

public enum Syphon26ControlPlaneState: Equatable, Sendable, CustomStringConvertible {
    case notConfigured
    case disconnected
    case connecting(String)
    case connected(String)
    case missingService(String)
    case staleService(String)
    case permissionMismatch(String)
    case schemaMismatch(expected: UInt32, actual: UInt32?)
    case xpcConnectionFailed(serviceName: String, reason: String)

    public var description: String {
        switch self {
        case .notConfigured:
            "notConfigured"
        case .disconnected:
            "disconnected"
        case .connecting(let serviceName):
            "connecting(\(serviceName))"
        case .connected(let serviceName):
            "connected(\(serviceName))"
        case .missingService(let serviceName):
            "missingService(\(serviceName))"
        case .staleService(let serviceName):
            "staleService(\(serviceName))"
        case .permissionMismatch(let serviceName):
            "permissionMismatch(\(serviceName))"
        case .schemaMismatch(let expected, let actual):
            "schemaMismatch(expected=\(expected), actual=\(String(describing: actual)))"
        case .xpcConnectionFailed(let serviceName, let reason):
            "xpcConnectionFailed(service=\(serviceName), reason=\(reason))"
        }
    }
}

public struct Syphon26DiagnosticsSnapshot: Equatable, Sendable {
    public let lifecycleState: Syphon26LifecycleState
    public let controlPlaneState: Syphon26ControlPlaneState
    public let syncMode: Syphon26SyncMode
    public let syncFallbackReason: Syphon26SyncFallbackReason
    public let publishedFrames: UInt64
    public let receivedFrames: UInt64
    public let missedFrames: UInt64
    public let repeatedReads: UInt64
    public let overwrittenFrames: UInt64
    public let consumerCount: Int
    public let gpuWaitNanoseconds: UInt64
    public let xpcConnectionFailures: UInt64

    public init(
        lifecycleState: Syphon26LifecycleState = .initialized,
        controlPlaneState: Syphon26ControlPlaneState = .notConfigured,
        syncMode: Syphon26SyncMode = .automatic,
        syncFallbackReason: Syphon26SyncFallbackReason = .none,
        publishedFrames: UInt64 = 0,
        receivedFrames: UInt64 = 0,
        missedFrames: UInt64 = 0,
        repeatedReads: UInt64 = 0,
        overwrittenFrames: UInt64 = 0,
        consumerCount: Int = 0,
        gpuWaitNanoseconds: UInt64 = 0,
        xpcConnectionFailures: UInt64 = 0
    ) {
        self.lifecycleState = lifecycleState
        self.controlPlaneState = controlPlaneState
        self.syncMode = syncMode
        self.syncFallbackReason = syncFallbackReason
        self.publishedFrames = publishedFrames
        self.receivedFrames = receivedFrames
        self.missedFrames = missedFrames
        self.repeatedReads = repeatedReads
        self.overwrittenFrames = overwrittenFrames
        self.consumerCount = consumerCount
        self.gpuWaitNanoseconds = gpuWaitNanoseconds
        self.xpcConnectionFailures = xpcConnectionFailures
    }
}
