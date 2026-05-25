# PLAN.md

## Objective

Rebuild Syphon26 v2 from a minimal, testable core into a reliable Metal-first frame-sharing transport for macOS. The plan must prevent broad implementation drift and make XPC/control-plane failures diagnosable before sample apps depend on them.

## Phase 1: Public API Contract And Validation Core

### Phase Objective

Create the smallest testable core: public configuration types, stream metadata, diagnostics snapshots, error taxonomy, and pure validation logic. No transport runtime is implemented in this phase.

### Allowed Scope

- API types and validation-only library code under `Sources/Syphon26/`.
- Unit tests under `Tests/Syphon26Tests/`.
- Documentation updates that describe the API contract.

### Out Of Scope

- Metal rendering implementation.
- IOSurface allocation.
- XPC or launchd service implementation.
- AppKit UI.
- CLI sample apps.
- Benchmarks.
- Classic Syphon compatibility.

### Files Or Modules To Create

- `Sources/Syphon26/Syphon26Types.swift`
- `Sources/Syphon26/Syphon26Error.swift`
- `Sources/Syphon26/Syphon26Configuration.swift`
- `Sources/Syphon26/Syphon26StreamDescription.swift`
- `Sources/Syphon26/Syphon26Diagnostics.swift`
- `Tests/Syphon26Tests/Syphon26APITests.swift`

### Acceptance Criteria

See `ACCEPTANCE.md` Phase 1.

### Commands To Run

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

### Risks

- API may become too implementation-specific before the runtime exists.
- Diagnostics may miss the XPC/control-plane failure classes that caused the restart.
- Validation may be too weak if invalid sizes, names, formats, and service identifiers are not tested.

### Handoff To Next Phase

Proceed only after API validation tests pass and error cases are explicit enough to guide runtime implementation.

## Phase 2: In-Process Metal Validation

### Phase Objective

Validate deterministic Metal texture creation, format metadata, and GPU-only frame checks without cross-process transport.

### Allowed Scope

- Metal helper code.
- In-process tests.
- Deterministic fixture descriptions.

### Out Of Scope

- IOSurface sharing.
- XPC.
- AppKit previews.

### Files Or Modules To Create

- `Sources/Syphon26/Syphon26PixelFormat.swift`
- `Sources/Syphon26/Syphon26MetalValidation.swift`
- `Tests/Syphon26Tests/Syphon26MetalValidationTests.swift`
- `fixtures/metal/README.md`

### Acceptance Criteria

See `ACCEPTANCE.md` Phase 2.

### Commands To Run

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

### Risks

- Hardware-dependent Metal behavior may require conditional test skips.
- GPU validation must not fall back to CPU readback as the transport design.

### Handoff To Next Phase

Proceed when BGRA8 and RGBA16F in-process texture behavior is testable and deterministic.

## Phase 3: IOSurface Transport Core

### Phase Objective

Implement IOSurface-backed frame resources and slot metadata without XPC. Use an in-process fake control plane for deterministic tests.

### Allowed Scope

- IOSurface resource wrappers.
- Ring slot metadata.
- Latest-frame and bounded-latency semantics.
- In-process fake transport tests.

### Out Of Scope

- Launchd/XPC service.
- AppKit UI.
- Benchmarks against external apps.

### Files Or Modules To Create

- `Sources/Syphon26/Syphon26IOSurfaceResource.swift`
- `Sources/Syphon26/Syphon26RingSlotMetadata.swift`
- `Sources/Syphon26/Syphon26TransportStream.swift`
- `Tests/Syphon26Tests/Syphon26TransportCoreTests.swift`

### Acceptance Criteria

See `ACCEPTANCE.md` Phase 3.

### Commands To Run

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

### Risks

- ABI metadata can become difficult to migrate if versioning is not added early.
- Slot overwrite semantics can hide consumer lag unless diagnostics are explicit.

### Handoff To Next Phase

Proceed when in-process producer/consumer semantics are tested without XPC.

## Phase 4: Control Plane And XPC Lifecycle

### Phase Objective

Implement the cross-process control plane only after the protocol is tested in-process.

### Allowed Scope

- Control-plane protocol.
- In-process fake control plane.
- XPC service executable.
- Launchd bootstrap scripts.
- Startup verification command.
- Failure classification tests.

### Out Of Scope

- AppKit previews.
- Performance tuning.
- Classic Syphon bridge.

### Files Or Modules To Create

- `Sources/Syphon26/Syphon26ControlPlane.swift`
- `Sources/Syphon26/Syphon26ControlPlaneProtocol.swift`
- `Sources/Syphon26/Syphon26XPCControlPlane.swift`
- `Sources/Syphon26ControlPlaneService/main.swift`
- `scripts/verify_control_plane.sh`
- `Tests/Syphon26Tests/Syphon26ControlPlaneTests.swift`

### Acceptance Criteria

See `ACCEPTANCE.md` Phase 4.

### Commands To Run

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/verify_control_plane.sh
git diff --check
```

### Risks

- Mach service names, stale services, and permission mismatches can produce vague connection failures.
- Launchd lifecycle failures must be visible before sample apps are built.

### Handoff To Next Phase

Proceed when missing, stale, mismatched, and healthy control-plane states have distinct validation outcomes.

## Phase 5: Synchronization

### Phase Objective

Add explicit GPU synchronization with `MTLSharedEvent` and a visible fallback path.

### Allowed Scope

- Shared event handle exchange.
- Consumer wait encoding API.
- Sequence-counter fallback.
- Wait-time diagnostics.

### Out Of Scope

- UI.
- Benchmarks.

### Files Or Modules To Create

- `Sources/Syphon26/Syphon26Frame.swift`
- `Sources/Syphon26/Syphon26Synchronization.swift`
- `Tests/Syphon26Tests/Syphon26SynchronizationTests.swift`

### Acceptance Criteria

See `ACCEPTANCE.md` Phase 5.

### Commands To Run

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

### Risks

- Closing frames before GPU work completes can create intermittent failures.
- Fallback mode can hide sync regressions unless diagnostics expose it.

### Handoff To Next Phase

Proceed when frame lifetime and wait behavior are tested.

## Phase 6: Samples And App UI

### Phase Objective

Build CLI and AppKit samples only after core transport and control-plane lifecycle are validated.

### Allowed Scope

- CLI Simple Server and Simple Client.
- AppKit Simple Server and Simple Client.
- Preview rendering that is separate from transport correctness.
- App export script.

### Out Of Scope

- Benchmark claims.
- Classic Syphon bridge.

### Files Or Modules To Create

- `Examples/SimpleServer/main.swift`
- `Examples/SimpleClient/main.swift`
- `Examples/SimpleServerApp/main.swift`
- `Examples/SimpleClientApp/main.swift`
- `Examples/SimpleUIShared/`
- `scripts/run_simple_pair.sh`
- `scripts/export_simple_ui_apps.sh`

### Acceptance Criteria

See `ACCEPTANCE.md` Phase 6.

### Commands To Run

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_simple_pair.sh
git diff --check
```

### Risks

- Preview rendering can be mistaken for transport correctness.
- AppKit timing can make animation look broken even when publish/receive is healthy.

### Handoff To Next Phase

Proceed when sample apps prove stream discovery, connection, frame receipt, and diagnostics under a verified control plane.

## Phase 7: Benchmarks And Production Readiness

### Phase Objective

Measure v2 against v1 and classic Syphon-style workflows, then prepare the stable integration surface.

### Allowed Scope

- Benchmark harness.
- Benchmark reports.
- Integration guide.
- Troubleshooting guide.
- Release checklist.

### Out Of Scope

- Unverified performance claims.
- Feature expansion not covered by benchmark acceptance criteria.

### Files Or Modules To Create

- `Sources/Syphon26Benchmark/main.swift`
- `scripts/run_benchmark_matrix.py`
- `benchmark-reports/`
- `docs/integration.md`
- `docs/troubleshooting.md`
- `docs/release_checklist.md`

### Acceptance Criteria

See `ACCEPTANCE.md` Phase 7.

### Commands To Run

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_benchmark_matrix.py
git diff --check
```

### Risks

- v1 comparison can be misleading if test conditions differ.
- Classic Syphon comparison needs an explicitly documented environment.

### Handoff To Next Phase

Proceed only after benchmark reports include environment, commands, raw results, and interpretation limits.
