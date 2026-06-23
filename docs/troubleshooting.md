# Troubleshooting

## Control Plane

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/verify_control_plane.sh
```

Expected healthy output includes:

- `serviceName: com.syphon26.control-plane`
- `schemaVersion: 1`
- `permissionToken: syphon26.local-user`
- `bootIdentifier: local-session`

Startup verification distinguishes missing service, stale service, permission mismatch, and schema mismatch. A plain `xpc connection failed` result is not sufficient.

## Samples

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_simple_pair.sh
```

Expected output includes `status: ok`, `expectedFrames`, `clientReceivedFrames`, and `transportScope: in-process`.

The same script also validates the bounded cross-process IOSurface smoke. Expected output includes `crossProcessTextureOpened: true` and `crossProcessStreamID`.

## AppKit Windows

The sample preview windows must not become key or main:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26SimpleServerApp --smoke
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run Syphon26SimpleClientApp --smoke
```

Expected smoke output includes `canBecomeKey: false`, `canBecomeMain: false`, `isKeyWindow: false`, and `isMainWindow: false`.

## Test Pattern Apps

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_test_pattern_pair.sh --duration 1 --fps 60 --width 1280 --height 720
```

Expected output includes `status: ok`, `textureOpened: true`, `transportScope: app-to-app-syphon26-production-xpc`, and a nonzero client `framesObserved` value. The pattern contains color bars, top/bottom bands, corner markers, and a moving frame tick so orientation and color issues are visible in the client preview.

If the client reports `waiting for stream`, verify that the temporary launchd service was bootstrapped and that the server process is still running. The smoke script writes logs under `benchmark-reports/test-pattern/`.

## Benchmarks

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_benchmark_matrix.py
```

Reports are written under `benchmark-reports/`. `run_benchmark_matrix.py` measures only the in-process v2 harness and must not be treated as a v1 or classic Syphon comparison.

For the v2 app-to-app benchmark path, run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_v2_app_to_app_benchmark.py --matrix 1080p60 --duration 1 --warmup 0.25
```

Expected output includes one server process and one client process with return code `0`, plus JSON artifacts under `benchmark-reports/v2-app-to-app/`.

For the production XPC benchmark path, run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_production_xpc_benchmark.py --matrix 1080p60 --duration 1 --warmup 0.25
```

Expected output includes `launchd-bootstrap`, `health`, `reset`, `client`, `server`, and `launchd-bootout` statuses with return code `0`, plus JSON artifacts under `benchmark-reports/production-xpc/`. The run manifest must report `controlPlane: launchd-mach-xpc` and `handleTransport: iosurface-xpc-object`.

For 8K/16K transport-limit validation, run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_production_xpc_benchmark.py --matrix 8k60,8kmax,16k60,16kmax --duration 1 --warmup 0.25
```

These rows validate Syphon26 production XPC allocation and app-to-app exchange. They are not v2-vs-classic claims unless a same-session classic benchmark row exists for the same matrix.

For 8K/16K claim-gated comparisons, run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 8k60,16k60,8kmax,16kmax --duration 1 --warmup 0.25 --require-production-xpc-claim
```

Expected output includes `productionXPCClaimStatus: ready` when both the production XPC rows and matching classic Syphon rows complete.

For claim-gated comparisons, run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_claim_gate.py --matrix 1080p60 --duration 1 --warmup 0.25 --require-production-xpc-claim
```

Expected output includes `internalV2V1ClaimStatus: ready`, `publicClassicClaimStatus: ready`, and `productionXPCClaimStatus: ready`. Production wording must name the measured v2 launchd Mach XPC path with IOSurface XPC object handoff.
