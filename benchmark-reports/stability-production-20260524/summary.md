# Syphon26 App-To-App Stability Report

Created: `2026-05-24T19:46:14`
Git commit: `ec64cb36a29803023d8237a5e2b4ee339309f903`

| Matrix | Duration | Format | Consumer FPS | Producer RSS Delta | Consumer RSS Delta | Producer FD Delta | Consumer FD Delta | Result |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1080p60-30m | 1800s | bgra8 | 60.00 | -16 KB | 1776 KB | 0 | 0 | pass |
| 4k60-30m | 1800s | bgra8 | 60.00 | -16 KB | 1760 KB | 0 | 0 | pass |
| 1080pmax-10m | 600s | bgra8 | 783.85 | 224 KB | 1744 KB | 0 | 0 | pass |

Memory stability is evaluated from RSS start/end deltas. Handle stability is evaluated from file-descriptor count deltas sampled during the producer and consumer lifetimes.
