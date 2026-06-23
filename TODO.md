# TODO

## Active Goal

Close the remaining Goal 14 completion gaps for the Syphon26 test-pattern server/client apps by making the smoke validation fail-fast for orientation modes, expected frame counts, production XPC texture opening, and passive-window state.

## Remaining Items To Complete

- [x] Reclassify the previously incomplete Goal 14 coverage: orientation modes were implemented but not required by validation.
- [x] Reclassify the previously incomplete smoke gate: frame receipt was checked only as nonzero instead of against the expected frame count.
- [x] Reclassify the previously incomplete passive-window gate: passive flags were emitted but not required by the smoke JSON status.
- [x] Strengthen `scripts/run_test_pattern_pair.sh` so `status: ok` requires production XPC scope, texture opening, expected server frame count, minimum client observed frames, requested orientation, requested dimensions/FPS, and passive-window flags.
- [x] Update `GOALS.md` and `VALIDATION.md` so Goal 14 requires normal, `flipY`, and `rotate180` smoke checks.
- [x] Update docs to state the exact smoke output fields and manual visual orientation checks.
- [x] Run the full Goal 14 validation matrix.
- [x] Commit and push.

## Completion Conditions

- Normal 1280x720 at 60 FPS smoke reports `status: ok`.
- `flipY` and `rotate180` smoke runs report `status: ok`.
- Smoke output includes `expectedFrames`, `minClientObservedFrames`, and per-field `checks`.
- `server.framesPublished == expectedFrames`.
- `client.framesObserved >= minClientObservedFrames`.
- Server/client `orientationMode` match the requested mode.
- Server/client use `transportScope: app-to-app-syphon26-production-xpc`.
- Server/client passive-window flags remain false for key/main capability and state.
- `swift test`, focus audit, forbidden transport audit, privacy scan, and `git diff --check` pass.

## Validation Matrix

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --product Syphon26TestPatternServerApp`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --product Syphon26TestPatternClientApp`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --duration 1 --fps 60 --width 1280 --height 720 --orientation normal`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --duration 0.5 --fps 30 --width 640 --height 360 --orientation flipY`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --duration 0.5 --fps 30 --width 640 --height 360 --orientation rotate180`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26TestPatternServerApp --smoke --help-json`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26TestPatternClientApp --smoke --help-json`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `! rg -n "makeKeyAndOrderFront|orderFrontRegardless|orderFront\\(|orderOut\\(|screenSaver|floating|NSApp\\.activate|NSApplication\\.shared\\.activate|activate\\(ignoringOtherApps" Examples/TestPatternShared Examples/TestPatternServerApp Examples/TestPatternClientApp`
- `! rg -n "^import Syphon$|SyphonServer|SyphonClient|SyphonMetalServer|SyphonServerDirectory|CGWindowListCreateImage|CGDisplayStream|getBytes\\(|replaceRegion\\(|CVPixelBufferLockBaseAddress|vImage" Examples/TestPatternShared Examples/TestPatternServerApp Examples/TestPatternClientApp scripts docs README.md`
- The `github-push-privacy-guard` absolute-path scan must produce no matches.
- `git diff --check`

## Constraints

- Use production XPC with IOSurface XPC object handoff.
- Keep pattern generation and preview on Metal/GPU paths.
- Do not use CPU texture readback, screen capture, window capture, or preview capture as transport.
- Preview windows must be passive and not become key/main.
- The test pattern must include color bars, visible top/bottom orientation markers, corner markers, and a moving frame tick.
