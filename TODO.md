# TODO

## Active Goal

Implement and validate the production XPC app-to-app benchmark path so final performance claims are gated separately from the older file-backed benchmark path, including 8K and 16K rows.

## Checklist

- [x] Add Goal 12 for production XPC performance claim readiness.
- [x] Add a launchd Mach XPC service mode to `Syphon26ControlPlaneService`.
- [x] Add a production XPC transport helper that exchanges IOSurface XPC objects without app-facing raw IOSurface IDs.
- [x] Add `Syphon26ProductionXPCBenchmark` and `scripts/run_production_xpc_benchmark.py`.
- [x] Add 8K and 16K matrices to benchmark runners.
- [x] Extend `scripts/run_performance_claim_gate.py` with `productionXPCClaimStatus`.
- [x] Run production XPC fixed-FPS matrix: `1080p60,4k60,8k60,16k60`.
- [x] Run production XPC throughput matrix: `1080pmax,4kmax,8kmax,16kmax`.
- [x] Run production XPC claim gate for fixed-FPS and throughput matrices.
- [x] Run build, tests, forbidden-pattern search, Python compile, and diff checks.

## Validation Matrix

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_production_xpc_benchmark.py --matrix 1080p60,4k60,8k60,16k60 --duration 1 --warmup 0.25`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_production_xpc_benchmark.py --matrix 1080pmax,4kmax,8kmax,16kmax --duration 1 --warmup 0.25`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080p60,4k60,8k60,16k60 --duration 1 --warmup 0.25`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080pmax,4kmax,8kmax,16kmax --duration 1 --warmup 0.25`
- `python3 -m py_compile scripts/run_v2_app_to_app_benchmark.py scripts/run_production_xpc_benchmark.py scripts/run_performance_claim_gate.py`
- `! rg -n "^import Syphon$|SyphonServer|SyphonClient|SyphonMetalServer|SyphonServerDirectory|CGWindowListCreateImage|CGDisplayStream|getBytes\\(|replaceRegion\\(|CVPixelBufferLockBaseAddress|vImage" Sources Tests Examples scripts docs README.md GOALS.md`
- `git diff --check`

## Constraints

- Do not import, link, or bundle `Syphon.framework` in the Syphon26 core or production XPC path.
- Do not use CPU texture readback, screen capture, or window capture as transport.
- Production XPC rows must report `controlPlane: launchd-mach-xpc` and `handleTransport: iosurface-xpc-object`.
- Fixed-FPS rows support stability wording only; `fpsTarget: 0` rows support throughput wording.
- 8K/16K production XPC rows can be reported as measured Syphon26 rows, but 8K/16K v2-vs-classic claims remain blocked until the classic benchmark runner has matching 8K/16K rows.
