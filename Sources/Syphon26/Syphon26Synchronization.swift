import Metal

public struct Syphon26SynchronizationSignal {
    public let syncMode: Syphon26SyncMode
    public let fallbackReason: Syphon26SyncFallbackReason
    public let sharedEventValue: UInt64?
    public let sequenceCounterValue: UInt64

    let sharedEvent: (any MTLSharedEvent)?

    public var requiresGPUWait: Bool {
        syncMode == .sharedEvent && sharedEvent != nil && sharedEventValue != nil
    }
}

public struct Syphon26SynchronizationDiagnostics: Equatable, Sendable {
    public let syncMode: Syphon26SyncMode
    public let fallbackReason: Syphon26SyncFallbackReason
    public let signalCount: UInt64
    public let waitCount: UInt64
    public let gpuWaitNanoseconds: UInt64
}

public final class Syphon26SynchronizationCoordinator {
    public let syncMode: Syphon26SyncMode
    public let fallbackReason: Syphon26SyncFallbackReason

    private let sharedEvent: (any MTLSharedEvent)?
    private var signalCount: UInt64 = 0
    private var waitCount: UInt64 = 0
    private var gpuWaitNanoseconds: UInt64 = 0

    public init(
        device: any MTLDevice,
        preferredMode: Syphon26SyncMode = .automatic,
        sharedEventAvailable: Bool? = nil
    ) {
        let shouldUseSharedEvent: Bool
        switch preferredMode {
        case .automatic, .sharedEvent:
            shouldUseSharedEvent = sharedEventAvailable ?? true
        case .sequenceCounter:
            shouldUseSharedEvent = false
        }

        if shouldUseSharedEvent, let event = device.makeSharedEvent() {
            self.syncMode = .sharedEvent
            self.fallbackReason = .none
            self.sharedEvent = event
        } else {
            self.syncMode = .sequenceCounter
            self.sharedEvent = nil
            switch preferredMode {
            case .sequenceCounter:
                self.fallbackReason = .consumerUnsupported
            case .automatic, .sharedEvent:
                self.fallbackReason = .sharedEventUnavailable
            }
        }
    }

    public func signal(on commandBuffer: any MTLCommandBuffer) -> Syphon26SynchronizationSignal {
        signalCount += 1
        let value = signalCount

        if let sharedEvent {
            commandBuffer.encodeSignalEvent(sharedEvent, value: value)
            return Syphon26SynchronizationSignal(
                syncMode: .sharedEvent,
                fallbackReason: .none,
                sharedEventValue: value,
                sequenceCounterValue: value,
                sharedEvent: sharedEvent
            )
        }

        return Syphon26SynchronizationSignal(
            syncMode: .sequenceCounter,
            fallbackReason: fallbackReason,
            sharedEventValue: nil,
            sequenceCounterValue: value,
            sharedEvent: nil
        )
    }

    public func recordWait(_ waitNanoseconds: UInt64) {
        waitCount += 1
        gpuWaitNanoseconds += waitNanoseconds
    }

    public func diagnosticsSnapshot() -> Syphon26SynchronizationDiagnostics {
        Syphon26SynchronizationDiagnostics(
            syncMode: syncMode,
            fallbackReason: fallbackReason,
            signalCount: signalCount,
            waitCount: waitCount,
            gpuWaitNanoseconds: gpuWaitNanoseconds
        )
    }
}
