import Foundation
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

@objc(Syphon26XPCControlServicing)
protocol Syphon26XPCControlServicing {
    func registerProducer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void)
    func retireProducer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void)
    func registerConsumer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void)
    func retireConsumer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void)
    func listStreams(withReply reply: @escaping (Data?, NSError?) -> Void)
}

final class Syphon26XPCControlService: NSObject, Syphon26XPCControlServicing {
    private let lock = NSLock()
    private var streams: [Syphon26StreamID: Syphon26XPCStreamDescription] = [:]
    private var consumersByStream: [Syphon26StreamID: Set<String>] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func registerProducer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        do {
            let request = try decoder.decode(Syphon26XPCProducerRegistrationRequest.self, from: requestData)
            lock.lock()
            streams[request.stream.streamID] = request.stream
            consumersByStream[request.stream.streamID, default: []] = consumersByStream[request.stream.streamID, default: []]
            lock.unlock()
            try replyEncoded(Syphon26XPCProducerRegistrationResponse(stream: request.stream), reply: reply)
        } catch {
            reply(nil, nsError(Syphon26Error.invalidConfiguration))
        }
    }

    func retireProducer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        do {
            let request = try decoder.decode(Syphon26XPCProducerRetirementRequest.self, from: requestData)
            lock.lock()
            streams.removeValue(forKey: request.streamID)
            consumersByStream.removeValue(forKey: request.streamID)
            lock.unlock()
            reply(Data(), nil)
        } catch {
            reply(nil, nsError(Syphon26Error.invalidConfiguration))
        }
    }

    func registerConsumer(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
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
            lock.unlock()
            reply(Data(), nil)
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
}

final class Syphon26XPCControlListener: NSObject, NSXPCListenerDelegate {
    private let listener: NSXPCListener
    private let service: Syphon26XPCControlService

    var endpoint: NSXPCListenerEndpoint {
        listener.endpoint
    }

    override init() {
        self.listener = NSXPCListener.anonymous()
        self.service = Syphon26XPCControlService()
        super.init()
        self.listener.delegate = self
    }

    func start() {
        listener.resume()
    }

    func stop() {
        listener.invalidate()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: (any Syphon26XPCControlServicing).self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}

final class Syphon26XPCControlClient {
    private let connection: NSXPCConnection
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(endpoint: NSXPCListenerEndpoint) {
        self.connection = NSXPCConnection(listenerEndpoint: endpoint)
        self.connection.remoteObjectInterface = NSXPCInterface(with: (any Syphon26XPCControlServicing).self)
        self.connection.resume()
    }

    deinit {
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
            result = .failure(error)
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
}
