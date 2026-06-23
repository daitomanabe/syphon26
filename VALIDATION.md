# VALIDATION.md

Run these commands from the Syphon26 repository root unless noted otherwise.

## Required For Goal 14

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

Before commit/push, also run the `github-push-privacy-guard` absolute-path scan against README, docs, scripts, control files, package files, source, tests, and examples. It must produce no matches.

## Test Pattern Acceptance

- Server pattern generation uses Metal and publishes over production XPC.
- Client opens the received IOSurface-backed texture and previews it with Metal.
- The pattern includes color bars, top/bottom orientation markers, corner markers, and a moving frame tick.
- Smoke output includes `status: ok`, `expectedFrames`, `minClientObservedFrames`, and a `checks` object.
- Smoke `checks` must require production XPC scope, texture opening, expected server frame count, minimum client observed frames, requested dimensions/FPS, requested orientation, and passive-window flags.
- The required smoke matrix must cover `normal`, `flipY`, and `rotate180`.
- Preview windows are passive: they must not become key/main or activate the app.

## Manual Run

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --gui --duration 0 --fps 60 --width 1280 --height 720 --orientation normal
```

For visual orientation checks, rerun with `--orientation flipY` and `--orientation rotate180`. The script bootstraps a temporary launchd Mach XPC service, opens the server and client apps, and prints the service name and log directory.
