import Foundation
import IOSurface
import Metal

struct Syphon26XPCStreamDescription: Codable, Equatable, Sendable {
    var streamID: Syphon26StreamID
    var name: String
    var appName: String?
    var processIdentifier: Int32
    var width: Int
    var height: Int
    var pixelFormatRawValue: UInt
    var colorPrimaries: Syphon26ColorPrimaries
    var transferFunction: Syphon26TransferFunction
    var alphaMode: Syphon26AlphaMode
    var slotCount: Int
    var syncMode: Syphon26SyncMode
    var deliveryMode: Syphon26DeliveryMode
    var fallbackReason: Syphon26FallbackReason
    var capabilities: Set<String>
    var metadata: [String: Syphon26MetadataValue]
    var descriptionVersion: UInt64
    var createdAtHostTime: Syphon26HostTime

    init(description: Syphon26StreamDescription) {
        self.streamID = description.streamID
        self.name = description.name
        self.appName = description.appName
        self.processIdentifier = description.processIdentifier
        self.width = description.width
        self.height = description.height
        self.pixelFormatRawValue = description.pixelFormat.rawValue
        self.colorPrimaries = description.colorPrimaries
        self.transferFunction = description.transferFunction
        self.alphaMode = description.alphaMode
        self.slotCount = description.slotCount
        self.syncMode = description.syncMode
        self.deliveryMode = description.deliveryMode
        self.fallbackReason = description.transportCapabilities.fallbackReason
        self.capabilities = description.capabilities
        self.metadata = description.metadata
        self.descriptionVersion = description.descriptionVersion
        self.createdAtHostTime = description.createdAtHostTime
    }

    func makeDescription() -> Syphon26StreamDescription {
        let pixelFormat = MTLPixelFormat(rawValue: pixelFormatRawValue) ?? .invalid
        return Syphon26StreamDescription(
            streamID: streamID,
            name: name,
            appName: appName,
            processIdentifier: processIdentifier,
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            colorPrimaries: colorPrimaries,
            transferFunction: transferFunction,
            alphaMode: alphaMode,
            slotCount: slotCount,
            syncMode: syncMode,
            deliveryMode: deliveryMode,
            transportCapabilities: Syphon26TransportCapabilities(
                syncMode: syncMode,
                pixelFormat: pixelFormat,
                colorPrimaries: colorPrimaries,
                transferFunction: transferFunction,
                alphaMode: alphaMode,
                ringSlotCount: slotCount,
                fallbackReason: fallbackReason
            ),
            capabilities: capabilities,
            metadata: metadata,
            descriptionVersion: descriptionVersion,
            createdAtHostTime: createdAtHostTime
        )
    }
}

struct Syphon26XPCProducerRegistrationRequest: Codable, Sendable {
    var stream: Syphon26XPCStreamDescription
}

struct Syphon26XPCProducerRegistrationResponse: Codable, Sendable {
    var stream: Syphon26XPCStreamDescription
}

struct Syphon26XPCProducerRetirementRequest: Codable, Sendable {
    var streamID: Syphon26StreamID
}

struct Syphon26XPCConsumerRegistrationRequest: Codable, Sendable {
    var streamID: Syphon26StreamID
    var processIdentifier: Int32
}

struct Syphon26XPCConsumerRegistrationResponse: Codable, Sendable {
    var consumerID: String
    var stream: Syphon26XPCStreamDescription
}

struct Syphon26XPCConsumerRetirementRequest: Codable, Sendable {
    var streamID: Syphon26StreamID
    var consumerID: String
}

struct Syphon26XPCListStreamsResponse: Codable, Sendable {
    var streams: [Syphon26XPCStreamDescription]
}

struct Syphon26XPCIOSurfaceSlotDescriptor: Codable, Equatable, Sendable {
    var slotIndex: Int
    var ioSurfaceID: UInt32
    var width: Int
    var height: Int
    var pixelFormatRawValue: UInt
}

struct Syphon26XPCProducerTransportRegistrationRequest: Codable, Sendable {
    var stream: Syphon26XPCStreamDescription
    var slots: [Syphon26XPCIOSurfaceSlotDescriptor]
}

struct Syphon26XPCProducerTransportRegistrationResponse: Codable, Sendable {
    var stream: Syphon26XPCStreamDescription
    var slots: [Syphon26XPCIOSurfaceSlotDescriptor]
    var hasSharedEventHandle: Bool
}

struct Syphon26XPCIOSurfaceSlotRequest: Codable, Sendable {
    var streamID: Syphon26StreamID
}

struct Syphon26XPCIOSurfaceSlotResponse: Codable, Sendable {
    var slots: [Syphon26XPCIOSurfaceSlotDescriptor]
}

struct Syphon26XPCSharedEventHandleRequest: Codable, Sendable {
    var streamID: Syphon26StreamID
}

struct Syphon26XPCSharedEventHandleResponse: Codable, Sendable {
    var hasSharedEventHandle: Bool
}

struct Syphon26XPCSharedStateRequest: Codable, Sendable {
    var streamID: Syphon26StreamID
}

struct Syphon26XPCSharedStateUpdateRequest: Codable, Sendable {
    var streamID: Syphon26StreamID
    var state: Syphon26SharedState
}

struct Syphon26XPCSharedStateResponse: Codable, Sendable {
    var state: Syphon26SharedState
}

struct Syphon26XPCStreamDiagnosticsRequest: Codable, Sendable {
    var streamID: Syphon26StreamID
}

struct Syphon26XPCStreamDiagnosticsResponse: Codable, Sendable {
    var activeConsumerCount: Int
}

struct Syphon26XPCIOSurfaceSlot {
    var descriptor: Syphon26XPCIOSurfaceSlotDescriptor
    var surface: IOSurfaceRef
}

@objc(Syphon26XPCControlServicing)
protocol Syphon26XPCControlServicing {
    func registerProducer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void)
    func registerProducerTransport(
        _ requestData: Data,
        surfaces: NSArray,
        sharedEventHandle: MTLSharedEventHandle?,
        withReply reply: @escaping (Data?, NSError?) -> Void
    )
    func retireProducer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void)
    func registerConsumer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void)
    func retireConsumer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void)
    func copyIOSurfaceSlots(
        _ requestData: Data,
        withReply reply: @escaping (Data?, NSArray?, NSError?) -> Void
    )
    func copySharedEventHandle(
        _ requestData: Data,
        withReply reply: @escaping (Data?, MTLSharedEventHandle?, NSError?) -> Void
    )
    func updateSharedState(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void)
    func copySharedState(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void)
    func streamDiagnostics(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void)
    func listStreams(withReply reply: @escaping (Data?, NSError?) -> Void)
}

final class Syphon26XPCControlService: NSObject {
    private let lock = NSLock()
    private var streams: [Syphon26StreamID: Syphon26XPCStreamDescription] = [:]
    private var slotDescriptorsByStream: [Syphon26StreamID: [Syphon26XPCIOSurfaceSlotDescriptor]] = [:]
    private var surfacesByStream: [Syphon26StreamID: [IOSurfaceRef]] = [:]
    private var sharedEventHandlesByStream: [Syphon26StreamID: MTLSharedEventHandle] = [:]
    private var sharedStatesByStream: [Syphon26StreamID: Syphon26SharedState] = [:]
    private var consumersByStream: [Syphon26StreamID: Set<String>] = [:]
    private var producerOwners: [Syphon26StreamID: UUID] = [:]
    private var consumerOwners: [Syphon26StreamID: [String: UUID]] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func registerProducer(_ requestData: Data, ownerID: UUID, withReply reply: @escaping (Data?, NSError?) -> Void) {
        do {
            let request = try decoder.decode(Syphon26XPCProducerRegistrationRequest.self, from: requestData)
            lock.lock()
            streams[request.stream.streamID] = request.stream
            producerOwners[request.stream.streamID] = ownerID
            consumersByStream[request.stream.streamID, default: []] = consumersByStream[request.stream.streamID, default: []]
            lock.unlock()
            try replyEncoded(Syphon26XPCProducerRegistrationResponse(stream: request.stream), reply: reply)
        } catch {
            reply(nil, nsError(Syphon26Error.invalidConfiguration))
        }
    }

    func registerProducerTransport(
        _ requestData: Data,
        surfaces surfaceArray: NSArray,
        sharedEventHandle: MTLSharedEventHandle?,
        ownerID: UUID,
        withReply reply: @escaping (Data?, NSError?) -> Void
    ) {
        do {
            let request = try decoder.decode(Syphon26XPCProducerTransportRegistrationRequest.self, from: requestData)
            let surfaces = try Self.copySurfaces(from: surfaceArray)
            guard surfaces.count == request.slots.count else {
                reply(nil, nsError(Syphon26Error.invalidConfiguration))
                return
            }
            for (surface, slot) in zip(surfaces, request.slots) {
                guard IOSurfaceGetID(surface) == slot.ioSurfaceID else {
                    reply(nil, nsError(Syphon26Error.ioSurfaceHandoffFailed))
                    return
                }
            }

            lock.lock()
            streams[request.stream.streamID] = request.stream
            slotDescriptorsByStream[request.stream.streamID] = request.slots
            surfacesByStream[request.stream.streamID] = surfaces
            sharedEventHandlesByStream[request.stream.streamID] = sharedEventHandle
            sharedStatesByStream[request.stream.streamID] = Syphon26SharedState(description: request.stream.makeDescription())
            producerOwners[request.stream.streamID] = ownerID
            consumersByStream[request.stream.streamID, default: []] = consumersByStream[request.stream.streamID, default: []]
            lock.unlock()
            try replyEncoded(
                Syphon26XPCProducerTransportRegistrationResponse(
                    stream: request.stream,
                    slots: request.slots,
                    hasSharedEventHandle: sharedEventHandle != nil
                ),
                reply: reply
            )
        } catch let error as Syphon26Error {
            reply(nil, nsError(error))
        } catch {
            reply(nil, nsError(Syphon26Error.invalidConfiguration))
        }
    }

    func retireProducer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        do {
            let request = try decoder.decode(Syphon26XPCProducerRetirementRequest.self, from: requestData)
            lock.lock()
            streams.removeValue(forKey: request.streamID)
            slotDescriptorsByStream.removeValue(forKey: request.streamID)
            surfacesByStream.removeValue(forKey: request.streamID)
            sharedEventHandlesByStream.removeValue(forKey: request.streamID)
            sharedStatesByStream.removeValue(forKey: request.streamID)
            consumersByStream.removeValue(forKey: request.streamID)
            producerOwners.removeValue(forKey: request.streamID)
            consumerOwners.removeValue(forKey: request.streamID)
            lock.unlock()
            reply(Data(), nil)
        } catch {
            reply(nil, nsError(Syphon26Error.invalidConfiguration))
        }
    }

    func registerConsumer(_ requestData: Data, ownerID: UUID, withReply reply: @escaping (Data?, NSError?) -> Void) {
        do {
            let request = try decoder.decode(Syphon26XPCConsumerRegistrationRequest.self, from: requestData)
            lock.lock()
            guard let stream = streams[request.streamID] else {
                lock.unlock()
                reply(nil, nsError(Syphon26Error.streamNotFound))
                return
            }
            let consumerID = UUID().uuidString
            consumersByStream[request.streamID, default: []].insert(consumerID)
            consumerOwners[request.streamID, default: [:]][consumerID] = ownerID
            lock.unlock()
            try replyEncoded(
                Syphon26XPCConsumerRegistrationResponse(consumerID: consumerID, stream: stream),
                reply: reply
            )
        } catch {
            reply(nil, nsError(Syphon26Error.invalidConfiguration))
        }
    }

    func retireConsumer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        do {
            let request = try decoder.decode(Syphon26XPCConsumerRetirementRequest.self, from: requestData)
            lock.lock()
            consumersByStream[request.streamID]?.remove(request.consumerID)
            consumerOwners[request.streamID]?.removeValue(forKey: request.consumerID)
            lock.unlock()
            reply(Data(), nil)
        } catch {
            reply(nil, nsError(Syphon26Error.invalidConfiguration))
        }
    }

    func copyIOSurfaceSlots(
        _ requestData: Data,
        withReply reply: @escaping (Data?, NSArray?, NSError?) -> Void
    ) {
        do {
            let request = try decoder.decode(Syphon26XPCIOSurfaceSlotRequest.self, from: requestData)
            lock.lock()
            guard let slots = slotDescriptorsByStream[request.streamID],
                  let surfaces = surfacesByStream[request.streamID] else {
                lock.unlock()
                reply(nil, nil, nsError(Syphon26Error.streamNotFound))
                return
            }
            lock.unlock()
            let response = Syphon26XPCIOSurfaceSlotResponse(slots: slots)
            reply(try encoder.encode(response), NSArray(array: surfaces), nil)
        } catch let error as Syphon26Error {
            reply(nil, nil, nsError(error))
        } catch {
            reply(nil, nil, nsError(Syphon26Error.invalidConfiguration))
        }
    }

    func copySharedEventHandle(
        _ requestData: Data,
        withReply reply: @escaping (Data?, MTLSharedEventHandle?, NSError?) -> Void
    ) {
        do {
            let request = try decoder.decode(Syphon26XPCSharedEventHandleRequest.self, from: requestData)
            lock.lock()
            guard streams[request.streamID] != nil else {
                lock.unlock()
                reply(nil, nil, nsError(Syphon26Error.streamNotFound))
                return
            }
            let handle = sharedEventHandlesByStream[request.streamID]
            lock.unlock()
            let response = Syphon26XPCSharedEventHandleResponse(hasSharedEventHandle: handle != nil)
            reply(try encoder.encode(response), handle, nil)
        } catch {
            reply(nil, nil, nsError(Syphon26Error.invalidConfiguration))
        }
    }

    func updateSharedState(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        do {
            let request = try decoder.decode(Syphon26XPCSharedStateUpdateRequest.self, from: requestData)
            lock.lock()
            guard streams[request.streamID] != nil else {
                lock.unlock()
                reply(nil, nsError(Syphon26Error.streamNotFound))
                return
            }
            sharedStatesByStream[request.streamID] = request.state
            lock.unlock()
            reply(Data(), nil)
        } catch let error as Syphon26Error {
            reply(nil, nsError(error))
        } catch {
            reply(nil, nsError(Syphon26Error.invalidConfiguration))
        }
    }

    func copySharedState(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        do {
            let request = try decoder.decode(Syphon26XPCSharedStateRequest.self, from: requestData)
            lock.lock()
            guard let state = sharedStatesByStream[request.streamID] else {
                lock.unlock()
                reply(nil, nsError(Syphon26Error.streamNotFound))
                return
            }
            lock.unlock()
            try replyEncoded(Syphon26XPCSharedStateResponse(state: state), reply: reply)
        } catch {
            reply(nil, nsError(Syphon26Error.invalidConfiguration))
        }
    }

    func streamDiagnostics(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        do {
            let request = try decoder.decode(Syphon26XPCStreamDiagnosticsRequest.self, from: requestData)
            lock.lock()
            guard streams[request.streamID] != nil else {
                lock.unlock()
                reply(nil, nsError(Syphon26Error.streamNotFound))
                return
            }
            let count = consumersByStream[request.streamID]?.count ?? 0
            lock.unlock()
            try replyEncoded(Syphon26XPCStreamDiagnosticsResponse(activeConsumerCount: count), reply: reply)
        } catch {
            reply(nil, nsError(Syphon26Error.invalidConfiguration))
        }
    }

    func listStreams(withReply reply: @escaping (Data?, NSError?) -> Void) {
        lock.lock()
        let response = Syphon26XPCListStreamsResponse(streams: streams.values.sorted { $0.name < $1.name })
        lock.unlock()
        do {
            try replyEncoded(response, reply: reply)
        } catch {
            reply(nil, nsError(Syphon26Error.internalInconsistency))
        }
    }

    private func replyEncoded<T: Encodable>(_ value: T, reply: (Data?, NSError?) -> Void) throws {
        reply(try encoder.encode(value), nil)
    }

    private func nsError(_ error: Syphon26Error) -> NSError {
        NSError(domain: Syphon26ErrorDomain, code: error.rawValue)
    }

    private static func copySurfaces(from surfaceArray: NSArray) throws -> [IOSurfaceRef] {
        var surfaces: [IOSurfaceRef] = []
        surfaces.reserveCapacity(surfaceArray.count)
        for item in surfaceArray {
            guard CFGetTypeID(item as CFTypeRef) == IOSurfaceGetTypeID() else {
                throw Syphon26Error.ioSurfaceHandoffFailed
            }
            let surface = item as! IOSurfaceRef
            surfaces.append(surface)
        }
        return surfaces
    }

    func retireConnection(_ ownerID: UUID) {
        lock.lock()
        let retiredStreamIDs = producerOwners.compactMap { streamID, currentOwnerID in
            currentOwnerID == ownerID ? streamID : nil
        }
        for streamID in retiredStreamIDs {
            streams.removeValue(forKey: streamID)
            slotDescriptorsByStream.removeValue(forKey: streamID)
            surfacesByStream.removeValue(forKey: streamID)
            sharedEventHandlesByStream.removeValue(forKey: streamID)
            sharedStatesByStream.removeValue(forKey: streamID)
            consumersByStream.removeValue(forKey: streamID)
            producerOwners.removeValue(forKey: streamID)
            consumerOwners.removeValue(forKey: streamID)
        }
        for (streamID, ownersByConsumer) in consumerOwners {
            let staleConsumerIDs = ownersByConsumer.compactMap { consumerID, currentOwnerID in
                currentOwnerID == ownerID ? consumerID : nil
            }
            for consumerID in staleConsumerIDs {
                consumersByStream[streamID]?.remove(consumerID)
                consumerOwners[streamID]?.removeValue(forKey: consumerID)
            }
        }
        lock.unlock()
    }
}

final class Syphon26XPCControlConnection: NSObject, Syphon26XPCControlServicing {
    private let service: Syphon26XPCControlService
    private let ownerID: UUID

    init(service: Syphon26XPCControlService, ownerID: UUID) {
        self.service = service
        self.ownerID = ownerID
        super.init()
    }

    func registerProducer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        service.registerProducer(requestData, ownerID: ownerID, withReply: reply)
    }

    func registerProducerTransport(
        _ requestData: Data,
        surfaces: NSArray,
        sharedEventHandle: MTLSharedEventHandle?,
        withReply reply: @escaping (Data?, NSError?) -> Void
    ) {
        service.registerProducerTransport(
            requestData,
            surfaces: surfaces,
            sharedEventHandle: sharedEventHandle,
            ownerID: ownerID,
            withReply: reply
        )
    }

    func retireProducer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        service.retireProducer(requestData, withReply: reply)
    }

    func registerConsumer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        service.registerConsumer(requestData, ownerID: ownerID, withReply: reply)
    }

    func retireConsumer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        service.retireConsumer(requestData, withReply: reply)
    }

    func copyIOSurfaceSlots(
        _ requestData: Data,
        withReply reply: @escaping (Data?, NSArray?, NSError?) -> Void
    ) {
        service.copyIOSurfaceSlots(requestData, withReply: reply)
    }

    func copySharedEventHandle(
        _ requestData: Data,
        withReply reply: @escaping (Data?, MTLSharedEventHandle?, NSError?) -> Void
    ) {
        service.copySharedEventHandle(requestData, withReply: reply)
    }

    func updateSharedState(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        service.updateSharedState(requestData, withReply: reply)
    }

    func copySharedState(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        service.copySharedState(requestData, withReply: reply)
    }

    func streamDiagnostics(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        service.streamDiagnostics(requestData, withReply: reply)
    }

    func listStreams(withReply reply: @escaping (Data?, NSError?) -> Void) {
        service.listStreams(withReply: reply)
    }
}

final class Syphon26XPCControlListener: NSObject, NSXPCListenerDelegate {
    private let listener: NSXPCListener
    private let service: Syphon26XPCControlService
    private let namespace: Syphon26ControlPlaneNamespace

    var endpoint: NSXPCListenerEndpoint {
        listener.endpoint
    }

    init(namespace: Syphon26ControlPlaneNamespace = .current()) {
        self.listener = NSXPCListener.anonymous()
        self.service = Syphon26XPCControlService()
        self.namespace = namespace
        super.init()
        self.listener.delegate = self
    }

    func start() throws {
        try namespace.prepareRuntimeDirectory()
        listener.resume()
    }

    func stop() {
        listener.invalidate()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard namespace.acceptsPeer(userIdentifier: newConnection.effectiveUserIdentifier) else {
            return false
        }
        let interface = Self.makeInterface()
        let ownerID = UUID()
        newConnection.exportedInterface = interface
        newConnection.exportedObject = Syphon26XPCControlConnection(service: service, ownerID: ownerID)
        newConnection.invalidationHandler = { [service] in
            service.retireConnection(ownerID)
        }
        newConnection.interruptionHandler = { [service] in
            service.retireConnection(ownerID)
        }
        newConnection.resume()
        return true
    }

    static func makeInterface() -> NSXPCInterface {
        let interface = NSXPCInterface(with: (any Syphon26XPCControlServicing).self)
        let surfaceClasses = NSSet(objects: NSArray.self, IOSurface.self) as! Set<AnyHashable>
        let sharedEventHandleClasses = NSSet(objects: MTLSharedEventHandle.self) as! Set<AnyHashable>
        interface.setClasses(
            surfaceClasses,
            for: #selector((any Syphon26XPCControlServicing).registerProducerTransport(_:surfaces:sharedEventHandle:withReply:)),
            argumentIndex: 1,
            ofReply: false
        )
        interface.setClasses(
            sharedEventHandleClasses,
            for: #selector((any Syphon26XPCControlServicing).registerProducerTransport(_:surfaces:sharedEventHandle:withReply:)),
            argumentIndex: 2,
            ofReply: false
        )
        interface.setClasses(
            surfaceClasses,
            for: #selector((any Syphon26XPCControlServicing).copyIOSurfaceSlots(_:withReply:)),
            argumentIndex: 1,
            ofReply: true
        )
        interface.setClasses(
            sharedEventHandleClasses,
            for: #selector((any Syphon26XPCControlServicing).copySharedEventHandle(_:withReply:)),
            argumentIndex: 1,
            ofReply: true
        )
        return interface
    }
}

final class Syphon26XPCControlClient {
    private let connection: NSXPCConnection
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(endpoint: NSXPCListenerEndpoint) {
        self.connection = NSXPCConnection(listenerEndpoint: endpoint)
        self.connection.remoteObjectInterface = Syphon26XPCControlListener.makeInterface()
        self.connection.resume()
    }

    deinit {
        connection.invalidate()
    }

    func invalidate() {
        connection.invalidate()
    }

    func registerProducer(_ description: Syphon26StreamDescription) throws -> Syphon26StreamDescription {
        let request = Syphon26XPCProducerRegistrationRequest(stream: Syphon26XPCStreamDescription(description: description))
        let responseData = try perform { service, reply in
            service.registerProducer(try encoder.encode(request), withReply: reply)
        }
        return try decoder.decode(Syphon26XPCProducerRegistrationResponse.self, from: responseData)
            .stream
            .makeDescription()
    }

    func registerProducerTransport(
        _ description: Syphon26StreamDescription,
        surfaces: [IOSurfaceRef],
        sharedEventHandle: MTLSharedEventHandle? = nil
    ) throws -> [Syphon26XPCIOSurfaceSlotDescriptor] {
        let slots = surfaces.enumerated().map { index, surface in
            Syphon26XPCIOSurfaceSlotDescriptor(
                slotIndex: index,
                ioSurfaceID: IOSurfaceGetID(surface),
                width: IOSurfaceGetWidth(surface),
                height: IOSurfaceGetHeight(surface),
                pixelFormatRawValue: description.pixelFormat.rawValue
            )
        }
        let request = Syphon26XPCProducerTransportRegistrationRequest(
            stream: Syphon26XPCStreamDescription(description: description),
            slots: slots
        )
        let responseData = try perform { service, reply in
            service.registerProducerTransport(
                try encoder.encode(request),
                surfaces: NSArray(array: surfaces),
                sharedEventHandle: sharedEventHandle,
                withReply: reply
            )
        }
        return try decoder.decode(Syphon26XPCProducerTransportRegistrationResponse.self, from: responseData).slots
    }

    func retireProducer(streamID: Syphon26StreamID) throws {
        let request = Syphon26XPCProducerRetirementRequest(streamID: streamID)
        _ = try perform { service, reply in
            service.retireProducer(try encoder.encode(request), withReply: reply)
        }
    }

    func registerConsumer(streamID: Syphon26StreamID) throws -> Syphon26XPCConsumerRegistrationResponse {
        let request = Syphon26XPCConsumerRegistrationRequest(
            streamID: streamID,
            processIdentifier: ProcessInfo.processInfo.processIdentifier
        )
        let responseData = try perform { service, reply in
            service.registerConsumer(try encoder.encode(request), withReply: reply)
        }
        return try decoder.decode(Syphon26XPCConsumerRegistrationResponse.self, from: responseData)
    }

    func copyIOSurfaceSlots(streamID: Syphon26StreamID) throws -> [Syphon26XPCIOSurfaceSlot] {
        let request = Syphon26XPCIOSurfaceSlotRequest(streamID: streamID)
        let (responseData, surfaceArray) = try performSurfaceReply { service, reply in
            service.copyIOSurfaceSlots(try encoder.encode(request), withReply: reply)
        }
        let response = try decoder.decode(Syphon26XPCIOSurfaceSlotResponse.self, from: responseData)
        let surfaces = try Self.copySurfaces(from: surfaceArray)
        guard surfaces.count == response.slots.count else {
            throw Syphon26Error.ioSurfaceHandoffFailed
        }
        return zip(response.slots, surfaces).map { slot, surface in
            Syphon26XPCIOSurfaceSlot(descriptor: slot, surface: surface)
        }
    }

    func copySharedEventHandle(streamID: Syphon26StreamID) throws -> MTLSharedEventHandle? {
        let request = Syphon26XPCSharedEventHandleRequest(streamID: streamID)
        let (responseData, handle) = try performSharedEventHandleReply { service, reply in
            service.copySharedEventHandle(try encoder.encode(request), withReply: reply)
        }
        let response = try decoder.decode(Syphon26XPCSharedEventHandleResponse.self, from: responseData)
        if response.hasSharedEventHandle {
            guard let handle else {
                throw Syphon26Error.sharedEventUnavailable
            }
            return handle
        }
        return nil
    }

    func updateSharedState(streamID: Syphon26StreamID, state: Syphon26SharedState) throws {
        let request = Syphon26XPCSharedStateUpdateRequest(streamID: streamID, state: state)
        _ = try perform { service, reply in
            service.updateSharedState(try encoder.encode(request), withReply: reply)
        }
    }

    func copySharedState(streamID: Syphon26StreamID) throws -> Syphon26SharedState {
        let request = Syphon26XPCSharedStateRequest(streamID: streamID)
        let responseData = try perform { service, reply in
            service.copySharedState(try encoder.encode(request), withReply: reply)
        }
        return try decoder.decode(Syphon26XPCSharedStateResponse.self, from: responseData).state
    }

    func activeConsumerCount(streamID: Syphon26StreamID) throws -> Int {
        let request = Syphon26XPCStreamDiagnosticsRequest(streamID: streamID)
        let responseData = try perform { service, reply in
            service.streamDiagnostics(try encoder.encode(request), withReply: reply)
        }
        return try decoder.decode(Syphon26XPCStreamDiagnosticsResponse.self, from: responseData).activeConsumerCount
    }

    func retireConsumer(streamID: Syphon26StreamID, consumerID: String) throws {
        let request = Syphon26XPCConsumerRetirementRequest(streamID: streamID, consumerID: consumerID)
        _ = try perform { service, reply in
            service.retireConsumer(try encoder.encode(request), withReply: reply)
        }
    }

    func listStreams() throws -> [Syphon26StreamDescription] {
        let responseData = try perform { service, reply in
            service.listStreams(withReply: reply)
        }
        return try decoder.decode(Syphon26XPCListStreamsResponse.self, from: responseData)
            .streams
            .map { $0.makeDescription() }
    }

    private func perform(
        _ body: (any Syphon26XPCControlServicing, @escaping (Data?, NSError?) -> Void) throws -> Void
    ) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result: Result<Data, any Error>?

        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            lock.lock()
            result = .failure(Syphon26Error.xpcConnectionFailed)
            lock.unlock()
            semaphore.signal()
        }

        guard let service = proxy as? any Syphon26XPCControlServicing else {
            throw Syphon26Error.xpcConnectionFailed
        }

        try body(service) { data, error in
            lock.lock()
            if let error {
                result = .failure(Syphon26Error(rawValue: error.code) ?? Syphon26Error.xpcConnectionFailed)
            } else {
                result = .success(data ?? Data())
            }
            lock.unlock()
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + 2) == .success else {
            throw Syphon26Error.timeout
        }

        lock.lock()
        let finalResult = result
        lock.unlock()
        return try finalResult?.get() ?? Data()
    }

    private func performSurfaceReply(
        _ body: (
            any Syphon26XPCControlServicing,
            @escaping (Data?, NSArray?, NSError?) -> Void
        ) throws -> Void
    ) throws -> (Data, NSArray) {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result: Result<(Data, NSArray), any Error>?

        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            lock.lock()
            result = .failure(Syphon26Error.xpcConnectionFailed)
            lock.unlock()
            semaphore.signal()
        }

        guard let service = proxy as? any Syphon26XPCControlServicing else {
            throw Syphon26Error.xpcConnectionFailed
        }

        try body(service) { data, surfaces, error in
            lock.lock()
            if let error {
                result = .failure(Syphon26Error(rawValue: error.code) ?? Syphon26Error.xpcConnectionFailed)
            } else if let data, let surfaces {
                result = .success((data, surfaces))
            } else {
                result = .failure(Syphon26Error.ioSurfaceHandoffFailed)
            }
            lock.unlock()
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + 2) == .success else {
            throw Syphon26Error.timeout
        }

        lock.lock()
        let finalResult = result
        lock.unlock()
        return try finalResult?.get() ?? (Data(), NSArray())
    }

    private func performSharedEventHandleReply(
        _ body: (
            any Syphon26XPCControlServicing,
            @escaping (Data?, MTLSharedEventHandle?, NSError?) -> Void
        ) throws -> Void
    ) throws -> (Data, MTLSharedEventHandle?) {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result: Result<(Data, MTLSharedEventHandle?), any Error>?

        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            lock.lock()
            result = .failure(Syphon26Error.xpcConnectionFailed)
            lock.unlock()
            semaphore.signal()
        }

        guard let service = proxy as? any Syphon26XPCControlServicing else {
            throw Syphon26Error.xpcConnectionFailed
        }

        try body(service) { data, handle, error in
            lock.lock()
            if let error {
                result = .failure(Syphon26Error(rawValue: error.code) ?? Syphon26Error.xpcConnectionFailed)
            } else if let data {
                result = .success((data, handle))
            } else {
                result = .failure(Syphon26Error.sharedEventUnavailable)
            }
            lock.unlock()
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + 2) == .success else {
            throw Syphon26Error.timeout
        }

        lock.lock()
        let finalResult = result
        lock.unlock()
        return try finalResult?.get() ?? (Data(), nil)
    }

    private static func copySurfaces(from surfaceArray: NSArray) throws -> [IOSurfaceRef] {
        var surfaces: [IOSurfaceRef] = []
        surfaces.reserveCapacity(surfaceArray.count)
        for item in surfaceArray {
            guard CFGetTypeID(item as CFTypeRef) == IOSurfaceGetTypeID() else {
                throw Syphon26Error.ioSurfaceHandoffFailed
            }
            let surface = item as! IOSurfaceRef
            surfaces.append(surface)
        }
        return surfaces
    }
}
