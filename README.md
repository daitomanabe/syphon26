# Syphon26

Syphon26 is a modern, from-scratch implementation of a Syphon-compatible frame sharing system for current macOS, Swift, AppKit, and Metal workflows.

The goal is to keep the practical interoperability that made Syphon useful for live visuals, while rebuilding the transport around current Apple APIs: Metal, IOSurface, CoreVideo, XPC, and explicit GPU synchronization.

## Status

This repository is the starting point for a new implementation. The API and internal transport are not stable yet.

Current direction:

- Metal-first frame sharing.
- No CPU texture readback in the fast path.
- IOSurface-backed ring buffers for producer/consumer sharing.
- Latest-frame semantics for live visuals, where slow consumers drop old frames instead of blocking producers.
- `MTLSharedEvent` synchronization when available, with a sequence-counter fallback.
- Explicit format metadata for color primaries, transfer function, pixel format, alpha mode, and timestamps.
- Bridges for compatibility with existing Syphon applications.

## Relationship To Syphon

Syphon26 is not a fork of the original Syphon Framework. It is intended as a clean, scratch implementation designed for the 2026-era macOS graphics stack.

The project aims to provide compatibility paths for existing Syphon workflows where practical. Any bridge or compatibility layer should be clearly separated from the new Metal-native transport.

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

The target is not to remove classic Syphon compatibility. The target is to make a modern transport that can coexist with it and outperform it in Metal-native local pipelines.

## Initial Production Plan

The first production implementation should focus on:

1. Public Objective-C and Swift-friendly APIs for a Metal server and client.
2. A private, versioned shared-state ABI.
3. Secure XPC handoff for IOSurface references and `MTLSharedEventHandle`.
4. BGRA8 compatibility first, then RGBA16F/HDR support.
5. Diagnostics for published frames, observed frames, missed frames, repeated reads, consumer lag, producer stalls, GPU waits, and sync fallback reasons.
6. Syphon-to-Syphon26 and Syphon26-to-Syphon bridges after the native transport is stable.
7. Benchmark gates against classic Syphon at 1080p60, 4K60, 4K120, RGBA16F, and max-throughput workloads.

## Compatibility Principles

- Keep BGRA8 as the default compatibility format.
- Keep server names stable.
- Publish one final composited texture per frame.
- Do not use screen or window capture as a transport.
- Do not depend on a preview window being visible for publishing.
- Treat OpenGL as a compatibility adapter, not the core transport.
- Make fallback modes visible in diagnostics.

## License

Syphon26 is released under the BSD 3-Clause License. See [LICENSE](LICENSE).

