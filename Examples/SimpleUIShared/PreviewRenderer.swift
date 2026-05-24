import AppKit
import Metal
import MetalKit

public enum Syphon26PreviewRendererError: Error {
    case missingFunction(String)
    case encoderUnavailable
}

private struct PatternUniforms {
    var frame: Float
    var formatMode: Float
    var width: Float
    var height: Float
}

public final class Syphon26PreviewRenderer {
    private let device: any MTLDevice
    private let library: any MTLLibrary
    private let sampler: any MTLSamplerState
    private var patternPipelines: [UInt: any MTLRenderPipelineState] = [:]
    private var texturePipelines: [UInt: any MTLRenderPipelineState] = [:]

    public init(device: any MTLDevice) throws {
        self.device = device
        self.library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else {
            throw Syphon26PreviewRendererError.encoderUnavailable
        }
        self.sampler = sampler
    }

    @MainActor
    public func configurePreviewView(_ view: MTKView) {
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.03, green: 0.03, blue: 0.035, alpha: 1.0)
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = false
        view.isPaused = true
        view.autoResizeDrawable = true
        view.wantsLayer = true
        view.layer?.cornerRadius = 6
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor.separatorColor.cgColor
    }

    @discardableResult
    public func renderPattern(
        into texture: any MTLTexture,
        commandBuffer: any MTLCommandBuffer,
        frameIndex: Int,
        sourcePixelFormat: MTLPixelFormat
    ) throws -> Bool {
        let descriptor = MTLRenderPassDescriptor()
        guard let colorAttachment = descriptor.colorAttachments[0] else {
            throw Syphon26PreviewRendererError.encoderUnavailable
        }
        colorAttachment.texture = texture
        colorAttachment.loadAction = .clear
        colorAttachment.storeAction = .store
        colorAttachment.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        try encodePattern(
            descriptor: descriptor,
            commandBuffer: commandBuffer,
            colorPixelFormat: texture.pixelFormat,
            frameIndex: frameIndex,
            sourcePixelFormat: sourcePixelFormat,
            width: texture.width,
            height: texture.height
        )
        return true
    }

    @discardableResult
    @MainActor
    public func renderPattern(
        to view: MTKView,
        commandBuffer: any MTLCommandBuffer,
        frameIndex: Int,
        sourcePixelFormat: MTLPixelFormat,
        width: Int,
        height: Int
    ) throws -> Bool {
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return false
        }
        try encodePattern(
            descriptor: descriptor,
            commandBuffer: commandBuffer,
            colorPixelFormat: view.colorPixelFormat,
            frameIndex: frameIndex,
            sourcePixelFormat: sourcePixelFormat,
            width: width,
            height: height
        )
        commandBuffer.present(drawable)
        return true
    }

    @discardableResult
    @MainActor
    public func renderTexture(
        _ texture: any MTLTexture,
        to view: MTKView,
        commandBuffer: any MTLCommandBuffer
    ) throws -> Bool {
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return false
        }
        let pipeline = try texturePipeline(colorPixelFormat: view.colorPixelFormat)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            throw Syphon26PreviewRendererError.encoderUnavailable
        }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        return true
    }

    @MainActor
    public func clear(_ view: MTKView, commandQueue: (any MTLCommandQueue)?) {
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func encodePattern(
        descriptor: MTLRenderPassDescriptor,
        commandBuffer: any MTLCommandBuffer,
        colorPixelFormat: MTLPixelFormat,
        frameIndex: Int,
        sourcePixelFormat: MTLPixelFormat,
        width: Int,
        height: Int
    ) throws {
        let pipeline = try patternPipeline(colorPixelFormat: colorPixelFormat)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            throw Syphon26PreviewRendererError.encoderUnavailable
        }
        var uniforms = PatternUniforms(
            frame: Float(frameIndex),
            formatMode: sourcePixelFormat == .rgba16Float ? 1.0 : 0.0,
            width: Float(width),
            height: Float(height)
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<PatternUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    private func patternPipeline(colorPixelFormat: MTLPixelFormat) throws -> any MTLRenderPipelineState {
        let key = UInt(colorPixelFormat.rawValue)
        if let pipeline = patternPipelines[key] {
            return pipeline
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = try function(named: "fullscreen_vertex")
        descriptor.fragmentFunction = try function(named: "pattern_fragment")
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        patternPipelines[key] = pipeline
        return pipeline
    }

    private func texturePipeline(colorPixelFormat: MTLPixelFormat) throws -> any MTLRenderPipelineState {
        let key = UInt(colorPixelFormat.rawValue)
        if let pipeline = texturePipelines[key] {
            return pipeline
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = try function(named: "fullscreen_vertex")
        descriptor.fragmentFunction = try function(named: "texture_fragment")
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        texturePipelines[key] = pipeline
        return pipeline
    }

    private func function(named name: String) throws -> any MTLFunction {
        guard let function = library.makeFunction(name: name) else {
            throw Syphon26PreviewRendererError.missingFunction(name)
        }
        return function
    }

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct PatternUniforms {
        float frame;
        float formatMode;
        float width;
        float height;
    };

    struct VertexOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex VertexOut fullscreen_vertex(uint vertexID [[vertex_id]]) {
        float2 positions[3] = {
            float2(-1.0, -1.0),
            float2( 3.0, -1.0),
            float2(-1.0,  3.0)
        };
        float2 p = positions[vertexID];
        VertexOut out;
        out.position = float4(p, 0.0, 1.0);
        out.uv = float2((p.x + 1.0) * 0.5, 1.0 - ((p.y + 1.0) * 0.5));
        return out;
    }

    static float rectMask(float2 uv, float2 low, float2 high) {
        return step(low.x, uv.x) * step(uv.x, high.x) * step(low.y, uv.y) * step(uv.y, high.y);
    }

    static float lineMask(float value, float target, float width) {
        return 1.0 - smoothstep(width * 0.45, width, abs(value - target));
    }

    fragment float4 pattern_fragment(VertexOut in [[stage_in]],
                                     constant PatternUniforms& u [[buffer(0)]]) {
        float2 uv = clamp(in.uv, 0.0, 1.0);
        float checker = fmod(floor(uv.x * 16.0) + floor(uv.y * 9.0), 2.0);
        float3 color = mix(float3(0.10, 0.10, 0.11), float3(0.18, 0.18, 0.20), checker);

        float3 bars[8] = {
            float3(1.0, 0.0, 0.0),
            float3(0.0, 1.0, 0.0),
            float3(0.0, 0.0, 1.0),
            float3(0.0, 1.0, 1.0),
            float3(1.0, 0.0, 1.0),
            float3(1.0, 1.0, 0.0),
            float3(1.0, 1.0, 1.0),
            float3(0.0, 0.0, 0.0)
        };
        int bar = clamp(int(floor(uv.x * 8.0)), 0, 7);
        float barArea = rectMask(uv, float2(0.08, 0.38), float2(0.92, 0.62));
        color = mix(color, bars[bar], barArea);

        float top = step(uv.y, 0.05);
        float bottom = step(0.95, uv.y);
        float left = step(uv.x, 0.05);
        float right = step(0.95, uv.x);
        color = mix(color, float3(1.0, 0.05, 0.03), top);
        color = mix(color, float3(0.05, 0.15, 1.0), bottom);
        color = mix(color, float3(0.10, 1.0, 0.20), left);
        color = mix(color, float3(1.0, 0.85, 0.00), right);

        color = mix(color, float3(1.0, 0.0, 0.0), rectMask(uv, float2(0.06, 0.06), float2(0.17, 0.17)));
        color = mix(color, float3(0.0, 1.0, 0.0), rectMask(uv, float2(0.83, 0.06), float2(0.94, 0.17)));
        color = mix(color, float3(0.0, 0.0, 1.0), rectMask(uv, float2(0.06, 0.83), float2(0.17, 0.94)));
        color = mix(color, float3(1.0, 1.0, 0.0), rectMask(uv, float2(0.83, 0.83), float2(0.94, 0.94)));

        float gridX = lineMask(fract(uv.x * 16.0), 0.0, 0.035);
        float gridY = lineMask(fract(uv.y * 9.0), 0.0, 0.035);
        float grid = max(gridX, gridY) * rectMask(uv, float2(0.05, 0.05), float2(0.95, 0.95));
        color = mix(color, float3(0.75, 0.75, 0.78), grid * 0.45);

        float center = max(lineMask(uv.x, 0.5, 0.008), lineMask(uv.y, 0.5, 0.008));
        color = mix(color, float3(1.0, 1.0, 1.0), center * 0.85);

        float markerX = fract(u.frame / 120.0);
        float marker = lineMask(uv.x, markerX, 0.015) * rectMask(uv, float2(0.05, 0.0), float2(0.95, 1.0));
        color = mix(color, float3(1.0, 0.45, 0.0), marker);

        float framePulse = 0.5 + 0.5 * sin(u.frame * 0.21);
        color = mix(color, float3(framePulse, 1.0 - framePulse, 1.0), rectMask(uv, float2(0.43, 0.68), float2(0.57, 0.82)));

        float diagonal = fract((uv.x + uv.y + u.frame * 0.01) * 8.0);
        float3 floatPattern = float3(uv.x * uv.x, sqrt(uv.y), diagonal);
        color = mix(color, floatPattern, 0.32 * step(0.5, u.formatMode));

        return float4(color, 1.0);
    }

    fragment float4 texture_fragment(VertexOut in [[stage_in]],
                                     texture2d<float, access::sample> source [[texture(0)]],
                                     sampler textureSampler [[sampler(0)]]) {
        return source.sample(textureSampler, clamp(in.uv, 0.0, 1.0));
    }
    """
}
