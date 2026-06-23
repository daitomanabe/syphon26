import Metal
import Testing
import Syphon26

@Test
func ioSurfaceResourceCreatesMetalTexture() throws {
    let device = try makeTransportTestDevice()
    let descriptor = try Syphon26IOSurfaceResourceDescriptor(
        width: 64,
        height: 32,
        pixelFormat: .bgra8Unorm
    )
    let resource = try Syphon26IOSurfaceResource(descriptor: descriptor, device: device)

    #expect(resource.descriptor.width == 64)
    #expect(resource.descriptor.height == 32)
    #expect(resource.descriptor.pixelFormat == .bgra8Unorm)
    #expect(resource.descriptor.bytesPerRow >= 64 * 4)
    #expect(resource.texture.width == 64)
    #expect(resource.texture.height == 32)
    #expect(resource.texture.pixelFormat == .bgra8Unorm)
    #expect(resource.texture.storageMode == .shared)
    #expect(resource.texture.usage.contains(.shaderRead))
    #expect(resource.texture.usage.contains(.shaderWrite))
    #expect(resource.texture.usage.contains(.renderTarget))
}

@Test
func ringSlotMetadataValidatesABIVersion() throws {
    let empty = try Syphon26RingSlotMetadata(slotIndex: 0)
    let acquired = try empty.acquiredForWrite(nextGeneration: 1)
    let published = try acquired.published(frameID: 7, publishedNanoseconds: 123)

    #expect(empty.abiVersion == Syphon26RingSlotMetadata.currentABIVersion)
    #expect(acquired.state == .acquiredForWrite)
    #expect(acquired.generation == 1)
    #expect(published.state == .published)
    #expect(published.frameID == 7)

    let error = captureTransportSyphonError {
        _ = try Syphon26RingSlotMetadata(abiVersion: 999, slotIndex: 0)
    }
    #expect(error?.category == .ioSurface)
}

@Test
func transportStreamPublishesAndCopiesLatestFrame() throws {
    let stream = try makeTransportStream(bufferCount: 3)

    #expect(try stream.copyLatestFrame(consumerID: "consumer-a") == nil)

    let firstDrawable = try stream.acquireDrawable()
    let firstSnapshot = try stream.presentDrawable(firstDrawable)
    let secondDrawable = try stream.acquireDrawable()
    let secondSnapshot = try stream.presentDrawable(secondDrawable)

    #expect(firstSnapshot.frameID == 1)
    #expect(secondSnapshot.frameID == 2)
    #expect(secondSnapshot.slotIndex == 1)

    let frame = try requireTransportFrame(try stream.copyLatestFrame(consumerID: "consumer-a"))
    #expect(frame.snapshot.frameID == 2)
    #expect(frame.snapshot.slotIndex == 1)
    #expect(frame.snapshot.missedFrameCount == 1)
    #expect(frame.snapshot.repeatedForConsumer == false)
    #expect(frame.texture.width == 320)
    #expect(frame.texture.height == 180)

    let repeatedFrame = try requireTransportFrame(try stream.copyLatestFrame(consumerID: "consumer-a"))
    #expect(repeatedFrame.snapshot.frameID == 2)
    #expect(repeatedFrame.snapshot.repeatedForConsumer == true)
    #expect(repeatedFrame.snapshot.missedFrameCount == 0)

    let diagnostics = stream.diagnosticsSnapshot()
    #expect(diagnostics.publishedFrames == 2)
    #expect(diagnostics.receivedFrames == 2)
    #expect(diagnostics.missedFrames == 1)
    #expect(diagnostics.repeatedReads == 1)
    #expect(diagnostics.overwrittenFrames == 0)
    #expect(diagnostics.consumerCount == 1)
}

@Test
func transportStreamUsesBoundedRingAndReportsConsumerLag() throws {
    let stream = try makeTransportStream(bufferCount: 2)

    for _ in 0..<5 {
        let drawable = try stream.acquireDrawable()
        try stream.presentDrawable(drawable)
    }

    let frame = try requireTransportFrame(try stream.copyLatestFrame(consumerID: "slow-consumer"))
    #expect(frame.snapshot.frameID == 5)
    #expect(frame.snapshot.missedFrameCount == 4)

    let diagnostics = stream.diagnosticsSnapshot()
    #expect(diagnostics.publishedFrames == 5)
    #expect(diagnostics.receivedFrames == 1)
    #expect(diagnostics.missedFrames == 4)
    #expect(diagnostics.overwrittenFrames == 3)
    #expect(diagnostics.consumerCount == 1)

    let metadata = stream.metadataSnapshot()
    #expect(metadata.count == 2)
    #expect(Set(metadata.compactMap(\.frameID)) == Set([4, 5]))
    #expect(metadata.allSatisfy { $0.state == .published })
}

@Test
func transportStreamRejectsStaleDrawablePresentation() throws {
    let stream = try makeTransportStream(bufferCount: 2)
    let drawable = try stream.acquireDrawable()
    try stream.presentDrawable(drawable)

    let error = captureTransportSyphonError {
        try stream.presentDrawable(drawable)
    }
    #expect(error?.category == .lifecycle)
}

private func makeTransportStream(bufferCount: Int) throws -> Syphon26TransportStream {
    let device = try makeTransportTestDevice()
    let configuration = try Syphon26ServerConfiguration(
        name: "Transport Test",
        appName: "Syphon26Tests",
        width: 320,
        height: 180,
        pixelFormat: .bgra8Unorm,
        bufferCount: bufferCount,
        controlPlaneServiceName: "com.example.syphon26.tests"
    )
    return try Syphon26TransportStream(configuration: configuration, device: device)
}

private func makeTransportTestDevice() throws -> any MTLDevice {
    guard let device = MTLCreateSystemDefaultDevice() else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createTransportTestDevice", reason: "no default Metal device")
        )
    }
    return device
}

private func requireTransportFrame(_ frame: Syphon26TransportFrame?) throws -> Syphon26TransportFrame {
    guard let frame else {
        throw Syphon26Error.lifecycle(
            Syphon26LifecycleIssue(code: .invalidState, state: .running, reason: "expected latest frame")
        )
    }
    return frame
}

private func captureTransportSyphonError(_ body: () throws -> Void) -> Syphon26Error? {
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
