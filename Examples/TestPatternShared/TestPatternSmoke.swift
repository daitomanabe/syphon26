import Foundation
import Metal
import Syphon26

public enum Syphon26TestPatternSmoke {
    public static func runServer(options: Syphon26TestPatternOptions) throws -> Syphon26TestPatternSummary {
        let publisher = try Syphon26TestPatternPublisher(options: options)
        try publisher.resetService()

        let frameCount = max(1, Int(max(options.durationSeconds, 0.1) * Double(max(options.fps, 1))))
        let interval = max(1.0 / Double(max(options.fps, 1)), 1.0 / 240.0)
        let start = Date()
        var published: UInt64 = 0

        for index in 0..<frameCount {
            published = try publisher.publishNextFrame()
            if index == 0 {
                try touchReadyFile(options.readyURL)
            }
            let nextFrameTime = start.addingTimeInterval(Double(index + 1) * interval)
            let sleepDuration = nextFrameTime.timeIntervalSinceNow
            if sleepDuration > 0 {
                Thread.sleep(forTimeInterval: sleepDuration)
            }
        }

        let elapsed = max(Date().timeIntervalSince(start), 0.001)

        if options.holdSeconds > 0 {
            Thread.sleep(forTimeInterval: options.holdSeconds)
        }

        let summary = Syphon26TestPatternSummary(
            role: "server",
            transportScope: "app-to-app-syphon26-production-xpc",
            serviceName: options.serviceName,
            streamID: publisher.streamDescription.streamID.value,
            width: publisher.streamDescription.width,
            height: publisher.streamDescription.height,
            fpsTarget: options.fps,
            orientationMode: options.orientationMode.rawValue,
            colorBars: true,
            topBottomMarkers: true,
            movingFrameTick: true,
            textureOpened: true,
            framesPublished: published,
            framesObserved: 0,
            firstFrameID: nil,
            lastFrameID: published,
            measuredFPS: Double(published) / elapsed,
            windowCanBecomeKey: false,
            windowCanBecomeMain: false,
            windowIsKey: false,
            windowIsMain: false
        )
        try writeSummary(summary, to: options.summaryURL)
        return summary
    }

    public static func runClient(options: Syphon26TestPatternOptions) throws -> Syphon26TestPatternSummary {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "createTestPatternSmokeClientDevice", reason: "Metal device is unavailable")
            )
        }
        let controlPlane = try Syphon26ProductionXPCControlPlane(serviceName: options.serviceName)
        let firstMetadata = try controlPlane.waitForMetadata(timeoutSeconds: options.waitTimeoutSeconds)
        let frame = try controlPlane.openLatestFrame(device: device)

        let deadline = Date().addingTimeInterval(max(options.durationSeconds, 0.1))
        let start = Date()
        var firstFrameID: UInt64?
        var lastFrameID: UInt64?
        var observedFrames: UInt64 = 0

        while Date() < deadline {
            if let metadata = try? controlPlane.latestMetadata(),
               metadata.frameID != lastFrameID {
                firstFrameID = firstFrameID ?? metadata.frameID
                lastFrameID = metadata.frameID
                observedFrames += 1
            }
            Thread.sleep(forTimeInterval: 0.002)
        }

        let elapsed = max(Date().timeIntervalSince(start), 0.001)
        let stream = frame.metadata.streamDescription
        let summary = Syphon26TestPatternSummary(
            role: "client",
            transportScope: "app-to-app-syphon26-production-xpc",
            serviceName: options.serviceName,
            streamID: stream.streamID.value,
            width: frame.texture.width,
            height: frame.texture.height,
            fpsTarget: options.fps,
            orientationMode: options.orientationMode.rawValue,
            colorBars: true,
            topBottomMarkers: true,
            movingFrameTick: true,
            textureOpened: frame.texture.width == firstMetadata.streamDescription.width && frame.texture.height == firstMetadata.streamDescription.height,
            framesPublished: lastFrameID ?? firstMetadata.frameID,
            framesObserved: observedFrames,
            firstFrameID: firstFrameID,
            lastFrameID: lastFrameID,
            measuredFPS: Double(observedFrames) / elapsed,
            windowCanBecomeKey: false,
            windowCanBecomeMain: false,
            windowIsKey: false,
            windowIsMain: false
        )
        try writeSummary(summary, to: options.summaryURL)
        return summary
    }
}
