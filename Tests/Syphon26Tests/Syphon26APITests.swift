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
