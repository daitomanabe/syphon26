import Foundation
import Metal

public enum Syphon26FrameCloseState: String, CaseIterable, Sendable {
    case open
    case closeScheduled
    case closed
}

public final class Syphon26Frame: @unchecked Sendable {
    public let texture: any MTLTexture
    public let synchronizationSignal: Syphon26SynchronizationSignal

    private let lock = NSLock()
    private var closeStateStorage: Syphon26FrameCloseState = .open

    public init(texture: any MTLTexture, synchronizationSignal: Syphon26SynchronizationSignal) {
        self.texture = texture
        self.synchronizationSignal = synchronizationSignal
    }

    public var requiresGPUWait: Bool {
        synchronizationSignal.requiresGPUWait
    }

    public var closeState: Syphon26FrameCloseState {
        lock.lock()
        defer { lock.unlock() }
        return closeStateStorage
    }

    public func encodeWait(on commandBuffer: any MTLCommandBuffer) throws -> UInt64 {
        guard let sharedEvent = synchronizationSignal.sharedEvent,
              let value = synchronizationSignal.sharedEventValue else {
            if synchronizationSignal.syncMode == .sequenceCounter {
                return 0
            }
            throw Syphon26Error.synchronization(
                Syphon26RuntimeIssue(operation: "encodeWait", reason: "shared event handle missing")
            )
        }

        let start = DispatchTime.now().uptimeNanoseconds
        commandBuffer.encodeWaitForEvent(sharedEvent, value: value)
        return DispatchTime.now().uptimeNanoseconds - start
    }

    public func close() {
        setCloseState(.closed)
    }

    public func close(after commandBuffer: any MTLCommandBuffer) {
        lock.lock()
        guard closeStateStorage == .open else {
            lock.unlock()
            return
        }
        closeStateStorage = .closeScheduled
        lock.unlock()

        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.setCloseState(.closed)
        }
    }

    private func setCloseState(_ closeState: Syphon26FrameCloseState) {
        lock.lock()
        closeStateStorage = closeState
        lock.unlock()
    }
}
