# Syphon26

Syphon26 is a modern, from-scratch frame sharing transport for current macOS, Swift, AppKit, and Metal workflows.

The project is inspired by the original Syphon idea of simple app-to-app frame sharing for live visuals, but the first implementation is a new native transport built around current Apple APIs: Metal, IOSurface, CoreVideo, XPC, and explicit GPU synchronization.

## Status

This repository contains the first Syphon26 native-transport implementation. The API and internal transport are usable for Swift/AppKit/Metal experiments and sample apps, but they are still developer-preview surfaces and may change before a stable release.

Current direction:

- Metal-first frame sharing.
- No CPU texture readback in the fast path.
- IOSurface-backed ring buffers for producer/consumer sharing.
- Latest-frame semantics for live visuals, where slow consumers drop old frames instead of blocking producers.
- `MTLSharedEvent` synchronization when available, with a sequence-counter fallback.
- Explicit format metadata for color primaries, transfer function, pixel format, alpha mode, and timestamps.
- No classic Syphon bridge in the first implementation phase.

## Relationship To Syphon

Syphon26 is not a fork of the original Syphon Framework. It is intended as a clean, scratch implementation designed for the 2026-era macOS graphics stack.

The first phase does not aim to provide classic Syphon compatibility. It focuses on the Syphon26 native transport itself. Any future bridge or compatibility layer should be a separate adapter around the native transport, not part of the core design.

The original Syphon Framework was created by bangnoise (Tom Butterworth) and vade (Anton Marini), with later Metal work by other contributors. Syphon26 does not claim endorsement by the original Syphon Project or its contributors.

If any source file from the original Syphon Framework is imported in the future, that file must retain its original copyright and license notice. New Syphon26 source files should use the license in this repository.

## Why A New Implementation

The existing Syphon design predates much of the modern macOS graphics stack. A scratch implementation gives us room to design around:

- Metal command-buffer ownership.
- Explicit GPU event synchronization.
- Secure IOSurface and shared-memory handoff.
- Lower per-frame IPC overhead.
- Modern Swift and Objective-C API surfaces.
- HDR and high-precision pixel formats.
- Repeatable performance benchmarks.

The target is to make a modern transport that can outperform classic Syphon-style pipelines in Metal-native local workflows. Classic Syphon interoperability is intentionally deferred until the Syphon26 core transport is stable.

## Initial Production Plan

The first production implementation should focus only on the Syphon26 native transport:

1. Public Objective-C and Swift-friendly APIs for a Metal server and client.
2. A private, versioned shared-state ABI.
3. Secure XPC handoff for IOSurface references and `MTLSharedEventHandle`.
4. BGRA8 baseline support first, then RGBA16F/HDR support.
5. Diagnostics for published frames, observed frames, missed frames, repeated reads, consumer lag, producer stalls, GPU waits, and sync fallback reasons.
6. Producer and consumer sample apps that use only the Syphon26 transport.
7. Benchmark gates against classic Syphon at 1080p60, 4K60, 4K120, RGBA16F, and max-throughput workloads.

See [NATIVE_TRANSPORT_TODO.md](NATIVE_TRANSPORT_TODO.md) for the implementation checklist.
See [API_DESIGN.md](API_DESIGN.md) for the Phase 1 `Syphon26Server` / `Syphon26Client` API surface.
See [INTEGRATION.md](INTEGRATION.md) for SwiftPM app integration and the control-plane service setup.
See [VALIDATION_BENCHMARK_PLAN.md](VALIDATION_BENCHMARK_PLAN.md) for validation and classic Syphon comparison benchmarks.
See [BENCHMARK_RESULTS_20260524.md](BENCHMARK_RESULTS_20260524.md) for the first MVP benchmark checkpoint.
See [FORMAT_SUPPORT.md](FORMAT_SUPPORT.md) for supported formats and deferred multi-plane requirements.

## Repository Layout

- `Sources/Syphon26/`: core Swift implementation for server, client, control plane, IOSurface-backed transport, diagnostics, and synchronization.
- `include/Syphon26/`: Objective-C-facing API headers that mirror the intended public wrapper surface.
- `Examples/`: minimal simple server/client and compile-only API examples for embedding checks.
- `Examples/SimpleServerApp` and `Examples/SimpleClientApp`: AppKit UI samples for configuring transport settings and watching communication diagnostics.
- `Samples/`: app-to-app producer, consumer, and control-plane service executables used by validation scripts.
- `Sources/Syphon26Benchmark/`: in-process benchmark harness for upper-bound transport measurements.
- `scripts/`: validation, sample-pair, benchmark, and stability runners.
- `benchmark-reports/`: committed benchmark summaries for app-to-app and stability checkpoints.
- `skills/syphon26-native-transport/`: reusable Codex skill for integrating Syphon26 into another Swift/AppKit/Metal app.

## Reusable Skill

The repo includes a Codex skill at [skills/syphon26-native-transport/SKILL.md](skills/syphon26-native-transport/SKILL.md). Use it when asking an agent to integrate Syphon26 into a different implementation.

The skill encodes the core integration rules: use `Syphon26Server` and `Syphon26Client` directly, share a launchd-managed `Syphon26ControlPlaneService`, keep frames on Metal/IOSurface, honor GPU synchronization with `frame.encodeWait(on:)`, and avoid classic `Syphon.framework`, bridge APIs, CPU readback, screen capture, or window capture in the frame loop.

## Native Samples

Minimal examples for embedding into other Swift/Metal apps:

```bash
scripts/run_simple_pair.sh --duration 5 --width 1920 --height 1080 --fps 60
```

The sample pair runs a launchd-managed Syphon26 control plane plus separate producer and consumer processes:

```bash
scripts/run_bgra8_sample_pair.sh --duration 3 --width 1920 --height 1080 --fps 60
scripts/run_rgba16f_sample_pair.sh --duration 3 --width 1920 --height 1080 --fps 60
```

For interactive configuration, preview, and communication status, run the AppKit UI pair:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_simple_ui_pair.sh
```

To export double-clickable AppKit bundles into the local development tree at `dist/Syphon26 Apps`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/export_simple_ui_apps.sh
```

## Phase 1 Principles

- Keep BGRA8 as the default low-risk format.
- Keep server names stable.
- Publish one final composited texture per frame.
- Do not use screen or window capture as a transport.
- Do not depend on a preview window being visible for publishing.
- Keep OpenGL out of the core transport.
- Defer classic Syphon compatibility bridges.
- Make fallback modes visible in diagnostics.

## License

Syphon26 is released under the BSD 3-Clause License. See [LICENSE](LICENSE).
