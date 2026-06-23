# TODO

## Active Goal

Add small Syphon26 test-pattern server/client AppKit apps that send and receive a GPU-generated pattern for frame-rate, top/bottom orientation, and color verification.

## Checklist

- [x] Add Goal 14 for test-pattern server/client apps.
- [x] Add SwiftPM products and shared TestPattern target.
- [x] Implement the server app with GPU-generated color/orientation/frame-tick pattern publishing over production XPC.
- [x] Implement the client app with production XPC receive, passive Metal preview, and received-FPS telemetry.
- [x] Add a smoke script that bootstraps the XPC service, runs server/client, and verifies frame receipt.
- [x] Update docs and export script.
- [x] Run build, smoke, test, focus, forbidden-pattern, privacy, and diff checks.
- [x] Commit and push.

## Validation Matrix

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --product Syphon26TestPatternServerApp`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --product Syphon26TestPatternClientApp`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --duration 1 --fps 60 --width 1280 --height 720`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26TestPatternServerApp --smoke --help-json`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26TestPatternClientApp --smoke --help-json`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `! rg -n "makeKeyAndOrderFront|orderFrontRegardless|orderFront\\(|orderOut\\(|screenSaver|floating|NSApp\\.activate|NSApplication\\.shared\\.activate|activate\\(ignoringOtherApps" Examples/TestPatternShared Examples/TestPatternServerApp Examples/TestPatternClientApp`
- `! rg -n "^import Syphon$|SyphonServer|SyphonClient|SyphonMetalServer|SyphonServerDirectory|CGWindowListCreateImage|CGDisplayStream|getBytes\\(|replaceRegion\\(|CVPixelBufferLockBaseAddress|vImage" Examples/TestPatternShared Examples/TestPatternServerApp Examples/TestPatternClientApp scripts docs README.md`
- `git diff --check`

## Constraints

- Use production XPC with IOSurface XPC object handoff.
- Keep pattern generation and preview on Metal/GPU paths.
- Do not use CPU texture readback, screen capture, window capture, or preview capture as transport.
- Preview windows must be passive and not become key/main.
- The test pattern must include color bars, visible top/bottom orientation markers, and a moving frame tick.
