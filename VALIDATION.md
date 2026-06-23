# VALIDATION.md

Run these commands from the repository root unless noted otherwise.

## Required For Goal 12

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_production_xpc_benchmark.py --matrix 1080p60,4k60,8k60,16k60 --duration 1 --warmup 0.25
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_production_xpc_benchmark.py --matrix 1080pmax,4kmax,8kmax,16kmax --duration 1 --warmup 0.25
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080p60,4k60,8k60,16k60 --duration 1 --warmup 0.25
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080pmax,4kmax,8kmax,16kmax --duration 1 --warmup 0.25
python3 -m py_compile scripts/run_v2_app_to_app_benchmark.py scripts/run_production_xpc_benchmark.py scripts/run_performance_claim_gate.py
! rg -n "^import Syphon$|SyphonServer|SyphonClient|SyphonMetalServer|SyphonServerDirectory|CGWindowListCreateImage|CGDisplayStream|getBytes\(|replaceRegion\(|CVPixelBufferLockBaseAddress|vImage" Sources Tests Examples scripts docs README.md GOALS.md
git diff --check
```

## Claim Gate Rules

- `scripts/run_production_xpc_benchmark.py` must write producer/client JSON artifacts under `benchmark-reports/production-xpc/`.
- Production XPC run manifests must include launchd bootstrap/bootout status, `controlPlane: launchd-mach-xpc`, and `handleTransport: iosurface-xpc-object`.
- `scripts/run_performance_claim_gate.py` must write `benchmark-reports/performance-claim-gate/latest.json` and `.md`.
- v2 in-process, v2 file-backed app-to-app, v2 production XPC, v1, and classic Syphon measurements must be generated in the same runner invocation before comparison wording is used.
- `internalV2V1ClaimStatus` only permits internal benchmark wording for the in-process v2-v1 row.
- `publicClassicClaimStatus` describes the measured file-backed v2 app-to-app benchmark path.
- `productionXPCClaimStatus` describes only rows where the measured v2 path is app-to-app launchd Mach XPC with IOSurface XPC object handoff.
- 8K/16K production XPC rows may be reported as Syphon26 measurements when their producer/client artifacts pass, but 8K/16K v2-vs-classic claims remain blocked until the classic benchmark runner supplies matching 8K/16K rows.
- If a claim status is `blocked` or `partial`, use the blocker text from the report instead of a broader speed claim.

## Extended Production XPC Matrix

Use this when preparing stronger public benchmark wording:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080p60,4k60,1080pmax,4kmax --duration 2 --warmup 0.5 --require-production-xpc-claim
```

Use this when validating 8K/16K transport limits:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_production_xpc_benchmark.py --matrix 8k60,8kmax,16k60,16kmax --duration 2 --warmup 0.5
```

Fixed-FPS rows support stability statements. `fpsTarget: 0` throughput rows are required for speedup statements.
