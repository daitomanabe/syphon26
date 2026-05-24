import Foundation
import Metal
import Syphon26

struct ConsumerOptions {
    var machServiceName = "com.syphon26.samples.control-plane"
    var duration: TimeInterval = 5
    var attachTimeout: TimeInterval = 5
    var pixelFormat: MTLPixelFormat = .bgra8Unorm
}

func parseOptions() throws -> ConsumerOptions {
    var options = ConsumerOptions()
    var arguments = Array(CommandLine.arguments.dropFirst())
    while !arguments.isEmpty {
        let key = arguments.removeFirst()
        guard !arguments.isEmpty else {
            throw Syphon26Error.invalidConfiguration
        }
        let value = arguments.removeFirst()
        switch key {
        case "--mach-service":
            options.machServiceName = value
        case "--duration":
            options.duration = TimeInterval(value) ?? options.duration
        case "--attach-timeout":
            options.attachTimeout = TimeInterval(value) ?? options.attachTimeout
        case "--pixel-format":
            switch value.lowercased() {
            case "bgra8", "bgra8unorm":
                options.pixelFormat = .bgra8Unorm
            case "rgba16f", "rgba16float":
                options.pixelFormat = .rgba16Float
            default:
                throw Syphon26Error.unsupportedPixelFormat
            }
        default:
            throw Syphon26Error.invalidConfiguration
        }
    }
    return options
}

let options = try parseOptions()
guard let device = MTLCreateSystemDefaultDevice() else {
    throw Syphon26Error.unsupportedDevice
}

let controlPlane = Syphon26ControlPlane(machServiceName: options.machServiceName)
let attachDeadline = Date().addingTimeInterval(options.attachTimeout)
var client: Syphon26Client?
var lastAttachError: (any Error)?

while Date() < attachDeadline, client == nil {
    do {
        let candidate = try Syphon26Client(
            configuration: Syphon26ClientConfiguration(
                device: device,
                preferredPixelFormats: [options.pixelFormat],
                controlPlane: controlPlane
            )
        )
        try candidate.start()
        client = candidate
    } catch {
        lastAttachError = error
        Thread.sleep(forTimeInterval: 0.05)
    }
}

guard let client else {
    throw lastAttachError ?? Syphon26Error.streamNotFound
}
defer { client.stop() }
fputs("Syphon26SampleConsumer attached streamID=\(client.streamID ?? "none")\n", stderr)

let deadline = Date().addingTimeInterval(options.duration)
var observedFrames: UInt64 = 0
var repeatedReads: UInt64 = 0
var lastSequence: Syphon26Sequence = 0

while Date() < deadline {
    do {
        if let frame = try client.copyLatestFrame() {
            observedFrames += 1
            lastSequence = frame.sequence
            frame.close()
        } else {
            repeatedReads += 1
            Thread.sleep(forTimeInterval: 0.001)
        }
    } catch {
        repeatedReads += 1
        if observedFrames > 0 {
            fputs("Syphon26SampleConsumer frame read stopped: \(error)\n", stderr)
            break
        }
        Thread.sleep(forTimeInterval: 0.01)
    }
}

let diagnostics = client.diagnosticsSnapshot()
print("Syphon26SampleConsumer streamID=\(client.streamID ?? "none") observed=\(observedFrames) lastSequence=\(lastSequence) repeatedReads=\(repeatedReads) diagnosticsObserved=\(diagnostics.observedFrames)")
