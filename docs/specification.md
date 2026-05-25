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
- BGRA8 is the baseline format.
- RGBA16F/HDR support is planned after baseline validation.
- No CPU readback in the transport hot path.
- No screen or window capture as transport.
- No AppKit preview dependency for publishing or receiving frames.
- No classic Syphon compatibility in the v2 core.

## API Contract Direction

Phase 1 should define the public shape before runtime transport:

- `Syphon26ServerConfiguration`
- `Syphon26ClientConfiguration`
- `Syphon26StreamDescription`
- `Syphon26DiagnosticsSnapshot`
- `Syphon26Error`
- validation helpers that fail before runtime resource allocation

The first API surface must make XPC/control-plane failures explicit enough that an app can show useful status instead of a generic connection failure.

## Non Goals

- Classic Syphon bridge in the core transport.
- OpenGL support.
- Network streaming.
- Screen capture based transport.
- Window capture based transport.
- Polished AppKit UI before core transport validation.
