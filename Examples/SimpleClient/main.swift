import Foundation
import Metal
import Syphon26

struct SimpleClientOptions {
    var machServiceName = Syphon26.defaultControlPlaneMachServiceName
    var streamID: Syphon26StreamID?
    var streamName: String?
    var duration: TimeInterval = 5
    var attachTimeout: TimeInterval = 10
    var pixelFormat: MTLPixelFormat = .bgra8Unorm
    var printEvery = 60
}

func parseOptions() throws -> SimpleClientOptions {
    var options = SimpleClientOptions()
    var arguments = Array(CommandLine.arguments.dropFirst())
    while !arguments.isEmpty {
        let key = arguments.removeFirst()
        if key == "--help" || key == "-h" {
            printHelpAndExit()
        }
        guard !arguments.isEmpty else {
            throw Syphon26Error.invalidConfiguration
        }
        let value = arguments.removeFirst()
        switch key {
        case "--mach-service":
            options.machServiceName = value
        case "--stream-id":
            options.streamID = value
        case "--stream-name", "--name":
            options.streamName = value
        case "--duration":
            options.duration = TimeInterval(value) ?? options.duration
        case "--attach-timeout":
            options.attachTimeout = TimeInterval(value) ?? options.attachTimeout
        case "--pixel-format":
            options.pixelFormat = try parsePixelFormat(value)
        case "--print-every":
            options.printEvery = Int(value) ?? options.printEvery
        default:
            throw Syphon26Error.invalidConfiguration
        }
    }
    return options
}

func parsePixelFormat(_ value: String) throws -> MTLPixelFormat {
    switch value.lowercased() {
    case "bgra8", "bgra8unorm":
        return .bgra8Unorm
    case "rgba16f", "rgba16float":
        return .rgba16Float
    default:
        throw Syphon26Error.unsupportedPixelFormat
    }
}

func printHelpAndExit() -> Never {
    print("""
    Syphon26SimpleClient

    Options:
      --mach-service <name>   Default: \(Syphon26.defaultControlPlaneMachServiceName)
      --stream-id <id>        Optional. Defaults to the first visible Syphon26 stream
      --stream-name <name>    Optional. Polls for a stream with this exact name
      --duration <seconds>    Default: 5
      --attach-timeout <sec>  Default: 10
      --pixel-format <fmt>    bgra8 or rgba16f. Default: bgra8
      --print-every <n>       Print every n observed frames. Default: 60
    """)
    Foundation.exit(0)
}

func resolveTargetStreamID(
    controlPlane: Syphon26ControlPlane,
    options: SimpleClientOptions
) throws -> Syphon26StreamID? {
    if let streamID = options.streamID {
        return streamID
    }
    guard let streamName = options.streamName else {
        return nil
    }
    return try controlPlane.streams().first { $0.name == streamName }?.streamID
}

func attachClient(
    device: any MTLDevice,
    options: SimpleClientOptions
) throws -> Syphon26Client {
    let controlPlane = Syphon26ControlPlane(machServiceName: options.machServiceName)
    let deadline = Date().addingTimeInterval(options.attachTimeout)
    var lastError: (any Error)?

    while Date() < deadline {
        do {
            let targetStreamID = try resolveTargetStreamID(controlPlane: controlPlane, options: options)
            if options.streamName != nil, targetStreamID == nil {
                throw Syphon26Error.streamNotFound
            }
            let client = try Syphon26Client(
                configuration: Syphon26ClientConfiguration(
                    device: device,
                    streamID: targetStreamID,
                    preferredPixelFormats: [options.pixelFormat],
                    controlPlane: controlPlane
                )
            )
            try client.start()
            return client
        } catch {
            lastError = error
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    throw lastError ?? Syphon26Error.streamNotFound
}

do {
    let options = try parseOptions()
    guard let device = MTLCreateSystemDefaultDevice(),
          let queue = device.makeCommandQueue() else {
        throw Syphon26Error.unsupportedDevice
    }

    let client = try attachClient(device: device, options: options)
    defer { client.stop() }

    let stream = client.streamDescription
    fputs(
        "Syphon26SimpleClient attached streamID=\(client.streamID ?? "none") name=\(stream?.name ?? "unknown")\n",
        stderr
    )

    let deadline = Date().addingTimeInterval(options.duration)
    var observedFrames: UInt64 = 0
    var repeatedReads: UInt64 = 0
    var lastSequence: Syphon26Sequence = 0

    while Date() < deadline {
        if let frame = try client.copyLatestFrame() {
            if frame.requiresGPUWait {
                guard let commandBuffer = queue.makeCommandBuffer() else {
                    throw Syphon26Error.commandBufferRequired
                }
                try frame.encodeWait(on: commandBuffer)
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }
            observedFrames += 1
            lastSequence = frame.sequence
            if options.printEvery > 0, observedFrames % UInt64(options.printEvery) == 0 {
                print("Syphon26SimpleClient frame sequence=\(frame.sequence) size=\(frame.width)x\(frame.height)")
            }
            frame.close()
        } else {
            repeatedReads += 1
            Thread.sleep(forTimeInterval: 0.001)
        }
    }

    let diagnostics = client.diagnosticsSnapshot()
    print(
        "Syphon26SimpleClient streamID=\(client.streamID ?? "none") observed=\(observedFrames) lastSequence=\(lastSequence) repeatedReads=\(repeatedReads) diagnosticsObserved=\(diagnostics.observedFrames)"
    )
} catch {
    fputs("Syphon26SimpleClient failed: \(error)\n", stderr)
    Foundation.exit(1)
}
