import Foundation
import IOSurface
import Metal
@preconcurrency import XPC

public struct Syphon26ProductionXPCFrameMetadata: Equatable, Sendable {
    public let streamDescription: Syphon26StreamDescription
    public let frameID: UInt64
    public let publishedFrames: UInt64
    public let processID: Int32
    public let publishedNanoseconds: UInt64
}

public final class Syphon26ProductionXPCFrame {
    public let metadata: Syphon26ProductionXPCFrameMetadata
    public let texture: any MTLTexture

    init(metadata: Syphon26ProductionXPCFrameMetadata, texture: any MTLTexture) {
        self.metadata = metadata
        self.texture = texture
    }
}

public final class Syphon26ProductionXPCControlPlane {
    public let serviceName: String

    public init(serviceName: String = Syphon26.defaultControlPlaneServiceName) throws {
        self.serviceName = try Syphon26Validation.validateControlPlaneServiceName(serviceName)
    }

    public func health() throws -> Syphon26ControlPlaneHealth {
        let reply = try request(operation: "health")
        try Self.requireOK(reply, serviceName: serviceName)
        let state = Syphon26ControlPlaneState.connected(Self.string(reply, "serviceName") ?? serviceName)
        return Syphon26ControlPlaneHealth(
            serviceName: Self.string(reply, "serviceName") ?? serviceName,
            schemaVersion: UInt32(Self.uint(reply, "schemaVersion")),
            state: state,
            registeredStreamCount: Int(Self.uint(reply, "registeredStreamCount")),
            registeredConsumerCount: Int(Self.uint(reply, "registeredConsumerCount"))
        )
    }

    public func reset() throws {
        let reply = try request(operation: "reset")
        try Self.requireOK(reply, serviceName: serviceName)
    }

    public func publish(
        resource: Syphon26IOSurfaceResource,
        streamDescription: Syphon26StreamDescription,
        frameID: UInt64,
        publishedFrames: UInt64,
        processID: Int32 = getpid()
    ) throws {
        let message = makeRequest(operation: "publish")
        xpc_dictionary_set_string(message, "streamID", streamDescription.streamID.value)
        xpc_dictionary_set_string(message, "name", streamDescription.name)
        if let appName = streamDescription.appName {
            xpc_dictionary_set_string(message, "appName", appName)
        }
        xpc_dictionary_set_int64(message, "width", Int64(streamDescription.width))
        xpc_dictionary_set_int64(message, "height", Int64(streamDescription.height))
        xpc_dictionary_set_string(message, "pixelFormat", streamDescription.pixelFormat.rawName)
        xpc_dictionary_set_uint64(message, "frameID", frameID)
        xpc_dictionary_set_uint64(message, "publishedFrames", publishedFrames)
        xpc_dictionary_set_int64(message, "processID", Int64(processID))
        xpc_dictionary_set_uint64(message, "publishedNanoseconds", DispatchTime.now().uptimeNanoseconds)

        let surfaceObject = IOSurfaceCreateXPCObject(resource.surface)
        xpc_dictionary_set_value(message, "surface", surfaceObject)

        let reply = try send(message)
        try Self.requireOK(reply, serviceName: serviceName)
    }

    public func latestMetadata() throws -> Syphon26ProductionXPCFrameMetadata {
        let reply = try request(operation: "latest")
        try Self.requireOK(reply, serviceName: serviceName)
        return try Self.metadata(from: reply)
    }

    public func waitForMetadata(timeoutSeconds: Double = 5.0, pollIntervalSeconds: Double = 0.01) throws -> Syphon26ProductionXPCFrameMetadata {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var lastError: (any Error)?
        while Date() < deadline {
            do {
                return try latestMetadata()
            } catch {
                lastError = error
                Thread.sleep(forTimeInterval: pollIntervalSeconds)
            }
        }
        throw Syphon26Error.controlPlane(
            Syphon26ControlPlaneIssue(
                code: .missingService,
                serviceName: serviceName,
                reason: "production XPC metadata unavailable: \(String(describing: lastError))"
            )
        )
    }

    public func openLatestFrame(device: any MTLDevice) throws -> Syphon26ProductionXPCFrame {
        let reply = try request(operation: "latest")
        try Self.requireOK(reply, serviceName: serviceName)
        let metadata = try Self.metadata(from: reply)
        guard let surfaceObject = xpc_dictionary_get_value(reply, "surface"),
              let surface = IOSurfaceLookupFromXPCObject(surfaceObject) else {
            throw Syphon26Error.ioSurface(
                Syphon26RuntimeIssue(operation: "IOSurfaceLookupFromXPCObject", reason: "production XPC reply did not include a usable IOSurface object")
            )
        }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: try metadata.streamDescription.pixelFormat.metalPixelFormat,
            width: metadata.streamDescription.width,
            height: metadata.streamDescription.height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        textureDescriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: textureDescriptor, iosurface: surface, plane: 0) else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "makeTextureFromProductionXPCSurface", reason: "Metal returned nil texture")
            )
        }
        return Syphon26ProductionXPCFrame(metadata: metadata, texture: texture)
    }

    private func request(operation: String) throws -> xpc_object_t {
        try send(makeRequest(operation: operation))
    }

    private func makeRequest(operation: String) -> xpc_object_t {
        let message = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_string(message, "operation", operation)
        xpc_dictionary_set_string(message, "serviceName", serviceName)
        xpc_dictionary_set_uint64(message, "schemaVersion", UInt64(Syphon26ControlPlaneWireProtocol.currentSchemaVersion))
        return message
    }

    private func send(_ message: xpc_object_t) throws -> xpc_object_t {
        let connection = xpc_connection_create_mach_service(serviceName, nil, 0)
        xpc_connection_set_event_handler(connection) { _ in }
        xpc_connection_resume(connection)
        defer {
            xpc_connection_cancel(connection)
        }

        let reply = xpc_connection_send_message_with_reply_sync(connection, message)
        if xpc_get_type(reply) == XPC_TYPE_ERROR {
            let reason = Self.xpcErrorDescription(reply)
            throw Syphon26Error.xpcConnection(
                Syphon26XPCConnectionIssue(code: .connectionFailed, serviceName: serviceName, reason: reason)
            )
        }
        guard xpc_get_type(reply) == XPC_TYPE_DICTIONARY else {
            throw Syphon26Error.xpcConnection(
                Syphon26XPCConnectionIssue(code: .connectionFailed, serviceName: serviceName, reason: "reply was not an XPC dictionary")
            )
        }
        return reply
    }

    private static func requireOK(_ reply: xpc_object_t, serviceName: String) throws {
        guard xpc_dictionary_get_bool(reply, "ok") else {
            let code = string(reply, "errorCode") ?? "unavailable"
            let reason = string(reply, "errorReason") ?? "production XPC request failed"
            throw Syphon26Error.controlPlane(
                Syphon26ControlPlaneIssue(code: controlPlaneFailureCode(code), serviceName: serviceName, reason: reason)
            )
        }
    }

    private static func metadata(from reply: xpc_object_t) throws -> Syphon26ProductionXPCFrameMetadata {
        let serviceName = string(reply, "serviceName") ?? Syphon26.defaultControlPlaneServiceName
        let streamID = string(reply, "streamID") ?? "missing-stream"
        let name = string(reply, "name") ?? "Missing Stream"
        let appName = string(reply, "appName")
        let pixelFormat = Syphon26PixelFormat(rawName: string(reply, "pixelFormat") ?? "unsupported")
        let streamDescription = try Syphon26StreamDescription(
            streamID: Syphon26StreamID.unchecked(streamID),
            name: name,
            appName: appName,
            width: Int(int(reply, "width")),
            height: Int(int(reply, "height")),
            pixelFormat: pixelFormat,
            controlPlaneServiceName: serviceName
        )
        return Syphon26ProductionXPCFrameMetadata(
            streamDescription: streamDescription,
            frameID: uint(reply, "frameID"),
            publishedFrames: uint(reply, "publishedFrames"),
            processID: Int32(int(reply, "processID")),
            publishedNanoseconds: uint(reply, "publishedNanoseconds")
        )
    }

    private static func controlPlaneFailureCode(_ rawCode: String) -> Syphon26ControlPlaneFailureCode {
        switch rawCode {
        case "missingService":
            .missingService
        case "staleService":
            .staleService
        case "permissionMismatch":
            .permissionMismatch
        case "schemaMismatch":
            .schemaMismatch
        case "registrationFailed":
            .registrationFailed
        default:
            .unavailable
        }
    }

    private static func string(_ object: xpc_object_t, _ key: String) -> String? {
        guard let pointer = xpc_dictionary_get_string(object, key) else {
            return nil
        }
        return String(cString: pointer)
    }

    private static func int(_ object: xpc_object_t, _ key: String) -> Int64 {
        xpc_dictionary_get_int64(object, key)
    }

    private static func uint(_ object: xpc_object_t, _ key: String) -> UInt64 {
        xpc_dictionary_get_uint64(object, key)
    }

    private static func xpcErrorDescription(_ object: xpc_object_t) -> String {
        guard let pointer = xpc_dictionary_get_string(object, XPC_ERROR_KEY_DESCRIPTION) else {
            return "unknown XPC error"
        }
        return String(cString: pointer)
    }
}

public enum Syphon26ProductionXPCService {
    public static func run(serviceName rawServiceName: String = Syphon26.defaultControlPlaneServiceName) throws -> Never {
        let validatedServiceName = try Syphon26Validation.validateControlPlaneServiceName(rawServiceName)
        syphon26ProductionXPCServiceState = try Syphon26ProductionXPCServiceState(serviceName: validatedServiceName)
        let listener = xpc_connection_create_mach_service(
            validatedServiceName,
            nil,
            UInt64(XPC_CONNECTION_MACH_SERVICE_LISTENER)
        )
        xpc_connection_set_event_handler(listener, syphon26ProductionXPCPeerHandler)
        xpc_connection_resume(listener)
        dispatchMain()
    }
}

private nonisolated(unsafe) var syphon26ProductionXPCServiceState: Syphon26ProductionXPCServiceState?

private func syphon26ProductionXPCPeerHandler(_ peer: xpc_object_t) {
    guard xpc_get_type(peer) == XPC_TYPE_CONNECTION else {
        return
    }
    xpc_connection_set_event_handler(peer) { event in
        guard xpc_get_type(event) == XPC_TYPE_DICTIONARY,
              let state = syphon26ProductionXPCServiceState else {
            return
        }
        let reply = state.handle(event)
        xpc_connection_send_message(peer, reply)
    }
    xpc_connection_resume(peer)
}

private final class Syphon26ProductionXPCServiceState {
    private let serviceName: String
    private let lock = NSLock()
    private var latest: LatestFrame?

    init(serviceName rawServiceName: String) throws {
        self.serviceName = try Syphon26Validation.validateControlPlaneServiceName(rawServiceName)
    }

    func handle(_ request: xpc_object_t) -> xpc_object_t {
        let operation = string(request, "operation") ?? ""
        switch operation {
        case "health":
            return healthReply(to: request)
        case "reset":
            return resetReply(to: request)
        case "publish":
            return publishReply(to: request)
        case "latest":
            return latestReply(to: request)
        default:
            return errorReply(to: request, code: "unavailable", reason: "unknown production XPC operation \(operation)")
        }
    }

    private func healthReply(to request: xpc_object_t) -> xpc_object_t {
        lock.lock()
        let hasLatest = latest != nil
        lock.unlock()

        let reply = okReply(to: request)
        xpc_dictionary_set_string(reply, "serviceName", serviceName)
        xpc_dictionary_set_uint64(reply, "schemaVersion", UInt64(Syphon26ControlPlaneWireProtocol.currentSchemaVersion))
        xpc_dictionary_set_uint64(reply, "registeredStreamCount", hasLatest ? 1 : 0)
        xpc_dictionary_set_uint64(reply, "registeredConsumerCount", 0)
        return reply
    }

    private func resetReply(to request: xpc_object_t) -> xpc_object_t {
        lock.lock()
        latest = nil
        lock.unlock()
        return okReply(to: request)
    }

    private func publishReply(to request: xpc_object_t) -> xpc_object_t {
        guard requestServiceName(request) == serviceName else {
            return errorReply(to: request, code: "registrationFailed", reason: "request used a different control-plane service name")
        }
        guard let surfaceObject = xpc_dictionary_get_value(request, "surface"),
              let surface = IOSurfaceLookupFromXPCObject(surfaceObject) else {
            return errorReply(to: request, code: "registrationFailed", reason: "publish request did not include a usable IOSurface XPC object")
        }
        let frame = LatestFrame(
            serviceName: serviceName,
            streamID: string(request, "streamID") ?? "missing-stream",
            name: string(request, "name") ?? "Missing Stream",
            appName: string(request, "appName"),
            width: Int(int(request, "width")),
            height: Int(int(request, "height")),
            pixelFormat: string(request, "pixelFormat") ?? "unsupported",
            frameID: uint(request, "frameID"),
            publishedFrames: uint(request, "publishedFrames"),
            processID: Int32(int(request, "processID")),
            publishedNanoseconds: uint(request, "publishedNanoseconds"),
            surface: surface
        )
        lock.lock()
        latest = frame
        lock.unlock()
        return okReply(to: request)
    }

    private func latestReply(to request: xpc_object_t) -> xpc_object_t {
        lock.lock()
        let frame = latest
        lock.unlock()

        guard let frame else {
            return errorReply(to: request, code: "missingService", reason: "no frame has been published to the production XPC service")
        }
        let surfaceObject = IOSurfaceCreateXPCObject(frame.surface)
        let reply = okReply(to: request)
        write(frame, to: reply)
        xpc_dictionary_set_value(reply, "surface", surfaceObject)
        return reply
    }

    private func okReply(to request: xpc_object_t) -> xpc_object_t {
        let reply = xpc_dictionary_create_reply(request) ?? xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_bool(reply, "ok", true)
        return reply
    }

    private func errorReply(to request: xpc_object_t, code: String, reason: String) -> xpc_object_t {
        let reply = xpc_dictionary_create_reply(request) ?? xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_bool(reply, "ok", false)
        xpc_dictionary_set_string(reply, "errorCode", code)
        xpc_dictionary_set_string(reply, "errorReason", reason)
        return reply
    }

    private func write(_ frame: LatestFrame, to reply: xpc_object_t) {
        xpc_dictionary_set_string(reply, "serviceName", frame.serviceName)
        xpc_dictionary_set_string(reply, "streamID", frame.streamID)
        xpc_dictionary_set_string(reply, "name", frame.name)
        if let appName = frame.appName {
            xpc_dictionary_set_string(reply, "appName", appName)
        }
        xpc_dictionary_set_int64(reply, "width", Int64(frame.width))
        xpc_dictionary_set_int64(reply, "height", Int64(frame.height))
        xpc_dictionary_set_string(reply, "pixelFormat", frame.pixelFormat)
        xpc_dictionary_set_uint64(reply, "frameID", frame.frameID)
        xpc_dictionary_set_uint64(reply, "publishedFrames", frame.publishedFrames)
        xpc_dictionary_set_int64(reply, "processID", Int64(frame.processID))
        xpc_dictionary_set_uint64(reply, "publishedNanoseconds", frame.publishedNanoseconds)
    }

    private func requestServiceName(_ request: xpc_object_t) -> String? {
        string(request, "serviceName")
    }

    private func string(_ object: xpc_object_t, _ key: String) -> String? {
        guard let pointer = xpc_dictionary_get_string(object, key) else {
            return nil
        }
        return String(cString: pointer)
    }

    private func int(_ object: xpc_object_t, _ key: String) -> Int64 {
        xpc_dictionary_get_int64(object, key)
    }

    private func uint(_ object: xpc_object_t, _ key: String) -> UInt64 {
        xpc_dictionary_get_uint64(object, key)
    }

    private struct LatestFrame {
        let serviceName: String
        let streamID: String
        let name: String
        let appName: String?
        let width: Int
        let height: Int
        let pixelFormat: String
        let frameID: UInt64
        let publishedFrames: UInt64
        let processID: Int32
        let publishedNanoseconds: UInt64
        let surface: IOSurfaceRef
    }
}
