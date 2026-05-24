import Darwin
import Foundation
import IOSurface
import Metal
import Testing
@testable import Syphon26

func waitUntil(_ predicate: () throws -> Bool) throws -> Bool {
    let deadline = Date().addingTimeInterval(1.0)
    repeat {
        if try predicate() {
            return true
        }
        Thread.sleep(forTimeInterval: 0.01)
    } while Date() < deadline
    return try predicate()
}

@Test
func serverConfigurationValidationRejectsInvalidSize() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let configuration = Syphon26ServerConfiguration(name: "Invalid", device: device, width: 0, height: 1080)
    #expect(throws: Syphon26Error.invalidConfiguration) {
        _ = try Syphon26Server(configuration: configuration)
    }
}

@Test
func serverExposesStreamDescription() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let configuration = Syphon26ServerConfiguration(name: "Test Stream", device: device, width: 1920, height: 1080)
    let server = try Syphon26Server(configuration: configuration)
    #expect(server.streamDescription.name == "Test Stream")
    #expect(server.streamDescription.width == 1920)
    #expect(server.streamDescription.height == 1080)
    #expect(server.streamDescription.pixelFormat == .bgra8Unorm)
    #expect(server.streamDescription.transportCapabilities.pixelFormat == .bgra8Unorm)
    #expect(server.streamDescription.transportCapabilities.ringSlotCount == 3)
    #expect(server.streamDescription.transportCapabilities.fallbackReason == .none)
}

@Test
func serverExposesResolvedTransportCapabilities() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let configuration = Syphon26ServerConfiguration(
        name: "Capability Stream",
        device: device,
        width: 64,
        height: 64,
        pixelFormat: .rgba16Float,
        syncMode: .automatic
    )
    let server = try Syphon26Server(configuration: configuration)
    try server.start()
    defer { server.stop() }

    let capabilities = server.streamDescription.transportCapabilities
    #expect(capabilities.syncMode == server.diagnosticsSnapshot().syncMode)
    #expect(capabilities.pixelFormat == .rgba16Float)
    #expect(capabilities.colorPrimaries == .sRGB)
    #expect(capabilities.transferFunction == .sRGB)
    #expect(capabilities.alphaMode == .opaque)
    #expect(capabilities.ringSlotCount == 3)
    #expect(capabilities.fallbackReason == server.diagnosticsSnapshot().fallbackReason)
    #expect(server.streamDescription.capabilities.contains("metal"))
    #expect(server.streamDescription.capabilities.contains("iosurface"))
    #expect(server.streamDescription.capabilities.contains("rgba16f"))
}

@Test
func xpcControlChannelRegistersConsumersAndRetiresStreams() throws {
    let listener = Syphon26XPCControlListener()
    try listener.start()
    defer { listener.stop() }

    let client = Syphon26XPCControlClient(endpoint: listener.endpoint)
    let description = Syphon26StreamDescription(
        streamID: "xpc-stream",
        name: "XPC Stream",
        appName: "Tests",
        processIdentifier: ProcessInfo.processInfo.processIdentifier,
        width: 128,
        height: 64,
        pixelFormat: .rgba16Float,
        colorPrimaries: .displayP3,
        transferFunction: .linear,
        alphaMode: .premultiplied,
        slotCount: 4,
        syncMode: .sharedEvent,
        deliveryMode: .latest,
        transportCapabilities: Syphon26TransportCapabilities(
            syncMode: .sharedEvent,
            pixelFormat: .rgba16Float,
            colorPrimaries: .displayP3,
            transferFunction: .linear,
            alphaMode: .premultiplied,
            ringSlotCount: 4,
            fallbackReason: .none
        ),
        capabilities: ["metal", "iosurface", "shared-event", "rgba16f"]
    )

    let registered = try client.registerProducer(description)
    #expect(registered.streamID == description.streamID)
    #expect(registered.pixelFormat == .rgba16Float)
    #expect(registered.transportCapabilities.ringSlotCount == 4)

    let streams = try client.listStreams()
    #expect(streams.map(\.streamID) == ["xpc-stream"])

    let consumer = try client.registerConsumer(streamID: description.streamID)
    #expect(!consumer.consumerID.isEmpty)
    #expect(consumer.stream.streamID == description.streamID)

    try client.retireConsumer(streamID: description.streamID, consumerID: consumer.consumerID)
    try client.retireProducer(streamID: description.streamID)
    #expect(try client.listStreams().isEmpty)
}

@Test
func xpcControlChannelRejectsMissingConsumerStream() throws {
    let listener = Syphon26XPCControlListener()
    try listener.start()
    defer { listener.stop() }

    let client = Syphon26XPCControlClient(endpoint: listener.endpoint)
    #expect(throws: Syphon26Error.streamNotFound) {
        _ = try client.registerConsumer(streamID: "missing")
    }
}

@Test
func controlPlaneNamespaceCreatesPrivateRuntimeDirectory() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("syphon26-namespace-\(UUID().uuidString)", isDirectory: true)
    let namespace = Syphon26ControlPlaneNamespace.testing(
        userIdentifier: Darwin.getuid(),
        runtimeDirectory: directory,
        validatesRuntimeDirectory: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }

    try namespace.prepareRuntimeDirectory()

    let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
    let owner = try #require(attributes[.ownerAccountID] as? NSNumber)
    let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
    #expect(owner.uint32Value == Darwin.getuid())
    #expect(permissions.uint16Value & 0o077 == 0)
    #expect(namespace.acceptsPeer(userIdentifier: Darwin.getuid()))
}

@Test
func controlPlaneNamespaceTightensSharedRuntimeDirectory() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("syphon26-open-namespace-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: NSNumber(value: Int16(0o700))]
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o755))],
        ofItemAtPath: directory.path
    )
    defer { try? FileManager.default.removeItem(at: directory) }

    let namespace = Syphon26ControlPlaneNamespace.testing(
        userIdentifier: Darwin.getuid(),
        runtimeDirectory: directory,
        validatesRuntimeDirectory: true
    )

    try namespace.prepareRuntimeDirectory()

    let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
    let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
    #expect(permissions.uint16Value & 0o077 == 0)
}

@Test
func controlPlaneNamespaceRejectsSymlinkRuntimeDirectory() throws {
    let target = FileManager.default.temporaryDirectory
        .appendingPathComponent("syphon26-namespace-target-\(UUID().uuidString)", isDirectory: true)
    let link = FileManager.default.temporaryDirectory
        .appendingPathComponent("syphon26-namespace-link-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
        at: target,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: NSNumber(value: Int16(0o700))]
    )
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    defer {
        try? FileManager.default.removeItem(at: link)
        try? FileManager.default.removeItem(at: target)
    }

    let namespace = Syphon26ControlPlaneNamespace.testing(
        userIdentifier: Darwin.getuid(),
        runtimeDirectory: link,
        validatesRuntimeDirectory: true
    )

    #expect(throws: Syphon26Error.namespaceIsolationFailed) {
        try namespace.prepareRuntimeDirectory()
    }
}

@Test
func xpcControlChannelRejectsDifferentUserNamespace() throws {
    let namespace = Syphon26ControlPlaneNamespace.testing(userIdentifier: Darwin.getuid() &+ 1)
    let listener = Syphon26XPCControlListener(namespace: namespace)
    try listener.start()
    defer { listener.stop() }

    let client = Syphon26XPCControlClient(endpoint: listener.endpoint)
    var rejected = false
    do {
        _ = try client.listStreams()
    } catch let error as Syphon26Error {
        rejected = error == .xpcConnectionFailed || error == .timeout
    }
    #expect(rejected)
}

@Test
func controlPlaneServerCreatesLocalControlPlanes() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let controlPlaneServer = Syphon26ControlPlaneServer()
    try controlPlaneServer.start()
    defer { controlPlaneServer.stop() }

    let producerControlPlane = controlPlaneServer.makeControlPlane()
    let observerControlPlane = Syphon26ControlPlane(endpoint: controlPlaneServer.endpoint)
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Endpoint Data Source",
            device: device,
            width: 32,
            height: 32,
            controlPlane: producerControlPlane
        )
    )
    try server.start()
    defer { server.stop() }

    #expect(try observerControlPlane.listStreams().map(\.streamID) == [server.streamID])
}

@Test
func xpcControlChannelExchangesIOSurfaceSlots() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let listener = Syphon26XPCControlListener()
    try listener.start()
    defer { listener.stop() }

    let client = Syphon26XPCControlClient(endpoint: listener.endpoint)
    let description = Syphon26StreamDescription(
        streamID: "xpc-iosurface-stream",
        name: "XPC IOSurface Stream",
        appName: "Tests",
        processIdentifier: ProcessInfo.processInfo.processIdentifier,
        width: 32,
        height: 16,
        pixelFormat: .bgra8Unorm,
        colorPrimaries: .sRGB,
        transferFunction: .sRGB,
        alphaMode: .opaque,
        slotCount: 2,
        syncMode: .sequencePolling,
        deliveryMode: .latest
    )
    let surfaces = try (0..<2).map { _ in
        try #require(IOSurfaceCreate([
            kIOSurfaceWidth: description.width,
            kIOSurfaceHeight: description.height,
            kIOSurfacePixelFormat: Syphon26PixelFormatSupport.cvPixelFormat(for: description.pixelFormat),
            kIOSurfaceBytesPerElement: Syphon26PixelFormatSupport.bytesPerElement(for: description.pixelFormat)
        ] as CFDictionary))
    }

    let registeredSlots = try client.registerProducerTransport(description, surfaces: surfaces)
    #expect(registeredSlots.map(\.ioSurfaceID) == surfaces.map { IOSurfaceGetID($0) })

    let receivedSlots = try client.copyIOSurfaceSlots(streamID: description.streamID)
    #expect(receivedSlots.count == 2)
    #expect(receivedSlots.map(\.descriptor.ioSurfaceID) == surfaces.map { IOSurfaceGetID($0) })
    #expect(receivedSlots.map { IOSurfaceGetID($0.surface) } == surfaces.map { IOSurfaceGetID($0) })
    #expect(receivedSlots.allSatisfy { $0.descriptor.width == description.width })
    #expect(receivedSlots.allSatisfy { $0.descriptor.height == description.height })

    let resolvedSlots = try Syphon26XPCTransportResolver.makeTextures(from: receivedSlots, device: device)
    #expect(resolvedSlots.count == 2)
    #expect(resolvedSlots.allSatisfy { $0.texture.width == description.width })
    #expect(resolvedSlots.allSatisfy { $0.texture.height == description.height })
    #expect(resolvedSlots.allSatisfy { $0.texture.pixelFormat == description.pixelFormat })
}

@Test
func xpcControlChannelExchangesSharedEventHandle() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let sharedEvent = try #require(device.makeSharedEvent())
    let sharedEventHandle = sharedEvent.makeSharedEventHandle()
    let listener = Syphon26XPCControlListener()
    try listener.start()
    defer { listener.stop() }

    let client = Syphon26XPCControlClient(endpoint: listener.endpoint)
    let description = Syphon26StreamDescription(
        streamID: "xpc-shared-event-stream",
        name: "XPC Shared Event Stream",
        appName: "Tests",
        processIdentifier: ProcessInfo.processInfo.processIdentifier,
        width: 32,
        height: 16,
        pixelFormat: .bgra8Unorm,
        colorPrimaries: .sRGB,
        transferFunction: .sRGB,
        alphaMode: .opaque,
        slotCount: 1,
        syncMode: .sharedEvent,
        deliveryMode: .latest
    )
    let surface = try #require(IOSurfaceCreate([
        kIOSurfaceWidth: description.width,
        kIOSurfaceHeight: description.height,
        kIOSurfacePixelFormat: Syphon26PixelFormatSupport.cvPixelFormat(for: description.pixelFormat),
        kIOSurfaceBytesPerElement: Syphon26PixelFormatSupport.bytesPerElement(for: description.pixelFormat)
    ] as CFDictionary))

    _ = try client.registerProducerTransport(
        description,
        surfaces: [surface],
        sharedEventHandle: sharedEventHandle
    )

    let receivedHandle = try #require(try client.copySharedEventHandle(streamID: description.streamID))
    let recreatedEvent = try #require(try Syphon26XPCTransportResolver.makeSharedEvent(
        from: receivedHandle,
        device: device
    ))
    #expect(recreatedEvent.signaledValue == sharedEvent.signaledValue)
}

@Test
func serverStartRegistersProducerWithControlPlane() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let listener = Syphon26XPCControlListener()
    try listener.start()
    defer { listener.stop() }
    let controlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)

    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Control Producer",
            device: device,
            width: 64,
            height: 64,
            controlPlane: controlPlane
        )
    )
    try server.start()

    let streams = try controlPlane.listStreams()
    #expect(streams.map(\.streamID) == [server.streamID])
    #expect(server.diagnosticsSnapshot().xpcMessagesSent == 1)

    server.stop()
    #expect(try controlPlane.listStreams().isEmpty)
}

@Test
func clientStartRegistersConsumerWithControlPlaneByStreamID() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let listener = Syphon26XPCControlListener()
    try listener.start()
    defer { listener.stop() }
    let controlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)

    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Control Consumer Source",
            device: device,
            width: 64,
            height: 64,
            controlPlane: controlPlane
        )
    )
    try server.start()
    defer { server.stop() }

    let client = try Syphon26Client(
        configuration: Syphon26ClientConfiguration(
            device: device,
            streamID: server.streamID,
            controlPlane: controlPlane
        )
    )
    try client.start()
    defer { client.stop() }

    #expect(client.isRunning)
    #expect(client.streamDescription?.streamID == server.streamID)
    #expect(client.streamDescription?.name == "Control Consumer Source")
    #expect(client.diagnosticsSnapshot().slotDepthFrames == UInt64(server.streamDescription.slotCount))
    #expect(client.diagnosticsSnapshot().xpcMessagesSent == 3)
}

@Test
func clientReceivesFrameThroughControlPlaneTransportPath() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let listener = Syphon26XPCControlListener()
    try listener.start()
    defer { listener.stop() }
    let controlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)

    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Control Frame Source",
            device: device,
            width: 64,
            height: 64,
            syncMode: .sequencePolling,
            controlPlane: controlPlane
        )
    )
    try server.start()
    defer { server.stop() }

    let client = try Syphon26Client(
        configuration: Syphon26ClientConfiguration(
            device: device,
            streamID: server.streamID,
            controlPlane: controlPlane
        )
    )
    try client.start()
    defer { client.stop() }

    let drawable = try server.acquireDrawable()
    let commandBuffer = try #require(queue.makeCommandBuffer())
    try server.presentDrawable(drawable, commandBuffer: commandBuffer)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    let frame = try #require(try client.copyLatestFrame())
    #expect(frame.sequence == 1)
    #expect(frame.texture.width == 64)
    #expect(frame.texture.height == 64)
    #expect(client.diagnosticsSnapshot().observedFrames == 1)
    #expect(client.diagnosticsSnapshot().xpcMessagesSent == 4)
}

@Test
func clientReadsSharedEventControlPlaneFramesWithoutPerFrameXPC() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let listener = Syphon26XPCControlListener()
    try listener.start()
    defer { listener.stop() }
    let controlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)

    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Shared Event Control Frame Source",
            device: device,
            width: 64,
            height: 64,
            syncMode: .sharedEvent,
            controlPlane: controlPlane
        )
    )
    try server.start()
    defer { server.stop() }
    guard server.streamDescription.syncMode == .sharedEvent else {
        return
    }

    let client = try Syphon26Client(
        configuration: Syphon26ClientConfiguration(
            device: device,
            streamID: server.streamID,
            controlPlane: controlPlane
        )
    )
    try client.start()
    defer { client.stop() }
    let startupMessages = client.diagnosticsSnapshot().xpcMessagesSent

    let drawable = try server.acquireDrawable()
    let commandBuffer = try #require(queue.makeCommandBuffer())
    try server.presentDrawable(drawable, commandBuffer: commandBuffer)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    let frame = try #require(try client.copyLatestFrame())
    #expect(frame.sequence == 1)
    #expect(client.diagnosticsSnapshot().observedFrames == 1)
    #expect(client.diagnosticsSnapshot().xpcMessagesSent == startupMessages)
}

@Test
func fanoutClientsReceiveFrameThroughControlPlaneTransportPath() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    for clientCount in [2, 4, 8, 16] {
        let listener = Syphon26XPCControlListener()
        try listener.start()
        let controlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)
        let server = try Syphon26Server(
            configuration: Syphon26ServerConfiguration(
                name: "Control Fanout \(clientCount)",
                device: device,
                width: 64,
                height: 64,
                syncMode: .sequencePolling,
                controlPlane: controlPlane
            )
        )
        try server.start()
        defer {
            server.stop()
            listener.stop()
        }

        var clients: [Syphon26Client] = []
        for _ in 0..<clientCount {
            let client = try Syphon26Client(
                configuration: Syphon26ClientConfiguration(
                    device: device,
                    streamID: server.streamID,
                    controlPlane: controlPlane
                )
            )
            try client.start()
            clients.append(client)
        }

        let drawable = try server.acquireDrawable()
        let commandBuffer = try #require(queue.makeCommandBuffer())
        try server.presentDrawable(drawable, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        for client in clients {
            let frame = try #require(try client.copyLatestFrame())
            #expect(frame.sequence == 1)
            #expect(frame.texture.width == 64)
            client.stop()
        }

        server.stop()
        listener.stop()
    }
}

@Test
func staleProducerIsRemovedWhenControlConnectionInvalidates() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let listener = Syphon26XPCControlListener()
    try listener.start()
    defer { listener.stop() }

    let observerControlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)
    let producerControlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Stale Producer",
            device: device,
            width: 64,
            height: 64,
            controlPlane: producerControlPlane
        )
    )
    try server.start()
    #expect(try observerControlPlane.listStreams().map(\.streamID) == [server.streamID])

    producerControlPlane.invalidate()
    #expect(try waitUntil {
        try observerControlPlane.listStreams().isEmpty
    })
}

@Test
func staleConsumerIsRemovedWhenControlConnectionInvalidates() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let listener = Syphon26XPCControlListener()
    try listener.start()
    defer { listener.stop() }

    let producerControlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)
    let observerControlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Stale Consumer Source",
            device: device,
            width: 64,
            height: 64,
            controlPlane: producerControlPlane
        )
    )
    try server.start()
    defer { server.stop() }

    let consumerControlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)
    let client = try Syphon26Client(
        configuration: Syphon26ClientConfiguration(
            device: device,
            streamID: server.streamID,
            controlPlane: consumerControlPlane
        )
    )
    try client.start()
    #expect(try observerControlPlane.activeConsumerCount(streamID: server.streamID) == 1)

    consumerControlPlane.invalidate()
    #expect(try waitUntil {
        try observerControlPlane.activeConsumerCount(streamID: server.streamID) == 0
    })
}

@Test
func repeatedCreateDestroyLeavesNoRegisteredStreams() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let listener = Syphon26XPCControlListener()
    try listener.start()
    defer { listener.stop() }

    let producerControlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)
    let observerControlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)

    for index in 0..<32 {
        var server: Syphon26Server? = try Syphon26Server(
            configuration: Syphon26ServerConfiguration(
                name: "Create Destroy \(index)",
                device: device,
                width: 32,
                height: 32,
                controlPlane: producerControlPlane
            )
        )
        weak let weakServer = server
        try server?.start()
        let streamID = try #require(server?.streamID)
        #expect(try observerControlPlane.listStreams().count == 1)

        server?.stop()
        server = nil
        #expect(weakServer == nil)
        #expect(try observerControlPlane.listStreams().isEmpty)
        #expect(!Syphon26Directory.shared.streams().contains { $0.streamID == streamID })
    }
}

@Test
func repeatedAttachDetachLeavesNoActiveConsumers() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let listener = Syphon26XPCControlListener()
    try listener.start()
    defer { listener.stop() }

    let producerControlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)
    let observerControlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)
    let consumerControlPlane = Syphon26ControlPlane(endpoint: listener.endpoint)
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Attach Detach Source",
            device: device,
            width: 32,
            height: 32,
            controlPlane: producerControlPlane
        )
    )
    try server.start()
    defer { server.stop() }

    for _ in 0..<32 {
        var client: Syphon26Client? = try Syphon26Client(
            configuration: Syphon26ClientConfiguration(
                device: device,
                streamID: server.streamID,
                controlPlane: consumerControlPlane
            )
        )
        weak let weakClient = client
        try client?.start()
        #expect(try observerControlPlane.activeConsumerCount(streamID: server.streamID) == 1)

        client?.stop()
        client = nil
        #expect(weakClient == nil)
        #expect(try observerControlPlane.activeConsumerCount(streamID: server.streamID) == 0)
    }
}

@Test
func directorySeesRunningServer() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let configuration = Syphon26ServerConfiguration(name: "Directory Stream", device: device, width: 64, height: 64)
    let server = try Syphon26Server(configuration: configuration)
    try server.start()
    defer { server.stop() }

    let streams = Syphon26Directory.shared.streams()
    #expect(streams.contains { $0.streamID == server.streamID })
}

@Test
func clientReceivesPresentedDrawable() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let configuration = Syphon26ServerConfiguration(name: "Frame Stream", device: device, width: 64, height: 64)
    let server = try Syphon26Server(configuration: configuration)
    try server.start()
    defer { server.stop() }

    let client = try Syphon26Client(streamDescription: server.streamDescription, device: device)
    try client.start()
    defer { client.stop() }

    let drawable = try server.acquireDrawable()
    let commandBuffer = try #require(queue.makeCommandBuffer())
    try server.presentDrawable(drawable, commandBuffer: commandBuffer)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    let frame = try #require(try client.copyLatestFrame())
    #expect(frame.sequence == 1)
    #expect(frame.texture.width == 64)
    #expect(frame.texture.height == 64)
    #expect(client.diagnosticsSnapshot().observedFrames == 1)
    #expect(server.diagnosticsSnapshot().publishedFrames == 1)
}

@Test
func rgba16FloatStreamCanPublishAndReceive() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let configuration = Syphon26ServerConfiguration(
        name: "RGBA16F Stream",
        device: device,
        width: 64,
        height: 64,
        pixelFormat: .rgba16Float
    )
    let server = try Syphon26Server(configuration: configuration)
    try server.start()
    defer { server.stop() }

    let client = try Syphon26Client(streamDescription: server.streamDescription, device: device)
    try client.start()
    defer { client.stop() }

    let drawable = try server.acquireDrawable()
    #expect(drawable.pixelFormat == .rgba16Float)
    let commandBuffer = try #require(queue.makeCommandBuffer())
    try server.presentDrawable(drawable, commandBuffer: commandBuffer)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    let frame = try #require(try client.copyLatestFrame())
    #expect(frame.texture.pixelFormat == .rgba16Float)
    #expect(frame.pixelFormat == .rgba16Float)
    #expect(frame.sequence == 1)
}

@Test
func lifecycleCallsAreIdempotent() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let configuration = Syphon26ServerConfiguration(name: "Lifecycle Stream", device: device, width: 64, height: 64)
    let server = try Syphon26Server(configuration: configuration)

    try server.start()
    try server.start()
    #expect(server.isRunning)

    server.stop()
    server.stop()
    #expect(!server.isRunning)

    server.invalidate()
    server.invalidate()
    #expect(!server.isRunning)
}

@Test
func stoppedServerIsRemovedFromDirectory() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let configuration = Syphon26ServerConfiguration(name: "Retire Stream", device: device, width: 64, height: 64)
    let server = try Syphon26Server(configuration: configuration)
    try server.start()
    #expect(Syphon26Directory.shared.stream(withID: server.streamID) != nil)

    server.stop()
    #expect(Syphon26Directory.shared.stream(withID: server.streamID) == nil)
}

@Test
func clientReportsRepeatedReadWhenNoNewFrame() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let server = try Syphon26Server(configuration: Syphon26ServerConfiguration(name: "Repeated Stream", device: device, width: 64, height: 64))
    try server.start()
    defer { server.stop() }

    let client = try Syphon26Client(streamDescription: server.streamDescription, device: device)
    try client.start()
    defer { client.stop() }

    let drawable = try server.acquireDrawable()
    let commandBuffer = try #require(queue.makeCommandBuffer())
    try server.presentDrawable(drawable, commandBuffer: commandBuffer)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    _ = try #require(try client.copyLatestFrame())
    #expect(try client.copyLatestFrame() == nil)
    #expect(client.diagnosticsSnapshot().repeatedReads == 1)
}

@Test
func latestFrameSemanticsAccountForMissedFrames() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let server = try Syphon26Server(configuration: Syphon26ServerConfiguration(name: "Missed Stream", device: device, width: 64, height: 64))
    try server.start()
    defer { server.stop() }

    let client = try Syphon26Client(streamDescription: server.streamDescription, device: device)
    try client.start()
    defer { client.stop() }

    func publishOne() throws {
        let drawable = try server.acquireDrawable()
        let commandBuffer = try #require(queue.makeCommandBuffer())
        try server.presentDrawable(drawable, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    try publishOne()
    #expect(try #require(try client.copyLatestFrame()).sequence == 1)

    try publishOne()
    try publishOne()
    #expect(try #require(try client.copyLatestFrame()).sequence == 3)
    #expect(client.diagnosticsSnapshot().missedFrames == 1)
}

@Test
func ringSlotMetadataTracksPublishedFrame() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Slot Metadata Stream",
            device: device,
            width: 64,
            height: 32,
            slotCount: 2
        )
    )
    try server.start()
    defer { server.stop() }

    let stream = try #require(Syphon26TransportRegistry.shared.stream(withID: server.streamID))
    let drawable = try server.acquireDrawable()
    let commandBuffer = try #require(queue.makeCommandBuffer())
    try server.presentDrawable(drawable, commandBuffer: commandBuffer, timestamp: 123)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    let metadata = try #require(stream.slotMetadataSnapshot().first { $0.sequence == 1 })
    #expect(metadata.readySequence == 1)
    #expect(metadata.width == 64)
    #expect(metadata.height == 32)
    #expect(MTLPixelFormat(rawValue: UInt(metadata.pixelFormatRawValue)) == .bgra8Unorm)
    #expect(metadata.timestamp == 123)
    #expect(metadata.ioSurfaceID != nil)
}

@Test
func serverDiagnosticsTrackOverwrittenFramesAndConsumerLag() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Lag Stream",
            device: device,
            width: 64,
            height: 64,
            slotCount: 2
        )
    )
    try server.start()
    defer { server.stop() }

    let client = try Syphon26Client(streamDescription: server.streamDescription, device: device)
    try client.start()
    defer { client.stop() }

    func publishOne(_ timestamp: Syphon26HostTime) throws {
        let drawable = try server.acquireDrawable()
        let commandBuffer = try #require(queue.makeCommandBuffer())
        try server.presentDrawable(drawable, commandBuffer: commandBuffer, timestamp: timestamp)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    try publishOne(1)
    try publishOne(2)
    try publishOne(3)

    let beforeRead = server.diagnosticsSnapshot()
    #expect(beforeRead.overwrittenFrames == 1)
    #expect(beforeRead.currentConsumerLagFrames == 3)
    #expect(beforeRead.maxConsumerLagFrames == 3)

    let frame = try #require(try client.copyLatestFrame())
    #expect(frame.sequence == 3)

    let afterRead = server.diagnosticsSnapshot()
    #expect(afterRead.currentConsumerLagFrames == 0)
    #expect(afterRead.maxConsumerLagFrames == 3)
}

@Test
func boundedLatencyReportsNoSlotWhenAllSlotsAreBusy() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Busy Slot Stream",
            device: device,
            width: 64,
            height: 64,
            slotCount: 2,
            deliveryMode: .boundedLatency
        )
    )
    try server.start()
    defer { server.stop() }

    let client = try Syphon26Client(streamDescription: server.streamDescription, device: device)
    try client.start()
    defer { client.stop() }

    func publishOne() throws {
        let drawable = try server.acquireDrawable()
        let commandBuffer = try #require(queue.makeCommandBuffer())
        try server.presentDrawable(drawable, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    try publishOne()
    try publishOne()

    #expect(throws: Syphon26Error.noAvailableSlot) {
        _ = try server.acquireDrawable()
    }
}

@Test
func boundedLatencyMeasuresProducerStallUntilSlotIsReusable() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Producer Stall Stream",
            device: device,
            width: 64,
            height: 64,
            slotCount: 2,
            deliveryMode: .boundedLatency,
            maximumProducerWaitNanoseconds: 50_000_000
        )
    )
    try server.start()
    defer { server.stop() }

    let client = try Syphon26Client(streamDescription: server.streamDescription, device: device)
    try client.start()
    defer { client.stop() }

    func publishOne() throws {
        let drawable = try server.acquireDrawable()
        let commandBuffer = try #require(queue.makeCommandBuffer())
        try server.presentDrawable(drawable, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    try publishOne()
    try publishOne()

    let group = DispatchGroup()
    group.enter()
    DispatchQueue.global(qos: .userInitiated).async {
        Thread.sleep(forTimeInterval: 0.005)
        _ = try? client.copyLatestFrame()
        group.leave()
    }

    _ = try server.acquireDrawable()
    group.wait()

    #expect(server.diagnosticsSnapshot().producerStallNanoseconds > 0)
}

@Test
func clientReadsFailAfterProducerRetires() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Retired Producer Stream",
            device: device,
            width: 64,
            height: 64
        )
    )
    try server.start()

    let client = try Syphon26Client(streamDescription: server.streamDescription, device: device)
    try client.start()
    defer { client.stop() }

    server.stop()

    #expect(throws: Syphon26Error.streamRetired) {
        _ = try client.copyLatestFrame()
    }
}

@Test
func producerRetireDropsInFlightCompletion() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Retire In Flight Stream",
            device: device,
            width: 64,
            height: 64
        )
    )
    try server.start()
    let stream = try #require(Syphon26TransportRegistry.shared.stream(withID: server.streamID))

    let drawable = try server.acquireDrawable()
    let commandBuffer = try #require(queue.makeCommandBuffer())
    try server.presentDrawable(drawable, commandBuffer: commandBuffer)
    server.stop()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    #expect(stream.diagnosticsSnapshot().publishedFrames == 0)
}

@Test
func clientCanStopWhileProducerCommandBufferIsInFlight() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Client Stop In Flight Stream",
            device: device,
            width: 64,
            height: 64
        )
    )
    try server.start()
    defer { server.stop() }

    let client = try Syphon26Client(streamDescription: server.streamDescription, device: device)
    try client.start()

    let drawable = try server.acquireDrawable()
    let commandBuffer = try #require(queue.makeCommandBuffer())
    try server.presentDrawable(drawable, commandBuffer: commandBuffer)
    client.stop()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    let diagnostics = server.diagnosticsSnapshot()
    #expect(diagnostics.publishedFrames == 1)
    #expect(diagnostics.activeClientCount == 0)
}

@Test
func clientStartFailsWhenStreamIsMissing() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let client = try Syphon26Client(configuration: Syphon26ClientConfiguration(device: device, streamID: "missing-stream"))
    #expect(throws: Syphon26Error.streamNotFound) {
        try client.start()
    }
}

@Test
func automaticSyncReportsResolvedMode() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Sync Stream",
            device: device,
            width: 64,
            height: 64,
            syncMode: .automatic
        )
    )
    try server.start()
    defer { server.stop() }

    #expect([Syphon26SyncMode.sharedEvent, .sequencePolling].contains(server.streamDescription.syncMode))
    if server.streamDescription.syncMode == .sequencePolling {
        #expect(server.diagnosticsSnapshot().fallbackReason != .none)
    }
}

@Test
func sharedEventSignalIsCountedWhenAvailable() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Shared Event Stream",
            device: device,
            width: 64,
            height: 64,
            syncMode: .automatic
        )
    )
    try server.start()
    defer { server.stop() }

    let drawable = try server.acquireDrawable()
    let commandBuffer = try #require(queue.makeCommandBuffer())
    try server.presentDrawable(drawable, commandBuffer: commandBuffer)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    let diagnostics = server.diagnosticsSnapshot()
    if diagnostics.syncMode == .sharedEvent {
        #expect(diagnostics.sharedEventSignals == 1)
    }
}

@Test
func sharedEventFrameCanEncodeConsumerWait() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: "Shared Event Wait Stream",
            device: device,
            width: 64,
            height: 64,
            syncMode: .sharedEvent
        )
    )
    try server.start()
    defer { server.stop() }

    guard server.streamDescription.syncMode == .sharedEvent else {
        return
    }

    let client = try Syphon26Client(streamDescription: server.streamDescription, device: device)
    try client.start()
    defer { client.stop() }

    let drawable = try server.acquireDrawable()
    let producerCommandBuffer = try #require(queue.makeCommandBuffer())
    try server.presentDrawable(drawable, commandBuffer: producerCommandBuffer)
    producerCommandBuffer.commit()
    producerCommandBuffer.waitUntilCompleted()

    let frame = try #require(try client.copyLatestFrame())
    #expect(frame.requiresGPUWait)

    let consumerCommandBuffer = try #require(queue.makeCommandBuffer())
    try frame.encodeWait(on: consumerCommandBuffer)
    consumerCommandBuffer.commit()
    consumerCommandBuffer.waitUntilCompleted()
    #expect(consumerCommandBuffer.status == .completed)
    #expect(client.diagnosticsSnapshot().sharedEventWaits == 1)
    #expect(client.diagnosticsSnapshot().gpuWaitNanoseconds > 0)
}

@Test
func sharedStateValidatesStreamDescription() throws {
    let description = Syphon26StreamDescription(
        streamID: "state",
        name: "State",
        appName: nil,
        processIdentifier: 1,
        width: 1920,
        height: 1080,
        pixelFormat: .bgra8Unorm,
        colorPrimaries: .sRGB,
        transferFunction: .sRGB,
        alphaMode: .opaque,
        slotCount: 3,
        syncMode: .sequencePolling,
        deliveryMode: .latest
    )
    let state = Syphon26SharedState(description: description)
    try state.validate()
}

@Test
func sharedStateRejectsBadMagic() throws {
    let description = Syphon26StreamDescription(
        streamID: "state",
        name: "State",
        appName: nil,
        processIdentifier: 1,
        width: 1920,
        height: 1080,
        pixelFormat: .bgra8Unorm,
        colorPrimaries: .sRGB,
        transferFunction: .sRGB,
        alphaMode: .opaque,
        slotCount: 3,
        syncMode: .sequencePolling,
        deliveryMode: .latest
    )
    var state = Syphon26SharedState(description: description)
    state.magic = 0
    #expect(throws: Syphon26Error.invalidSharedState) {
        try state.validate()
    }
}

@Test
func sharedStateRejectsUnsupportedPixelFormat() throws {
    let description = Syphon26StreamDescription(
        streamID: "state",
        name: "State",
        appName: nil,
        processIdentifier: 1,
        width: 1920,
        height: 1080,
        pixelFormat: .bgra8Unorm,
        colorPrimaries: .sRGB,
        transferFunction: .sRGB,
        alphaMode: .opaque,
        slotCount: 3,
        syncMode: .sequencePolling,
        deliveryMode: .latest
    )
    var state = Syphon26SharedState(description: description)
    state.pixelFormatRawValue = UInt64(MTLPixelFormat.rgba32Uint.rawValue)
    #expect(throws: Syphon26Error.unsupportedPixelFormat) {
        try state.validate()
    }
}
