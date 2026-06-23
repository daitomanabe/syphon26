import Testing
import Syphon26

@Test
func exposesV2DevelopmentIdentity() {
    #expect(Syphon26.version == "0.2.0-dev")
    #expect(Syphon26.transportName == "Syphon26 v2")
}

@Test
func exposesCurrentCompatibilityAndBenchmarkScope() {
    let capabilities = Syphon26.capabilities

    #expect(capabilities.validatedPixelFormats == [.bgra8Unorm, .rgba16Float])
    #expect(capabilities.compatibilityContract == .nativeTransportOnly)
    #expect(capabilities.benchmarkContract == .noCurrentBenchmarkClaims)
    #expect(capabilities.crossProcessTransportAvailable == true)
    #expect(capabilities.classicSyphonBridgeAvailable == false)
    #expect(capabilities.benchmarkHarnessAvailable == true)
}
