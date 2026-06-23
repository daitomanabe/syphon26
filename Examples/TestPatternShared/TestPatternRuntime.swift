import AppKit
import Foundation
import Metal
import MetalKit
import Syphon26

public struct Syphon26TestPatternOptions: Sendable {
    public let serviceName: String
    public let width: Int
    public let height: Int
    public let fps: Int
    public let durationSeconds: Double
    public let holdSeconds: Double
    public let waitTimeoutSeconds: Double
    public let orientationMode: Syphon26TestPatternOrientation
    public let smoke: Bool
    public let helpJSON: Bool
    public let summaryURL: URL?
    public let readyURL: URL?

    public init(arguments: [String]) {
        self.serviceName = Self.value(after: "--service-name", in: arguments) ?? "com.syphon26.test-pattern"
        self.width = Self.value(after: "--width", in: arguments).flatMap(Int.init) ?? 1280
        self.height = Self.value(after: "--height", in: arguments).flatMap(Int.init) ?? 720
        self.fps = Self.value(after: "--fps", in: arguments).flatMap(Int.init) ?? 60
        self.durationSeconds = Self.value(after: "--duration", in: arguments).flatMap(Double.init) ?? 0
        self.holdSeconds = Self.value(after: "--hold-seconds", in: arguments).flatMap(Double.init) ?? 0
        self.waitTimeoutSeconds = Self.value(after: "--wait-timeout", in: arguments).flatMap(Double.init) ?? 10
        self.orientationMode = Syphon26TestPatternOrientation(rawValue: Self.value(after: "--orientation", in: arguments) ?? "normal") ?? .normal
        self.smoke = arguments.contains("--smoke")
        self.helpJSON = arguments.contains("--help-json")
        self.summaryURL = Self.value(after: "--summary", in: arguments).map { URL(fileURLWithPath: $0) }
        self.readyURL = Self.value(after: "--ready-file", in: arguments).map { URL(fileURLWithPath: $0) }
    }

    public static func helpPayload(role: String) -> [String: Any] {
        [
            "role": role,
            "flags": [
                "--service-name",
                "--width",
                "--height",
                "--fps",
                "--duration",
                "--orientation normal|flipY|rotate180",
                "--smoke",
                "--summary",
                "--ready-file",
                "--hold-seconds",
                "--wait-timeout"
            ],
            "pattern": [
                "colorBars": true,
                "topBottomMarkers": true,
                "cornerMarkers": true,
                "movingFrameTick": true
            ]
        ]
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

public enum Syphon26TestPatternOrientation: String, Sendable {
    case normal
    case flipY
    case rotate180

    var shaderValue: UInt32 {
        switch self {
        case .normal:
            0
        case .flipY:
            1
        case .rotate180:
            2
        }
    }
}

public struct Syphon26TestPatternSummary: Codable, Equatable, Sendable {
    public let role: String
    public let transportScope: String
    public let serviceName: String
    public let streamID: String
    public let width: Int
    public let height: Int
    public let fpsTarget: Int
    public let orientationMode: String
    public let colorBars: Bool
    public let topBottomMarkers: Bool
    public let movingFrameTick: Bool
    public let textureOpened: Bool
    public let framesPublished: UInt64
    public let framesObserved: UInt64
    public let firstFrameID: UInt64?
    public let lastFrameID: UInt64?
    public let measuredFPS: Double
    public let windowCanBecomeKey: Bool
    public let windowCanBecomeMain: Bool
    public let windowIsKey: Bool
    public let windowIsMain: Bool
}

public func encodeJSONLine(_ payload: [String: Any]) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    return String(decoding: data, as: UTF8.self)
}

public func encodeJSONLine<T: Encodable>(_ payload: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(payload)
    return String(decoding: data, as: UTF8.self)
}

public func writeSummary(_ summary: Syphon26TestPatternSummary, to url: URL?) throws {
    guard let url else {
        return
    }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(encodeJSONLine(summary).utf8).write(to: url, options: .atomic)
}

public func touchReadyFile(_ url: URL?) throws {
    guard let url else {
        return
    }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data().write(to: url, options: .atomic)
}

public final class Syphon26TestPatternPublisher {
    public let resource: Syphon26IOSurfaceResource
    public let streamDescription: Syphon26StreamDescription
    public let controlPlane: Syphon26ProductionXPCControlPlane
    public private(set) var frameID: UInt64 = 0

    private let commandQueue: any MTLCommandQueue
    private let pipeline: any MTLComputePipelineState
    private let orientationMode: Syphon26TestPatternOrientation
    private let startNanoseconds: UInt64

    public init(options: Syphon26TestPatternOptions) throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "createTestPatternDevice", reason: "Metal device or command queue is unavailable")
            )
        }

        let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        guard let function = library.makeFunction(name: "syphon26_test_pattern") else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "createTestPatternFunction", reason: "Metal shader function is unavailable")
            )
        }
        self.pipeline = try device.makeComputePipelineState(function: function)
        self.commandQueue = commandQueue
        self.orientationMode = options.orientationMode
        self.startNanoseconds = DispatchTime.now().uptimeNanoseconds

        let descriptor = try Syphon26IOSurfaceResourceDescriptor(
            width: options.width,
            height: options.height,
            pixelFormat: .bgra8Unorm
        )
        self.resource = try Syphon26IOSurfaceResource(descriptor: descriptor, device: device)
        self.streamDescription = try Syphon26StreamDescription(
            streamID: Syphon26StreamID.unchecked("test-pattern-\(options.serviceName)"),
            name: "Syphon26 Test Pattern",
            appName: "Syphon26TestPatternServerApp",
            width: options.width,
            height: options.height,
            pixelFormat: .bgra8Unorm,
            controlPlaneServiceName: options.serviceName
        )
        self.controlPlane = try Syphon26ProductionXPCControlPlane(serviceName: options.serviceName)
    }

    public func resetService() throws {
        try controlPlane.reset()
    }

    public func publishNextFrame() throws -> UInt64 {
        frameID += 1
        try encodePattern(frameID: frameID)
        try controlPlane.publish(
            resource: resource,
            streamDescription: streamDescription,
            frameID: frameID,
            publishedFrames: frameID
        )
        return frameID
    }

    private func encodePattern(frameID: UInt64) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "encodeTestPattern", reason: "Metal returned nil command buffer or encoder")
            )
        }

        var uniforms = Syphon26TestPatternUniforms(
            frameID: UInt32(truncatingIfNeeded: frameID),
            width: UInt32(resource.texture.width),
            height: UInt32(resource.texture.height),
            orientationMode: orientationMode.shaderValue,
            elapsedSeconds: Float(Double(DispatchTime.now().uptimeNanoseconds - startNanoseconds) / 1_000_000_000)
        )
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(resource.texture, index: 0)
        encoder.setBytes(&uniforms, length: MemoryLayout<Syphon26TestPatternUniforms>.stride, index: 0)
        let width = pipeline.threadExecutionWidth
        let height = max(1, pipeline.maxTotalThreadsPerThreadgroup / width)
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
        let threadsPerGrid = MTLSize(width: resource.texture.width, height: resource.texture.height, depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}

private struct Syphon26TestPatternUniforms {
    var frameID: UInt32
    var width: UInt32
    var height: UInt32
    var orientationMode: UInt32
    var elapsedSeconds: Float
}

extension Syphon26TestPatternPublisher {
    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct Uniforms {
        uint frameID;
        uint width;
        uint height;
        uint orientationMode;
        float elapsedSeconds;
    };

    static bool inRect(uint2 p, uint x, uint y, uint w, uint h) {
        return p.x >= x && p.x < x + w && p.y >= y && p.y < y + h;
    }

    static bool inTopWord(uint2 p, uint scale) {
        uint x = p.x / scale;
        uint y = p.y / scale;
        if (y >= 7) { return false; }
        if (x < 5) {
            uint rows[7] = {31, 4, 4, 4, 4, 4, 4};
            return ((rows[y] >> (4 - x)) & 1) != 0;
        }
        if (x >= 6 && x < 11) {
            uint cx = x - 6;
            uint rows[7] = {14, 17, 17, 17, 17, 17, 14};
            return ((rows[y] >> (4 - cx)) & 1) != 0;
        }
        if (x >= 12 && x < 17) {
            uint cx = x - 12;
            uint rows[7] = {30, 17, 17, 30, 16, 16, 16};
            return ((rows[y] >> (4 - cx)) & 1) != 0;
        }
        return false;
    }

    static bool inBottomWord(uint2 p, uint scale) {
        uint x = p.x / scale;
        uint y = p.y / scale;
        if (y >= 7) { return false; }
        uint rowsB[7] = {30, 17, 17, 30, 17, 17, 30};
        uint rowsO[7] = {14, 17, 17, 17, 17, 17, 14};
        uint rowsT[7] = {31, 4, 4, 4, 4, 4, 4};
        uint rowsM[7] = {17, 27, 21, 21, 17, 17, 17};
        uint charIndex = x / 6;
        uint cx = x - charIndex * 6;
        if (cx >= 5 || charIndex >= 6) { return false; }
        uint row = 0;
        if (charIndex == 0) { row = rowsB[y]; }
        else if (charIndex == 1) { row = rowsO[y]; }
        else if (charIndex == 2 || charIndex == 3) { row = rowsT[y]; }
        else if (charIndex == 4) { row = rowsO[y]; }
        else { row = rowsM[y]; }
        return ((row >> (4 - cx)) & 1) != 0;
    }

    kernel void syphon26_test_pattern(
        texture2d<float, access::write> outTexture [[texture(0)]],
        constant Uniforms& uniforms [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= uniforms.width || gid.y >= uniforms.height) { return; }

        uint2 p = gid;
        if (uniforms.orientationMode == 1) {
            p.y = uniforms.height - 1 - p.y;
        } else if (uniforms.orientationMode == 2) {
            p.x = uniforms.width - 1 - p.x;
            p.y = uniforms.height - 1 - p.y;
        }

        float2 uv = float2(p) / float2(max(uniforms.width - 1, 1u), max(uniforms.height - 1, 1u));
        float4 color = float4(0.04, 0.04, 0.04, 1.0);

        uint topBand = max(48u, uniforms.height / 9u);
        uint bottomBand = max(48u, uniforms.height / 9u);
        if (p.y < topBand) {
            color = float4(0.0, 0.78, 0.22, 1.0);
        } else if (p.y >= uniforms.height - bottomBand) {
            color = float4(0.78, 0.0, 0.72, 1.0);
        } else {
            uint bar = min(7u, (p.x * 8u) / max(uniforms.width, 1u));
            float4 bars[8] = {
                float4(1.0, 1.0, 1.0, 1.0),
                float4(1.0, 1.0, 0.0, 1.0),
                float4(0.0, 1.0, 1.0, 1.0),
                float4(0.0, 1.0, 0.0, 1.0),
                float4(1.0, 0.0, 1.0, 1.0),
                float4(1.0, 0.0, 0.0, 1.0),
                float4(0.0, 0.0, 1.0, 1.0),
                float4(0.0, 0.0, 0.0, 1.0)
            };
            color = bars[bar];
            float luma = 0.55 + 0.45 * fmod(floor(uv.y * 18.0) + floor(uv.x * 18.0), 2.0);
            color.rgb *= luma;
        }

        uint border = max(4u, uniforms.width / 260u);
        if (p.x < border || p.y < border || p.x >= uniforms.width - border || p.y >= uniforms.height - border) {
            bool white = (((p.x + p.y) / max(border, 1u)) % 2u) == 0u;
            color = white ? float4(1.0, 1.0, 1.0, 1.0) : float4(0.0, 0.0, 0.0, 1.0);
        }

        uint corner = max(34u, min(uniforms.width, uniforms.height) / 12u);
        if (inRect(p, border * 2u, border * 2u, corner, corner)) {
            color = float4(1.0, 0.0, 0.0, 1.0);
        } else if (inRect(p, uniforms.width - corner - border * 2u, border * 2u, corner, corner)) {
            color = float4(0.0, 0.2, 1.0, 1.0);
        } else if (inRect(p, border * 2u, uniforms.height - corner - border * 2u, corner, corner)) {
            color = float4(1.0, 1.0, 0.0, 1.0);
        } else if (inRect(p, uniforms.width - corner - border * 2u, uniforms.height - corner - border * 2u, corner, corner)) {
            color = float4(0.0, 1.0, 1.0, 1.0);
        }

        uint scale = max(3u, min(uniforms.width, uniforms.height) / 220u);
        uint2 topTextOrigin = uint2(max(16u, uniforms.width / 40u), max(10u, topBand / 4u));
        if (p.x >= topTextOrigin.x && p.y >= topTextOrigin.y) {
            if (inTopWord(p - topTextOrigin, scale)) {
                color = float4(0.0, 0.0, 0.0, 1.0);
            }
        }
        uint2 bottomTextOrigin = uint2(max(16u, uniforms.width / 40u), uniforms.height - bottomBand + max(10u, bottomBand / 4u));
        if (p.x >= bottomTextOrigin.x && p.y >= bottomTextOrigin.y) {
            if (inBottomWord(p - bottomTextOrigin, scale)) {
                color = float4(1.0, 1.0, 1.0, 1.0);
            }
        }

        uint tickWidth = max(6u, uniforms.width / 150u);
        uint tickX = (uniforms.frameID * max(7u, uniforms.width / 180u)) % max(uniforms.width, 1u);
        if (p.x >= tickX && p.x < min(uniforms.width, tickX + tickWidth)) {
            color = float4(1.0, 1.0, 1.0, 1.0);
        }

        uint centerLine = max(2u, uniforms.height / 360u);
        if (abs(int(p.x) - int(uniforms.width / 2u)) <= int(centerLine) ||
            abs(int(p.y) - int(uniforms.height / 2u)) <= int(centerLine)) {
            color = mix(color, float4(1.0, 1.0, 1.0, 1.0), 0.55);
        }

        outTexture.write(color, gid);
    }
    """
}
