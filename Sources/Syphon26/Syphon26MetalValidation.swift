import Metal

public struct Syphon26MetalValidationPlan: Equatable, Sendable {
    public let pixelFormat: Syphon26PixelFormat
    public let width: Int
    public let height: Int
    public let fixture: Syphon26MetalFixture

    public init(
        pixelFormat: Syphon26PixelFormat,
        width: Int,
        height: Int,
        fixture: Syphon26MetalFixture? = nil
    ) throws {
        try Syphon26Validation.validatePixelFormat(pixelFormat)
        try Syphon26Validation.validateDimensions(width: width, height: height)
        self.pixelFormat = pixelFormat
        self.width = width
        self.height = height
        self.fixture = try fixture ?? Syphon26MetalFixture.defaultFixture(for: pixelFormat)
    }

    public var expectedChecksum: UInt32 {
        fixture.expectedChecksum(width: width, height: height)
    }
}

public struct Syphon26MetalValidationResult: Equatable, Sendable {
    public let pixelFormat: Syphon26PixelFormat
    public let metalPixelFormatRawValue: UInt
    public let width: Int
    public let height: Int
    public let fixture: Syphon26MetalFixture
    public let checksum: UInt32
    public let expectedChecksum: UInt32
    public let pixelCount: UInt32
    public let usedGPUChecksumPass: Bool

    public var matchesExpectedChecksum: Bool {
        checksum == expectedChecksum
    }
}

public final class Syphon26MetalValidator {
    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue
    private let writePipeline: any MTLComputePipelineState
    private let checksumPipeline: any MTLComputePipelineState

    public init(device: (any MTLDevice)? = MTLCreateSystemDefaultDevice()) throws {
        guard let device else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "createMetalValidator", reason: "no default Metal device")
            )
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "makeCommandQueue", reason: "Metal returned nil command queue")
            )
        }
        do {
            let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
            guard let writeFunction = library.makeFunction(name: "syphon26_write_fixture") else {
                throw Syphon26Error.metal(
                    Syphon26RuntimeIssue(operation: "makeFunction", reason: "missing syphon26_write_fixture")
                )
            }
            guard let checksumFunction = library.makeFunction(name: "syphon26_checksum_fixture") else {
                throw Syphon26Error.metal(
                    Syphon26RuntimeIssue(operation: "makeFunction", reason: "missing syphon26_checksum_fixture")
                )
            }
            self.device = device
            self.commandQueue = commandQueue
            self.writePipeline = try device.makeComputePipelineState(function: writeFunction)
            self.checksumPipeline = try device.makeComputePipelineState(function: checksumFunction)
        } catch let error as Syphon26Error {
            throw error
        } catch {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "compileMetalValidationShaders", reason: String(describing: error))
            )
        }
    }

    public func validate(_ plan: Syphon26MetalValidationPlan) throws -> Syphon26MetalValidationResult {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: try plan.pixelFormat.metalPixelFormat,
            width: plan.width,
            height: plan.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "makeTexture", reason: "Metal returned nil validation texture")
            )
        }
        guard let checksumBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared),
              let pixelCountBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared) else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "makeBuffer", reason: "Metal returned nil validation buffer")
            )
        }
        checksumBuffer.contents().storeBytes(of: UInt32(0), as: UInt32.self)
        pixelCountBuffer.contents().storeBytes(of: UInt32(0), as: UInt32.self)

        var uniforms = Syphon26MetalFixtureUniforms(
            width: UInt32(plan.width),
            height: UInt32(plan.height),
            fixture: plan.fixture.identifier,
            reserved: 0
        )

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "makeCommandBuffer", reason: "Metal returned nil command buffer")
            )
        }

        try encodeWritePass(texture: texture, uniforms: &uniforms, commandBuffer: commandBuffer)
        try encodeChecksumPass(
            texture: texture,
            checksumBuffer: checksumBuffer,
            pixelCountBuffer: pixelCountBuffer,
            uniforms: &uniforms,
            commandBuffer: commandBuffer
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "validateMetalTexture", reason: String(describing: error))
            )
        }

        let checksum = checksumBuffer.contents().load(as: UInt32.self)
        let pixelCount = pixelCountBuffer.contents().load(as: UInt32.self)
        return Syphon26MetalValidationResult(
            pixelFormat: plan.pixelFormat,
            metalPixelFormatRawValue: texture.pixelFormat.rawValue,
            width: texture.width,
            height: texture.height,
            fixture: plan.fixture,
            checksum: checksum,
            expectedChecksum: plan.expectedChecksum,
            pixelCount: pixelCount,
            usedGPUChecksumPass: true
        )
    }

    private func encodeWritePass(
        texture: any MTLTexture,
        uniforms: inout Syphon26MetalFixtureUniforms,
        commandBuffer: any MTLCommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "makeComputeCommandEncoder", reason: "write pass encoder unavailable")
            )
        }
        encoder.setComputePipelineState(writePipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBytes(&uniforms, length: MemoryLayout<Syphon26MetalFixtureUniforms>.stride, index: 0)
        dispatch(encoder: encoder, width: Int(uniforms.width), height: Int(uniforms.height))
        encoder.endEncoding()
    }

    private func encodeChecksumPass(
        texture: any MTLTexture,
        checksumBuffer: any MTLBuffer,
        pixelCountBuffer: any MTLBuffer,
        uniforms: inout Syphon26MetalFixtureUniforms,
        commandBuffer: any MTLCommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Syphon26Error.metal(
                Syphon26RuntimeIssue(operation: "makeComputeCommandEncoder", reason: "checksum pass encoder unavailable")
            )
        }
        encoder.setComputePipelineState(checksumPipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(checksumBuffer, offset: 0, index: 0)
        encoder.setBuffer(pixelCountBuffer, offset: 0, index: 1)
        encoder.setBytes(&uniforms, length: MemoryLayout<Syphon26MetalFixtureUniforms>.stride, index: 2)
        dispatch(encoder: encoder, width: Int(uniforms.width), height: Int(uniforms.height))
        encoder.endEncoding()
    }

    private func dispatch(encoder: any MTLComputeCommandEncoder, width: Int, height: Int) {
        let threadgroup = MTLSize(width: 8, height: 8, depth: 1)
        let grid = MTLSize(
            width: (width + threadgroup.width - 1) / threadgroup.width,
            height: (height + threadgroup.height - 1) / threadgroup.height,
            depth: 1
        )
        encoder.dispatchThreadgroups(grid, threadsPerThreadgroup: threadgroup)
    }

    private struct Syphon26MetalFixtureUniforms {
        var width: UInt32
        var height: UInt32
        var fixture: UInt32
        var reserved: UInt32
    }

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct Syphon26MetalFixtureUniforms {
        uint width;
        uint height;
        uint fixture;
        uint reserved;
    };

    static half4 syphon26_fixture_color(uint2 gid, constant Syphon26MetalFixtureUniforms& uniforms) {
        if (uniforms.fixture == 0) {
            uint bar = min((gid.x * 4u) / max(uniforms.width, 1u), 3u);
            switch (bar) {
            case 0:
                return half4(1.0h, 0.0h, 0.0h, 1.0h);
            case 1:
                return half4(0.0h, 1.0h, 0.0h, 1.0h);
            case 2:
                return half4(0.0h, 0.0h, 1.0h, 1.0h);
            default:
                return half4(1.0h, 1.0h, 1.0h, 1.0h);
            }
        }

        return half4(
            half(gid.x & 3u) * 0.25h,
            half(gid.y & 3u) * 0.25h,
            half((gid.x + gid.y) & 3u) * 0.25h,
            1.0h
        );
    }

    static uint syphon26_contribution(uint2 gid, uint4 quantized) {
        return ((gid.x + 1u) * 3u)
            + ((gid.y + 1u) * 5u)
            + (quantized.x * 11u)
            + (quantized.y * 17u)
            + (quantized.z * 23u)
            + (quantized.w * 29u);
    }

    kernel void syphon26_write_fixture(
        texture2d<half, access::write> output [[texture(0)]],
        constant Syphon26MetalFixtureUniforms& uniforms [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= uniforms.width || gid.y >= uniforms.height) {
            return;
        }
        output.write(syphon26_fixture_color(gid, uniforms), gid);
    }

    kernel void syphon26_checksum_fixture(
        texture2d<half, access::read> input [[texture(0)]],
        device atomic_uint& checksum [[buffer(0)]],
        device atomic_uint& pixelCount [[buffer(1)]],
        constant Syphon26MetalFixtureUniforms& uniforms [[buffer(2)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= uniforms.width || gid.y >= uniforms.height) {
            return;
        }

        half4 color = input.read(gid);
        uint4 quantized = uint4(
            uint(round(float(color.x) * 1024.0)),
            uint(round(float(color.y) * 1024.0)),
            uint(round(float(color.z) * 1024.0)),
            uint(round(float(color.w) * 1024.0))
        );
        atomic_fetch_add_explicit(&checksum, syphon26_contribution(gid, quantized), memory_order_relaxed);
        atomic_fetch_add_explicit(&pixelCount, 1u, memory_order_relaxed);
    }
    """
}
