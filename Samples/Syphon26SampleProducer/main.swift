import Foundation
import Metal
import Syphon26

struct ProducerOptions {
    var machServiceName = "com.syphon26.samples.control-plane"
    var duration: TimeInterval = 5
    var width = 1920
    var height = 1080
    var framesPerSecond: Double = 60
    var pixelFormat: MTLPixelFormat = .bgra8Unorm
}

func parseOptions() throws -> ProducerOptions {
    var options = ProducerOptions()
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
        case "--width":
            options.width = Int(value) ?? options.width
        case "--height":
            options.height = Int(value) ?? options.height
        case "--fps":
            options.framesPerSecond = Double(value) ?? options.framesPerSecond
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
guard let device = MTLCreateSystemDefaultDevice(),
      let queue = device.makeCommandQueue() else {
    throw Syphon26Error.unsupportedDevice
}

let controlPlane = Syphon26ControlPlane(machServiceName: options.machServiceName)
let server = try Syphon26Server(
    configuration: Syphon26ServerConfiguration(
        name: "Syphon26 Sample Producer \(options.pixelFormat.rawValue)",
        appName: "Syphon26SampleProducer",
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

let deadline = Date().addingTimeInterval(options.duration)
let frameInterval = options.framesPerSecond > 0 ? 1.0 / options.framesPerSecond : 0
var nextFrameDeadline = Date()
var frameCount = 0

while Date() < deadline {
    let drawable = try server.acquireDrawable()
    guard let commandBuffer = queue.makeCommandBuffer() else {
        throw Syphon26Error.commandBufferRequired
    }

    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = drawable.texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let phase = Double(frameCount % 240) / 240.0
    pass.colorAttachments[0].clearColor = MTLClearColor(
        red: phase,
        green: 1.0 - phase,
        blue: 0.25 + 0.5 * phase,
        alpha: 1.0
    )
    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
        throw Syphon26Error.transportUnavailable
    }
    encoder.endEncoding()
    try server.presentDrawable(drawable, commandBuffer: commandBuffer)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    frameCount += 1

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
print("Syphon26SampleProducer streamID=\(server.streamID) frames=\(frameCount) published=\(diagnostics.publishedFrames) pixelFormat=\(options.pixelFormat.rawValue)")
