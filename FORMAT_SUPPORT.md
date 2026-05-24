# Syphon26 Format Support

Phase 1 supports single-plane Metal texture transport:

- `MTLPixelFormat.bgra8Unorm`
- `MTLPixelFormat.bgra8Unorm_srgb`
- `MTLPixelFormat.rgba16Float`

## Deferred Multi-Plane Formats

NV12, P010, and other multi-plane YCbCr formats are intentionally deferred. They should not be added until there is a real producer and consumer pipeline that requires them.

Before adding multi-plane support, define and validate:

- plane count and per-plane dimensions
- IOSurface plane allocation and Metal texture creation rules
- color matrix, range, primaries, and transfer metadata
- chroma siting metadata
- synchronization semantics across all planes in one frame
- fallback behavior when a consumer cannot import all planes
- benchmark cases against BGRA8 and RGBA16F
- Objective-C and Swift API representation without exposing raw IOSurface internals

Until those requirements are written for a concrete pipeline, Syphon26 should reject unsupported pixel formats explicitly instead of adding partial NV12/P010 behavior.
