import Testing
import Syphon26

@Test
func xpcStartupVerifierDistinguishesStartupStates() throws {
    let serviceName = "com.example.syphon26.control-plane"
    let verifier = try Syphon26XPCStartupVerifier(expectedServiceName: serviceName)

    #expect(verifier.classify(reply: nil) == .missingService(serviceName))
    #expect(verifier.classify(reply: startupReply(serviceName: "com.example.other")) == .missingService(serviceName))
    #expect(verifier.classify(reply: startupReply(serviceName: serviceName, bootIdentifier: "old-session")) == .staleService(serviceName))
    #expect(verifier.classify(reply: startupReply(serviceName: serviceName, permissionToken: "wrong")) == .permissionMismatch(serviceName))
    #expect(verifier.classify(reply: startupReply(serviceName: serviceName, schemaVersion: 99)) == .schemaMismatch(expected: 1, actual: 99))
    #expect(verifier.classify(reply: startupReply(serviceName: serviceName)) == .connected(serviceName))

    let error = captureControlPlaneSyphonError {
        try verifier.requireHealthy(reply: nil)
    }
    #expect(error?.category == .controlPlane)
    #expect(error?.description.contains("missingService") == true)
}

@Test
func inProcessControlPlaneRegistersStreamsAndConsumers() throws {
    let serviceName = "com.example.syphon26.control-plane"
    let controlPlane = try Syphon26InProcessControlPlane(serviceName: serviceName)
    let stream = try makeControlPlaneStream(id: "stream-a", serviceName: serviceName)

    try controlPlane.registerProducer(stream, processID: 100)
    #expect(try controlPlane.streams() == [stream])

    try controlPlane.registerConsumer(streamID: stream.streamID, consumerID: "consumer-a", processID: 200)
    let consumers = try controlPlane.consumers(for: stream.streamID)
    #expect(consumers.map(\.consumerID) == ["consumer-a"])
    #expect(consumers.map(\.processID) == [200])

    let health = controlPlane.health()
    #expect(health.state == .connected(serviceName))
    #expect(health.registeredStreamCount == 1)
    #expect(health.registeredConsumerCount == 1)

    try controlPlane.unregisterConsumer(streamID: stream.streamID, consumerID: "consumer-a")
    #expect(try controlPlane.consumers(for: stream.streamID).isEmpty)

    try controlPlane.unregisterProducer(streamID: stream.streamID)
    #expect(try controlPlane.streams().isEmpty)
}

@Test
func inProcessControlPlaneRejectsMissingStreamConsumerRegistration() throws {
    let controlPlane = try Syphon26InProcessControlPlane(serviceName: "com.example.syphon26.control-plane")
    let streamID = try Syphon26StreamID("missing-stream")

    let error = captureControlPlaneSyphonError {
        try controlPlane.registerConsumer(streamID: streamID, consumerID: "consumer-a", processID: 200)
    }
    #expect(error?.category == .controlPlane)
    #expect(error?.description.contains("missing stream") == true)
}

@Test
func inProcessControlPlaneCleansUpCrashedProducerAndConsumerState() throws {
    let serviceName = "com.example.syphon26.control-plane"
    let controlPlane = try Syphon26InProcessControlPlane(serviceName: serviceName)
    let first = try makeControlPlaneStream(id: "stream-a", serviceName: serviceName)
    let second = try makeControlPlaneStream(id: "stream-b", serviceName: serviceName)

    try controlPlane.registerProducer(first, processID: 101)
    try controlPlane.registerProducer(second, processID: 102)
    try controlPlane.registerConsumer(streamID: first.streamID, consumerID: "first-consumer", processID: 201)
    try controlPlane.registerConsumer(streamID: second.streamID, consumerID: "second-consumer", processID: 202)

    let removedConsumers = try controlPlane.cleanupConsumer(processID: 201)
    #expect(removedConsumers.map(\.consumerID) == ["first-consumer"])
    #expect(try controlPlane.consumers(for: first.streamID).isEmpty)
    #expect(try controlPlane.consumers(for: second.streamID).map(\.consumerID) == ["second-consumer"])

    let removedStreams = try controlPlane.cleanupProducer(processID: 102)
    #expect(removedStreams == [second.streamID])
    #expect(try controlPlane.streams() == [first])
    #expect(try controlPlane.consumers(for: second.streamID).isEmpty)

    let health = controlPlane.health()
    #expect(health.registeredStreamCount == 1)
    #expect(health.registeredConsumerCount == 0)
}

@Test
func controlPlaneFacadeUsesDefaultHealthyBackend() throws {
    let controlPlane = Syphon26ControlPlane()
    let health = controlPlane.health()

    #expect(controlPlane.serviceName == Syphon26.defaultControlPlaneServiceName)
    #expect(health.state == .connected(Syphon26.defaultControlPlaneServiceName))
    #expect(try controlPlane.streams().isEmpty)
}

private func startupReply(
    serviceName: String,
    schemaVersion: UInt32? = Syphon26ControlPlaneWireProtocol.currentSchemaVersion,
    permissionToken: String? = Syphon26ControlPlaneWireProtocol.localPermissionToken,
    bootIdentifier: String? = Syphon26ControlPlaneWireProtocol.localBootIdentifier
) -> Syphon26XPCStartupReply {
    Syphon26XPCStartupReply(
        serviceName: serviceName,
        schemaVersion: schemaVersion,
        permissionToken: permissionToken,
        bootIdentifier: bootIdentifier,
        processID: 123
    )
}

private func makeControlPlaneStream(id: String, serviceName: String) throws -> Syphon26StreamDescription {
    try Syphon26StreamDescription(
        streamID: Syphon26StreamID.unchecked(id),
        name: id,
        appName: "Syphon26Tests",
        width: 640,
        height: 360,
        pixelFormat: .bgra8Unorm,
        controlPlaneServiceName: serviceName
    )
}

private func captureControlPlaneSyphonError(_ body: () throws -> Void) -> Syphon26Error? {
    do {
        try body()
        return nil
    } catch let error as Syphon26Error {
        return error
    } catch {
        #expect(Bool(false))
        return nil
    }
}
