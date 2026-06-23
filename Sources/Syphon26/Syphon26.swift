public enum Syphon26CompatibilityContract: String, CaseIterable, Sendable {
    case nativeTransportOnly
}

public enum Syphon26BenchmarkContract: String, CaseIterable, Sendable {
    case noCurrentBenchmarkClaims
}

public struct Syphon26Capabilities: Equatable, Sendable {
    public let validatedPixelFormats: [Syphon26PixelFormat]
    public let compatibilityContract: Syphon26CompatibilityContract
    public let benchmarkContract: Syphon26BenchmarkContract
    public let crossProcessTransportAvailable: Bool
    public let classicSyphonBridgeAvailable: Bool
    public let benchmarkHarnessAvailable: Bool

    public init(
        validatedPixelFormats: [Syphon26PixelFormat],
        compatibilityContract: Syphon26CompatibilityContract,
        benchmarkContract: Syphon26BenchmarkContract,
        crossProcessTransportAvailable: Bool,
        classicSyphonBridgeAvailable: Bool,
        benchmarkHarnessAvailable: Bool
    ) {
        self.validatedPixelFormats = validatedPixelFormats
        self.compatibilityContract = compatibilityContract
        self.benchmarkContract = benchmarkContract
        self.crossProcessTransportAvailable = crossProcessTransportAvailable
        self.classicSyphonBridgeAvailable = classicSyphonBridgeAvailable
        self.benchmarkHarnessAvailable = benchmarkHarnessAvailable
    }
}

public enum Syphon26 {
    public static let version = "0.2.0-dev"
    public static let transportName = "Syphon26 v2"
    public static let defaultControlPlaneServiceName = "com.syphon26.control-plane"
    public static let maximumTextureDimension = 16_384
    public static let minimumBufferCount = 2
    public static let maximumBufferCount = 8
    public static let capabilities = Syphon26Capabilities(
        validatedPixelFormats: [.bgra8Unorm, .rgba16Float],
        compatibilityContract: .nativeTransportOnly,
        benchmarkContract: .noCurrentBenchmarkClaims,
        crossProcessTransportAvailable: true,
        classicSyphonBridgeAvailable: false,
        benchmarkHarnessAvailable: true
    )
}
