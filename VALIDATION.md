# VALIDATION.md

Run these commands from the Syphon26 repository root unless noted otherwise.

## Required For Goal 15

```bash
python3 -m py_compile scripts/run_performance_claim_gate.py scripts/export_github_benchmark_report.py
python3 -m py_compile ../Syphon-Framework/Examples/SyphonMetalBenchmark/scripts/run_benchmark.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080p60,4k60,8k60,16k60 --duration 1 --warmup 0.25 --require-production-xpc-claim --output benchmark-reports/performance-claim-gate/fixed
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080pmax,4kmax,8kmax,16kmax --duration 1 --warmup 0.25 --require-production-xpc-claim --output benchmark-reports/performance-claim-gate/throughput
scripts/export_github_benchmark_report.py --fixed benchmark-reports/performance-claim-gate/fixed/latest.json --throughput benchmark-reports/performance-claim-gate/throughput/latest.json --markdown docs/benchmarks/classic-vs-syphon26-16k.md --json docs/benchmarks/classic-vs-syphon26-16k.json
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

Before commit/push, also run the `github-push-privacy-guard` absolute-path scan against README, docs, scripts, control files, package files, source, tests, and examples. It must produce no matches.

## Classic Vs Syphon26 16K Acceptance

- Fixed-FPS rows cover `1080p60`, `4k60`, `8k60`, and `16k60`.
- Max-throughput rows cover `1080pmax`, `4kmax`, `8kmax`, and `16kmax`.
- Each claim-gate run includes Syphon26 file-backed app-to-app, Syphon26 production XPC, and classic Syphon app-to-app measurements.
- Production XPC rows are claimable only when the gate reports `productionXPCClaimStatus: ready`.
- Public classic rows are claimable only when the gate reports `publicClassicClaimStatus: ready`.
- GitHub report output is sanitized: no local absolute paths, usernames, generated artifact paths, or raw command dumps.
- GitHub report wording names the measured scope: same-session, app-to-app, BGRA8, `clear` render mode, headless CLI no preview, fixed-FPS stability or max-throughput.

## Report Output

```text
docs/benchmarks/classic-vs-syphon26-16k.md
docs/benchmarks/classic-vs-syphon26-16k.json
```
