import Foundation
import Metal
import Syphon26

struct SimpleServerOptions {
    var machServiceName = Syphon26.defaultControlPlaneMachServiceName
    var streamName = "Syphon26 Simple Server"
    var width = 1920
    var height = 1080
    var framesPerSecond = 60.0
    var duration: TimeInterval?
    var pixelFormat: MTLPixelFormat = .bgra8Unorm
}

func parseOptions() throws -> SimpleServerOptions {
    var options = SimpleServerOptions()
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
        case "--name":
            options.streamName = value
        case "--width":
            options.width = Int(value) ?? options.width
        case "--height":
            options.height = Int(value) ?? options.height
        case "--fps":
            options.framesPerSecond = Double(value) ?? options.framesPerSecond
        case "--duration":
            let seconds = TimeInterval(value) ?? 0
            options.duration = seconds > 0 ? seconds : nil
        case "--pixel-format":
            options.pixelFormat = try parsePixelFormat(value)
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
    Syphon26SimpleServer

    Options:
      --mach-service <name>   Default: \(Syphon26.defaultControlPlaneMachServiceName)
      --name <stream name>    Default: Syphon26 Simple Server
      --width <pixels>        Default: 1920
      --height <pixels>       Default: 1080
      --fps <frames/sec>      0 means unthrottled. Default: 60
      --duration <seconds>    Omit or pass 0 to run until interrupted
      --pixel-format <fmt>    bgra8 or rgba16f. Default: bgra8
    """)
    Foundation.exit(0)
}

func shouldContinue(start: Date, duration: TimeInterval?) -> Bool {
    guard let duration else {
        return true
    }
    return Date().timeIntervalSince(start) < duration
}

func encodeFrame(
    into texture: any MTLTexture,
    commandBuffer: any MTLCommandBuffer,
    frameIndex: Int
) throws {
    let pass = MTLRenderPassDescriptor()
    guard let colorAttachment = pass.colorAttachments[0] else {
        throw Syphon26Error.internalInconsistency
    }
    colorAttachment.texture = texture
    colorAttachment.loadAction = .clear
    colorAttachment.storeAction = .store
    let phase = Double(frameIndex % 240) / 240.0
    colorAttachment.clearColor = MTLClearColor(
        red: phase,
        green: 1.0 - phase,
        blue: 0.2 + 0.6 * phase,
        alpha: 1.0
    )
    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
        throw Syphon26Error.internalInconsistency
    }
    encoder.endEncoding()
}

do {
    let options = try parseOptions()
    guard let device = MTLCreateSystemDefaultDevice(),
          let queue = device.makeCommandQueue() else {
        throw Syphon26Error.unsupportedDevice
    }

    let controlPlane = Syphon26ControlPlane(machServiceName: options.machServiceName)
    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: options.streamName,
            appName: "Syphon26SimpleServer",
            device: device,
            width: options.width,
            height: options.height,
            pixelFormat: options.pixelFormat,
            syncMode: .automatic,
            controlPlane: controlPlane
        )
    )
    try server.start()
    defer { server.stop() }

    fputs("Syphon26SimpleServer started streamID=\(server.streamID) \(options.width)x\(options.height)\n", stderr)

    let start = Date()
    let frameInterval = options.framesPerSecond > 0 ? 1.0 / options.framesPerSecond : 0
    var nextFrameDeadline = Date()
    var frameIndex = 0

    while shouldContinue(start: start, duration: options.duration) {
        let drawable = try server.acquireDrawable()
        guard let commandBuffer = queue.makeCommandBuffer() else {
            throw Syphon26Error.commandBufferRequired
        }
        try encodeFrame(into: drawable.texture, commandBuffer: commandBuffer, frameIndex: frameIndex)
        try server.presentDrawable(drawable, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        frameIndex += 1

        if frameInterval > 0 {
            nextFrameDeadline = nextFrameDeadline.addingTimeInterval(frameInterval)
            let sleepTime = nextFrameDeadline.timeIntervalSinceNow
            if sleepTime > 0 {
                Thread.sleep(forTimeInterval: sleepTime)
            } else {
                nextFrameDeadline = Date()
            }
        }
    }

    let diagnostics = server.diagnosticsSnapshot()
    print("Syphon26SimpleServer streamID=\(server.streamID) frames=\(frameIndex) published=\(diagnostics.publishedFrames)")
} catch {
    fputs("Syphon26SimpleServer failed: \(error)\n", stderr)
    Foundation.exit(1)
}
