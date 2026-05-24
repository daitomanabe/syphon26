# Syphon26 Validation And Benchmark Plan

This plan defines how Syphon26 development is validated and how performance is compared with the original Syphon Framework.

## Development Phases

### Phase 0: API Lock

- [ ] Review `API_DESIGN.md`.
- [ ] Freeze Phase 1 public type names.
- [ ] Freeze Phase 1 initializer and frame acquisition semantics.
- [x] Mark all bridge-related APIs out of scope.
- [x] Add compile-only Objective-C and Swift API usage examples.

### Phase 1: Sequence-Poll Transport

- [ ] Implement shared stream state.
- [ ] Implement IOSurface-backed ring slots.
- [ ] Implement `Syphon26Server` direct render path.
- [ ] Implement `Syphon26Client` latest-frame acquisition.
- [ ] Implement atomic sequence polling sync.
- [ ] Implement diagnostics snapshots.
- [ ] Validate 1080p60 BGRA8 with one client.

### Phase 2: XPC Control Plane

- [ ] Add stream registration.
- [ ] Add stream retirement.
- [ ] Add client registration.
- [ ] Add client retirement.
- [ ] Move IOSurface handoff to XPC.
- [ ] Add stale process cleanup.
- [ ] Validate producer crash cleanup.
- [ ] Validate consumer crash cleanup.

### Phase 3: `MTLSharedEvent` Sync

- [ ] Exchange `MTLSharedEventHandle` over XPC.
- [ ] Signal readiness from the producer command buffer.
- [ ] Encode client waits on consumer command buffers.
- [ ] Preserve sequence polling fallback.
- [ ] Record fallback reason when shared events are unavailable.
- [ ] Validate shared-event and fallback modes with the same benchmark matrix.

### Phase 4: Format Expansion

- [ ] Add RGBA16F.
- [ ] Validate color metadata propagation.
- [ ] Validate alpha metadata propagation.
- [ ] Add unsupported-format rejection tests.

### Phase 5: Release Candidate Benchmarks

- [x] Run full Syphon26 matrix.
- [x] Run classic Syphon matrix on the same machine.
- [x] Publish JSON, CSV, environment metadata, and trace samples.
- [x] Produce speedup tables.
- [ ] Verify no CPU readback in fast-path samples.

## Validation Checklist

### API Validation

- [ ] Objective-C import of `Syphon26.h`.
- [ ] Swift import of module.
- [ ] Server create/start/stop/invalidate.
- [ ] Client create/start/stop/invalidate.
- [ ] Idempotent lifecycle calls.
- [ ] Invalid configuration failure paths.
- [ ] Unsupported pixel format failure paths.
- [ ] Stream description update after resize.
- [ ] Diagnostics snapshot before start, during run, after stop.

### Transport Validation

- [ ] One producer, one consumer.
- [ ] One producer, 2 consumers.
- [ ] One producer, 4 consumers.
- [ ] One producer, 8 consumers.
- [ ] One producer, 16 consumers.
- [ ] No-consumer publishing.
- [ ] Consumer starts before producer.
- [ ] Consumer starts after producer.
- [ ] Producer stops while consumers are active.
- [ ] Consumer stops while producer is active.
- [ ] Producer crash cleanup.
- [ ] Consumer crash cleanup.
- [ ] Stream resize while consumers are active.

### Frame Correctness

- [ ] Monotonic sequence numbers.
- [ ] Correct dimensions.
- [ ] Correct pixel format.
- [ ] Correct color metadata.
- [ ] Correct timestamp propagation.
- [ ] No stale frame after resize.
- [ ] No CPU readback in publish path.
- [ ] No CPU readback in client acquisition path.

### Synchronization Validation

- [ ] Sequence polling mode.
- [ ] Shared-event mode.
- [ ] Automatic mode choosing shared event when available.
- [ ] Automatic mode falling back to sequence polling when needed.
- [ ] Shared-event timeout accounting.
- [ ] Producer stall accounting.
- [ ] Client GPU wait accounting.
- [ ] Slot not reused before consumer GPU work completes.

### Stress Validation

- [ ] 30 minute 1080p60 run.
- [ ] 30 minute 4K60 run.
- [ ] 10 minute max-throughput run.
- [ ] Slow consumer at 1 ms per frame.
- [ ] Slow consumer at 5 ms per frame.
- [ ] Slow consumer at 16 ms per frame.
- [ ] Repeated stream create/destroy loop.
- [ ] Repeated client attach/detach loop.
- [ ] Memory growth check.
- [ ] Handle leak check.

## Benchmark Protocol

All benchmark comparisons must run Syphon26 and classic Syphon on the same machine, same OS session, same GPU, same display state, and same power mode.

Default run protocol:

- Warmup: 2 seconds.
- Measured duration: 10 seconds.
- Fixed FPS tests: producer throttled to target frame rate.
- Max-throughput tests: producer unthrottled.
- Sampling: JSON summary and CSV frame samples.
- Trace capture: `sample` or Instruments trace for server and client during measured window.
- CPU readback check: inspect traces for `getBytes`, `CGWindowListCreateImage`, `CGDisplayStream`, `CGContextDrawImage`, vImage conversion, or equivalent readback/capture symbols.

## Benchmark Matrix

### Fixed FPS

- [ ] 1920x1080@60 BGRA8.
- [ ] 3840x2160@60 BGRA8.
- [ ] 3840x2160@120 BGRA8 when hardware supports it.
- [ ] 3840x2160@60 RGBA16F.

### Max Throughput

- [ ] 1920x1080 BGRA8 unthrottled.
- [ ] 3840x2160 BGRA8 unthrottled.
- [ ] 3840x2160 RGBA16F unthrottled.

### Fan-Out

- [ ] 1 client.
- [ ] 2 clients.
- [ ] 4 clients.
- [ ] 8 clients.
- [ ] 16 clients.

### Slow Consumer

- [ ] 1 ms per-frame client delay.
- [ ] 5 ms per-frame client delay.
- [ ] 16 ms per-frame client delay.

## Metrics

Server metrics:

- submitted frames
- measured FPS
- dropped frames
- overwritten frames
- slot depth
- active client count
- producer stall nanoseconds
- shared-event signals
- XPC messages sent
- CPU percent
- resident memory

Client metrics:

- observed frames
- measured FPS
- missed frames
- repeated reads
- current lag
- max lag
- GPU wait nanoseconds
- shared-event waits
- shared-event timeouts
- XPC messages received
- CPU percent
- resident memory

Comparison metrics:

- fixed-FPS pass/fail
- max-throughput FPS ratio
- p50/p95/p99 frame latency when timestamp correlation is available
- CPU usage delta
- XPC message rate delta
- memory delta

Speedup formula:

```text
speedup = syphon26_client_fps / classic_syphon_client_fps
```

For fixed-FPS tests, report target stability instead of speedup:

```text
target_stability = measured_client_fps / target_fps
```

## Required Artifacts

Each benchmark run must write:

- `environment.json`
- `run.json`
- `server-summary.json`
- `client-summary-*.json`
- `server-samples.csv`
- `client-samples-*.csv`
- `trace/server.sample.txt`
- `trace/client-*.sample.txt`
- `summary.md`

The Syphon26 matrix helper is:

```sh
python3 scripts/run_benchmark_matrix.py --matrix 1080p60,4k60,4k120,1080pmax,4kmax --clients 1 --sync sequence-polling --configuration release
python3 scripts/run_benchmark_matrix.py --matrix 1080p60 --clients 1,2,4,8,16 --sync sequence-polling --configuration release
python3 scripts/run_benchmark_matrix.py --matrix 1080pmax --clients 1 --slow-consumer-ms 1 --client-poll-us 100 --sync sequence-polling --configuration release
```

The final report must include:

- Syphon26 results.
- Classic Syphon results.
- Speedup table.
- Fixed-FPS stability table.
- Fan-out table.
- Slow-consumer table.
- CPU readback trace check.
- Known fallback modes.

## Reference Prototype Result

The earlier FrameBus prototype in the Syphon-Framework sandbox is not a Syphon26 production result, but it gives a useful target range for the native transport.

| Test | Classic Syphon client FPS | Prototype client FPS | Ratio |
| --- | ---: | ---: | ---: |
| 1920x1080 max BGRA8 | 572.89 | 5679.00 | 9.91x |
| 3840x2160 max BGRA8 | 471.93 | 3219.00 | 6.82x |
| 3840x2160@120 BGRA8 | 119.95 | 120.00 | target met |

Syphon26 should not claim these numbers until the Syphon26 implementation and benchmark harness reproduce them. The initial production target is:

- Fixed FPS: no regression versus classic Syphon.
- 1920x1080 max throughput: materially faster than classic Syphon, target 5x or better.
- 3840x2160 max throughput: materially faster than classic Syphon, target 3x or better.
- Stretch target: match or exceed the prototype ratios above.

## Release Gate

Syphon26 Phase 1 is not considered validated until:

- [ ] API examples compile.
- [ ] 1080p60 and 4K60 fixed-FPS tests pass.
- [ ] Max-throughput tests show a clear speedup versus classic Syphon.
- [ ] Fan-out tests pass through 8 clients.
- [ ] Slow-consumer tests show bounded lag.
- [ ] No CPU readback appears in fast-path traces.
- [ ] Shared-event mode works or reports a clear fallback reason.
- [ ] All benchmark artifacts are committed or attached to a release report.
