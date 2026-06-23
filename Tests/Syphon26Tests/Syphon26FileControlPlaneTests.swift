import Foundation
import Metal
import Testing
import Syphon26

@Test
func fileControlPlanePublishesMetadataAndOpensLatestTexture() throws {
    let device = try makeFileControlPlaneDevice()
    let temporaryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("syphon26-file-control-plane-\(UUID().uuidString).json")
    let controlPlane = Syphon26FileControlPlane(stateURL: temporaryURL)
    defer {
        try? controlPlane.reset()
    }

    let descriptor = try Syphon26IOSurfaceResourceDescriptor(width: 64, height: 32, pixelFormat: .bgra8Unorm)
    let resource = try Syphon26IOSurfaceResource(descriptor: descriptor, device: device)
    let stream = try Syphon26StreamDescription(
        streamID: Syphon26StreamID.unchecked("file-control-plane-test"),
        name: "File Control Plane Test",
        appName: "Syphon26Tests",
        width: 64,
        height: 32,
        pixelFormat: .bgra8Unorm,
        controlPlaneServiceName: Syphon26.defaultControlPlaneServiceName
    )

    try controlPlane.publish(resource: resource, streamDescription: stream, frameID: 7, publishedFrames: 7)
    let metadata = try controlPlane.metadata()
    let frame = try controlPlane.openLatestFrame(device: device)

    #expect(metadata.streamDescription == stream)
    #expect(metadata.frameID == 7)
    #expect(metadata.publishedFrames == 7)
    #expect(frame.metadata == metadata)
    #expect(frame.texture.width == 64)
    #expect(frame.texture.height == 32)
    #expect(frame.texture.pixelFormat == .bgra8Unorm)
}

@Test
func fileControlPlaneWaitReportsMissingState() throws {
    let temporaryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("syphon26-missing-control-plane-\(UUID().uuidString).json")
    let controlPlane = Syphon26FileControlPlane(stateURL: temporaryURL)

    let error = captureFileControlPlaneSyphonError {
        _ = try controlPlane.waitForMetadata(timeoutSeconds: 0.05, pollIntervalSeconds: 0.01)
    }

    #expect(error?.category == .controlPlane)
    #expect(error?.description.contains("missingService") == true)
}

private func makeFileControlPlaneDevice() throws -> any MTLDevice {
    guard let device = MTLCreateSystemDefaultDevice() else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createFileControlPlaneDevice", reason: "no default Metal device")
        )
    }
    return device
}

private func captureFileControlPlaneSyphonError(_ body: () throws -> Void) -> Syphon26Error? {
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
