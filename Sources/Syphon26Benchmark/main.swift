import Darwin
import Foundation
import Metal
import Syphon26

struct BenchmarkReport: Codable {
    let schemaVersion: Int
    let benchmarkName: String
    let transportScope: String
    let measurementMode: String
    let environment: Environment
    let command: [String]
    let resolution: Resolution
    let pixelFormat: String
    let fpsTarget: Int
    let warmupSeconds: Double
    let durationSeconds: Double?
    let renderMode: String
    let frameCount: Int
    let publishFPS: Double
    let receiveFPS: Double
    let missedFrames: UInt64
    let repeatedReads: UInt64
    let latencyNanosecondsAverage: UInt64
    let cpuUserSeconds: Double
    let cpuSystemSeconds: Double
    let memoryMaxRSSBytes: Int64
    let gpuWaitNanoseconds: UInt64
    let interpretationLimits: [String]
}

struct Environment: Codable {
    let hostName: String
    let operatingSystemVersion: String
    let processorCount: Int
    let physicalMemoryBytes: UInt64
    let metalDeviceName: String
}

struct Resolution: Codable {
    let width: Int
    let height: Int
}

struct Options {
    let frames: Int
    let width: Int
    let height: Int
    let fpsTarget: Int
    let warmupSeconds: Double
    let durationSeconds: Double?
    let renderMode: RenderMode
    let json: Bool

    init(arguments: [String]) {
        self.frames = Self.value(after: "--frames", in: arguments).flatMap(Int.init) ?? 240
        self.width = Self.value(after: "--width", in: arguments).flatMap(Int.init) ?? 640
        self.height = Self.value(after: "--height", in: arguments).flatMap(Int.init) ?? 360
        self.fpsTarget = Self.value(after: "--fps-target", in: arguments).flatMap(Int.init) ?? 60
        self.warmupSeconds = Self.value(after: "--warmup", in: arguments).flatMap(Double.init) ?? 0
        self.durationSeconds = Self.value(after: "--duration", in: arguments).flatMap(Double.init)
        self.renderMode = Self.value(after: "--render", in: arguments).flatMap(RenderMode.init(rawValue:)) ?? .clear
        self.json = arguments.contains("--json")
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

enum RenderMode: String {
    case clear
    case none
}

let options = Options(arguments: Array(CommandLine.arguments.dropFirst()))
let report = try runBenchmark(options: options)

if options.json {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    print(String(decoding: try encoder.encode(report), as: UTF8.self))
} else {
    print("publishFPS=\(report.publishFPS) receiveFPS=\(report.receiveFPS) frames=\(report.frameCount)")
}

func runBenchmark(options: Options) throws -> BenchmarkReport {
    guard options.frames > 0 else {
        throw Syphon26Error.validation(
            Syphon26ValidationIssue(code: .invalidDimensions, field: "frames", reason: "frame count must be positive")
        )
    }
    guard let device = MTLCreateSystemDefaultDevice() else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createBenchmarkDevice", reason: "no default Metal device")
        )
    }
    guard let commandQueue = device.makeCommandQueue() else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createBenchmarkCommandQueue", reason: "Metal returned nil command queue")
        )
    }

    let configuration = try Syphon26ServerConfiguration(
        name: "Syphon26 Benchmark Stream",
        appName: "Syphon26Benchmark",
        width: options.width,
        height: options.height,
        pixelFormat: .bgra8Unorm,
        bufferCount: 3,
        controlPlaneServiceName: Syphon26.defaultControlPlaneServiceName
    )

    if options.warmupSeconds > 0 {
        let warmupStream = try Syphon26TransportStream(configuration: configuration, device: device)
        try runLoop(
            stream: warmupStream,
            commandQueue: commandQueue,
            fpsTarget: options.fpsTarget,
            renderMode: options.renderMode,
            durationSeconds: options.warmupSeconds,
            frameLimit: nil
        )
    }

    let stream = try Syphon26TransportStream(configuration: configuration, device: device)
    let startUsage = currentResourceUsage()
    var totalLatencyNanoseconds: UInt64 = 0
    let start = DispatchTime.now().uptimeNanoseconds
    let measuredFrames = try runLoop(
        stream: stream,
        commandQueue: commandQueue,
        fpsTarget: options.fpsTarget,
        renderMode: options.renderMode,
        durationSeconds: options.durationSeconds,
        frameLimit: options.durationSeconds == nil ? options.frames : nil,
        totalLatencyNanoseconds: &totalLatencyNanoseconds
    )
    let end = DispatchTime.now().uptimeNanoseconds
    let endUsage = currentResourceUsage()
    let diagnostics = stream.diagnosticsSnapshot()
    let elapsedSeconds = max(Double(end - start) / 1_000_000_000, 0.000_001)

    return BenchmarkReport(
        schemaVersion: 2,
        benchmarkName: "syphon26-in-process-transport",
        transportScope: "in-process-transport-core",
        measurementMode: options.durationSeconds == nil ? "frame-count" : "duration",
        environment: Environment(
            hostName: Host.current().localizedName ?? "unknown",
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            processorCount: ProcessInfo.processInfo.processorCount,
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            metalDeviceName: device.name
        ),
        command: CommandLine.arguments,
        resolution: Resolution(width: options.width, height: options.height),
        pixelFormat: configuration.pixelFormat.rawName,
        fpsTarget: options.fpsTarget,
        warmupSeconds: options.warmupSeconds,
        durationSeconds: options.durationSeconds,
        renderMode: options.renderMode.rawValue,
        frameCount: measuredFrames,
        publishFPS: Double(diagnostics.publishedFrames) / elapsedSeconds,
        receiveFPS: Double(diagnostics.receivedFrames) / elapsedSeconds,
        missedFrames: diagnostics.missedFrames,
        repeatedReads: diagnostics.repeatedReads,
        latencyNanosecondsAverage: totalLatencyNanoseconds / UInt64(max(measuredFrames, 1)),
        cpuUserSeconds: endUsage.userSeconds - startUsage.userSeconds,
        cpuSystemSeconds: endUsage.systemSeconds - startUsage.systemSeconds,
        memoryMaxRSSBytes: endUsage.maxRSSBytes,
        gpuWaitNanoseconds: diagnostics.gpuWaitNanoseconds,
        interpretationLimits: [
            "Measures current in-process Syphon26 transport-core path only.",
            "Does not measure cross-process XPC or launchd service overhead.",
            "Does not compare against v1 or classic Syphon.",
            "Does not represent an app-to-app classic Syphon comparison."
        ]
    )
}

@discardableResult
func runLoop(
    stream: Syphon26TransportStream,
    commandQueue: any MTLCommandQueue,
    fpsTarget: Int,
    renderMode: RenderMode,
    durationSeconds: Double?,
    frameLimit: Int?,
    totalLatencyNanoseconds: inout UInt64
) throws -> Int {
    var measuredFrames = 0
    var pacer = FramePacer(fpsTarget: fpsTarget)
    let end = durationSeconds.map { DispatchTime.now().uptimeNanoseconds + UInt64(max($0, 0) * 1_000_000_000) }

    while true {
        if let frameLimit, measuredFrames >= frameLimit {
            break
        }
        if let end, DispatchTime.now().uptimeNanoseconds >= end {
            break
        }

        let drawable = try stream.acquireDrawable()
        if renderMode == .clear {
            try encodeClear(into: drawable.texture, commandQueue: commandQueue, sequence: UInt64(measuredFrames + 1))
        }
        let snapshot = try stream.presentDrawable(drawable)
        if let frame = try stream.copyLatestFrame(consumerID: "benchmark-client") {
            totalLatencyNanoseconds += DispatchTime.now().uptimeNanoseconds - snapshot.publishedNanoseconds
            _ = frame.texture.width
        }
        measuredFrames += 1
        pacer.waitIfNeeded()
    }
    return measuredFrames
}

@discardableResult
func runLoop(
    stream: Syphon26TransportStream,
    commandQueue: any MTLCommandQueue,
    fpsTarget: Int,
    renderMode: RenderMode,
    durationSeconds: Double?,
    frameLimit: Int?
) throws -> Int {
    var latency: UInt64 = 0
    return try runLoop(
        stream: stream,
        commandQueue: commandQueue,
        fpsTarget: fpsTarget,
        renderMode: renderMode,
        durationSeconds: durationSeconds,
        frameLimit: frameLimit,
        totalLatencyNanoseconds: &latency
    )
}

func encodeClear(into texture: any MTLTexture, commandQueue: any MTLCommandQueue, sequence: UInt64) throws {
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createBenchmarkCommandBuffer", reason: "Metal returned nil command buffer")
        )
    }
    let descriptor = MTLRenderPassDescriptor()
    guard let colorAttachment = descriptor.colorAttachments[0] else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createBenchmarkColorAttachment", reason: "Metal returned nil color attachment")
        )
    }
    let phase = Double(sequence % 255) / 255.0
    colorAttachment.texture = texture
    colorAttachment.loadAction = .clear
    colorAttachment.storeAction = .store
    colorAttachment.clearColor = MTLClearColor(red: phase, green: 1.0 - phase, blue: 0.25, alpha: 1.0)

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createBenchmarkRenderEncoder", reason: "Metal returned nil render encoder")
        )
    }
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
}

struct FramePacer {
    private let intervalNanoseconds: UInt64?
    private var nextDeadline: UInt64

    init(fpsTarget: Int) {
        if fpsTarget > 0 {
            self.intervalNanoseconds = UInt64(1_000_000_000 / fpsTarget)
            self.nextDeadline = DispatchTime.now().uptimeNanoseconds
        } else {
            self.intervalNanoseconds = nil
            self.nextDeadline = 0
        }
    }

    mutating func waitIfNeeded() {
        guard let intervalNanoseconds else {
            return
        }
        nextDeadline += intervalNanoseconds
        let now = DispatchTime.now().uptimeNanoseconds
        guard nextDeadline > now else {
            nextDeadline = now
            return
        }
        let delay = Double(nextDeadline - now) / 1_000_000_000
        Thread.sleep(forTimeInterval: delay)
    }
}

struct ResourceUsage {
    let userSeconds: Double
    let systemSeconds: Double
    let maxRSSBytes: Int64
}

func currentResourceUsage() -> ResourceUsage {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return ResourceUsage(
        userSeconds: seconds(usage.ru_utime),
        systemSeconds: seconds(usage.ru_stime),
        maxRSSBytes: Int64(usage.ru_maxrss)
    )
}

func seconds(_ value: timeval) -> Double {
    Double(value.tv_sec) + Double(value.tv_usec) / 1_000_000
}
