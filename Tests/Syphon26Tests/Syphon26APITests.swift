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

