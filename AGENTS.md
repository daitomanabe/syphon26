# AGENTS.md

## Project Overview

Syphon26 v2 is a clean-room restart of a modern macOS frame-sharing transport for Swift, AppKit, and Metal. The previous implementation is preserved on the `v1` branch. The current `v2` branch must rebuild the transport from small, verified layers before adding sample apps or performance benchmarks.

The immediate problem to avoid is hidden runtime coupling around XPC/control-plane setup. Every cross-process dependency must become explicit, testable, and diagnosable.

## Repository Layout

- `README.md`: project overview and branch orientation.
- `V2_IMPLEMENTATION_PLAN.md`: high-level scratch rewrite checklist.
- `PLAN.md`: phased implementation plan used by goal-based development.
- `GOALS.md`: copyable bounded goals with edit scopes and stop conditions.
- `ACCEPTANCE.md`: checkable acceptance criteria for each phase.
- `docs/specification.md`: project-specific transport and API specification.
- `docs/development_plan.md`: execution strategy and milestones.
- `docs/test_data.md`: deterministic fixture and benchmark data plan.
- `fixtures/`: deterministic fixtures and golden outputs only.
- `scripts/`: validation, benchmark, export, and maintenance scripts only.
- `Sources/Syphon26/`: library source. Product code may only be edited by an active goal that explicitly allows it.
- `Tests/Syphon26Tests/`: automated tests for the library.

## Architecture Rules

- Keep the transport Metal-first.
- Keep the frame hot path on Metal textures and IOSurface-backed resources.
- Do not use CPU texture readback as transport.
- Do not use screen capture, window capture, preview capture, or AppKit views as transport.
- Do not import, link, or bundle `Syphon.framework` in the core implementation.
- Treat XPC/control-plane startup failure as a first-class API and validation failure.
- Define contracts before wiring runtime implementation.
- Keep preview rendering separate from transport correctness.
- Keep benchmarks separate from product implementation.
- Prefer deterministic tests before manual app verification.

## Implementation Order

1. Public API contracts, validation rules, diagnostics, and error taxonomy.
2. In-process Metal texture validation.
3. IOSurface-backed frame resources and ring metadata.
4. Control-plane protocol and fake in-process control-plane tests.
5. XPC/launchd control-plane service.
6. Synchronization with `MTLSharedEvent` and fallback sequence counters.
7. CLI Simple Server and Simple Client.
8. AppKit Simple Server and Simple Client previews.
9. Benchmarks against `v1` and classic Syphon-style workflows.
10. Integration guide, troubleshooting guide, and release checklist.

## Testing Rules

- Every goal must add or update tests when behavior changes.
- Tests must distinguish Metal, IOSurface, XPC/control-plane, synchronization, lifecycle, and validation failures.
- Manual smoke tests are allowed only when they include exact steps and expected logs.
- Do not claim completion when required commands fail. Report the failure, command, and likely cause.

## Build Commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Lint Commands

No lint command is configured yet. Until one exists, run:

```bash
git diff --check
```

## Forbidden Edit Scopes

- Do not edit product code unless the active goal explicitly allows the path.
- Do not edit `Sources/Syphon26/` outside the allowed paths for the active goal.
- Do not edit generated outputs, benchmark result folders, `.build/`, `dist/`, or user-local files.
- Do not change public API names or semantics outside an API-design goal.
- Do not add UI, sample apps, XPC services, launchd files, or benchmarks during Phase 1.
- Do not rewrite `v1`, `main`, or historical benchmark artifacts from this branch.

## Definition Of Done

An active goal is done only when:

- All required files for that goal are created or updated.
- Required tests or deterministic validations exist.
- All required commands pass, or failures are reported with exact command output context.
- Changes stay inside the allowed edit paths.
- `ACCEPTANCE.md` criteria for the phase are satisfied.
- Remaining risks and the next recommended goal are summarized.

## Uncertainty Handling

- If a requirement is unclear, choose the smallest reversible design and document the assumption.
- If an API decision affects future compatibility, record it in `docs/specification.md`.
- If runtime behavior cannot be validated locally, add an explicit manual smoke test before implementation continues.
- If XPC/control-plane behavior fails, stop and classify the failure before attempting broad fixes.
