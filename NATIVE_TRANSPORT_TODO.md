# Syphon26 Native Transport TODO

This checklist tracks the first implementation phase: build the Syphon26 native transport itself without classic Syphon bridge support.

## Scope

- [x] Build a new transport, not a wrapper around the original Syphon Framework.
- [x] Support local app-to-app frame sharing on current macOS.
- [x] Use Metal textures and IOSurface-backed storage in the fast path.
- [x] Avoid CPU texture readback in the fast path.
- [x] Defer classic Syphon compatibility bridges until the native transport is stable.
- [x] Defer OpenGL support until there is a specific adapter requirement.

## Public API

- [x] Review and lock `API_DESIGN.md`.
- [x] Add `Syphon26Server`.
- [x] Add `Syphon26Client`.
- [x] Add `Syphon26Frame`.
- [x] Add `Syphon26StreamDescription`.
- [x] Add `Syphon26Directory`.
- [x] Add `Syphon26ServerDrawable`.
- [x] Add `Syphon26DiagnosticsSnapshot`.
- [x] Add `Syphon26ErrorDomain`.
- [x] Add Swift-friendly nullability and lightweight generics to Objective-C headers.
- [x] Keep API names independent from classic Syphon classes.
- [x] Expose transport capability metadata:
  - sync mode
  - pixel format
  - color primaries
  - transfer function
  - alpha mode
  - ring slot count
  - fallback reason

## Transport Core

- [x] Define a private, versioned shared-state layout.
- [x] Define ring slot metadata:
  - IOSurface reference
  - slot sequence
  - ready sequence
  - dimensions
  - pixel format
  - timestamp
- [x] Add an initial in-process ring stream for API and test validation.
- [x] Implement triple-buffered IOSurface-backed slots.
- [x] Support configurable slot count.
- [x] Implement latest-frame consumption semantics.
- [x] Track slow consumers without blocking the producer.
- [x] Add all-slots-busy policy for latest-frame mode.

## Control Plane

- [x] Add an XPC-based control channel.
- [x] Exchange stream metadata over XPC.
- [x] Exchange IOSurface references or secure IOSurface handles over XPC.
- [x] Exchange `MTLSharedEventHandle` over XPC.
- [x] Add producer registration and retirement.
- [x] Add consumer registration and retirement.
- [x] Add stale process cleanup.
- [x] Add per-user isolation for any shared memory or temporary state.

## GPU Synchronization

- [x] Use `MTLSharedEvent` when available.
- [x] Signal frame readiness from the producer command buffer.
- [x] Wait on frame readiness from the consumer command buffer when needed.
- [x] Add atomic sequence polling fallback.
- [x] Expose sync fallback reason in diagnostics.
- [x] Measure GPU wait time.
- [x] Measure producer stall time.
- [x] Test producer shutdown while clients are waiting.
- [x] Test client shutdown while producer command buffers are in flight.

## Format Support

- [x] Implement BGRA8 first.
- [x] Add RGBA16F after BGRA8 is stable.
- [x] Store color primaries metadata.
- [x] Store transfer function metadata.
- [x] Store alpha mode metadata.
- [x] Reject unsupported pixel formats explicitly.
- [ ] Defer NV12/P010 multi-plane support until a real pipeline requires it.

## Diagnostics

- [x] Add server diagnostics snapshot.
- [x] Add client diagnostics snapshot.
- [x] Track published frames.
- [x] Track observed frames.
- [x] Track missed frames.
- [x] Track repeated reads.
- [x] Track overwritten frames.
- [x] Track current consumer lag.
- [x] Track max consumer lag.
- [x] Track active client count.
- [x] Track sync mode and fallback reason.
- [x] Add `os_signpost` markers for publish, acquire, wait, consume, and retire.

## Samples

- [x] Add a minimal Metal producer app.
- [x] Add a minimal Metal consumer app.
- [x] Add a multi-consumer benchmark runner.
- [x] Add a slow-consumer benchmark mode.
- [x] Add an RGBA16F benchmark mode after format support lands.

## Benchmark Gates

- [ ] Follow `VALIDATION_BENCHMARK_PLAN.md`.
- [x] 1920x1080@60 BGRA8.
- [x] 3840x2160@60 BGRA8.
- [x] 3840x2160@120 BGRA8 when hardware supports it.
- [x] 1920x1080 max throughput.
- [x] 3840x2160 max throughput.
- [x] 1, 2, 4, 8, and 16 consumer fan-out.
- [x] Slow consumer delays at 1 ms, 5 ms, and 16 ms.
- [x] Verify no CPU readback symbols in fast-path samples.

## First Code Slice

- [x] Create the framework or Swift package structure.
- [x] Add the private shared-state header.
- [x] Add the server-side ring allocator.
- [x] Add the client-side ring reader.
- [x] Add sequence polling sync first.
- [x] Add `MTLSharedEvent` sync through XPC second.
- [x] Add BGRA8 producer and consumer samples.
- [x] Run 1080p60 and 1080p max-throughput benchmarks.
