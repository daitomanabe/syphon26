import Foundation
import Metal

public final class Syphon26ControlPlane: @unchecked Sendable {
    private let client: Syphon26XPCControlClient

    public init(endpoint: NSXPCListenerEndpoint) {
        self.client = Syphon26XPCControlClient(endpoint: endpoint)
    }

    public init(machServiceName: String) {
        self.client = Syphon26XPCControlClient(machServiceName: machServiceName)
    }

    public func invalidate() {
        client.invalidate()
    }

    func registerProducer(
        description: Syphon26StreamDescription,
        resources: [Syphon26SlotResource],
        sharedEvent: (any MTLSharedEvent)?
    ) throws {
        let surfaces = resources.compactMap(\.surface)
        guard surfaces.count == resources.count else {
            throw Syphon26Error.ioSurfaceHandoffFailed
        }
        let sharedEventHandle = sharedEvent?.makeSharedEventHandle()
        _ = try client.registerProducerTransport(
            description,
            surfaces: surfaces,
            sharedEventHandle: sharedEventHandle
        )
    }

    func retireProducer(streamID: Syphon26StreamID) throws {
        try client.retireProducer(streamID: streamID)
    }

    func registerConsumer(streamID: Syphon26StreamID) throws -> Syphon26XPCConsumerRegistrationResponse {
        try client.registerConsumer(streamID: streamID)
    }

    func retireConsumer(streamID: Syphon26StreamID, consumerID: String) throws {
        try client.retireConsumer(streamID: streamID, consumerID: consumerID)
    }

    func copyIOSurfaceSlots(
        streamID: Syphon26StreamID,
        device: any MTLDevice
    ) throws -> [Syphon26XPCResolvedSlot] {
        let slots = try client.copyIOSurfaceSlots(streamID: streamID)
        return try Syphon26XPCTransportResolver.makeTextures(from: slots, device: device)
    }

    func copySharedEvent(streamID: Syphon26StreamID, device: any MTLDevice) throws -> (any MTLSharedEvent)? {
        let handle = try client.copySharedEventHandle(streamID: streamID)
        return try Syphon26XPCTransportResolver.makeSharedEvent(from: handle, device: device)
    }

    func updateSharedState(streamID: Syphon26StreamID, state: Syphon26SharedState) throws {
        try client.updateSharedState(streamID: streamID, state: state)
    }

    func copySharedState(streamID: Syphon26StreamID) throws -> Syphon26SharedState {
        try client.copySharedState(streamID: streamID)
    }

    func listStreams() throws -> [Syphon26StreamDescription] {
        try client.listStreams()
    }

    func activeConsumerCount(streamID: Syphon26StreamID) throws -> Int {
        try client.activeConsumerCount(streamID: streamID)
    }
}

public final class Syphon26ControlPlaneServer: @unchecked Sendable {
    private let listener: Syphon26XPCControlListener

    public var endpoint: NSXPCListenerEndpoint {
        listener.endpoint
    }

    public init() {
        self.listener = Syphon26XPCControlListener()
    }

    deinit {
        listener.stop()
    }

    public func start() throws {
        try listener.start()
    }

    public func stop() {
        listener.stop()
    }

    public func makeControlPlane() -> Syphon26ControlPlane {
        Syphon26ControlPlane(endpoint: endpoint)
    }
}

public enum Syphon26ControlPlaneServiceMain {
    public static func run() throws -> Never {
        let listener = Syphon26XPCControlListener(listener: .service())
        try listener.start()
        RunLoop.current.run()
        fatalError("RunLoop.current.run() returned unexpectedly")
    }
}
