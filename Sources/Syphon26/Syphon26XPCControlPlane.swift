import Foundation

public struct Syphon26XPCStartupReply: Codable, Equatable, Sendable {
    public let serviceName: String
    public let schemaVersion: UInt32?
    public let permissionToken: String?
    public let bootIdentifier: String?
    public let processID: Int32

    public init(
        serviceName: String,
        schemaVersion: UInt32?,
        permissionToken: String?,
        bootIdentifier: String?,
        processID: Int32
    ) {
        self.serviceName = serviceName
        self.schemaVersion = schemaVersion
        self.permissionToken = permissionToken
        self.bootIdentifier = bootIdentifier
        self.processID = processID
    }
}

public struct Syphon26XPCStartupVerifier: Equatable, Sendable {
    public let expectedServiceName: String
    public let expectedSchemaVersion: UInt32
    public let expectedPermissionToken: String
    public let expectedBootIdentifier: String

    public init(
        expectedServiceName: String,
        expectedSchemaVersion: UInt32 = Syphon26ControlPlaneWireProtocol.currentSchemaVersion,
        expectedPermissionToken: String = Syphon26ControlPlaneWireProtocol.localPermissionToken,
        expectedBootIdentifier: String = Syphon26ControlPlaneWireProtocol.localBootIdentifier
    ) throws {
        self.expectedServiceName = try Syphon26Validation.validateControlPlaneServiceName(expectedServiceName)
        self.expectedSchemaVersion = expectedSchemaVersion
        self.expectedPermissionToken = expectedPermissionToken
        self.expectedBootIdentifier = expectedBootIdentifier
    }

    public func classify(reply: Syphon26XPCStartupReply?) -> Syphon26ControlPlaneState {
        guard let reply else {
            return .missingService(expectedServiceName)
        }
        guard reply.serviceName == expectedServiceName else {
            return .missingService(expectedServiceName)
        }
        guard reply.bootIdentifier == expectedBootIdentifier else {
            return .staleService(expectedServiceName)
        }
        guard reply.permissionToken == expectedPermissionToken else {
            return .permissionMismatch(expectedServiceName)
        }
        guard reply.schemaVersion == expectedSchemaVersion else {
            return .schemaMismatch(expected: expectedSchemaVersion, actual: reply.schemaVersion)
        }
        return .connected(expectedServiceName)
    }

    public func requireHealthy(reply: Syphon26XPCStartupReply?) throws {
        let state = classify(reply: reply)
        guard case .connected = state else {
            throw issue(for: state)
        }
    }

    private func issue(for state: Syphon26ControlPlaneState) -> Syphon26Error {
        switch state {
        case .missingService(let serviceName):
            return .controlPlane(
                Syphon26ControlPlaneIssue(code: .missingService, serviceName: serviceName, reason: "service did not reply")
            )
        case .staleService(let serviceName):
            return .controlPlane(
                Syphon26ControlPlaneIssue(code: .staleService, serviceName: serviceName, reason: "stale boot identifier")
            )
        case .permissionMismatch(let serviceName):
            return .controlPlane(
                Syphon26ControlPlaneIssue(code: .permissionMismatch, serviceName: serviceName, reason: "permission token mismatch")
            )
        case .schemaMismatch(let expected, let actual):
            return .controlPlane(
                Syphon26ControlPlaneIssue(
                    code: .schemaMismatch,
                    serviceName: expectedServiceName,
                    reason: "expected schema \(expected), got \(String(describing: actual))"
                )
            )
        case .xpcConnectionFailed(let serviceName, let reason):
            return .xpcConnection(
                Syphon26XPCConnectionIssue(code: .connectionFailed, serviceName: serviceName, reason: reason)
            )
        default:
            return .controlPlane(
                Syphon26ControlPlaneIssue(code: .unavailable, serviceName: expectedServiceName, reason: state.description)
            )
        }
    }
}

public final class Syphon26XPCControlPlane {
    public let serviceName: String
    public let verifier: Syphon26XPCStartupVerifier

    public init(serviceName: String = Syphon26.defaultControlPlaneServiceName) throws {
        self.serviceName = try Syphon26Validation.validateControlPlaneServiceName(serviceName)
        self.verifier = try Syphon26XPCStartupVerifier(expectedServiceName: self.serviceName)
    }

    public func verifyStartup(reply: Syphon26XPCStartupReply?) throws -> Syphon26ControlPlaneState {
        let state = verifier.classify(reply: reply)
        try verifier.requireHealthy(reply: reply)
        return state
    }
}
