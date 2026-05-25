# Syphon26 v2

Syphon26 v2 is a clean-room restart of Syphon26: a modern macOS frame-sharing transport for Swift, AppKit, and Metal.

The previous implementation is preserved on the `v1` branch. This branch intentionally starts from a minimal package so the transport, API, validation, and sample applications can be rebuilt without carrying over hidden assumptions from the first prototype.

## Direction

- Metal-first producer and consumer APIs.
- IOSurface-backed frame exchange.
- Explicit GPU synchronization.
- No CPU texture readback in the hot path.
- No screen capture or window capture as transport.
- No classic Syphon bridge in the core transport.
- Control-plane setup that is explicit, inspectable, and easy to diagnose.

## Why Restart

The first prototype proved that high-rate publish/receive is possible, but the app-level failure mode around XPC/control-plane setup made the architecture too difficult to reason about. v2 will rebuild the system from smaller validated layers:

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
