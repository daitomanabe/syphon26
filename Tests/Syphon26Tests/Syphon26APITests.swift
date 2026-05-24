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
