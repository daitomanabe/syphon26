# ACCEPTANCE.md

Acceptance criteria must be checkable by tests, build commands, fixture validation, benchmark scripts, or manual smoke tests with exact steps.

## Phase 1: Public API Contract And Validation Core

Phase 1 is complete only when all of the following are true:

- `swift build` passes.
- `swift test` passes.
- `git diff --check` passes.
- Public configuration types exist for server and client setup.
- Stream metadata and diagnostics snapshot types exist.
- Validation rejects invalid stream names, dimensions, pixel formats, buffer counts, and control-plane service names.
- Error taxonomy distinguishes validation, Metal, IOSurface, control-plane, XPC connection, synchronization, and lifecycle failures.
- Tests cover valid and invalid configuration cases.
- No XPC service, IOSurface allocation, AppKit UI, sample app, or benchmark implementation is added.

## Phase 2: In-Process Metal Validation

Phase 2 is complete only when all of the following are true:

- `swift test` passes.
- `git diff --check` passes.
- Deterministic in-process Metal texture validation exists.
- BGRA8 baseline behavior is tested.
- RGBA16F behavior is tested or explicitly skipped with a hardware/runtime reason.
- Pixel format metadata is documented.
- No cross-process transport or AppKit UI is added.

## Phase 3: IOSurface Transport Core

Phase 3 is complete only when all of the following are true:

- `swift test` passes.
- `git diff --check` passes.
- IOSurface-backed Metal texture creation is tested.
- Ring slot metadata has ABI version checks.
- Latest-frame semantics are tested.
- Bounded-latency semantics are tested.
- Missed-frame, overwrite, and consumer-lag diagnostics are tested.
- No XPC service or AppKit UI is added.

## Phase 4: Control Plane And XPC Lifecycle

Phase 4 is complete only when all of the following are true:

- `swift test` passes.
- `scripts/verify_control_plane.sh` passes in a healthy local service case.
- `git diff --check` passes.
- The control-plane protocol is tested with an in-process fake.
- XPC startup verification distinguishes missing service, stale service, permission mismatch, schema mismatch, and healthy service.
- Stream registration and consumer registration are tested.
- Crashed producer and crashed consumer cleanup are tested or have exact manual smoke steps.
- A plain `xpc connection failed` outcome is not accepted as sufficient diagnostics.

## Phase 5: Synchronization

Phase 5 is complete only when all of the following are true:

- `swift test` passes.
- `git diff --check` passes.
- `MTLSharedEvent` wait encoding is tested when available.
- Sequence-counter fallback is tested.
- Frame lifetime is tied to GPU completion in tests or documented manual validation.
- Diagnostics expose sync mode, fallback reason, wait time, and signal count.

## Phase 6: Samples And App UI

Phase 6 is complete only when all of the following are true:

- `swift build` passes.
- CLI Simple Server and Simple Client can exchange frames through a verified control plane.
- AppKit Simple Server and Simple Client can select streams, preview frames, and display diagnostics.
- Manual smoke steps include exact commands, expected stream IDs, expected frame counts, and expected diagnostic lines.
- Preview rendering is not used as the only proof of transport correctness.
- App bundles can be exported into the repository-local `dist/` directory.

## Phase 7: Benchmarks And Production Readiness

Phase 7 is complete only when all of the following are true:

- `swift test` passes.
- Benchmark scripts produce raw machine-readable outputs and a human-readable summary.
- v2 is compared against `v1` under documented conditions.
- Classic Syphon-style comparison conditions are documented before claims are made.
- Reports include environment, resolution, pixel format, FPS target, publish FPS, receive FPS, missed frames, repeated reads, latency, CPU, memory, GPU wait, and interpretation limits.
- Integration and troubleshooting docs exist.
