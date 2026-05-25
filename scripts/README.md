# Scripts

This directory is for validation, benchmark, export, and maintenance scripts.

Scripts should be added only by a goal that explicitly allows script changes.

Planned scripts:

- `verify_control_plane.sh`: validate launchd/XPC service health and classify failures.
- `run_simple_pair.sh`: run CLI Simple Server and Simple Client after the transport exists.
- `export_simple_ui_apps.sh`: export AppKit sample apps after UI samples exist.
- `run_benchmark_matrix.py`: run repeatable benchmark cases after benchmark harness exists.
