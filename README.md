# Syphon26 v2

Syphon26 v2 is a clean-room restart of Syphon26: a modern macOS frame-sharing transport for Swift, AppKit, and Metal.

The previous implementation is preserved on the `v1` branch. This branch intentionally starts from a minimal package so the transport, API, validation, and sample applications can be rebuilt without carrying over hidden assumptions from the first prototype.

## Goal-Based Development

This branch uses a control layer before product code is written:

- [AGENTS.md](AGENTS.md): repository rules for future agent work.
- [PLAN.md](PLAN.md): phased development plan.
- [GOALS.md](GOALS.md): copyable bounded goals with allowed edit paths.
- [ACCEPTANCE.md](ACCEPTANCE.md): checkable phase acceptance criteria.
- [VALIDATION.md](VALIDATION.md): required validation commands and claim gate rules.
- [docs/specification.md](docs/specification.md): project-specific transport specification.
- [docs/development_plan.md](docs/development_plan.md): execution strategy and milestones.
- [docs/test_data.md](docs/test_data.md): deterministic fixture and benchmark data plan.

Start future implementation by running only one goal from `GOALS.md`.

## Direction

- Metal-first producer and consumer APIs.
- IOSurface-backed frame exchange.
- Explicit GPU synchronization.
- No CPU texture readback in the hot path.
- No screen capture or window capture as transport.
- No classic Syphon bridge in the core transport.
- Control-plane setup that is explicit, inspectable, and easy to diagnose.

## Current Scope

The `v2` branch currently contains the API contract, validation rules, diagnostics taxonomy, deterministic Metal/IOSurface transport layers, a bounded file-backed cross-process IOSurface smoke path, CLI samples, AppKit sample shells, and benchmark harnesses.

The current compatibility contract is native Syphon26 transport only. The core library does not import `Syphon.framework`, does not participate in the classic Syphon server directory, and does not claim compatibility with old or future official Syphon framework releases. A bridge can be considered later as a separate target after the native transport is stable.

The current benchmark contract is claim-gated. `scripts/run_benchmark_matrix.py` measures the v2 in-process transport-core harness, `scripts/run_v2_app_to_app_benchmark.py` measures a v2 file-backed app-to-app benchmark path, `scripts/run_production_xpc_benchmark.py` measures the launchd Mach XPC path with IOSurface XPC object handoff, and `scripts/run_performance_claim_gate.py` can run same-session v2, temporary `v1`, production XPC, and local classic Syphon measurements. Public v2-vs-classic Syphon benchmark claims are allowed only when the relevant gate marks them ready, and must name the measured app-to-app path. 8K/16K v2-vs-classic wording requires matching same-session classic rows.

The `Syphon26TestPatternServerApp` and `Syphon26TestPatternClientApp` examples provide a small production-XPC visual test pair. The server publishes a GPU-generated pattern with color bars, top/bottom orientation markers, corner markers, and a moving frame tick. The client opens the received IOSurface texture and previews it while reporting observed FPS.

## Why Restart

The first prototype exposed an app-level failure mode around XPC/control-plane setup that made the architecture too difficult to reason about. v2 will rebuild the system from smaller validated layers:

1. Core public API shape.
2. In-process Metal texture validation.
3. Cross-process IOSurface handoff.
4. Explicit control-plane lifecycle.
5. Synchronization and diagnostics.
6. Simple Server and Simple Client apps.
7. Benchmarks against the v1 branch and classic Syphon-style workflows.

See [V2_IMPLEMENTATION_PLAN.md](V2_IMPLEMENTATION_PLAN.md) for the working checklist.

## Build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## License

Syphon26 is released under the BSD 3-Clause License. See [LICENSE](LICENSE).
