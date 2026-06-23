# VALIDATION.md

Run these commands from the Syphon26 repository root unless noted otherwise.

## Required For Goal 13

```bash
python3 -m py_compile ../Syphon-Framework/Examples/SyphonMetalBenchmark/scripts/run_benchmark.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 ../Syphon-Framework/Examples/SyphonMetalBenchmark/scripts/run_benchmark.py --transport syphon --matrix 8k60,16k60 --duration 0.25 --warmup 0.1 --clients 1 --poll-us 0 --csv-every 100 --no-build --output-dir /tmp/syphon-classic-8k16k-smoke
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 8k60,16k60 --duration 1 --warmup 0.25 --require-production-xpc-claim
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 8kmax,16kmax --duration 1 --warmup 0.25 --require-production-xpc-claim
python3 -m py_compile scripts/run_performance_claim_gate.py
git diff --check
```

## Claim Gate Rules

- 8K/16K v2-vs-classic claims require same-session production XPC and classic Syphon rows.
- `productionXPCClaimStatus: ready` is required before making 8K/16K production XPC v2-vs-classic wording.
- Fixed-FPS rows prove stability against the target FPS. They are not throughput speedup claims.
- Throughput speedup claims require `fpsTarget: 0` rows.
- If a claim status is `blocked` or `partial`, use the blocker text from the report instead of a broader speed claim.

## Extended Matrix

Use this for the full fixed-FPS and throughput matrix:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080p60,4k60,8k60,16k60,1080pmax,4kmax,8kmax,16kmax --duration 1 --warmup 0.25 --require-production-xpc-claim
```
