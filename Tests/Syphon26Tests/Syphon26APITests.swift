import Testing
import Syphon26

@Test
func serverConfigurationAcceptsValidBaselineValues() throws {
    let configuration = try Syphon26ServerConfiguration(
        name: " Main Output ",
        appName: "Test Host",
        width: 1920,
        height: 1080,
        pixelFormat: .bgra8Unorm,
        bufferCount: 3,
        syncMode: .automatic,
        controlPlaneServiceName: "com.example.syphon26"
    )

    #expect(configuration.name == "Main Output")
    #expect(configuration.appName == "Test Host")
    #expect(configuration.width == 1920)
    #expect(configuration.height == 1080)
    #expect(configuration.pixelFormat == .bgra8Unorm)
    #expect(configuration.bufferCount == 3)
    #expect(configuration.controlPlaneServiceName == "com.example.syphon26")
}

@Test
func serverConfigurationRejectsInvalidStreamNames() {
    expectValidation(.invalidStreamName) {
        _ = try Syphon26ServerConfiguration(name: "  ", width: 1920, height: 1080)
    }

    expectValidation(.invalidStreamName) {
        _ = try Syphon26ServerConfiguration(name: "bad\nname", width: 1920, height: 1080)
    }
}

@Test
func serverConfigurationRejectsInvalidDimensions() {
    expectValidation(.invalidDimensions) {
        _ = try Syphon26ServerConfiguration(name: "Output", width: 0, height: 1080)
    }

    expectValidation(.invalidDimensions) {
        _ = try Syphon26ServerConfiguration(
            name: "Output",
            width: Syphon26.maximumTextureDimension + 1,
            height: 1080
        )
    }
}

@Test
func serverConfigurationRejectsUnsupportedPixelFormats() {
    expectValidation(.unsupportedPixelFormat) {
        _ = try Syphon26ServerConfiguration(
            name: "Output",
            width: 1920,
            height: 1080,
            pixelFormat: .unsupported("depth32Float")
        )
    }
}

@Test
func serverConfigurationRejectsInvalidBufferCounts() {
    expectValidation(.invalidBufferCount) {
        _ = try Syphon26ServerConfiguration(name: "Output", width: 1920, height: 1080, bufferCount: 1)
    }

    expectValidation(.invalidBufferCount) {
        _ = try Syphon26ServerConfiguration(name: "Output", width: 1920, height: 1080, bufferCount: 9)
    }
}

@Test
func configurationsRejectInvalidControlPlaneServiceNames() throws {
    expectValidation(.invalidControlPlaneServiceName) {
        _ = try Syphon26ServerConfiguration(
            name: "Output",
            width: 1920,
            height: 1080,
            controlPlaneServiceName: "bad service/name"
        )
    }

    let streamID = try Syphon26StreamID("stream-1")
    expectValidation(.invalidControlPlaneServiceName) {
        _ = try Syphon26ClientConfiguration(
            streamID: streamID,
            controlPlaneServiceName: ".bad.service."
        )
    }
}

@Test
func clientConfigurationValidatesStreamIDAndPreferredFormats() throws {
    let streamID = try Syphon26StreamID("A1B2C3")
    let configuration = try Syphon26ClientConfiguration(
        streamID: streamID,
        preferredPixelFormats: [.bgra8Unorm, .rgba16Float],
        controlPlaneServiceName: "com.example.syphon26"
    )

    #expect(configuration.streamID == streamID)
    #expect(configuration.preferredPixelFormats == [.bgra8Unorm, .rgba16Float])

    expectValidation(.invalidStreamID) {
        _ = try Syphon26StreamID("bad\nid")
    }

    expectValidation(.emptyPreferredPixelFormats) {
        _ = try Syphon26ClientConfiguration(streamID: streamID, preferredPixelFormats: [])
    }

    expectValidation(.unsupportedPixelFormat) {
        _ = try Syphon26ClientConfiguration(
            streamID: streamID,
            preferredPixelFormats: [.unsupported("r8Unorm")]
        )
    }
}

@Test
func streamDescriptionValidatesMetadata() throws {
    let streamID = try Syphon26StreamID("stream-42")
    let description = try Syphon26StreamDescription(
        streamID: streamID,
        name: "Main",
        appName: "Host",
        width: 3840,
        height: 2160,
        pixelFormat: .rgba16Float,
        alphaMode: .straight,
        colorPrimaries: .displayP3,
        transferFunction: .linear,
        controlPlaneServiceName: "com.example.syphon26"
    )

    #expect(description.streamID == streamID)
    #expect(description.pixelFormat == .rgba16Float)
    #expect(description.colorPrimaries == .displayP3)

    expectValidation(.unsupportedPixelFormat) {
        _ = try Syphon26StreamDescription(
            streamID: streamID,
            name: "Main",
            width: 3840,
            height: 2160,
            pixelFormat: .unsupported("r16Float")
        )
    }
}

@Test
func diagnosticsExposeControlPlaneAndTransportCounters() {
    let snapshot = Syphon26DiagnosticsSnapshot(
        lifecycleState: .running,
        controlPlaneState: .xpcConnectionFailed(serviceName: "com.example.syphon26", reason: "connection invalidated"),
        syncMode: .sharedEvent,
        syncFallbackReason: .none,
        publishedFrames: 120,
        receivedFrames: 118,
        missedFrames: 2,
        repeatedReads: 1,
        overwrittenFrames: 3,
        consumerCount: 1,
        gpuWaitNanoseconds: 10_000,
        xpcConnectionFailures: 1
    )

    #expect(snapshot.lifecycleState == .running)
    #expect(snapshot.publishedFrames == 120)
    #expect(snapshot.receivedFrames == 118)
    #expect(snapshot.controlPlaneState.description.contains("xpcConnectionFailed"))
    #expect(snapshot.xpcConnectionFailures == 1)
}

@Test
func errorTaxonomyKeepsRuntimeFailureCategoriesDistinct() {
    let runtimeIssue = Syphon26RuntimeIssue(operation: "createTexture", reason: "device unavailable")
    let serviceName = "com.example.syphon26"

    let errors: [Syphon26Error] = [
        .validation(Syphon26ValidationIssue(code: .invalidStreamName, field: "name", reason: "empty")),
        .metal(runtimeIssue),
        .ioSurface(Syphon26RuntimeIssue(operation: "allocateSurface", reason: "allocation failed")),
        .controlPlane(Syphon26ControlPlaneIssue(code: .missingService, serviceName: serviceName, reason: "not bootstrapped")),
        .xpcConnection(Syphon26XPCConnectionIssue(code: .connectionFailed, serviceName: serviceName, reason: "connection invalidated")),
        .synchronization(Syphon26RuntimeIssue(operation: "encodeWait", reason: "shared event missing")),
        .lifecycle(Syphon26LifecycleIssue(code: .notStarted, state: .stopped, reason: "client not running"))
    ]

    #expect(errors.map(\.category) == [
        .validation,
        .metal,
        .ioSurface,
        .controlPlane,
        .xpcConnection,
        .synchronization,
        .lifecycle
    ])
}

private func expectValidation(_ code: Syphon26ValidationCode, _ body: () throws -> Void) {
    let error = capturedSyphonError(body)
    #expect(error?.category == .validation)
    #expect(error?.validationCode == code)
}

private func capturedSyphonError(_ body: () throws -> Void) -> Syphon26Error? {
    do {
        try body()
        return nil
    } catch let error as Syphon26Error {
        return error
    } catch {
        #expect(Bool(false))
        return nil
    }
}
