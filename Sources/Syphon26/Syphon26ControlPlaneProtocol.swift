import Foundation

public enum Syphon26ControlPlaneWireProtocol: Sendable {
    public static let currentSchemaVersion: UInt32 = 1
    public static let localPermissionToken = "syphon26.local-user"
    public static let localBootIdentifier = "local-session"
}

public struct Syphon26ProducerRegistration: Equatable, Sendable {
    public let streamDescription: Syphon26StreamDescription
    public let processID: Int32
    public let registeredNanoseconds: UInt64
}

public struct Syphon26ConsumerRegistration: Equatable, Sendable {
    public let streamID: Syphon26StreamID
    public let consumerID: String
    public let processID: Int32
    public let registeredNanoseconds: UInt64
}

public struct Syphon26ControlPlaneHealth: Equatable, Sendable {
    public let serviceName: String
    public let schemaVersion: UInt32
    public let state: Syphon26ControlPlaneState
    public let registeredStreamCount: Int
    public let registeredConsumerCount: Int
}

public protocol Syphon26ControlPlaneProtocol: AnyObject {
    var serviceName: String { get }

    func health() -> Syphon26ControlPlaneHealth
    func streams() throws -> [Syphon26StreamDescription]
    func consumers(for streamID: Syphon26StreamID) throws -> [Syphon26ConsumerRegistration]
    func registerProducer(_ streamDescription: Syphon26StreamDescription, processID: Int32) throws
    func unregisterProducer(streamID: Syphon26StreamID) throws
    func registerConsumer(streamID: Syphon26StreamID, consumerID: String, processID: Int32) throws
    func unregisterConsumer(streamID: Syphon26StreamID, consumerID: String) throws
    func cleanupProducer(processID: Int32) throws -> [Syphon26StreamID]
    func cleanupConsumer(processID: Int32) throws -> [Syphon26ConsumerRegistration]
}
