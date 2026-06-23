import Darwin
import Foundation
import Metal
import Syphon26

enum BenchmarkRole: String {
    case health
    case reset
    case server
    case client
}

enum BenchmarkRenderMode: String {
    case clear
    case none
}

struct Options {
    let role: BenchmarkRole
    let name: String
    let serviceName: String
    let width: Int
    let height: Int
    let fpsTarget: Int
    let warmupSeconds: Double
    let durationSeconds: Double
    let pixelFormat: Syphon26PixelFormat
    let renderMode: BenchmarkRenderMode
    let serverReadyURL: URL?
    let clientReadyURL: URL?
    let waitTimeoutSeconds: Double
    let pollMicroseconds: Int
    let slowConsumerMilliseconds: Double
    let summaryURL: URL

    init(arguments: [String]) throws {
        let roleValue = Self.value(after: "--role", in: arguments) ?? "server"
        guard let role = BenchmarkRole(rawValue: roleValue) else {
            throw CLIError.invalidArgument("--role \(roleValue)")
        }
        self.role = role
        self.name = Self.value(after: "--name", in: arguments) ?? "Syphon26 Production XPC Benchmark"
        self.serviceName = Self.value(after: "--service-name", in: arguments) ?? Syphon26.defaultControlPlaneServiceName
        self.width = Self.value(after: "--width", in: arguments).flatMap(Int.init) ?? 1920
        self.height = Self.value(after: "--height", in: arguments).flatMap(Int.init) ?? 1080
        self.fpsTarget = Self.value(after: "--fps-target", in: arguments).flatMap(Int.init) ?? 60
        self.warmupSeconds = Self.value(after: "--warmup", in: arguments).flatMap(Double.init) ?? 0.25
        self.durationSeconds = Self.value(after: "--duration", in: arguments).flatMap(Double.init) ?? 1.0
        self.pixelFormat = try Self.parsePixelFormat(Self.value(after: "--pixel-format", in: arguments) ?? "bgra8")
        self.renderMode = BenchmarkRenderMode(rawValue: Self.value(after: "--render", in: arguments) ?? "clear") ?? .clear
        self.serverReadyURL = Self.value(after: "--server-ready", in: arguments).map { URL(fileURLWithPath: $0) }
        self.clientReadyURL = Self.value(after: "--client-ready", in: arguments).map { URL(fileURLWithPath: $0) }
        self.waitTimeoutSeconds = Self.value(after: "--wait-timeout", in: arguments).flatMap(Double.init) ?? 10.0
        self.pollMicroseconds = Self.value(after: "--poll-us", in: arguments).flatMap(Int.init) ?? 1_000
        self.slowConsumerMilliseconds = Self.value(after: "--slow-consumer-ms", in: arguments).flatMap(Double.init) ?? 0
        self.summaryURL = URL(fileURLWithPath: Self.requiredValue(after: "--summary", in: arguments))
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func requiredValue(after flag: String, in arguments: [String]) -> String {
        guard let value = value(after: flag, in: arguments) else {
            fputs("Missing required argument \(flag)\n", stderr)
            Foundation.exit(2)
        }
        return value
    }

    private static func parsePixelFormat(_ value: String) throws -> Syphon26PixelFormat {
        switch value.lowercased() {
        case "bgra8", "bgra8unorm":
            .bgra8Unorm
        case "rgba16f", "rgba16float":
            .rgba16Float
        default:
            throw CLIError.invalidArgument("--pixel-format \(value)")
        }
    }
}

enum CLIError: Error, CustomStringConvertible {
    case invalidArgument(String)

    var description: String {
        switch self {
        case .invalidArgument(let value):
            "Invalid argument \(value)"
        }
    }
}

struct HealthSummary: Codable {
    let schemaVersion: Int
    let role: String
    let transport: String
    let transportScope: String
    let processScope: String
    let serviceName: String
    let healthy: Bool
    let registeredStreamCount: Int
    let registeredConsumerCount: Int
}

struct ResetSummary: Codable {
    let schemaVersion: Int
    let role: String
    let transport: String
    let transportScope: String
    let processScope: String
    let serviceName: String
    let ok: Bool
}

struct ServerSummary: Codable {
    let schemaVersion: Int
    let role: String
    let transport: String
    let transportScope: String
    let processScope: String
    let controlPlane: String
    let handleTransport: String
    let serviceName: String
    let serverName: String
    let width: Int
    let height: Int
    let pixelFormat: String
    let targetFPS: Int
    let warmupSeconds: Double
    let durationSeconds: Double
    let waitTimeoutSeconds: Double
    let waitSeconds: Double
    let clientsReady: Bool
    let warmupFrames: Int
    let measuredFrames: Int
    let totalPublishedFrames: UInt64
    let measuredElapsedSeconds: Double
    let measuredSubmittedFPS: Double
    let cpuUserSeconds: Double
    let cpuSystemSeconds: Double
    let memoryMaxRSSBytes: Int64
}

struct ClientSummary: Codable {
    let schemaVersion: Int
    let role: String
    let transport: String
    let transportScope: String
    let processScope: String
    let controlPlane: String
    let handleTransport: String
    let serviceName: String
    let serverName: String
    let width: Int
    let height: Int
    let pixelFormat: String
    let targetFPS: Int
    let warmupSeconds: Double
    let durationSeconds: Double
    let findSeconds: Double
    let textureOpened: Bool
    let warmupObservedFrames: Int
    let measuredObservedFrames: Int
    let measuredObservedFPS: Double
    let missedFrames: UInt64
    let repeatedReads: UInt64
    let firstMeasuredFrameID: UInt64?
    let lastMeasuredFrameID: UInt64?
    let measuredElapsedSeconds: Double
    let slowConsumerMillis: Double
    let pollMicros: Int
    let cpuUserSeconds: Double
    let cpuSystemSeconds: Double
    let memoryMaxRSSBytes: Int64
}

struct ResourceUsage {
    let userSeconds: Double
    let systemSeconds: Double
    let maxRSSBytes: Int64
}

struct ClientPhaseResult {
    let observedFrames: Int
    let missedFrames: UInt64
    let repeatedReads: UInt64
    let firstFrameID: UInt64?
    let lastFrameID: UInt64?
    let elapsedSeconds: Double
}

let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
switch options.role {
case .health:
    try runHealth(options: options)
case .reset:
    try runReset(options: options)
case .server:
    try runServer(options: options)
case .client:
    try runClient(options: options)
}

func runHealth(options: Options) throws {
    let controlPlane = try Syphon26ProductionXPCControlPlane(serviceName: options.serviceName)
    let health = try controlPlane.health()
    let summary = HealthSummary(
        schemaVersion: 1,
        role: "health",
        transport: "syphon26-production-xpc",
        transportScope: "app-to-app-syphon26-production-xpc",
        processScope: "app-to-app",
        serviceName: options.serviceName,
        healthy: health.state == .connected(options.serviceName),
        registeredStreamCount: health.registeredStreamCount,
        registeredConsumerCount: health.registeredConsumerCount
    )
    try writeJSON(summary, to: options.summaryURL)
}

func runReset(options: Options) throws {
    let controlPlane = try Syphon26ProductionXPCControlPlane(serviceName: options.serviceName)
    try controlPlane.reset()
    let summary = ResetSummary(
        schemaVersion: 1,
        role: "reset",
        transport: "syphon26-production-xpc",
        transportScope: "app-to-app-syphon26-production-xpc",
        processScope: "app-to-app",
        serviceName: options.serviceName,
        ok: true
    )
    try writeJSON(summary, to: options.summaryURL)
}

func runServer(options: Options) throws {
    guard let device = MTLCreateSystemDefaultDevice(),
          let commandQueue = device.makeCommandQueue() else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createProductionXPCServerDevice", reason: "Metal device or command queue is unavailable")
        )
    }

    let descriptor = try Syphon26IOSurfaceResourceDescriptor(
        width: options.width,
        height: options.height,
        pixelFormat: options.pixelFormat
    )
    let resource = try Syphon26IOSurfaceResource(descriptor: descriptor, device: device)
    let streamDescription = try Syphon26StreamDescription(
        streamID: Syphon26StreamID.unchecked("production-xpc-\(options.name)"),
        name: options.name,
        appName: "Syphon26ProductionXPCBenchmarkServer",
        width: options.width,
        height: options.height,
        pixelFormat: options.pixelFormat,
        controlPlaneServiceName: options.serviceName
    )
    let controlPlane = try Syphon26ProductionXPCControlPlane(serviceName: options.serviceName)

    var frameID: UInt64 = 0
    try publishFrame(
        resource: resource,
        streamDescription: streamDescription,
        controlPlane: controlPlane,
        commandQueue: commandQueue,
        renderMode: options.renderMode,
        frameID: frameID
    )
    try touch(options.serverReadyURL)

    let waitStart = nowSeconds()
    let clientsReady = waitForFile(options.clientReadyURL, timeoutSeconds: options.waitTimeoutSeconds)
    let waitSeconds = nowSeconds() - waitStart

    let warmupFrames = try runServerPhase(
        resource: resource,
        streamDescription: streamDescription,
        controlPlane: controlPlane,
        commandQueue: commandQueue,
        renderMode: options.renderMode,
        fpsTarget: options.fpsTarget,
        durationSeconds: options.warmupSeconds,
        frameID: &frameID
    ).frames

    let startUsage = currentResourceUsage()
    let measured = try runServerPhase(
        resource: resource,
        streamDescription: streamDescription,
        controlPlane: controlPlane,
        commandQueue: commandQueue,
        renderMode: options.renderMode,
        fpsTarget: options.fpsTarget,
        durationSeconds: options.durationSeconds,
        frameID: &frameID
    )
    let endUsage = currentResourceUsage()
    let measuredFPS = Double(measured.frames) / max(measured.elapsedSeconds, 0.000_001)

    let summary = ServerSummary(
        schemaVersion: 1,
        role: "server",
        transport: "syphon26-production-xpc",
        transportScope: "app-to-app-syphon26-production-xpc",
        processScope: "app-to-app",
        controlPlane: "launchd-mach-xpc",
        handleTransport: "iosurface-xpc-object",
        serviceName: options.serviceName,
        serverName: options.name,
        width: options.width,
        height: options.height,
        pixelFormat: options.pixelFormat.rawName,
        targetFPS: options.fpsTarget,
        warmupSeconds: options.warmupSeconds,
        durationSeconds: options.durationSeconds,
        waitTimeoutSeconds: options.waitTimeoutSeconds,
        waitSeconds: waitSeconds,
        clientsReady: clientsReady,
        warmupFrames: warmupFrames,
        measuredFrames: measured.frames,
        totalPublishedFrames: frameID,
        measuredElapsedSeconds: measured.elapsedSeconds,
        measuredSubmittedFPS: measuredFPS,
        cpuUserSeconds: endUsage.userSeconds - startUsage.userSeconds,
        cpuSystemSeconds: endUsage.systemSeconds - startUsage.systemSeconds,
        memoryMaxRSSBytes: endUsage.maxRSSBytes
    )
    try writeJSON(summary, to: options.summaryURL)
}

func runClient(options: Options) throws {
    guard let device = MTLCreateSystemDefaultDevice() else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createProductionXPCClientDevice", reason: "Metal device is unavailable")
        )
    }

    let controlPlane = try Syphon26ProductionXPCControlPlane(serviceName: options.serviceName)
    let findStart = nowSeconds()
    let initialMetadata = try controlPlane.waitForMetadata(timeoutSeconds: options.waitTimeoutSeconds)
    let frame = try controlPlane.openLatestFrame(device: device)
    let findSeconds = nowSeconds() - findStart
    try touch(options.clientReadyURL)

    var cursor = initialMetadata.frameID
    let warmup = runClientPhase(
        controlPlane: controlPlane,
        texture: frame.texture,
        cursor: &cursor,
        durationSeconds: options.warmupSeconds,
        pollMicroseconds: options.pollMicroseconds,
        slowConsumerMilliseconds: options.slowConsumerMilliseconds
    )

    let startUsage = currentResourceUsage()
    let measured = runClientPhase(
        controlPlane: controlPlane,
        texture: frame.texture,
        cursor: &cursor,
        durationSeconds: options.durationSeconds,
        pollMicroseconds: options.pollMicroseconds,
        slowConsumerMilliseconds: options.slowConsumerMilliseconds
    )
    let endUsage = currentResourceUsage()
    let stream = frame.metadata.streamDescription
    let measuredFPS = Double(measured.observedFrames) / max(measured.elapsedSeconds, 0.000_001)

    let summary = ClientSummary(
        schemaVersion: 1,
        role: "client",
        transport: "syphon26-production-xpc",
        transportScope: "app-to-app-syphon26-production-xpc",
        processScope: "app-to-app",
        controlPlane: "launchd-mach-xpc",
        handleTransport: "iosurface-xpc-object",
        serviceName: options.serviceName,
        serverName: stream.name,
        width: frame.texture.width,
        height: frame.texture.height,
        pixelFormat: stream.pixelFormat.rawName,
        targetFPS: options.fpsTarget,
        warmupSeconds: options.warmupSeconds,
        durationSeconds: options.durationSeconds,
        findSeconds: findSeconds,
        textureOpened: frame.texture.width == stream.width && frame.texture.height == stream.height,
        warmupObservedFrames: warmup.observedFrames,
        measuredObservedFrames: measured.observedFrames,
        measuredObservedFPS: measuredFPS,
        missedFrames: measured.missedFrames,
        repeatedReads: measured.repeatedReads,
        firstMeasuredFrameID: measured.firstFrameID,
        lastMeasuredFrameID: measured.lastFrameID,
        measuredElapsedSeconds: measured.elapsedSeconds,
        slowConsumerMillis: options.slowConsumerMilliseconds,
        pollMicros: options.pollMicroseconds,
        cpuUserSeconds: endUsage.userSeconds - startUsage.userSeconds,
        cpuSystemSeconds: endUsage.systemSeconds - startUsage.systemSeconds,
        memoryMaxRSSBytes: endUsage.maxRSSBytes
    )
    try writeJSON(summary, to: options.summaryURL)
}

func runServerPhase(
    resource: Syphon26IOSurfaceResource,
    streamDescription: Syphon26StreamDescription,
    controlPlane: Syphon26ProductionXPCControlPlane,
    commandQueue: any MTLCommandQueue,
    renderMode: BenchmarkRenderMode,
    fpsTarget: Int,
    durationSeconds: Double,
    frameID: inout UInt64
) throws -> (frames: Int, elapsedSeconds: Double) {
    guard durationSeconds > 0 else {
        return (0, 0)
    }
    var frames = 0
    var pacer = FramePacer(fpsTarget: fpsTarget)
    let start = nowSeconds()
    while nowSeconds() - start < durationSeconds {
        frameID += 1
        try publishFrame(
            resource: resource,
            streamDescription: streamDescription,
            controlPlane: controlPlane,
            commandQueue: commandQueue,
            renderMode: renderMode,
            frameID: frameID
        )
        frames += 1
        pacer.waitIfNeeded()
    }
    return (frames, nowSeconds() - start)
}

func runClientPhase(
    controlPlane: Syphon26ProductionXPCControlPlane,
    texture: any MTLTexture,
    cursor: inout UInt64,
    durationSeconds: Double,
    pollMicroseconds: Int,
    slowConsumerMilliseconds: Double
) -> ClientPhaseResult {
    guard durationSeconds > 0 else {
        return ClientPhaseResult(observedFrames: 0, missedFrames: 0, repeatedReads: 0, firstFrameID: nil, lastFrameID: nil, elapsedSeconds: 0)
    }
    let start = nowSeconds()
    var observedFrames = 0
    var missedFrames: UInt64 = 0
    var repeatedReads: UInt64 = 0
    var firstFrameID: UInt64?
    var lastFrameID: UInt64?
    let idlePoll = useconds_t(max(pollMicroseconds, 100))
    let slowPoll = useconds_t(max(Int(slowConsumerMilliseconds * 1_000), 0))

    while nowSeconds() - start < durationSeconds {
        guard let metadata = try? controlPlane.latestMetadata() else {
            usleep(idlePoll)
            continue
        }

        if metadata.frameID != cursor {
            if metadata.frameID > cursor + 1 {
                missedFrames += metadata.frameID - cursor - 1
            }
            cursor = metadata.frameID
            observedFrames += 1
            firstFrameID = firstFrameID ?? metadata.frameID
            lastFrameID = metadata.frameID
            _ = texture.width
            if slowPoll > 0 {
                usleep(slowPoll)
            }
        } else {
            repeatedReads += 1
            usleep(idlePoll)
        }
    }

    return ClientPhaseResult(
        observedFrames: observedFrames,
        missedFrames: missedFrames,
        repeatedReads: repeatedReads,
        firstFrameID: firstFrameID,
        lastFrameID: lastFrameID,
        elapsedSeconds: nowSeconds() - start
    )
}

func publishFrame(
    resource: Syphon26IOSurfaceResource,
    streamDescription: Syphon26StreamDescription,
    controlPlane: Syphon26ProductionXPCControlPlane,
    commandQueue: any MTLCommandQueue,
    renderMode: BenchmarkRenderMode,
    frameID: UInt64
) throws {
    if renderMode == .clear {
        try encodeClear(into: resource.texture, commandQueue: commandQueue, sequence: frameID)
    }
    try controlPlane.publish(
        resource: resource,
        streamDescription: streamDescription,
        frameID: frameID,
        publishedFrames: frameID
    )
}

func encodeClear(into texture: any MTLTexture, commandQueue: any MTLCommandQueue, sequence: UInt64) throws {
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createProductionXPCCommandBuffer", reason: "Metal returned nil command buffer")
        )
    }
    let descriptor = MTLRenderPassDescriptor()
    guard let colorAttachment = descriptor.colorAttachments[0] else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createProductionXPCColorAttachment", reason: "Metal returned nil color attachment")
        )
    }
    let phase = Double(sequence % 255) / 255.0
    colorAttachment.texture = texture
    colorAttachment.loadAction = .clear
    colorAttachment.storeAction = .store
    colorAttachment.clearColor = MTLClearColor(red: phase, green: 1.0 - phase, blue: 0.25, alpha: 1.0)

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
        throw Syphon26Error.metal(
            Syphon26RuntimeIssue(operation: "createProductionXPCRenderEncoder", reason: "Metal returned nil render encoder")
        )
    }
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
}

struct FramePacer {
    private let intervalSeconds: Double?
    private var nextDeadline: Double

    init(fpsTarget: Int) {
        if fpsTarget > 0 {
            self.intervalSeconds = 1.0 / Double(fpsTarget)
            self.nextDeadline = nowSeconds()
        } else {
            self.intervalSeconds = nil
            self.nextDeadline = 0
        }
    }

    mutating func waitIfNeeded() {
        guard let intervalSeconds else {
            return
        }
        nextDeadline += intervalSeconds
        let delay = nextDeadline - nowSeconds()
        if delay > 0 {
            usleep(useconds_t(delay * 1_000_000))
        } else {
            nextDeadline = nowSeconds()
        }
    }
}

func waitForFile(_ url: URL?, timeoutSeconds: Double) -> Bool {
    guard let url else {
        return true
    }
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
        if FileManager.default.fileExists(atPath: url.path) {
            return true
        }
        Thread.sleep(forTimeInterval: 0.01)
    }
    return false
}

func touch(_ url: URL?) throws {
    guard let url else {
        return
    }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data().write(to: url)
}

func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    try data.write(to: url, options: .atomic)
}

func nowSeconds() -> Double {
    Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
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
