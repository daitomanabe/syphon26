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

## Goal 05: Phase 5 Synchronization

### Short Slash Command

```text
/goal Implement Phase 5 from GOALS.md. Follow AGENTS.md. Only edit the allowed Phase 5 paths. Stop when all Phase 5 required commands pass.
```

### Read First

- `AGENTS.md`
- `PLAN.md`
- `ACCEPTANCE.md`
- `docs/specification.md`

### Allowed Edit Paths

- `Sources/Syphon26/Syphon26Frame.swift`
- `Sources/Syphon26/Syphon26Synchronization.swift`
- `Tests/Syphon26Tests/Syphon26SynchronizationTests.swift`
- `docs/specification.md`

### Forbidden Edit Paths

- AppKit UI targets
- benchmark reports
- `Examples/`

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

### Stop Condition

Stop when shared-event wait behavior, sequence-counter fallback, wait diagnostics, and GPU-completion frame lifetime are tested.

### Summary Format

```text
files changed:
tests added:
commands run:
results:
remaining risks:
next recommended goal:
```

## Goal 06: Phase 6 Samples And App UI

### Short Slash Command

```text
/goal Implement Phase 6 from GOALS.md. Follow AGENTS.md and the passive-window skills. Stop when Phase 6 required commands pass.
```

### Read First

- `AGENTS.md`
- `PLAN.md`
- `ACCEPTANCE.md`
- `docs/specification.md`
- `TODO.md`

### Allowed Edit Paths

- `Package.swift`
- `Examples/SimpleServer/main.swift`
- `Examples/SimpleClient/main.swift`
- `Examples/SimpleServerApp/main.swift`
- `Examples/SimpleClientApp/main.swift`
- `Examples/SimpleUIShared/`
- `scripts/run_simple_pair.sh`
- `scripts/export_simple_ui_apps.sh`
- `docs/specification.md`
- `TODO.md`

### Forbidden Edit Paths

- benchmark reports
- classic Syphon bridge targets
- generated app bundles committed by hand

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_simple_pair.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/export_simple_ui_apps.sh
git diff --check
```

### Stop Condition

Stop when the CLI samples smoke-test stream registration, discovery, frame receipt, and diagnostics through the verified control-plane contract, AppKit samples build with passive preview windows, and app bundles can be exported locally.

### Summary Format

```text
files changed:
manual smoke:
commands run:
results:
remaining risks:
next recommended goal:
```

## Goal 07: Phase 7 Benchmarks And Production Readiness

### Short Slash Command

```text
/goal Implement Phase 7 from GOALS.md. Follow AGENTS.md. Do not make unverified performance claims. Stop when the benchmark matrix and docs validate.
```

### Read First

- `AGENTS.md`
- `PLAN.md`
- `ACCEPTANCE.md`
- `docs/specification.md`
- `TODO.md`

### Allowed Edit Paths

- `Package.swift`
- `Sources/Syphon26Benchmark/main.swift`
- `scripts/run_benchmark_matrix.py`
- `docs/integration.md`
- `docs/troubleshooting.md`
- `docs/release_checklist.md`
- `docs/specification.md`
- `TODO.md`

### Forbidden Edit Paths

- classic Syphon bridge targets
- checked-in generated benchmark result folders unless explicitly requested
- unverified FPS comparison claims

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_benchmark_matrix.py
git diff --check
```

### Stop Condition

Stop when the benchmark runner emits machine-readable and human-readable reports with environment metadata, commands, interpretation limits, and explicit placeholders for v1/classic comparisons that are not yet measured.

### Summary Format

```text
files changed:
reports:
commands run:
results:
remaining risks:
next recommended goal:
```

## Goal 08: Cross-Process IOSurface Smoke

### Short Slash Command

```text
/goal Add a bounded cross-process IOSurface smoke path without exposing raw IOSurface IDs as public app API.
```

### Read First

- `AGENTS.md`
- `PLAN.md`
- `ACCEPTANCE.md`
- `docs/specification.md`
- `TODO.md`

### Allowed Edit Paths

- `Sources/Syphon26/Syphon26IOSurfaceResource.swift`
- `Sources/Syphon26/Syphon26FileControlPlane.swift`
- `Examples/SimpleUIShared/`
- `Examples/SimpleServer/main.swift`
- `Examples/SimpleClient/main.swift`
- `scripts/run_simple_pair.sh`
- `Tests/Syphon26Tests/Syphon26FileControlPlaneTests.swift`
- `docs/specification.md`
- `docs/troubleshooting.md`
- `TODO.md`

### Forbidden Edit Paths

- classic Syphon bridge targets
- AppKit window focus/front behavior
- benchmark result claims

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_simple_pair.sh
git diff --check
```

### Stop Condition

Stop when `run_simple_pair.sh` proves both in-process publish/copy and a separate-process IOSurface texture open through the file-backed control-plane state, without exposing raw IOSurface IDs in the sample output.

### Summary Format

```text
files changed:
commands run:
results:
remaining risks:
next recommended goal:
```

## Goal 09: Performance Claim Gate

### Short Slash Command

```text
/goal Make Syphon26 performance claims gateable. Follow AGENTS.md and syphon26-native-transport. Do not publish a classic Syphon speed claim unless the gate marks it ready.
```

### Read First

- `AGENTS.md`
- `ACCEPTANCE.md`
- `docs/specification.md`
- `TODO.md`
- `VALIDATION.md`

### Allowed Edit Paths

- `Sources/Syphon26Benchmark/main.swift`
- `Sources/Syphon26/Syphon26.swift`
- `Tests/Syphon26Tests/Syphon26ScratchTests.swift`
- `scripts/run_benchmark_matrix.py`
- `scripts/run_performance_claim_gate.py`
- `GOALS.md`
- `TODO.md`
- `VALIDATION.md`
- `README.md`
- `docs/specification.md`
- `docs/troubleshooting.md`
- `docs/release_checklist.md`

### Forbidden Edit Paths

- `Sources/Syphon26/` core transport implementation except the `Syphon26.capabilities` snapshot above
- classic Syphon bridge targets
- committed benchmark result folders
- public FPS or speedup claims not emitted as ready by `scripts/run_performance_claim_gate.py`

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_benchmark_matrix.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080p60 --duration 1 --warmup 0.25
git diff --check
```

### Stop Condition

Stop when the claim gate emits JSON and Markdown reports that include same-session v2, v1, and classic Syphon measurements, marks internal v2-v1 claims separately from public classic claims, and blocks any public classic speed claim whose transport scope is not comparable.

### Summary Format

```text
files changed:
reports:
commands run:
results:
claim status:
remaining risks:
next recommended goal:
```

## Goal 10: App-To-App Public Classic Benchmark

### Short Slash Command

```text
/goal Add a v2 app-to-app benchmark harness so the performance claim gate can mark public classic comparisons ready under matched process scope.
```

### Read First

- `AGENTS.md`
- `ACCEPTANCE.md`
- `docs/specification.md`
- `TODO.md`
- `VALIDATION.md`

### Allowed Edit Paths

- `Package.swift`
- `Sources/Syphon26AppToAppBenchmark/`
- `scripts/run_v2_app_to_app_benchmark.py`
- `scripts/run_performance_claim_gate.py`
- `scripts/README.md`
- `GOALS.md`
- `TODO.md`
- `VALIDATION.md`
- `README.md`
- `docs/specification.md`
- `docs/troubleshooting.md`
- `docs/release_checklist.md`

### Forbidden Edit Paths

- `Sources/Syphon26/` core transport implementation
- classic Syphon bridge targets
- AppKit window focus/front behavior
- committed benchmark result folders
- public product-wide speed claims that omit benchmark scope, process count, resolution, pixel format, FPS target, and display state

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_v2_app_to_app_benchmark.py --matrix 1080p60 --duration 1 --warmup 0.25
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080p60 --duration 1 --warmup 0.25 --require-public-claim
git diff --check
```

### Stop Condition

Stop when the v2 app-to-app benchmark emits producer/client JSON artifacts, the performance claim gate compares that app-to-app v2 row against the same-session classic Syphon app-to-app row, and `publicClassicClaimStatus` is `ready` for the required 1080p60 smoke matrix.

### Summary Format

```text
files changed:
reports:
commands run:
results:
claim status:
remaining risks:
next recommended goal:
```

## Goal 11: Broader Public Classic Benchmark Matrix

### Short Slash Command

```text
/goal Extend the public classic performance claim gate from the 1080p60 smoke row to a broader fixed-FPS and max-throughput matrix.
```

### Read First

- `AGENTS.md`
- `ACCEPTANCE.md`
- `docs/specification.md`
- `TODO.md`
- `VALIDATION.md`

### Allowed Edit Paths

- `scripts/run_performance_claim_gate.py`
- `GOALS.md`
- `TODO.md`
- `VALIDATION.md`
- `README.md`
- `docs/specification.md`
- `docs/troubleshooting.md`
- `docs/release_checklist.md`

### Forbidden Edit Paths

- `Sources/Syphon26/` core transport implementation
- classic Syphon bridge targets
- AppKit window focus/front behavior
- committed benchmark result folders
- product-wide speed claims that are not scoped to the measured matrix and benchmark transport

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080p60,4k60,1080pmax,4kmax --duration 2 --warmup 0.5 --require-public-claim
git diff --check
```

### Stop Condition

Stop when the performance claim gate marks `publicClassicClaimStatus: ready` for the broader matrix and emits claimable statements that distinguish fixed-FPS stability evidence from `fpsTarget: 0` throughput evidence.

### Summary Format

```text
files changed:
reports:
commands run:
results:
claim status:
remaining risks:
next recommended goal:
```

## Goal 12: Production XPC Performance Claim Gate

### Short Slash Command

```text
/goal Add a production XPC benchmark path and gate final performance claims, including 8K and 16K matrices.
```

### Read First

- `AGENTS.md`
- `ACCEPTANCE.md`
- `docs/specification.md`
- `TODO.md`
- `VALIDATION.md`

### Allowed Edit Paths

- `Package.swift`
- `Sources/Syphon26/Syphon26.swift`
- `Sources/Syphon26/Syphon26ProductionXPCTransport.swift`
- `Sources/Syphon26ControlPlaneService/main.swift`
- `Sources/Syphon26ProductionXPCBenchmark/`
- `Tests/Syphon26Tests/Syphon26ScratchTests.swift`
- `scripts/run_production_xpc_benchmark.py`
- `scripts/run_v2_app_to_app_benchmark.py`
- `scripts/run_performance_claim_gate.py`
- `scripts/README.md`
- `GOALS.md`
- `TODO.md`
- `VALIDATION.md`
- `README.md`
- `docs/specification.md`
- `docs/troubleshooting.md`
- `docs/release_checklist.md`

### Forbidden Edit Paths

- classic Syphon bridge targets
- committed benchmark result folders
- AppKit window focus/front behavior
- product-wide speed claims that omit production XPC scope, process count, resolution, pixel format, FPS target, render mode, display state, and classic comparison availability

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_production_xpc_benchmark.py --matrix 1080p60,4k60,8k60,16k60 --duration 1 --warmup 0.25
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_production_xpc_benchmark.py --matrix 1080pmax,4kmax,8kmax,16kmax --duration 1 --warmup 0.25
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080p60,4k60,8k60,16k60 --duration 1 --warmup 0.25
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080pmax,4kmax,8kmax,16kmax --duration 1 --warmup 0.25
git diff --check
```

### Stop Condition

Stop when production XPC app-to-app benchmark artifacts prove launchd Mach XPC startup, IOSurface XPC object handoff, producer/client frame exchange, 8K/16K allocation, and claim-gate status. Production XPC vs classic claims are ready only for rows with matching same-session classic Syphon measurements.

### Summary Format

```text
files changed:
reports:
commands run:
results:
claim status:
8K/16K status:
remaining risks:
next recommended goal:
```

## Goal 13: 8K/16K Classic Claim Unblock

### Short Slash Command

```text
/goal Unblock 8K/16K production XPC v2-vs-classic claims by adding matching classic benchmark matrices and rerunning the claim gate.
```

### Read First

- `AGENTS.md`
- `TODO.md`
- `VALIDATION.md`
- `docs/specification.md`

### Allowed Edit Paths

- `scripts/run_performance_claim_gate.py`
- `GOALS.md`
- `TODO.md`
- `VALIDATION.md`
- `README.md`
- `docs/specification.md`
- `docs/troubleshooting.md`
- `docs/release_checklist.md`
- sibling classic benchmark runner: `../Syphon-Framework/Examples/SyphonMetalBenchmark/scripts/run_benchmark.py`

### Forbidden Edit Paths

- Syphon26 product transport code
- classic Syphon framework product code
- committed benchmark result folders
- broader public claims that are not emitted ready by the same-session gate

### Required Commands

```bash
python3 -m py_compile ../Syphon-Framework/Examples/SyphonMetalBenchmark/scripts/run_benchmark.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 ../Syphon-Framework/Examples/SyphonMetalBenchmark/scripts/run_benchmark.py --transport syphon --matrix 8k60,16k60 --duration 0.25 --warmup 0.1 --clients 1 --poll-us 0 --csv-every 100 --no-build --output-dir /tmp/syphon-classic-8k16k-smoke
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 8k60,16k60 --duration 1 --warmup 0.25 --require-production-xpc-claim
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 8kmax,16kmax --duration 1 --warmup 0.25 --require-production-xpc-claim
python3 -m py_compile scripts/run_performance_claim_gate.py
git diff --check
```

### Stop Condition

Stop when the classic runner accepts matching 8K/16K matrix names, the Syphon26 claim gate marks `productionXPCClaimStatus: ready` for fixed-FPS and max-throughput 8K/16K rows, and both affected repositories are committed and pushed.

### Summary Format

```text
files changed:
reports:
commands run:
results:
8K/16K claim status:
commits:
remaining risks:
```

## Goal 14: Test Pattern Server And Client Apps

### Short Slash Command

```text
/goal Add small Syphon26 test-pattern server/client apps for visual frame-rate, orientation, and color checks.
```

### Read First

- `AGENTS.md`
- `TODO.md`
- `VALIDATION.md`
- `docs/specification.md`

### Allowed Edit Paths

- `Package.swift`
- `Examples/TestPatternShared/`
- `Examples/TestPatternServerApp/`
- `Examples/TestPatternClientApp/`
- `scripts/run_test_pattern_pair.sh`
- `scripts/export_simple_ui_apps.sh`
- `scripts/README.md`
- `GOALS.md`
- `TODO.md`
- `VALIDATION.md`
- `README.md`
- `docs/integration.md`
- `docs/specification.md`
- `docs/troubleshooting.md`
- `docs/release_checklist.md`

### Forbidden Edit Paths

- classic Syphon bridge targets
- production benchmark result folders
- Syphon26 transport core unless a compile failure proves a narrow helper is required
- AppKit windows that steal focus or become key/main
- CPU texture readback, screen capture, window capture, or preview capture as transport

### Required Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --product Syphon26TestPatternServerApp
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --product Syphon26TestPatternClientApp
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --duration 1 --fps 60 --width 1280 --height 720 --orientation normal
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --duration 0.5 --fps 30 --width 640 --height 360 --orientation flipY
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --duration 0.5 --fps 30 --width 640 --height 360 --orientation rotate180
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26TestPatternServerApp --smoke --help-json
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26TestPatternClientApp --smoke --help-json
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
! rg -n "makeKeyAndOrderFront|orderFrontRegardless|orderFront\\(|orderOut\\(|screenSaver|floating|NSApp\\.activate|NSApplication\\.shared\\.activate|activate\\(ignoringOtherApps" Examples/TestPatternShared Examples/TestPatternServerApp Examples/TestPatternClientApp
! rg -n "^import Syphon$|SyphonServer|SyphonClient|SyphonMetalServer|SyphonServerDirectory|CGWindowListCreateImage|CGDisplayStream|getBytes\\(|replaceRegion\\(|CVPixelBufferLockBaseAddress|vImage" Examples/TestPatternShared Examples/TestPatternServerApp Examples/TestPatternClientApp scripts docs README.md
git diff --check
```

Before commit/push, run the `github-push-privacy-guard` absolute-path scan against README, docs, scripts, control files, package files, source, tests, and examples. It must produce no matches.

### Stop Condition

Stop when the server app publishes a GPU-generated test pattern over production XPC, the client app opens and previews the received IOSurface texture, smoke validation proves normal/`flipY`/`rotate180` runs with expected frame-count gates, texture opening, requested dimensions/FPS, requested orientation, production-XPC scope, and passive-window checks, and the repository is committed and pushed.

### Summary Format

```text
files changed:
apps:
commands run:
results:
pattern checks:
commit:
remaining risks:
```
