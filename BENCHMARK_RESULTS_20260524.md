# Syphon26 Benchmark Results - 2026-05-24

This report captures the first Syphon26 native transport MVP benchmark.

Important scope note: these Syphon26 numbers measure the current in-process native transport harness with IOSurface-backed Metal ring slots and sequence-poll sync. They are useful for early regression tracking, but they are not the final app-to-app/XPC production benchmark yet.

Classic Syphon baseline values are from the sibling Syphon-Framework benchmark run on the same Mac.

## Environment

- Xcode: 26.5
- Swift: 6.3.2
- SDK: macOS 26.5
- Syphon26 command: `swift run Syphon26Benchmark`
- Syphon26 render mode: `clear`
- Syphon26 sync mode: `sequence-polling`
- Clients: 1

## Fixed FPS

| Test | Classic Syphon Client FPS | Syphon26 Client FPS | Result |
| --- | ---: | ---: | --- |
| 1920x1080@60 BGRA8 | 59.97 | 59.90 | target met |
| 3840x2160@60 BGRA8 | 59.57 | 59.91 | target met |
| 3840x2160@120 BGRA8 | 119.95 | 119.91 | target met |

For fixed-FPS tests, the goal is target stability rather than max-FPS speedup. Syphon26 meets the target in this MVP harness.

## Max Throughput

| Test | Classic Syphon Client FPS | Syphon26 Client FPS | Syphon26 / Syphon |
| --- | ---: | ---: | ---: |
| 1920x1080 max BGRA8 | 572.89 | 3755.00 | 6.55x |
| 3840x2160 max BGRA8 | 471.93 | 3739.41 | 7.92x |

## Syphon26 Commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26Benchmark --width 1920 --height 1080 --fps 60 --warmup 0.5 --duration 2 --clients 1 --sync sequence-polling --output benchmark-results/current-1080p60
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26Benchmark --width 3840 --height 2160 --fps 60 --warmup 0.5 --duration 2 --clients 1 --sync sequence-polling --output benchmark-results/current-4k60
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26Benchmark --width 3840 --height 2160 --fps 120 --warmup 0.5 --duration 2 --clients 1 --sync sequence-polling --output benchmark-results/current-4k120
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26Benchmark --width 1920 --height 1080 --fps 0 --warmup 0.5 --duration 1 --clients 1 --sync sequence-polling --output benchmark-results/current-1080pmax
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26Benchmark --width 3840 --height 2160 --fps 0 --warmup 0.5 --duration 1 --clients 1 --sync sequence-polling --output benchmark-results/current-4kmax
```

## Validation State

Passed in this checkpoint:

- Swift package build.
- 11 unit/API/transport tests.
- IOSurface-backed Metal slot allocation.
- Direct server drawable presentation.
- Client latest-frame acquisition.
- Sequence-poll sync.
- `MTLSharedEvent` producer signal path.
- Benchmark CLI fixed-FPS and max-throughput smoke runs.

Still required before release-quality benchmark claims:

- Cross-process/XPC control plane.
- Secure IOSurface handoff over XPC.
- Consumer-side `MTLSharedEvent` wait encoding.
- Fan-out matrix at 1, 2, 4, 8, and 16 clients.
- Slow-consumer matrix.
- Trace-based no-CPU-readback validation.
- Same-run classic Syphon comparison rather than using the sibling baseline artifact.

