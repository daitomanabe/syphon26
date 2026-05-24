import Foundation
import Metal
import Syphon26

struct BenchmarkOptions {
    var width = 1920
    var height = 1080
    var fps = 60.0
    var warmupSeconds = 1.0
    var durationSeconds = 3.0
    var clients = 1
    var outputDirectory = "benchmark-results"
    var name = "Syphon26Benchmark"

    static func parse(_ arguments: [String]) throws -> BenchmarkOptions {
        var options = BenchmarkOptions()
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            func value() throws -> String {
                guard index + 1 < arguments.count else {
                    throw BenchmarkCLIError.missingValue(argument)
                }
                index += 1
                return arguments[index]
            }

            switch argument {
            case "--width":
                options.width = try Int(value()) ?? options.width
            case "--height":
                options.height = try Int(value()) ?? options.height
            case "--fps":
                options.fps = try Double(value()) ?? options.fps
            case "--warmup":
                options.warmupSeconds = try Double(value()) ?? options.warmupSeconds
            case "--duration":
                options.durationSeconds = try Double(value()) ?? options.durationSeconds
            case "--clients":
                options.clients = try Int(value()) ?? options.clients
            case "--output":
                options.outputDirectory = try value()
            case "--name":
                options.name = try value()
            case "--help", "-h":
                printHelpAndExit()
            default:
                throw BenchmarkCLIError.unknownArgument(argument)
            }
            index += 1
        }
        return options
    }
}

enum BenchmarkCLIError: Error, CustomStringConvertible {
    case missingValue(String)
    case unknownArgument(String)

    var description: String {
        switch self {
        case .missingValue(let argument):
            "Missing value for \(argument)"
        case .unknownArgument(let argument):
            "Unknown argument \(argument)"
        }
    }
}

struct BenchmarkManifest: Codable {
    var createdAt: String
    var width: Int
    var height: Int
    var fpsTarget: Double
    var warmupSeconds: Double
    var durationSeconds: Double
    var clients: Int
    var serverFrames: UInt64
    var serverFPS: Double
    var minClientFrames: UInt64
    var minClientFPS: Double
    var maxMissedFrames: UInt64
    var maxRepeatedReads: UInt64
    var syncMode: String
    var fallbackReason: String
}

func printHelpAndExit() -> Never {
    print("""
    Syphon26Benchmark

    Options:
      --width <pixels>       Default: 1920
      --height <pixels>      Default: 1080
      --fps <frames/sec>     0 means unthrottled. Default: 60
      --warmup <seconds>     Default: 1
      --duration <seconds>   Default: 3
      --clients <count>      Default: 1
      --output <directory>   Default: benchmark-results
      --name <stream name>   Default: Syphon26Benchmark
    """)
    Foundation.exit(0)
}

func hostSeconds() -> Double {
    Date().timeIntervalSinceReferenceDate
}

func runBenchmark(options: BenchmarkOptions) throws -> BenchmarkManifest {
    guard let device = MTLCreateSystemDefaultDevice(),
          let queue = device.makeCommandQueue()
    else {
        throw Syphon26Error.unsupportedDevice
    }

    let server = try Syphon26Server(
        configuration: Syphon26ServerConfiguration(
            name: options.name,
            device: device,
            width: options.width,
            height: options.height,
            pixelFormat: .bgra8Unorm,
            syncMode: .sequencePolling
        )
    )
    try server.start()
    defer { server.stop() }

    var clients: [Syphon26Client] = []
    for _ in 0..<options.clients {
        let client = try Syphon26Client(streamDescription: server.streamDescription, device: device)
        try client.start()
        clients.append(client)
    }
    defer { clients.forEach { $0.stop() } }

    let warmupEnd = hostSeconds() + options.warmupSeconds
    while hostSeconds() < warmupEnd {
        try publishOneFrame(server: server, queue: queue)
        for client in clients {
            _ = try client.copyLatestFrame()
        }
        throttleIfNeeded(fps: options.fps)
    }

    server.resetDiagnostics()
    for client in clients {
        client.resetDiagnostics()
    }

    let start = hostSeconds()
    let end = start + options.durationSeconds
    while hostSeconds() < end {
        try publishOneFrame(server: server, queue: queue)
        for client in clients {
            _ = try client.copyLatestFrame()
        }
        throttleIfNeeded(fps: options.fps)
    }
    let elapsed = max(hostSeconds() - start, 0.000001)

    let serverDiagnostics = server.diagnosticsSnapshot()
    let clientDiagnostics = clients.map { $0.diagnosticsSnapshot() }
    let minClientFrames = clientDiagnostics.map(\.observedFrames).min() ?? 0
    let maxMissedFrames = clientDiagnostics.map(\.missedFrames).max() ?? 0
    let maxRepeatedReads = clientDiagnostics.map(\.repeatedReads).max() ?? 0

    return BenchmarkManifest(
        createdAt: ISO8601DateFormatter().string(from: Date()),
        width: options.width,
        height: options.height,
        fpsTarget: options.fps,
        warmupSeconds: options.warmupSeconds,
        durationSeconds: options.durationSeconds,
        clients: options.clients,
        serverFrames: serverDiagnostics.publishedFrames,
        serverFPS: Double(serverDiagnostics.publishedFrames) / elapsed,
        minClientFrames: minClientFrames,
        minClientFPS: Double(minClientFrames) / elapsed,
        maxMissedFrames: maxMissedFrames,
        maxRepeatedReads: maxRepeatedReads,
        syncMode: serverDiagnostics.syncMode.rawValue,
        fallbackReason: serverDiagnostics.fallbackReason.rawValue
    )
}

func publishOneFrame(server: Syphon26Server, queue: any MTLCommandQueue) throws {
    let drawable = try server.acquireDrawable()
    guard let commandBuffer = queue.makeCommandBuffer() else {
        throw Syphon26Error.commandBufferRequired
    }
    try server.presentDrawable(drawable, commandBuffer: commandBuffer)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
}

func throttleIfNeeded(fps: Double) {
    guard fps > 0 else {
        return
    }
    Thread.sleep(forTimeInterval: 1.0 / fps)
}

func writeManifest(_ manifest: BenchmarkManifest, outputDirectory: String) throws {
    let directory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let outputURL = directory.appendingPathComponent("syphon26-benchmark.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(manifest)
    try data.write(to: outputURL)
    FileHandle.standardOutput.write(data)
    print("")
}

do {
    let options = try BenchmarkOptions.parse(Array(CommandLine.arguments.dropFirst()))
    let manifest = try runBenchmark(options: options)
    try writeManifest(manifest, outputDirectory: options.outputDirectory)
} catch {
    fputs("Syphon26Benchmark error: \(error)\n", stderr)
    Foundation.exit(1)
}
