import Testing
import Syphon26

@Test
func exposesV2DevelopmentIdentity() {
    #expect(Syphon26.version == "0.2.0-dev")
    #expect(Syphon26.transportName == "Syphon26 v2")
}
