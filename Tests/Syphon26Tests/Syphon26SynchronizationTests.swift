import Metal
import Testing
import Syphon26

@Test
func sharedEventSynchronizationEncodesWaitAndClosesAfterGPUCompletion() throws {
    let device = try makeSynchronizationTestDevice()
    let queue = try makeSynchronizationCommandQueue(device: device)
    let coordinator = Syphon26SynchronizationCoordinator(device: device, preferredMode: .sharedEvent)

    let producerCommandBuffer = try makeSynchronizationCommandBuffer(queue: queue)
    let signal = coordinator.signal(on: producerCommandBuffer)
    let frame = try Syphon26Frame(texture: makeSynchronizationTexture(device: device), synchronizationSignal: signal)

    if frame.requiresGPUWait {
        let consumerCommandBuffer = try makeSynchronizationCommandBuffer(queue: queue)
        let waitNanoseconds = try frame.encodeWait(on: consumerCommandBuffer)
        coordinator.recordWait(waitNanoseconds)
        frame.close(after: consumerCommandBuffer)

        #expect(frame.closeState == .closeScheduled)

        producerCommandBuffer.commit()
        consumerCommandBuffer.commit()
        producerCommandBuffer.waitUntilCompleted()
        consumerCommandBuffer.waitUntilCompleted()

        #expect(producerCommandBuffer.error == nil)
        #expect(consumerCommandBuffer.error == nil)
        #expect(frame.closeState == .closed)

        let diagnostics = coordinator.diagnosticsSnapshot()
        #expect(diagnostics.syncMode == .sharedEvent)
        #expect(diagnostics.fallbackReason == .none)
        #expect(diagnostics.signalCount == 1)
        #expect(diagnostics.waitCount == 1)
    } else {
        producerCommandBuffer.commit()
        producerCommandBuffer.waitUntilCompleted()

        let diagnostics = coordinator.diagnosticsSnapshot()
        #expect(diagnostics.syncMode == .sequenceCounter)
        #expect(diagnostics.fallbackReason == .sharedEventUnavailable)
    }
}

@Test
func sequenceCounterFallbackDoesNotRequireGPUWait() throws {
    let device = try makeSynchronizationTestDevice()
    let queue = try makeSynchronizationCommandQueue(device: device)
    let coordinator = Syphon26SynchronizationCoordinator(
        device: device,
        preferredMode: .automatic,
        sharedEventAvailable: false
    )

    let producerCommandBuffer = try makeSynchronizationCommandBuffer(queue: queue)
    let signal = coordinator.signal(on: producerCommandBuffer)
    let frame = try Syphon26Frame(texture: makeSynchronizationTexture(device: device), synchronizationSignal: signal)
    let consumerCommandBuffer = try makeSynchronizationCommandBuffer(queue: queue)

    #expect(coordinator.syncMode == .sequenceCounter)
    #expect(coordinator.fallbackReason == .sharedEventUnavailable)
    #expect(frame.requiresGPUWait == false)
    #expect(try frame.encodeWait(on: consumerCommandBuffer) == 0)

    frame.close(after: consumerCommandBuffer)
    producerCommandBuffer.commit()
    consumerCommandBuffer.commit()
    producerCommandBuffer.waitUntilCompleted()
    consumerCommandBuffer.waitUntilCompleted()

    #expect(frame.closeState == .closed)

    let diagnostics = coordinator.diagnosticsSnapshot()
    #expect(diagnostics.syncMode == .sequenceCounter)
    #expect(diagnostics.fallbackReason == .sharedEventUnavailable)
    #expect(diagnostics.signalCount == 1)
    #expect(diagnostics.waitCount == 0)
    #expect(diagnostics.gpuWaitNanoseconds == 0)
}

@Test
func explicitSequenceCounterModeReportsConsumerUnsupportedFallback() throws {
    let device = try makeSynchronizationTestDevice()
    let queue = try makeSynchronizationCommandQueue(device: device)
    let coordinator = Syphon26SynchronizationCoordinator(device: device, preferredMode: .sequenceCounter)
    let commandBuffer = try makeSynchronizationCommandBuffer(queue: queue)

    let signal = coordinator.signal(on: commandBuffer)
    #expect(signal.syncMode == .sequenceCounter)
    #expect(signal.fallbackReason == .consumerUnsupported)
    #expect(signal.sequenceCounterValue == 1)
    #expect(signal.sharedEventValue == nil)

    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
}

@Test
func frameCanCloseImmediatelyWithoutGPUCompletionHandler() throws {
    let device = try makeSynchronizationTestDevice()
    let queue = try makeSynchronizationCommandQueue(device: device)
    let coordinator = Syphon26SynchronizationCoordinator(
        device: device,
        preferredMode: .automatic,
        sharedEventAvailable: false
    )
    let signal = coordinator.signal(on: try makeSynchronizationCommandBuffer(queue: queue))
    let frame = try Syphon26Frame(texture: makeSynchronizationTexture(device: device), synchronizationSignal: signal)

    #expect(frame.closeState == .open)
    frame.close()
    #expect(frame.closeState == .closed)
}

private func makeSynchronizationTestDevice() throws -> any MTLDevice {
    guard let device = MTLCreateSystemDefaultDevice() else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createSynchronizationTestDevice", reason: "no default Metal device")
        )
    }
    return device
}

private func makeSynchronizationCommandQueue(device: any MTLDevice) throws -> any MTLCommandQueue {
    guard let queue = device.makeCommandQueue() else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "makeSynchronizationCommandQueue", reason: "Metal returned nil queue")
        )
    }
    return queue
}

private func makeSynchronizationCommandBuffer(queue: any MTLCommandQueue) throws -> any MTLCommandBuffer {
    guard let commandBuffer = queue.makeCommandBuffer() else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "makeSynchronizationCommandBuffer", reason: "Metal returned nil command buffer")
        )
    }
    return commandBuffer
}

private func makeSynchronizationTexture(device: any MTLDevice) throws -> any MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .bgra8Unorm,
        width: 16,
        height: 16,
        mipmapped: false
    )
    descriptor.usage = [.shaderRead, .shaderWrite]
    descriptor.storageMode = .private

    guard let texture = device.makeTexture(descriptor: descriptor) else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "makeSynchronizationTexture", reason: "Metal returned nil texture")
        )
    }
    return texture
}
