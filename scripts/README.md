# Scripts

This directory is for validation, benchmark, export, and maintenance scripts.

Scripts should be added only by a goal that explicitly allows script changes.

Current scripts:

- `verify_control_plane.sh`: validate launchd/XPC service health and classify failures.
- `run_simple_pair.sh`: run CLI Simple Server and Simple Client smoke checks.
- `export_simple_ui_apps.sh`: export AppKit sample apps.
- `run_test_pattern_pair.sh`: bootstrap a temporary production XPC service and validate the Test Pattern server/client apps.
- `run_benchmark_matrix.py`: run repeatable v2 in-process transport-core benchmark cases.
- `run_v2_app_to_app_benchmark.py`: run separate v2 producer/client benchmark processes over the file-backed Syphon26 IOSurface path.
- `run_production_xpc_benchmark.py`: run separate v2 producer/client benchmark processes through a launchd Mach XPC service with IOSurface XPC object handoff.
- `run_performance_claim_gate.py`: run same-session v2 in-process, v2 file-backed app-to-app, v2 production XPC, v1, and classic Syphon measurements and gate claim readiness.
