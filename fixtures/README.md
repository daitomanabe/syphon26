# Fixtures

This directory is for deterministic inputs and expected outputs used by tests, validation scripts, and benchmarks.

Do not place generated benchmark result folders here. Use `benchmark-reports/` or `benchmark-results/` only when a goal explicitly creates those outputs.

Planned fixture groups:

- `api/`: valid and invalid configuration examples.
- `metal/`: deterministic texture pattern descriptions.
- `transport/`: ring metadata and diagnostics examples.
- `control-plane/`: expected service health states and error classifications.
