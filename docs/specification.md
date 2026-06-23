# Specification

## Purpose

Syphon26 v2 provides a modern local frame-sharing transport for macOS applications that render with Metal. It is inspired by the app-to-app live visual workflow of Syphon, but v2 is a clean-room transport and does not implement a classic Syphon bridge in the core library.

## Primary Users

- Swift and AppKit application developers who need to publish Metal-rendered frames.
- VJ, media, and live visual tool developers who need low-latency local frame sharing.
- Developers embedding a GPU-native producer or consumer in another macOS app.

## Inputs

- Producer-side Metal textures or render commands.
- Stream configuration: name, dimensions, pixel format, timing, and synchronization preferences.
- Consumer-side stream selection and preferred pixel formats.
- Control-plane service configuration for cross-process discovery and resource handoff.

## Outputs

- Consumer-readable frame handles backed by IOSurface/Metal resources.
- Stream directory metadata.
- Diagnostics for frame counts, missed frames, repeated reads, fallback modes, synchronization waits, lifecycle state, and control-plane failures.

## Core Behavior

1. A producer creates a stable stream with explicit configuration.
2. The transport validates configuration before runtime resources are allocated.
3. The producer publishes frames into IOSurface-backed Metal resources.
4. The control plane exposes stream metadata and resource handles to consumers.
5. A consumer selects a stream and reads the latest frame while respecting GPU synchronization.
6. Diagnostics distinguish validation failures from Metal, IOSurface, XPC/control-plane, synchronization, and lifecycle failures.

## Constraints

- macOS 14 or later.
- SwiftPM package.
- Metal required.
- BGRA8 is the baseline transport format.
- RGBA16F is validated for deterministic in-process Metal behavior.
- End-to-end HDR transport behavior and color-management semantics are future acceptance items.
- No CPU readback in the transport hot path.
- No screen or window capture as transport.
- No AppKit preview dependency for publishing or receiving frames.
- No classic Syphon compatibility in the v2 core.

## Current Compatibility And Benchmark Scope

The current public capability snapshot is `Syphon26.capabilities`. It is intentionally conservative so applications and issue responses can distinguish implemented behavior from roadmap items:

- `compatibilityContract == .nativeTransportOnly`
- `classicSyphonBridgeAvailable == false`
- `crossProcessTransportAvailable == true` for the measured production XPC benchmark path
- `benchmarkContract == .noCurrentBenchmarkClaims`
- `benchmarkHarnessAvailable == true`

This means the v2 core currently does not import `Syphon.framework`, does not publish to or consume from the classic Syphon server directory, and should not be presented as compatible with old or future official Syphon framework releases. Classic interoperability may be designed as a separate bridge target later, but it is not part of the current core contract.

The current branch can generate benchmark reports, but it must not present public v2-vs-classic FPS or speedup claims unless the performance claim gate marks the relevant scope ready. Benchmark comparisons require raw outputs, environment metadata, resolution, pixel format, FPS target, publish FPS, receive FPS, missed frames, repeated reads, latency, CPU, memory, GPU wait, and interpretation limits.

## API Contract Direction

Phase 1 should define the public shape before runtime transport:

- `Syphon26ServerConfiguration`
- `Syphon26ClientConfiguration`
- `Syphon26StreamDescription`
- `Syphon26DiagnosticsSnapshot`
- `Syphon26Error`
- validation helpers that fail before runtime resource allocation

The first API surface must make XPC/control-plane failures explicit enough that an app can show useful status instead of a generic connection failure.

## Phase 1 API Contract

The v2 API contract starts with validation-only types. Constructing a server or client configuration should fail before any Metal, IOSurface, XPC, or launchd resource is touched.

Baseline public types:

- `Syphon26Capabilities`: conservative statement of implemented compatibility and benchmark scope.
- `Syphon26PixelFormat`: supported formats are `bgra8Unorm` and `rgba16Float`; unsupported values are representable so validation can reject them explicitly.
- `Syphon26FrameSize`: validated width and height.
- `Syphon26StreamID`: validated stream identifier.
- `Syphon26ServerConfiguration`: stream name, optional app name, dimensions, pixel format, buffer count, sync mode, and control-plane service name.
- `Syphon26ClientConfiguration`: stream ID, preferred pixel formats, and control-plane service name.
- `Syphon26StreamDescription`: directory-visible metadata for a published stream.
- `Syphon26DiagnosticsSnapshot`: lifecycle, control-plane state, sync state, frame counters, and XPC failure counters.
- `Syphon26Error`: distinct categories for validation, Metal, IOSurface, control-plane, XPC connection, synchronization, and lifecycle failures.

Control-plane service names use a reverse-DNS style form such as `com.syphon26.control-plane`. A generic `xpc connection failed` message is not sufficient for v2 diagnostics; errors and diagnostics must preserve the service name and failure class.

## Phase 3 IOSurface Transport Core

The first transport core is intentionally in-process. It allocates IOSurface-backed Metal textures and validates ring-slot behavior before any XPC service or launchd lifecycle is introduced.

Phase 3 public types:

- `Syphon26IOSurfaceResourceDescriptor`: validated width, height, pixel format, Metal format, IOSurface pixel format, row stride, and texture usage.
- `Syphon26IOSurfaceResource`: owns the IOSurface-backed Metal texture without exposing the raw IOSurface ID as app-facing API.
- `Syphon26RingSlotMetadata`: slot ABI version, slot index, generation, frame ID, state, and publish timestamp.
- `Syphon26TransportStream`: in-process producer/consumer ring that supports `acquireDrawable()`, `presentDrawable(_:)`, `copyLatestFrame(consumerID:)`, metadata snapshots, and diagnostics snapshots.
- `Syphon26TransportDrawable`: writable texture for the producer side of one ring slot.
- `Syphon26TransportFrame`: latest readable texture plus immutable frame snapshot for the consumer side.

Phase 3 semantics:

- The producer publishes into a bounded ring sized by `Syphon26ServerConfiguration.bufferCount`.
- Publishing wraps the ring instead of blocking behind slow consumers.
- `copyLatestFrame` always returns the newest published frame for that consumer.
- Diagnostics count published frames, received frame reads, missed frames, repeated reads, overwritten frames, and unique consumers.
- Stale drawable presentation is rejected as a lifecycle failure.
- Ring metadata rejects unsupported ABI versions before runtime code trusts slot state.

Phase 3 does not implement cross-process handle exchange, XPC service registration, shared-event synchronization, sample apps, classic Syphon compatibility, or benchmarks.

## Phase 4 Control Plane And XPC Lifecycle

The first control-plane layer defines the registration protocol and startup-health classification before sample apps depend on it. The local implementation includes an in-process backend for deterministic tests and a service executable with a health-check handshake for startup verification.

Phase 4 public types:

- `Syphon26ControlPlaneProtocol`: registration, stream listing, consumer listing, cleanup, and health contract shared by fake and future XPC backends.
- `Syphon26ControlPlane`: facade used by app code; currently delegates to the in-process backend by default.
- `Syphon26InProcessControlPlane`: deterministic fake/control-plane backend for tests and early integration.
- `Syphon26ProducerRegistration` and `Syphon26ConsumerRegistration`: process-owned registration records.
- `Syphon26ControlPlaneHealth`: service name, schema version, state, and registration counts.
- `Syphon26XPCStartupReply`: service health-check reply payload.
- `Syphon26XPCStartupVerifier`: classifies startup replies as missing service, stale service, permission mismatch, schema mismatch, or connected.
- `Syphon26XPCControlPlane`: startup-verification wrapper for the future XPC backend.

Phase 4 semantics:

- Producer registration requires the stream description to use the same control-plane service name.
- Consumer registration fails with a control-plane error when the target stream is absent.
- Producer cleanup removes streams owned by a crashed producer and removes dangling consumers for those streams.
- Consumer cleanup removes registrations owned by a crashed consumer without removing the producer stream.
- Startup verification must not collapse distinct missing, stale, permission, and schema failures into a generic `xpc connection failed` state.
- `scripts/verify_control_plane.sh` runs the `Syphon26ControlPlaneService --health-check` executable and verifies the healthy local service payload.

Phase 4 startup verification still does not itself make benchmark claims. Production XPC performance validation is handled by the Phase 7 benchmark harness, which bootstraps a temporary launchd Mach service and exchanges IOSurface XPC objects for measured app-to-app runs.

## Phase 5 Synchronization

Phase 5 adds the frame lifetime and wait contract used by future consumers.

- `Syphon26SynchronizationCoordinator` creates shared-event synchronization when available and falls back to sequence counters when not.
- `Syphon26SynchronizationSignal` records the shared-event value or sequence-counter value for a published frame.
- `Syphon26Frame` exposes `requiresGPUWait`, `encodeWait(on:)`, immediate `close()`, and GPU-completion-based `close(after:)`.
- `Syphon26SynchronizationDiagnostics` reports sync mode, fallback reason, signal count, wait count, and GPU wait time.

## Phase 6 Samples And App UI

The current samples exercise the implemented in-process transport and verified control-plane contract.

- `Syphon26SimpleServer` publishes deterministic frames through `Syphon26TransportStream`.
- `Syphon26SimpleClient` registers a consumer and reads the latest frames through the same verified in-process contract.
- `scripts/run_simple_pair.sh` validates service health, server publish counts, client receive counts, stream registration, consumer registration, and diagnostics.
- `Syphon26SimpleServerApp` and `Syphon26SimpleClientApp` provide AppKit preview windows that cannot become key or main.
- `scripts/export_simple_ui_apps.sh` exports local `.app` bundles under `dist/`.

The sample scope includes the in-process path plus a bounded file-backed cross-process IOSurface smoke. The samples do not claim persistent launchd/XPC service transport.

## Goal 08 Cross-Process IOSurface Smoke

The CLI samples also include a bounded file-backed control-plane smoke path for validating separate-process IOSurface texture opening before the real XPC service is completed.

- `Syphon26FileControlPlane` writes stream metadata and an internal IOSurface reference to a local state file.
- `Syphon26SimpleServer --state-file <path> --hold-seconds <n>` publishes a global IOSurface-backed texture and keeps the resource alive while the client opens it.
- `Syphon26SimpleClient --state-file <path>` waits for the state file and opens the latest texture by using the library API.
- `scripts/run_simple_pair.sh` validates both the in-process path and this separate-process file-backed path.

The raw IOSurface reference is not exposed in public sample output or app-facing frame APIs. This file-backed path is a development smoke test only; production cross-process transport still needs the launchd/XPC service to exchange handles without relying on global IOSurface lookup.

## Phase 7 Benchmarks And Production Readiness

The benchmark harness measures the v2 in-process transport-core path, the file-backed app-to-app benchmark path, and the production launchd Mach XPC app-to-app path, recording interpretation limits with every report.

- `Syphon26Benchmark` emits machine-readable JSON for one benchmark case.
- `Syphon26Benchmark` supports frame-count and duration measurement, fixed-FPS pacing, warmup, and `clear`/`none` render modes.
- `Syphon26AppToAppBenchmark` runs as separate server and client processes over the file-backed Syphon26 IOSurface control-plane smoke path.
- `Syphon26ProductionXPCBenchmark` runs as separate server and client processes over a temporary launchd Mach XPC service, with IOSurface XPC object handoff.
- `scripts/run_benchmark_matrix.py` runs a small matrix and writes `benchmark-reports/latest.json` plus `benchmark-reports/latest.md`.
- `scripts/run_v2_app_to_app_benchmark.py` builds the app-to-app benchmark binary, launches producer and consumer processes, and writes `benchmark-reports/v2-app-to-app/`.
- `scripts/run_production_xpc_benchmark.py` builds the production XPC benchmark and control-plane service binaries, bootstraps a temporary LaunchAgent Mach service, launches producer and consumer processes, and writes `benchmark-reports/production-xpc/`.
- Reports include environment, resolution, pixel format, FPS target, publish FPS, receive FPS, missed frames, repeated reads, latency, CPU time, memory, GPU wait, command, and interpretation limits.
- `scripts/run_performance_claim_gate.py` runs same-session current v2 in-process, current v2 file-backed app-to-app, current v2 production XPC, a temporary `v1` worktree, and the sibling classic Syphon Metal benchmark when available. It writes `benchmark-reports/performance-claim-gate/latest.json` and `.md`.
- `docs/integration.md`, `docs/troubleshooting.md`, and `docs/release_checklist.md` describe the current integration and validation surface.

The claim gate separates internal and public statements:

- `internalV2V1ClaimStatus: ready` permits only internal benchmark wording for the in-process v2-v1 row.
- `publicClassicClaimStatus: ready` is required before making any public v2-vs-classic Syphon benchmark claim.
- `productionXPCClaimStatus: ready` is required before making any production XPC v2-vs-classic Syphon benchmark claim.
- Public-ready wording must name either the measured v2 file-backed app-to-app benchmark path or the measured v2 launchd Mach XPC path with IOSurface XPC object handoff.
- If the v2 production XPC row is missing, not shape-compatible with the classic Syphon app-to-app row, or does not report `controlPlane: launchd-mach-xpc` and `handleTransport: iosurface-xpc-object`, the gate must report `productionXPCClaimStatus: blocked` or `partial` and the blocker text must be used instead of a speed claim.
- 8K/16K production XPC rows can be reported as Syphon26 measurements when producer/client artifacts pass. 8K/16K v2-vs-classic claims remain blocked until the classic benchmark runner supplies matching rows in the same session.

## Non Goals

- Classic Syphon bridge in the core transport.
- OpenGL support.
- Network streaming.
- Screen capture based transport.
- Window capture based transport.
- Polished AppKit UI before core transport validation.
