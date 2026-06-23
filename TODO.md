# TODO

## Active Goal

Unblock 8K/16K production XPC v2-vs-classic claims by adding matching classic Syphon benchmark matrices and rerunning the same-session claim gate.

## Checklist

- [x] Add Goal 13 for 8K/16K classic claim unblock.
- [x] Add `8k60`, `8kmax`, `16k60`, and `16kmax` to the sibling classic benchmark runner.
- [x] Confirm the classic runner accepts 8K/16K with a short smoke.
- [x] Enable 8K/16K classic rows in `scripts/run_performance_claim_gate.py`.
- [x] Run fixed-FPS 8K/16K production XPC claim gate.
- [x] Run max-throughput 8K/16K production XPC claim gate.
- [x] Run Python compile and diff checks in both repositories.
- [x] Run privacy scan, commit, and push both repositories.

## Validation Matrix

- `python3 -m py_compile ../Syphon-Framework/Examples/SyphonMetalBenchmark/scripts/run_benchmark.py`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 ../Syphon-Framework/Examples/SyphonMetalBenchmark/scripts/run_benchmark.py --transport syphon --matrix 8k60,16k60 --duration 0.25 --warmup 0.1 --clients 1 --poll-us 0 --csv-every 100 --no-build --output-dir /tmp/syphon-classic-8k16k-smoke`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 8k60,16k60 --duration 1 --warmup 0.25 --require-production-xpc-claim`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 8kmax,16kmax --duration 1 --warmup 0.25 --require-production-xpc-claim`
- `python3 -m py_compile scripts/run_performance_claim_gate.py`
- `git diff --check`

## Constraints

- 8K/16K claims must come from same-session production XPC and classic Syphon rows.
- Fixed-FPS rows support stability wording only.
- `fpsTarget: 0` rows are required for throughput speedup wording.
- Do not edit classic framework product code for this goal; only the benchmark runner matrix names are in scope.
