# Classic Syphon vs Syphon26 Benchmark Report

This report is a sanitized GitHub copy of same-session benchmark claim-gate output.
It compares classic Syphon app-to-app against Syphon26 file-backed app-to-app and Syphon26 production XPC app-to-app paths through 16K BGRA8.

## Scope

- Process scope: `app-to-app`
- Pixel format: `bgra8`
- Render mode: `clear`
- Display state: `headless-cli-no-preview`
- Syphon26 production XPC path: `launchd-mach-xpc` with `iosurface-xpc-object` handoff
- Ratios are shown only for rows marked ready by the same-session claim gate.

## Status

- fixed publicClassicClaimStatus: `ready`
- fixed productionXPCClaimStatus: `ready`
- throughput publicClassicClaimStatus: `ready`
- throughput productionXPCClaimStatus: `ready`

## Highlights

- All fixed-FPS rows from 1080p60 through 16k60 are claim-gate ready for classic-vs-Syphon26 comparison.
- All max-throughput rows from 1080pmax through 16kmax are claim-gate ready for classic-vs-Syphon26 comparison.
- 16k60 stability: classic `59.923` FPS, Syphon26 file-backed `59.998` FPS, Syphon26 production XPC `59.993` FPS.
- 16kmax throughput: Syphon26 file-backed is `2.897x` classic; Syphon26 production XPC is `3.455x` classic.

## Fixed-FPS Stability

| matrix | resolution | target | classic FPS | Syphon26 file FPS | file/classic | Syphon26 production XPC FPS | xpc/classic | production claim |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1080p60 | 1920x1080 | 60 FPS target | 59.931 | 59.997 | 1.001 | 59.996 | 1.001 | ready |
| 4k60 | 3840x2160 | 60 FPS target | 59.943 | 59.997 | 1.001 | 59.992 | 1.001 | ready |
| 8k60 | 7680x4320 | 60 FPS target | 59.919 | 59.995 | 1.001 | 59.997 | 1.001 | ready |
| 16k60 | 15360x8640 | 60 FPS target | 59.923 | 59.998 | 1.001 | 59.993 | 1.001 | ready |

## Max-Throughput

| matrix | resolution | target | classic FPS | Syphon26 file FPS | file/classic | Syphon26 production XPC FPS | xpc/classic | production claim |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1080pmax | 1920x1080 | max throughput | 618.275 | 2572.733 | 4.161 | 3818.357 | 6.176 | ready |
| 4kmax | 3840x2160 | max throughput | 486.334 | 2384.920 | 4.904 | 2498.626 | 5.138 | ready |
| 8kmax | 7680x4320 | max throughput | 327.660 | 1737.977 | 5.304 | 2369.954 | 7.233 | ready |
| 16kmax | 15360x8640 | max throughput | 243.696 | 705.924 | 2.897 | 841.980 | 3.455 | ready |

## Claimable Statements

- Public classic fixed-FPS stability comparison: in the same-session 1080p60 app-to-app benchmark, the v2 file-backed Syphon26 path received frames at 1.001x classic Syphon receive FPS against the 60 FPS target under matched resolution, pixel format, render mode, process scope, and display state.
- Public classic fixed-FPS stability comparison: in the same-session 4k60 app-to-app benchmark, the v2 file-backed Syphon26 path received frames at 1.001x classic Syphon receive FPS against the 60 FPS target under matched resolution, pixel format, render mode, process scope, and display state.
- Public classic fixed-FPS stability comparison: in the same-session 8k60 app-to-app benchmark, the v2 file-backed Syphon26 path received frames at 1.001x classic Syphon receive FPS against the 60 FPS target under matched resolution, pixel format, render mode, process scope, and display state.
- Public classic fixed-FPS stability comparison: in the same-session 16k60 app-to-app benchmark, the v2 file-backed Syphon26 path received frames at 1.001x classic Syphon receive FPS against the 60 FPS target under matched resolution, pixel format, render mode, process scope, and display state.
- Production XPC fixed-FPS stability comparison: in the same-session 1080p60 app-to-app benchmark, the v2 launchd production XPC path using IOSurface XPC object handoff received frames at 1.001x classic Syphon receive FPS against the 60 FPS target under matched resolution, pixel format, render mode, process scope, and display state.
- Production XPC fixed-FPS stability comparison: in the same-session 4k60 app-to-app benchmark, the v2 launchd production XPC path using IOSurface XPC object handoff received frames at 1.001x classic Syphon receive FPS against the 60 FPS target under matched resolution, pixel format, render mode, process scope, and display state.
- Production XPC fixed-FPS stability comparison: in the same-session 8k60 app-to-app benchmark, the v2 launchd production XPC path using IOSurface XPC object handoff received frames at 1.001x classic Syphon receive FPS against the 60 FPS target under matched resolution, pixel format, render mode, process scope, and display state.
- Production XPC fixed-FPS stability comparison: in the same-session 16k60 app-to-app benchmark, the v2 launchd production XPC path using IOSurface XPC object handoff received frames at 1.001x classic Syphon receive FPS against the 60 FPS target under matched resolution, pixel format, render mode, process scope, and display state.
- Public classic throughput comparison: in the same-session 1080pmax app-to-app benchmark, the v2 file-backed Syphon26 path received frames at 4.161x classic Syphon receive FPS under matched resolution, pixel format, render mode, process scope, and display state.
- Public classic throughput comparison: in the same-session 4kmax app-to-app benchmark, the v2 file-backed Syphon26 path received frames at 4.904x classic Syphon receive FPS under matched resolution, pixel format, render mode, process scope, and display state.
- Public classic throughput comparison: in the same-session 8kmax app-to-app benchmark, the v2 file-backed Syphon26 path received frames at 5.304x classic Syphon receive FPS under matched resolution, pixel format, render mode, process scope, and display state.
- Public classic throughput comparison: in the same-session 16kmax app-to-app benchmark, the v2 file-backed Syphon26 path received frames at 2.897x classic Syphon receive FPS under matched resolution, pixel format, render mode, process scope, and display state.
- Production XPC throughput comparison: in the same-session 1080pmax app-to-app benchmark, the v2 launchd production XPC path using IOSurface XPC object handoff received frames at 6.176x classic Syphon receive FPS under matched resolution, pixel format, render mode, process scope, and display state.
- Production XPC throughput comparison: in the same-session 4kmax app-to-app benchmark, the v2 launchd production XPC path using IOSurface XPC object handoff received frames at 5.138x classic Syphon receive FPS under matched resolution, pixel format, render mode, process scope, and display state.
- Production XPC throughput comparison: in the same-session 8kmax app-to-app benchmark, the v2 launchd production XPC path using IOSurface XPC object handoff received frames at 7.233x classic Syphon receive FPS under matched resolution, pixel format, render mode, process scope, and display state.
- Production XPC throughput comparison: in the same-session 16kmax app-to-app benchmark, the v2 launchd production XPC path using IOSurface XPC object handoff received frames at 3.455x classic Syphon receive FPS under matched resolution, pixel format, render mode, process scope, and display state.

## Interpretation Limits

- Rows are same-session measurements within each claim-gate invocation.
- Fixed-FPS rows are stability evidence, not max-speed evidence.
- Max-throughput rows use fpsTarget 0 and are speed evidence.
- Ratios are included only when the same-session claim gate marked that row ready.
- Syphon26 production XPC means app-to-app launchd Mach XPC with IOSurface XPC object handoff.
- Syphon26 file-backed app-to-app remains scoped to the development benchmark path.
- This report intentionally omits raw artifact paths, local usernames, hostnames, and command dumps.
