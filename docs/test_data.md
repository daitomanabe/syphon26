# Test Data Plan

## Purpose

Define deterministic fixtures, generated textures, expected metadata, and benchmark inputs so later implementation can be tested without relying on visual inspection alone.

## Fixture Categories

### API Validation Fixtures

- Valid server configurations.
- Invalid server configurations: empty name, invalid dimensions, unsupported pixel format, invalid buffer count, invalid service name.
- Valid client configurations.
- Invalid client configurations: empty stream ID, unsupported preferred formats, invalid service name.

### Metal Texture Fixtures

- BGRA8 color bars with edge markers.
- RGBA16F gradient with known value ranges.
- Frame index marker pattern for dropped-frame detection.

Phase 2 implements the first two Metal fixtures in `fixtures/metal/README.md`:

- `bgra8ColorBars`: four deterministic color bars for `bgra8Unorm`.
- `rgba16FloatGradient`: exact half-float-friendly gradient values for `rgba16Float`.

The validation path is GPU-oriented: a compute pass writes the texture and a second compute pass samples it to produce a checksum and pixel count. Tests read only those scalar validation buffers, not the full frame texture.

### Transport Fixtures

- Ring metadata examples for empty, published, overwritten, and retired slots.
- Expected diagnostics snapshots for repeated read, missed frame, consumer lag, and producer stall.

### Control-Plane Fixtures

- Healthy service description.
- Missing service case.
- Stale service case.
- Schema mismatch case.
- Permission mismatch case.

## Golden Outputs

Golden outputs should be small and textual when possible:

- JSON diagnostics snapshots.
- CSV benchmark summaries.
- Stable metadata dumps.
- Expected error code lists.

## Validation Commands

Commands will be added as scripts are introduced. Until then, required validation is:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```
