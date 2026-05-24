import Foundation

public struct Syphon26DiagnosticsSnapshot: Sendable, Equatable {
    public var role: Syphon26Role
    public var streamID: Syphon26StreamID?
    public var syncMode: Syphon26SyncMode
    public var fallbackReason: Syphon26FallbackReason
    public var activeClientCount: Int
    public var publishedFrames: UInt64
    public var observedFrames: UInt64
    public var missedFrames: UInt64
    public var repeatedReads: UInt64
    public var overwrittenFrames: UInt64
    public var droppedFrames: UInt64
    public var currentConsumerLagFrames: UInt64
    public var maxConsumerLagFrames: UInt64
    public var slotDepthFrames: UInt64
    public var producerStallNanoseconds: UInt64
    public var gpuWaitNanoseconds: UInt64
    public var xpcMessagesSent: UInt64
    public var xpcMessagesReceived: UInt64
    public var sharedEventSignals: UInt64
    public var sharedEventWaits: UInt64
    public var sharedEventTimeouts: UInt64
    public var lastErrorCode: Syphon26Error?

    public init(
        role: Syphon26Role,
        streamID: Syphon26StreamID? = nil,
        syncMode: Syphon26SyncMode = .automatic,
        fallbackReason: Syphon26FallbackReason = .none,
        activeClientCount: Int = 0,
        publishedFrames: UInt64 = 0,
        observedFrames: UInt64 = 0,
        missedFrames: UInt64 = 0,
        repeatedReads: UInt64 = 0,
        overwrittenFrames: UInt64 = 0,
        droppedFrames: UInt64 = 0,
        currentConsumerLagFrames: UInt64 = 0,
        maxConsumerLagFrames: UInt64 = 0,
        slotDepthFrames: UInt64 = 0,
        producerStallNanoseconds: UInt64 = 0,
        gpuWaitNanoseconds: UInt64 = 0,
        xpcMessagesSent: UInt64 = 0,
        xpcMessagesReceived: UInt64 = 0,
        sharedEventSignals: UInt64 = 0,
        sharedEventWaits: UInt64 = 0,
        sharedEventTimeouts: UInt64 = 0,
        lastErrorCode: Syphon26Error? = nil
    ) {
        self.role = role
        self.streamID = streamID
        self.syncMode = syncMode
        self.fallbackReason = fallbackReason
        self.activeClientCount = activeClientCount
        self.publishedFrames = publishedFrames
        self.observedFrames = observedFrames
        self.missedFrames = missedFrames
        self.repeatedReads = repeatedReads
        self.overwrittenFrames = overwrittenFrames
        self.droppedFrames = droppedFrames
        self.currentConsumerLagFrames = currentConsumerLagFrames
        self.maxConsumerLagFrames = maxConsumerLagFrames
        self.slotDepthFrames = slotDepthFrames
        self.producerStallNanoseconds = producerStallNanoseconds
        self.gpuWaitNanoseconds = gpuWaitNanoseconds
        self.xpcMessagesSent = xpcMessagesSent
        self.xpcMessagesReceived = xpcMessagesReceived
        self.sharedEventSignals = sharedEventSignals
        self.sharedEventWaits = sharedEventWaits
        self.sharedEventTimeouts = sharedEventTimeouts
        self.lastErrorCode = lastErrorCode
    }
}

