# Syphon26 v2 Implementation Plan

This branch is a full scratch rewrite. The `v1` branch preserves the previous implementation and benchmark artifacts.

## Non-Negotiable Constraints

- Keep the frame hot path on Metal textures and IOSurface-backed resources.
- Do not use CPU texture readback for transport.
- Do not use screen capture, window capture, or preview capture as transport.
- Do not import or link `Syphon.framework` in the core implementation.
- Make every cross-process dependency explicit in diagnostics.
- Treat XPC/control-plane startup failure as a first-class validation failure, not an app log detail.

## Phase 0: Repository Reset

- [x] Preserve the previous implementation on `v1`.
- [x] Create orphan branch `v2`.
- [x] Add a minimal SwiftPM package.
- [x] Add BSD 3-Clause license.
- [x] Add v2 implementation checklist.
- [ ] Add CI/build script entrypoints.
- [ ] Add a failure-oriented logging convention.

## Phase 1: Public API Contract

- [ ] Define `Syphon26ServerConfiguration`.
- [ ] Define `Syphon26ClientConfiguration`.
- [ ] Define `Syphon26Server`.
- [ ] Define `Syphon26Client`.
- [ ] Define `Syphon26Frame`.
- [ ] Define stream discovery API.
- [ ] Define diagnostics snapshots.
- [ ] Define errors that distinguish Metal, IOSurface, XPC, sync, and lifecycle failures.
- [ ] Add compile-only API examples.

## Phase 2: Local Metal Validation

- [ ] Add deterministic Metal test texture generator.
- [ ] Add texture format metadata model.
- [ ] Validate BGRA8 render and sample path in-process.
- [ ] Validate RGBA16F render and sample path in-process.
- [ ] Add GPU-only checksum or histogram validation.
- [ ] Add frame cadence measurement independent of AppKit preview.

## Phase 3: IOSurface Transport

- [ ] Add IOSurface allocation wrapper.
- [ ] Add `MTLTexture` creation from IOSurface.
- [ ] Add ring-buffer slot metadata.
- [ ] Add latest-frame semantics.
- [ ] Add bounded-latency semantics.
- [ ] Add overwrite and missed-frame diagnostics.
- [ ] Add transport ABI versioning.

## Phase 4: Control Plane

- [ ] Define a minimal control-plane protocol before writing XPC code.
- [ ] Add in-process fake control plane for tests.
- [ ] Add launchd/XPC control-plane service.
- [ ] Add explicit service-name configuration.
- [ ] Add startup verification command.
- [ ] Add clear errors for missing service, permission mismatch, stale service, and schema mismatch.
- [ ] Add stream registration and consumer registration tests.
- [ ] Add cleanup tests for crashed producer and crashed consumer.

## Phase 5: Synchronization

- [ ] Add `MTLSharedEvent` path.
- [ ] Add sequence-counter fallback.
- [ ] Add GPU wait encoding API.
- [ ] Keep frames alive until GPU work completes.
- [ ] Track wait time, fallback reason, and signal count.

## Phase 6: Sample Apps

- [ ] Add CLI Simple Server.
- [ ] Add CLI Simple Client.
- [ ] Add AppKit Simple Server with manual resolution, FPS, pixel format, and preview.
- [ ] Add AppKit Simple Client with server selection, preview, and diagnostics.
- [ ] Keep preview rendering separate from transport validation.
- [ ] Add repo-local app export script.

## Phase 7: Benchmarks

- [ ] Add v2 benchmark harness.
- [ ] Add v1 comparison runner.
- [ ] Add classic Syphon comparison plan.
- [ ] Measure 1080p60, 4K60, 4K120, RGBA16F, fanout, and max-throughput.
- [ ] Report publish FPS, receive FPS, missed frames, repeated reads, latency, CPU, memory, and GPU wait.

## Phase 8: Production Readiness

- [ ] Stabilize API naming.
- [ ] Add Objective-C-facing headers or wrappers only after Swift API stabilizes.
- [ ] Add integration guide.
- [ ] Add app embedding checklist.
- [ ] Add troubleshooting guide for control-plane and XPC failures.
- [ ] Add release checklist.
