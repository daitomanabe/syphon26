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
- Clients: 1 for baseline runs; 1, 2, 4, 8, and 16 for fan-out runs

## Fixed FPS

| Test | Classic Syphon Client FPS | Syphon26 Client FPS | Result |
| --- | ---: | ---: | --- |
| 1920x1080@60 BGRA8 | 59.97 | 59.90 | target met |
| 3840x2160@60 BGRA8 | 59.57 | 59.91 | target met |
| 3840x2160@120 BGRA8 | 119.95 | 119.91 | target met |

For fixed-FPS tests, the goal is target stability rather than max-FPS speedup. Syphon26 meets the target in this MVP harness.

## Fan-out

Command: `python3 scripts/run_benchmark_matrix.py --matrix 1080p60 --clients 1,2,4,8,16 --sync sequence-polling --pixel-format bgra8 --warmup 0.2 --client-poll-us 100 --configuration release --output benchmark-results/fanout-20260524`

| Test | Clients | Classic Syphon Client FPS | Syphon26 Min Client FPS | Result |
| --- | ---: | ---: | ---: | --- |
| 1920x1080@60 BGRA8 | 1 | 59.97 | 59.78 | target met |
| 1920x1080@60 BGRA8 | 2 | 59.97 | 59.83 | target met |
| 1920x1080@60 BGRA8 | 4 | 59.97 | 59.76 | target met |
| 1920x1080@60 BGRA8 | 8 | 59.97 | 59.84 | target met |
| 1920x1080@60 BGRA8 | 16 | 59.97 | 59.81 | target met |

This verifies that the current latest-frame in-process transport keeps 1080p60 stable through 16 concurrent consumers in the benchmark harness.

## Slow Consumers

Commands used the same 1080p60 BGRA8 release matrix with 4 clients, `--client-poll-us 100`, and `--slow-consumer-ms` set to 1, 5, and 16.

| Slow Consumer Delay | Clients | Syphon26 Server FPS | Syphon26 Min Client FPS | Max Missed Frames | Result |
| ---: | ---: | ---: | ---: | ---: | --- |
| 1 ms | 4 | 59.94 | 59.94 | 0 | producer not blocked |
| 5 ms | 4 | 59.87 | 59.87 | 0 | producer not blocked |
| 16 ms | 4 | 59.69 | 52.72 | 14 | producer not blocked; slow clients drop frames |

The 16 ms row intentionally slows consumers enough that they cannot observe every 60 fps update. The important transport behavior is that the producer remains near 60 fps instead of stalling behind the slowest client.

## Max Throughput

| Test | Classic Syphon Client FPS | Syphon26 Client FPS | Syphon26 / Syphon |
| --- | ---: | ---: | ---: |
| 1920x1080 max BGRA8 | 572.89 | 3755.00 | 6.55x |
| 3840x2160 max BGRA8 | 471.93 | 3739.41 | 7.92x |

## RGBA16F

Command: `python3 scripts/run_benchmark_matrix.py --matrix 1080p60,4k60,1080pmax --clients 1 --sync sequence-polling --pixel-format rgba16f --warmup 0.2 --client-poll-us 100 --configuration release --output benchmark-results/rgba16f-20260524`

| Test | Syphon26 Client FPS | Notes |
| --- | ---: | --- |
| 1920x1080@60 RGBA16F | 59.96 | target met |
| 3840x2160@60 RGBA16F | 59.88 | target met |
| 1920x1080 max RGBA16F | 5395.61 | no classic Syphon baseline |

## Fast-path Sampling

Command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release --product Syphon26Benchmark
.build/release/Syphon26Benchmark --width 1920 --height 1080 --fps 0 --warmup 0.2 --duration 8 --clients 4 --sync sequence-polling --pixel-format bgra8 --client-poll-us 100 --output benchmark-results/fastpath-sample-20260524/run
sample <benchmark-pid> 3 -file benchmark-results/fastpath-sample-20260524/sample.txt
```

Result:

- 1920x1080 max BGRA8 with 4 clients: server 5475.78 fps, minimum client 5400.28 fps.
- `sample` call graph did not contain `CGWindowListCreateImage`, `SLWindowListCreateImage`, `CGContextDrawImage`, `CVPixelBufferLockBaseAddress`, `getBytes`, `replaceRegion`, or `vImage` execution symbols.
- `vImage` appeared only in the Binary Images section as a loaded framework, not in the sampled call graph.

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
- 16 unit/API/transport tests.
- IOSurface-backed Metal slot allocation.
- Direct server drawable presentation.
- Client latest-frame acquisition.
- Sequence-poll sync.
- `MTLSharedEvent` producer signal path.
- RGBA16F publish/consume validation.
- 1080p60 fan-out through 16 clients.
- Slow-consumer 1 ms, 5 ms, and 16 ms matrix.
- `sample` call-graph check for fast-path CPU readback symbols.
- Benchmark CLI fixed-FPS and max-throughput smoke runs.

Still required before release-quality benchmark claims:

- No remaining Phase 1 benchmark gate is open in `REMAINING_IMPLEMENTATION_TODO.md`.

## App-To-App Production Checkpoint

The app-to-app benchmark report is published in `benchmark-reports/app-to-app-production-20260524/`.

| Test | Classic Syphon Client FPS | Syphon26 App-To-App Client FPS | Result |
| --- | ---: | ---: | ---: |
| 1920x1080@60 BGRA8 | 59.99 | 60.00 | target met |
| 3840x2160@60 BGRA8 | 59.97 | 60.10 | target met |
| 1920x1080 max BGRA8 | 346.44 | 667.20 | 1.93x |
| 3840x2160 max BGRA8 | 343.62 | 666.80 | 1.94x |

These values use a launchd-managed Syphon26 control plane and separate producer/consumer processes. The same-session classic Syphon comparison was rerun from the sibling Syphon-Framework benchmark app.

## App-To-App Stability

The long stability report is published in `benchmark-reports/stability-production-20260524/`.

| Test | Duration | Consumer FPS | Producer RSS Delta | Consumer RSS Delta | Producer FD Delta | Consumer FD Delta | Result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 1920x1080@60 BGRA8 | 30 min | 60.0006 | -16 KB | +1776 KB | 0 | 0 | pass |
| 3840x2160@60 BGRA8 | 30 min | 60.0006 | -16 KB | +1760 KB | 0 | 0 | pass |
| 1920x1080 max BGRA8 | 10 min | 783.8517 | +224 KB | +1744 KB | 0 | 0 | pass |

These runs use the launchd-managed Syphon26 control plane and separate producer/consumer processes. RSS and file-descriptor counts were sampled every 15 seconds.
