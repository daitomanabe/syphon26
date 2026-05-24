import Metal
import Syphon26

func syphon26SwiftCompileOnly(device: any MTLDevice) throws {
    let serverConfiguration = Syphon26ServerConfiguration(
        name: "Swift Compile Only",
        appName: "Syphon26 API Example",
        device: device,
        width: 1920,
        height: 1080,
        pixelFormat: .bgra8Unorm,
        slotCount: 3,
        syncMode: .automatic,
        deliveryMode: .latest,
        metadata: ["purpose": Syphon26MetadataValue("compile-only")]
    )
    let server = try Syphon26Server(configuration: serverConfiguration)
    _ = Syphon26Server.isSupported(on: device)
    _ = server.streamDescription.transportCapabilities.ringSlotCount
    try server.start()
    server.resetDiagnostics()
    let controlPlane = Syphon26ControlPlane()
    _ = try? controlPlane.streams()
    _ = try? controlPlane.activeConsumerCount(streamID: server.streamID)
    server.stop()

    let streams = Syphon26Directory.shared.streams()
    if let description = streams.first {
        let clientConfiguration = Syphon26ClientConfiguration(
            device: device,
            streamDescription: description,
            preferredPixelFormats: [.bgra8Unorm, .rgba16Float]
        )
        let client = try Syphon26Client(configuration: clientConfiguration)
        _ = Syphon26Client.isSupported(on: device)
        try client.start()
        _ = try client.copyLatestFrame()
        client.resetDiagnostics()
        client.stop()
    }

    _ = Syphon26.version
}
