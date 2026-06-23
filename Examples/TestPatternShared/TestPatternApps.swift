import AppKit
import Foundation
import Metal
import MetalKit
import Syphon26

@MainActor
public final class Syphon26TestPatternWindow: NSWindow {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

@MainActor
public final class Syphon26TestPatternServerDelegate: NSObject, NSApplicationDelegate {
    private let options: Syphon26TestPatternOptions
    private var controller: Syphon26TestPatternServerController?
    private var window: Syphon26TestPatternWindow?

    public init(options: Syphon26TestPatternOptions) {
        self.options = options
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let controller = try Syphon26TestPatternServerController(options: options)
            let window = makeWindow(title: "Syphon26 Test Pattern Server", previewView: controller.previewView, telemetryView: controller.telemetryView)
            self.controller = controller
            self.window = window
            controller.start()
            window.orderBack(nil)
        } catch {
            fputs("Syphon26 test-pattern server failed: \(error)\n", stderr)
            NSApplication.shared.terminate(nil)
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@MainActor
public final class Syphon26TestPatternClientDelegate: NSObject, NSApplicationDelegate {
    private let options: Syphon26TestPatternOptions
    private var controller: Syphon26TestPatternClientController?
    private var window: Syphon26TestPatternWindow?

    public init(options: Syphon26TestPatternOptions) {
        self.options = options
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let controller = try Syphon26TestPatternClientController(options: options)
            let window = makeWindow(title: "Syphon26 Test Pattern Client", previewView: controller.previewView, telemetryView: controller.telemetryView)
            self.controller = controller
            self.window = window
            controller.start()
            window.orderBack(nil)
        } catch {
            fputs("Syphon26 test-pattern client failed: \(error)\n", stderr)
            NSApplication.shared.terminate(nil)
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@MainActor
private func makeWindow(title: String, previewView: Syphon26TexturePreviewView, telemetryView: NSTextField) -> Syphon26TestPatternWindow {
    let content = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 540))
    previewView.translatesAutoresizingMaskIntoConstraints = false
    telemetryView.translatesAutoresizingMaskIntoConstraints = false
    content.addSubview(previewView)
    content.addSubview(telemetryView)
    NSLayoutConstraint.activate([
        previewView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
        previewView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        previewView.topAnchor.constraint(equalTo: content.topAnchor),
        previewView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        telemetryView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
        telemetryView.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),
        telemetryView.topAnchor.constraint(equalTo: content.topAnchor, constant: 10)
    ])

    let window = Syphon26TestPatternWindow(
        contentRect: NSRect(x: 80, y: 80, width: 960, height: 540),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.title = title
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.contentView = content
    return window
}

@MainActor
public final class Syphon26TestPatternServerController {
    public let previewView: Syphon26TexturePreviewView
    public let telemetryView: NSTextField

    private let publisher: Syphon26TestPatternPublisher
    private let options: Syphon26TestPatternOptions
    private let timerQueue = DispatchQueue(label: "com.syphon26.test-pattern.server")
    private var timer: (any DispatchSourceTimer)?
    private let startTime = Date()

    public init(options: Syphon26TestPatternOptions) throws {
        self.options = options
        self.publisher = try Syphon26TestPatternPublisher(options: options)
        self.previewView = try Syphon26TexturePreviewView.makeDefault()
        self.telemetryView = Syphon26TelemetryView.make()
        self.previewView.sourceTexture = publisher.resource.texture
    }

    public func start() {
        do {
            try publisher.resetService()
        } catch {
            telemetryView.stringValue = "service reset failed: \(error)"
        }

        let interval = max(1.0 / Double(max(options.fps, 1)), 1.0 / 240.0)
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }
            do {
                let frameID = try self.publisher.publishNextFrame()
                let elapsed = max(Date().timeIntervalSince(self.startTime), 0.001)
                let fps = Double(frameID) / elapsed
                DispatchQueue.main.async {
                    self.previewView.needsDisplay = true
                    self.telemetryView.stringValue = "server  \(self.options.width)x\(self.options.height)  target \(self.options.fps) fps  frame \(frameID)  avg \(String(format: "%.1f", fps)) fps  \(self.options.orientationMode.rawValue)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.telemetryView.stringValue = "publish failed: \(error)"
                }
            }
        }
        self.timer = timer
        timer.resume()
    }
}

@MainActor
public final class Syphon26TestPatternClientController {
    public let previewView: Syphon26TexturePreviewView
    public let telemetryView: NSTextField

    private let options: Syphon26TestPatternOptions
    private let controlPlane: Syphon26ProductionXPCControlPlane
    private let device: any MTLDevice
    private let timerQueue = DispatchQueue(label: "com.syphon26.test-pattern.client")
    private var timer: (any DispatchSourceTimer)?
    private var openedFrame: Syphon26ProductionXPCFrame?
    private var lastFrameID: UInt64?
    private var firstFrameID: UInt64?
    private var observedFrames: UInt64 = 0
    private let startTime = Date()

    public init(options: Syphon26TestPatternOptions) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "createTestPatternClientDevice", reason: "Metal device is unavailable")
            )
        }
        self.options = options
        self.device = device
        self.controlPlane = try Syphon26ProductionXPCControlPlane(serviceName: options.serviceName)
        self.previewView = try Syphon26TexturePreviewView(device: device)
        self.telemetryView = Syphon26TelemetryView.make()
    }

    public func start() {
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 60.0, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }
            self.poll()
        }
        self.timer = timer
        timer.resume()
    }

    private func poll() {
        do {
            if openedFrame == nil {
                openedFrame = try controlPlane.openLatestFrame(device: device)
                DispatchQueue.main.async {
                    self.previewView.sourceTexture = self.openedFrame?.texture
                }
            }
            let metadata = try controlPlane.latestMetadata()
            if metadata.frameID != lastFrameID {
                if firstFrameID == nil {
                    firstFrameID = metadata.frameID
                }
                lastFrameID = metadata.frameID
                observedFrames += 1
            }
            let elapsed = max(Date().timeIntervalSince(startTime), 0.001)
            let fps = Double(observedFrames) / elapsed
            DispatchQueue.main.async {
                self.previewView.needsDisplay = true
                self.telemetryView.stringValue = "client  \(metadata.streamDescription.width)x\(metadata.streamDescription.height)  observed \(String(format: "%.1f", fps)) fps  frame \(metadata.frameID)"
            }
        } catch {
            DispatchQueue.main.async {
                self.telemetryView.stringValue = "waiting for stream: \(error)"
            }
        }
    }
}

@MainActor
public final class Syphon26TexturePreviewView: MTKView, MTKViewDelegate {
    public var sourceTexture: (any MTLTexture)?

    private let commandQueue: any MTLCommandQueue
    private let pipeline: any MTLRenderPipelineState

    public static func makeDefault() throws -> Syphon26TexturePreviewView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "createTexturePreviewDevice", reason: "Metal device is unavailable")
            )
        }
        return try Syphon26TexturePreviewView(device: device)
    }

    public init(device: any MTLDevice) throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "createTexturePreviewCommandQueue", reason: "Metal returned nil command queue")
            )
        }
        let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "syphon26_preview_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "syphon26_preview_fragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.commandQueue = commandQueue
        self.pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        super.init(frame: .zero, device: device)
        self.colorPixelFormat = .bgra8Unorm
        self.framebufferOnly = false
        self.enableSetNeedsDisplay = false
        self.isPaused = false
        self.delegate = self
        self.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.025, alpha: 1.0)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard let descriptor = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        encoder.setRenderPipelineState(pipeline)
        if let sourceTexture {
            encoder.setFragmentTexture(sourceTexture, index: 0)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex VertexOut syphon26_preview_vertex(uint vertexID [[vertex_id]]) {
        float2 positions[3] = {
            float2(-1.0, -1.0),
            float2( 3.0, -1.0),
            float2(-1.0,  3.0)
        };
        float2 uvs[3] = {
            float2(0.0, 1.0),
            float2(2.0, 1.0),
            float2(0.0, -1.0)
        };
        VertexOut out;
        out.position = float4(positions[vertexID], 0.0, 1.0);
        out.uv = uvs[vertexID];
        return out;
    }

    fragment float4 syphon26_preview_fragment(VertexOut in [[stage_in]],
                                              texture2d<float> sourceTexture [[texture(0)]]) {
        constexpr sampler linearSampler(address::clamp_to_edge, filter::linear);
        if (is_null_texture(sourceTexture)) {
            return float4(0.02, 0.02, 0.025, 1.0);
        }
        return sourceTexture.sample(linearSampler, in.uv);
    }
    """
}

@MainActor
private enum Syphon26TelemetryView {
    static func make() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.backgroundColor = NSColor.black.withAlphaComponent(0.55)
        label.drawsBackground = true
        label.isBezeled = false
        label.lineBreakMode = .byTruncatingTail
        return label
    }
}
