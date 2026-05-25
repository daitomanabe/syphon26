import Metal
import Testing
import Syphon26

@Test
func pixelFormatMetadataDocumentsBaselineFormats() throws {
    let bgra = try Syphon26PixelFormat.bgra8Unorm.metadata
    #expect(bgra.metalPixelFormat == .bgra8Unorm)
    #expect(bgra.bytesPerPixel == 4)
    #expect(bgra.channelCount == 4)
    #expect(bgra.bitsPerComponent == 8)
    #expect(bgra.isFloat == false)

    let rgba16 = try Syphon26PixelFormat.rgba16Float.metadata
    #expect(rgba16.metalPixelFormat == .rgba16Float)
    #expect(rgba16.bytesPerPixel == 8)
    #expect(rgba16.channelCount == 4)
    #expect(rgba16.bitsPerComponent == 16)
    #expect(rgba16.isFloat == true)
}

@Test
func unsupportedPixelFormatHasNoMetalMetadata() {
    expectValidation(.unsupportedPixelFormat) {
        _ = try Syphon26PixelFormat.unsupported("depth32Float").metadata
    }
}

@Test
func bgra8MetalFixtureValidationIsDeterministic() throws {
    let validator = try Syphon26MetalValidator()
    let plan = try Syphon26MetalValidationPlan(
        pixelFormat: .bgra8Unorm,
        width: 16,
        height: 8,
        fixture: .bgra8ColorBars
    )

    let first = try validator.validate(plan)
    let second = try validator.validate(plan)

    #expect(first == second)
    #expect(first.pixelFormat == .bgra8Unorm)
    #expect(first.metalPixelFormatRawValue == MTLPixelFormat.bgra8Unorm.rawValue)
    #expect(first.pixelCount == UInt32(plan.width * plan.height))
    #expect(first.usedGPUChecksumPass)
    #expect(first.matchesExpectedChecksum)
    #expect(first.checksum == Syphon26MetalFixture.bgra8ColorBars.expectedChecksum(width: 16, height: 8))
}

@Test
func rgba16FloatMetalFixtureValidationIsDeterministic() throws {
    let validator = try Syphon26MetalValidator()
    let plan = try Syphon26MetalValidationPlan(
        pixelFormat: .rgba16Float,
        width: 8,
        height: 8,
        fixture: .rgba16FloatGradient
    )

    let first = try validator.validate(plan)
    let second = try validator.validate(plan)

    #expect(first == second)
    #expect(first.pixelFormat == .rgba16Float)
    #expect(first.metalPixelFormatRawValue == MTLPixelFormat.rgba16Float.rawValue)
    #expect(first.pixelCount == UInt32(plan.width * plan.height))
    #expect(first.usedGPUChecksumPass)
    #expect(first.matchesExpectedChecksum)
    #expect(first.checksum == Syphon26MetalFixture.rgba16FloatGradient.expectedChecksum(width: 8, height: 8))
}

@Test
func metalValidationPlanRejectsUnsupportedPixelFormats() {
    expectValidation(.unsupportedPixelFormat) {
        _ = try Syphon26MetalValidationPlan(pixelFormat: .unsupported("r8Unorm"), width: 8, height: 8)
    }
}

private func expectValidation(_ code: Syphon26ValidationCode, _ body: () throws -> Void) {
    let error = capturedSyphonError(body)
    #expect(error?.category == .validation)
    #expect(error?.validationCode == code)
}

private func capturedSyphonError(_ body: () throws -> Void) -> Syphon26Error? {
    do {
        try body()
        return nil
    } catch let error as Syphon26Error {
        return error
    } catch {
        #expect(Bool(false))
        return nil
    }
}
