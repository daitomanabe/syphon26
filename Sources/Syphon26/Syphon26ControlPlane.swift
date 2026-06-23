import Foundation

public final class Syphon26ControlPlane: Syphon26ControlPlaneProtocol {
    private let backend: any Syphon26ControlPlaneProtocol

    public convenience init() {
        self.init(backend: Syphon26InProcessControlPlane(uncheckedServiceName: Syphon26.defaultControlPlaneServiceName))
    }

    public convenience init(machServiceName: String) throws {
        self.init(backend: try Syphon26InProcessControlPlane(serviceName: machServiceName))
    }

    public init(backend: any Syphon26ControlPlaneProtocol) {
        self.backend = backend
    }

    public var serviceName: String {
        backend.serviceName
    }

    public func health() -> Syphon26ControlPlaneHealth {
        backend.health()
    }

    public func streams() throws -> [Syphon26StreamDescription] {
        try backend.streams()
    }

    public func consumers(for streamID: Syphon26StreamID) throws -> [Syphon26ConsumerRegistration] {
        try backend.consumers(for: streamID)
    }

    public func registerProducer(_ streamDescription: Syphon26StreamDescription, processID: Int32) throws {
        try backend.registerProducer(streamDescription, processID: processID)
    }

    public func unregisterProducer(streamID: Syphon26StreamID) throws {
        try backend.unregisterProducer(streamID: streamID)
    }

    public func registerConsumer(streamID: Syphon26StreamID, consumerID: String, processID: Int32) throws {
        try backend.registerConsumer(streamID: streamID, consumerID: consumerID, processID: processID)
    }

    public func unregisterConsumer(streamID: Syphon26StreamID, consumerID: String) throws {
        try backend.unregisterConsumer(streamID: streamID, consumerID: consumerID)
    }

    public func cleanupProducer(processID: Int32) throws -> [Syphon26StreamID] {
        try backend.cleanupProducer(processID: processID)
    }

    public func cleanupConsumer(processID: Int32) throws -> [Syphon26ConsumerRegistration] {
        try backend.cleanupConsumer(processID: processID)
    }
}

public final class Syphon26InProcessControlPlane: Syphon26ControlPlaneProtocol {
    public let serviceName: String

    private let lock = NSLock()
    private var producers: [Syphon26StreamID: Syphon26ProducerRegistration] = [:]
    private var consumersByKey: [ConsumerKey: Syphon26ConsumerRegistration] = [:]

    public convenience init(serviceName: String) throws {
        let validatedServiceName = try Syphon26Validation.validateControlPlaneServiceName(serviceName)
        self.init(uncheckedServiceName: validatedServiceName)
    }

    init(uncheckedServiceName serviceName: String) {
        self.serviceName = serviceName
    }

    public func health() -> Syphon26ControlPlaneHealth {
        lock.lock()
        defer { lock.unlock() }

        return Syphon26ControlPlaneHealth(
            serviceName: serviceName,
            schemaVersion: Syphon26ControlPlaneWireProtocol.currentSchemaVersion,
            state: .connected(serviceName),
            registeredStreamCount: producers.count,
            registeredConsumerCount: consumersByKey.count
        )
    }

    public func streams() throws -> [Syphon26StreamDescription] {
        lock.lock()
        defer { lock.unlock() }

        return producers.values
            .map(\.streamDescription)
            .sorted { $0.streamID.value < $1.streamID.value }
    }

    public func consumers(for streamID: Syphon26StreamID) throws -> [Syphon26ConsumerRegistration] {
        lock.lock()
        defer { lock.unlock() }

        return consumersByKey.values
            .filter { $0.streamID == streamID }
            .sorted { $0.consumerID < $1.consumerID }
    }

    public func registerProducer(_ streamDescription: Syphon26StreamDescription, processID: Int32) throws {
        try requireMatchingService(streamDescription.controlPlaneServiceName)

        lock.lock()
        defer { lock.unlock() }

        producers[streamDescription.streamID] = Syphon26ProducerRegistration(
            streamDescription: streamDescription,
            processID: processID,
            registeredNanoseconds: DispatchTime.now().uptimeNanoseconds
        )
    }

    public func unregisterProducer(streamID: Syphon26StreamID) throws {
        lock.lock()
        defer { lock.unlock() }

        producers.removeValue(forKey: streamID)
        consumersByKey = consumersByKey.filter { $0.key.streamID != streamID }
    }

    public func registerConsumer(streamID: Syphon26StreamID, consumerID rawConsumerID: String, processID: Int32) throws {
        let consumerID = try Syphon26Validation.validateIdentifier(rawConsumerID, field: "consumerID")

        lock.lock()
        defer { lock.unlock() }

        guard producers[streamID] != nil else {
            throw Syphon26Error.controlPlane(
                Syphon26ControlPlaneIssue(
                    code: .registrationFailed,
                    serviceName: serviceName,
                    reason: "cannot register consumer for missing stream \(streamID.value)"
                )
            )
        }

        let key = ConsumerKey(streamID: streamID, consumerID: consumerID)
        consumersByKey[key] = Syphon26ConsumerRegistration(
            streamID: streamID,
            consumerID: consumerID,
            processID: processID,
            registeredNanoseconds: DispatchTime.now().uptimeNanoseconds
        )
    }

    public func unregisterConsumer(streamID: Syphon26StreamID, consumerID rawConsumerID: String) throws {
        let consumerID = try Syphon26Validation.validateIdentifier(rawConsumerID, field: "consumerID")

        lock.lock()
        defer { lock.unlock() }

        consumersByKey.removeValue(forKey: ConsumerKey(streamID: streamID, consumerID: consumerID))
    }

    public func cleanupProducer(processID: Int32) throws -> [Syphon26StreamID] {
        lock.lock()
        defer { lock.unlock() }

        let removedStreamIDs = producers.values
            .filter { $0.processID == processID }
            .map(\.streamDescription.streamID)
        for streamID in removedStreamIDs {
            producers.removeValue(forKey: streamID)
        }
        consumersByKey = consumersByKey.filter { !removedStreamIDs.contains($0.key.streamID) }
        return removedStreamIDs.sorted { $0.value < $1.value }
    }

    public func cleanupConsumer(processID: Int32) throws -> [Syphon26ConsumerRegistration] {
        lock.lock()
        defer { lock.unlock() }

        let removedRegistrations = consumersByKey.values
            .filter { $0.processID == processID }
            .sorted { $0.consumerID < $1.consumerID }
        let removedKeys = Set(removedRegistrations.map { ConsumerKey(streamID: $0.streamID, consumerID: $0.consumerID) })
        consumersByKey = consumersByKey.filter { !removedKeys.contains($0.key) }
        return removedRegistrations
    }

    private func requireMatchingService(_ streamServiceName: String) throws {
        guard streamServiceName == serviceName else {
            throw Syphon26Error.controlPlane(
                Syphon26ControlPlaneIssue(
                    code: .registrationFailed,
                    serviceName: serviceName,
                    reason: "stream uses \(streamServiceName), expected \(serviceName)"
                )
            )
        }
    }

    private struct ConsumerKey: Hashable {
        let streamID: Syphon26StreamID
        let consumerID: String
    }
}
