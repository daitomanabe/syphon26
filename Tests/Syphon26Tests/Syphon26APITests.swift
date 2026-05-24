import IOSurface
import Metal
import Testing
@testable import Syphon26

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
    listener.start()
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
    listener.start()
    defer { listener.stop() }

    let client = Syphon26XPCControlClient(endpoint: listener.endpoint)
    #expect(throws: Syphon26Error.streamNotFound) {
        _ = try client.registerConsumer(streamID: "missing")
    }
}

@Test
func xpcControlChannelExchangesIOSurfaceSlots() throws {
    let listener = Syphon26XPCControlListener()
    listener.start()
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
}

@Test
func xpcControlChannelExchangesSharedEventHandle() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let sharedEvent = try #require(device.makeSharedEvent())
    let sharedEventHandle = sharedEvent.makeSharedEventHandle()
    let listener = Syphon26XPCControlListener()
    listener.start()
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
    let recreatedEvent = try #require(device.makeSharedEvent(handle: receivedHandle))
    #expect(recreatedEvent.signaledValue == sharedEvent.signaledValue)
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
