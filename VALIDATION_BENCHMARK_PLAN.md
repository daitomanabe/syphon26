# Syphon26 Validation And Benchmark Plan

This plan defines how Syphon26 development is validated and how performance is compared with the original Syphon Framework.

## Development Phases

### Phase 0: API Lock

- [x] Review `API_DESIGN.md`.
- [x] Freeze Phase 1 public type names.
- [x] Freeze Phase 1 initializer and frame acquisition semantics.
- [x] Mark all bridge-related APIs out of scope.
- [x] Add compile-only Objective-C and Swift API usage examples.

### Phase 1: Sequence-Poll Transport

- [x] Implement shared stream state.
- [x] Implement IOSurface-backed ring slots.
- [x] Implement `Syphon26Server` direct render path.
- [x] Implement `Syphon26Client` latest-frame acquisition.
- [x] Implement atomic sequence polling sync.
- [x] Implement diagnostics snapshots.
- [x] Validate 1080p60 BGRA8 with one client.

### Phase 2: XPC Control Plane

- [x] Add stream registration.
- [x] Add stream retirement.
- [x] Add client registration.
- [x] Add client retirement.
- [x] Move IOSurface handoff to XPC.
- [x] Add stale process cleanup.
- [x] Validate producer crash cleanup.
- [x] Validate consumer crash cleanup.

### Phase 3: `MTLSharedEvent` Sync

- [x] Exchange `MTLSharedEventHandle` over XPC.
- [x] Signal readiness from the producer command buffer.
- [x] Encode client waits on consumer command buffers.
- [x] Preserve sequence polling fallback.
- [x] Record fallback reason when shared events are unavailable.
- [x] Validate shared-event and fallback modes with the same benchmark matrix.

### Phase 4: Format Expansion

- [x] Add RGBA16F.
- [x] Validate color metadata propagation.
- [x] Validate alpha metadata propagation.
- [x] Add unsupported-format rejection tests.

### Phase 5: Release Candidate Benchmarks

- [x] Run full Syphon26 matrix.
- [x] Run classic Syphon matrix on the same machine.
- [x] Publish JSON, CSV, environment metadata, and trace samples.
- [x] Produce speedup tables.
- [x] Verify no CPU readback in fast-path samples.

## Validation Checklist

### API Validation

- [x] Objective-C import of `Syphon26.h`.
- [x] Swift import of module.
- [x] Server create/start/stop/invalidate.
- [x] Client create/start/stop/invalidate.
- [x] Idempotent lifecycle calls.
- [x] Invalid configuration failure paths.
- [x] Unsupported pixel format failure paths.
- [ ] Stream description update after resize.
- [x] Diagnostics snapshot before start, during run, after stop.

### Transport Validation

- [x] One producer, one consumer.
- [x] One producer, 2 consumers.
- [x] One producer, 4 consumers.
- [x] One producer, 8 consumers.
- [x] One producer, 16 consumers.
- [x] No-consumer publishing.
- [x] Consumer starts before producer.
- [x] Consumer starts after producer.
- [x] Producer stops while consumers are active.
- [x] Consumer stops while producer is active.
- [x] Producer crash cleanup.
- [x] Consumer crash cleanup.
- [ ] Stream resize while consumers are active.

### Frame Correctness

- [x] Monotonic sequence numbers.
- [x] Correct dimensions.
- [x] Correct pixel format.
- [x] Correct color metadata.
- [x] Correct timestamp propagation.
- [ ] No stale frame after resize.
- [x] No CPU readback in publish path.
- [x] No CPU readback in client acquisition path.

### Synchronization Validation

- [x] Sequence polling mode.
- [x] Shared-event mode.
- [x] Automatic mode choosing shared event when available.
- [x] Automatic mode falling back to sequence polling when needed.
- [ ] Shared-event timeout accounting.
- [x] Producer stall accounting.
- [x] Client GPU wait accounting.
- [ ] Slot not reused before consumer GPU work completes.

### Stress Validation

- [x] 30 minute 1080p60 run.
- [x] 30 minute 4K60 run.
- [x] 10 minute max-throughput run.
- [x] Slow consumer at 1 ms per frame.
- [x] Slow consumer at 5 ms per frame.
- [x] Slow consumer at 16 ms per frame.
- [x] Repeated stream create/destroy loop.
- [x] Repeated client attach/detach loop.
- [x] Memory growth check.
- [x] Handle leak check.

## Open Non-Gate Items

These items remain intentionally unchecked because they are outside the current Phase 1 benchmark release gate or need a dedicated future harness:

- Stream resize/reconfiguration validation. The current native transport preview uses immutable stream descriptions.
- Shared-event timeout accounting. Shared-event readiness and GPU wait accounting are validated, but forced timeout simulation is not yet part of the harness.
- Strict cross-process slot reuse after consumer GPU completion. Phase 1 app-to-app benchmarks use latest-frame semantics with shared-event producer readiness; a future bounded-latency contract should wire `markConsumed` back to producer-side slot reuse.
- 3840x2160 RGBA16F unthrottled benchmark. Fixed-FPS RGBA16F is validated; unthrottled RGBA16F has no classic Syphon baseline yet.

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

- [x] 1920x1080@60 BGRA8.
- [x] 3840x2160@60 BGRA8.
- [x] 3840x2160@120 BGRA8 when hardware supports it.
- [x] 3840x2160@60 RGBA16F.

### Max Throughput

- [x] 1920x1080 BGRA8 unthrottled.
- [x] 3840x2160 BGRA8 unthrottled.
- [ ] 3840x2160 RGBA16F unthrottled.

### Fan-Out

- [x] 1 client.
- [x] 2 clients.
- [x] 4 clients.
- [x] 8 clients.
- [x] 16 clients.

### Slow Consumer

- [x] 1 ms per-frame client delay.
- [x] 5 ms per-frame client delay.
- [x] 16 ms per-frame client delay.

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

- [x] API examples compile.
- [x] 1080p60 and 4K60 fixed-FPS tests pass.
- [x] Max-throughput tests show a clear speedup versus classic Syphon.
- [x] Fan-out tests pass through 8 clients.
- [x] Slow-consumer tests show bounded lag.
- [x] No CPU readback appears in fast-path traces.
- [x] Shared-event mode works or reports a clear fallback reason.
- [x] All benchmark artifacts are committed or attached to a release report.
