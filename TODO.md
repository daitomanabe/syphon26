# TODO

## Active Goal

Run and publish a GitHub-friendly classic Syphon vs Syphon26 comparison up to 16K, covering fixed-FPS stability and max-throughput rows.

## Checklist

- [x] Add Goal 15 for 1080p/4K/8K/16K classic-vs-Syphon26 comparison and GitHub report publication.
- [x] Add a sanitized report exporter that converts claim-gate JSON into commit-ready Markdown/JSON under `docs/benchmarks/`.
- [x] Run same-session claim gates for `1080p60,4k60,8k60,16k60` and `1080pmax,4kmax,8kmax,16kmax`.
- [x] Export a readable report and update README/docs links.
- [x] Run validation: script compile checks, benchmark gates, report export, `swift test`, privacy scan, and `git diff --check`.
- [x] Commit and push.

## Completion Conditions

- The classic runner accepts 8K and 16K matrix names.
- Claim-gate output includes classic Syphon, Syphon26 file-backed app-to-app, and Syphon26 production XPC rows for every requested matrix that the machine can complete.
- `productionXPCClaimStatus` is `ready` for rows that have matching completed classic measurements.
- The GitHub report clearly separates fixed-FPS stability rows from max-throughput rows.
- The GitHub report includes ratios only when the same-session gate marked the corresponding comparison ready.
- Committed report files contain no local absolute paths, usernames, or generated artifact paths.

## Validation Matrix

- `python3 -m py_compile scripts/run_performance_claim_gate.py scripts/export_github_benchmark_report.py`
- `python3 -m py_compile ../Syphon-Framework/Examples/SyphonMetalBenchmark/scripts/run_benchmark.py`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080p60,4k60,8k60,16k60 --duration 1 --warmup 0.25 --require-production-xpc-claim --output benchmark-reports/performance-claim-gate/fixed`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080pmax,4kmax,8kmax,16kmax --duration 1 --warmup 0.25 --require-production-xpc-claim --output benchmark-reports/performance-claim-gate/throughput`
- `scripts/export_github_benchmark_report.py --fixed benchmark-reports/performance-claim-gate/fixed/latest.json --throughput benchmark-reports/performance-claim-gate/throughput/latest.json --markdown docs/benchmarks/classic-vs-syphon26-16k.md --json docs/benchmarks/classic-vs-syphon26-16k.json`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `git diff --check`
- The `github-push-privacy-guard` absolute-path scan must produce no matches.

## Constraints

- Do not commit raw `benchmark-reports/` generated folders.
- Do not make product-wide speed claims outside the measured matrix and transport scope.
- Do not edit Syphon26 transport core unless a validation failure proves a narrow fix is required.
- Keep report wording explicit about same-session scope, resolution, pixel format, FPS target, render mode, process scope, and display state.
