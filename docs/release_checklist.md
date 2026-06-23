# Release Checklist

Do not cut a release until each item is checked from source-of-truth commands.

- `swift build` passes.
- `swift test` passes.
- `scripts/verify_control_plane.sh` passes.
- `scripts/run_simple_pair.sh` passes.
- `scripts/export_simple_ui_apps.sh` exports both local `.app` bundles.
- `scripts/run_test_pattern_pair.sh --duration 1 --fps 60 --width 1280 --height 720` proves the production-XPC test-pattern server/client pair.
- `scripts/run_benchmark_matrix.py` produces JSON and Markdown reports.
- `scripts/run_v2_app_to_app_benchmark.py --matrix 1080p60 --duration 1 --warmup 0.25` produces server/client JSON reports.
- `scripts/run_production_xpc_benchmark.py --matrix 1080p60 --duration 1 --warmup 0.25` produces launchd Mach XPC server/client JSON reports.
- `scripts/run_performance_claim_gate.py --matrix 1080p60 --duration 1 --warmup 0.25 --require-public-claim` produces JSON and Markdown reports.
- `scripts/run_performance_claim_gate.py --matrix 1080p60 --duration 1 --warmup 0.25 --require-production-xpc-claim` marks `productionXPCClaimStatus` ready.
- 8K/16K production XPC transport rows are validated with `scripts/run_production_xpc_benchmark.py --matrix 8k60,8kmax,16k60,16kmax --duration 1 --warmup 0.25`.
- Benchmark reports include environment, resolution, pixel format, FPS target, publish FPS, receive FPS, missed frames, repeated reads, latency, CPU, memory, GPU wait, and interpretation limits.
- v1 comparison is measured in the same claim-gate invocation before internal v2-v1 wording is used.
- Classic Syphon comparison is measured in the same claim-gate invocation before any public classic wording is considered.
- Public v2-vs-classic Syphon benchmark claims are omitted unless `publicClassicClaimStatus` is `ready`.
- Production XPC benchmark claims are omitted unless `productionXPCClaimStatus` is `ready`.
- Public benchmark wording names the measured v2 file-backed app-to-app path or the measured v2 launchd Mach XPC path explicitly.
- 8K/16K v2-vs-classic wording is omitted unless matching same-session classic benchmark rows are included and `productionXPCClaimStatus` is `ready`.
- AppKit preview windows are verified as passive and non-key/non-main.
- No core target imports, links, or bundles `Syphon.framework`.
- No transport path uses CPU texture readback, screen capture, window capture, or preview capture.
