# Development Plan

## Strategy

Build Syphon26 v2 as layered contracts rather than a monolithic app demo. Each layer must have tests or exact validation commands before the next layer starts.

The restart is specifically meant to avoid an opaque state where publish/receive metrics look healthy while app-level setup or rendering behavior is ambiguous. Control-plane health, transport correctness, and preview rendering must be validated separately.

## Milestones

### M1: Control Layer

Create `AGENTS.md`, `PLAN.md`, `GOALS.md`, `ACCEPTANCE.md`, and project docs before product code changes.

### M2: API Contract

Define configuration, metadata, diagnostics, and errors with validation tests.

### M3: Metal Validation

Validate deterministic in-process Metal texture behavior independent of cross-process sharing.

### M4: IOSurface Transport Core

Add IOSurface-backed frame resources and slot semantics without XPC.

### M5: Control Plane

Add in-process fake control plane first, then launchd/XPC service with explicit health checks.

### M6: Synchronization

Add `MTLSharedEvent` and fallback synchronization with frame lifetime tests.

### M7: Samples

Build CLI samples first, then AppKit preview apps after transport correctness is already proven.

### M8: Benchmarks And Release

Benchmark v2 against v1 and classic Syphon-style workflows under documented, repeatable conditions.

## Validation Philosophy

- Build and tests must be the default proof.
- Manual smoke tests must specify commands, expected logs, and failure interpretation.
- Benchmark claims require raw outputs and environment metadata.
- A vague XPC error is a bug in diagnostics even if the underlying failure is expected.

## Branch Policy

- `main` and `v1` preserve the first implementation.
- `v2` is the scratch rewrite branch.
- Do not port code from `v1` unless a goal explicitly allows comparison or adaptation.
- Do not change branch history unless the user explicitly asks.
