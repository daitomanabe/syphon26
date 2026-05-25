# GOALS.md

Each goal is intentionally bounded. Run one goal at a time and stop at its stop condition.

## Goal 01: Phase 1 API Contract And Validation Core

### Short Slash Command

```text
/goal Implement Phase 1 from GOALS.md. Follow AGENTS.md. Only edit the allowed Phase 1 paths. Stop when all Phase 1 required commands pass.
```

### Read First

- `AGENTS.md`
- `PLAN.md`
- `ACCEPTANCE.md`
- `docs/specification.md`
- `docs/development_plan.md`
- `V2_IMPLEMENTATION_PLAN.md`

### Allowed Edit Paths

- `Sources/Syphon26/Syphon26.swift`
- `Sources/Syphon26/Syphon26Types.swift`
- `Sources/Syphon26/Syphon26Error.swift`
- `Sources/Syphon26/Syphon26Configuration.swift`
- `Sources/Syphon26/Syphon26StreamDescription.swift`
- `Sources/Syphon26/Syphon26Diagnostics.swift`
- `Tests/Syphon26Tests/Syphon26ScratchTests.swift`
- `Tests/Syphon26Tests/Syphon26APITests.swift`
- `docs/specification.md`
- `docs/development_plan.md`

### Forbidden Edit Paths

- `Examples/`
- `Samples/`
- `scripts/`
- `fixtures/`
- `benchmark-reports/`
- `benchmark-results/`
- `dist/`
- `.build/`
- XPC service targets
- AppKit UI targets

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

### Stop Condition

Stop when Phase 1 acceptance criteria in `ACCEPTANCE.md` pass and the API contract distinguishes validation errors from future Metal, IOSurface, XPC/control-plane, synchronization, and lifecycle failures.

### Summary Format

```text
files changed:
tests added:
commands run:
results:
acceptance status:
remaining risks:
next recommended goal:
```

## Goal 02: Phase 2 In-Process Metal Validation

### Short Slash Command

```text
/goal Implement Phase 2 from GOALS.md. Follow AGENTS.md. Only edit the allowed Phase 2 paths. Stop when all Phase 2 required commands pass.
```

### Read First

- `AGENTS.md`
- `PLAN.md`
- `ACCEPTANCE.md`
- `docs/specification.md`
- `docs/test_data.md`

### Allowed Edit Paths

- `Sources/Syphon26/Syphon26PixelFormat.swift`
- `Sources/Syphon26/Syphon26MetalValidation.swift`
- `Tests/Syphon26Tests/Syphon26MetalValidationTests.swift`
- `fixtures/metal/`
- `docs/test_data.md`

### Forbidden Edit Paths

- XPC service targets
- AppKit UI targets
- benchmark reports
- `Examples/`

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

### Stop Condition

Stop when deterministic in-process Metal validation exists for the baseline formats and no cross-process transport is implemented.

### Summary Format

```text
files changed:
tests added:
commands run:
results:
remaining risks:
next recommended goal:
```

## Goal 03: Phase 3 IOSurface Transport Core

### Short Slash Command

```text
/goal Implement Phase 3 from GOALS.md. Follow AGENTS.md. Only edit the allowed Phase 3 paths. Stop when all Phase 3 required commands pass.
```

### Read First

- `AGENTS.md`
- `PLAN.md`
- `ACCEPTANCE.md`
- `docs/specification.md`
- `docs/development_plan.md`

### Allowed Edit Paths

- `Sources/Syphon26/Syphon26IOSurfaceResource.swift`
- `Sources/Syphon26/Syphon26RingSlotMetadata.swift`
- `Sources/Syphon26/Syphon26TransportStream.swift`
- `Tests/Syphon26Tests/Syphon26TransportCoreTests.swift`
- `docs/specification.md`

### Forbidden Edit Paths

- XPC service targets
- AppKit UI targets
- benchmark reports
- `Examples/`

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

### Stop Condition

Stop when IOSurface-backed in-process producer/consumer semantics are tested without adding XPC.

### Summary Format

```text
files changed:
tests added:
commands run:
results:
remaining risks:
next recommended goal:
```

## Goal 04: Phase 4 Control Plane And XPC Lifecycle

### Short Slash Command

```text
/goal Implement Phase 4 from GOALS.md. Follow AGENTS.md. Only edit the allowed Phase 4 paths. Stop when all Phase 4 required commands pass.
```

### Read First

- `AGENTS.md`
- `PLAN.md`
- `ACCEPTANCE.md`
- `docs/specification.md`

### Allowed Edit Paths

- `Package.swift`
- `Sources/Syphon26/Syphon26ControlPlane.swift`
- `Sources/Syphon26/Syphon26ControlPlaneProtocol.swift`
- `Sources/Syphon26/Syphon26XPCControlPlane.swift`
- `Sources/Syphon26ControlPlaneService/`
- `scripts/verify_control_plane.sh`
- `Tests/Syphon26Tests/Syphon26ControlPlaneTests.swift`
- `docs/specification.md`

### Forbidden Edit Paths

- AppKit UI targets
- benchmark reports
- `Examples/SimpleServerApp/`
- `Examples/SimpleClientApp/`

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/verify_control_plane.sh
git diff --check
```

### Stop Condition

Stop when missing service, stale service, permission mismatch, schema mismatch, and healthy control-plane states produce distinct verification outcomes.

### Summary Format

```text
files changed:
tests added:
commands run:
results:
remaining risks:
next recommended goal:
```
