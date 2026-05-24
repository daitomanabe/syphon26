# Syphon26 App-To-App Benchmark

Created: `2026-05-24T19:36:16`
Git commit: `c6834d08f98af259d19c2ee5d492e80f2438f0e6`

These runs use the launchd-managed Syphon26 control-plane service plus separate producer and consumer processes.
Classic Syphon comparison values are from the sibling Syphon-Framework benchmark run in the same OS session.

| Matrix | Format | Syphon26 Consumer FPS | Classic Syphon FPS | Result |
| --- | --- | ---: | ---: | ---: |
| 1080p60 | bgra8 | 60.00 | 59.99 | 1.000 target |
| 4k60 | bgra8 | 60.10 | 59.97 | 1.002 target |
| 1080pmax | bgra8 | 667.20 | 346.44 | 1.93x |
| 4kmax | bgra8 | 666.80 | 343.62 | 1.94x |
| 4k60-rgba16f | rgba16f | 60.10 | 0.00 | n/a |

Trace check: `trace-summary.json` found no CPU readback/capture symbols in the sampled producer or consumer call graphs.

Scope note: shared-event app-to-app reads latest sequence from `MTLSharedEvent.signaledValue`; sequence-poll fallback still uses XPC shared-state reads.
The in-process benchmark remains the upper-bound transport reference because the sample apps include launchd and process scheduling overhead.
