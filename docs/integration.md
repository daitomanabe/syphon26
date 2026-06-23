# Integration Guide

Syphon26 v2 is currently a native-only Metal transport. It does not import or bridge `Syphon.framework`.

## Current Integration Surface

- Use `Syphon26ServerConfiguration` to validate stream names, dimensions, pixel format, buffer count, sync mode, and control-plane service name.
- Use `Syphon26TransportStream` for the current in-process transport core.
- Use `Syphon26ControlPlane` or `Syphon26InProcessControlPlane` for deterministic stream and consumer registration in tests.
- Use the production XPC benchmark path when validating launchd Mach XPC startup and IOSurface XPC object handoff.
- Use `Syphon26SynchronizationCoordinator` and `Syphon26Frame` to encode shared-event waits when available, with sequence-counter fallback when not.

## Samples

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26SimpleServer --frames 6 --json
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26SimpleClient --frames 6 --json
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_simple_pair.sh
```

The sample scope includes an in-process publish/copy path plus a bounded file-backed cross-process IOSurface open smoke. Production XPC handle exchange is validated by `scripts/run_production_xpc_benchmark.py`, which bootstraps a temporary launchd Mach service and exchanges IOSurface XPC objects between producer and consumer processes.

## AppKit Preview Apps

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/export_simple_ui_apps.sh
```

The AppKit samples use passive preview windows that cannot become key or main. Transport state is created outside focus-dependent callbacks.

## Test Pattern Apps

Use the Test Pattern pair to validate frame rate, top/bottom orientation, corner orientation, and color bars over the production XPC path:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --duration 1 --fps 60 --width 1280 --height 720 --orientation normal
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --duration 0.5 --fps 30 --width 640 --height 360 --orientation flipY
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --duration 0.5 --fps 30 --width 640 --height 360 --orientation rotate180
```

For manual visual inspection, keep the temporary launchd Mach XPC service alive while both passive AppKit windows are open:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --gui --fps 60 --width 1280 --height 720
```

The server app publishes a GPU-generated IOSurface-backed pattern through production XPC. The client app opens the received IOSurface texture and previews it with Metal. Smoke `status: ok` requires expected server frame count, minimum client observed frames, requested orientation, requested dimensions/FPS, production XPC scope, and passive-window flags.
