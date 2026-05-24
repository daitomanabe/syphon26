# Syphon26 Native Transport TODO

This checklist tracks the first implementation phase: build the Syphon26 native transport itself without classic Syphon bridge support.

## Scope

- [ ] Build a new transport, not a wrapper around the original Syphon Framework.
- [ ] Support local app-to-app frame sharing on current macOS.
- [ ] Use Metal textures and IOSurface-backed storage in the fast path.
- [ ] Avoid CPU texture readback in the fast path.
- [ ] Defer classic Syphon compatibility bridges until the native transport is stable.
- [ ] Defer OpenGL support until there is a specific adapter requirement.

## Public API

- [ ] Review and lock `API_DESIGN.md`.
- [x] Add `Syphon26Server`.
- [x] Add `Syphon26Client`.
- [x] Add `Syphon26Frame`.
- [x] Add `Syphon26StreamDescription`.
- [x] Add `Syphon26Directory`.
- [x] Add `Syphon26ServerDrawable`.
- [x] Add `Syphon26DiagnosticsSnapshot`.
- [x] Add `Syphon26ErrorDomain`.
- [ ] Add Swift-friendly nullability and lightweight generics to Objective-C headers.
- [ ] Keep API names independent from classic Syphon classes.
- [ ] Expose transport capability metadata:
  - sync mode
  - pixel format
  - color primaries
  - transfer function
  - alpha mode
  - ring slot count
  - fallback reason

## Transport Core

- [ ] Define a private, versioned shared-state header.
- [ ] Define ring slot metadata:
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
- [ ] Track slow consumers without blocking the producer.
- [ ] Add all-slots-busy policy for latest-frame mode.

## Control Plane

- [ ] Add an XPC-based control channel.
- [ ] Exchange stream metadata over XPC.
- [ ] Exchange IOSurface references or secure IOSurface handles over XPC.
- [ ] Exchange `MTLSharedEventHandle` over XPC.
- [ ] Add producer registration and retirement.
- [ ] Add consumer registration and retirement.
- [ ] Add stale process cleanup.
- [ ] Add per-user isolation for any shared memory or temporary state.

## GPU Synchronization

- [x] Use `MTLSharedEvent` when available.
- [x] Signal frame readiness from the producer command buffer.
- [x] Wait on frame readiness from the consumer command buffer when needed.
- [x] Add atomic sequence polling fallback.
- [x] Expose sync fallback reason in diagnostics.
- [ ] Measure GPU wait time.
- [ ] Measure producer stall time.
- [ ] Test producer shutdown while clients are waiting.
- [ ] Test client shutdown while producer command buffers are in flight.

## Format Support

- [ ] Implement BGRA8 first.
- [ ] Add RGBA16F after BGRA8 is stable.
- [ ] Store color primaries metadata.
- [ ] Store transfer function metadata.
- [ ] Store alpha mode metadata.
- [ ] Reject unsupported pixel formats explicitly.
- [ ] Defer NV12/P010 multi-plane support until a real pipeline requires it.

## Diagnostics

- [x] Add server diagnostics snapshot.
- [x] Add client diagnostics snapshot.
- [x] Track published frames.
- [x] Track observed frames.
- [x] Track missed frames.
- [x] Track repeated reads.
- [ ] Track overwritten frames.
- [ ] Track current consumer lag.
- [ ] Track max consumer lag.
- [x] Track active client count.
- [x] Track sync mode and fallback reason.
- [x] Add `os_signpost` markers for publish, acquire, wait, consume, and retire.

## Samples

- [ ] Add a minimal Metal producer app.
- [ ] Add a minimal Metal consumer app.
- [x] Add a multi-consumer benchmark runner.
- [ ] Add a slow-consumer benchmark mode.
- [ ] Add an RGBA16F benchmark mode after format support lands.

## Benchmark Gates

- [ ] Follow `VALIDATION_BENCHMARK_PLAN.md`.
- [x] 1920x1080@60 BGRA8.
- [x] 3840x2160@60 BGRA8.
- [x] 3840x2160@120 BGRA8 when hardware supports it.
- [x] 1920x1080 max throughput.
- [x] 3840x2160 max throughput.
- [ ] 1, 2, 4, 8, and 16 consumer fan-out.
- [ ] Slow consumer delays at 1 ms, 5 ms, and 16 ms.
- [ ] Verify no CPU readback symbols in fast-path samples.

## First Code Slice

- [x] Create the framework or Swift package structure.
- [ ] Add the private shared-state header.
- [ ] Add the server-side ring allocator.
- [ ] Add the client-side ring reader.
- [x] Add sequence polling sync first.
- [ ] Add `MTLSharedEvent` sync through XPC second.
- [ ] Add BGRA8 producer and consumer samples.
- [ ] Run 1080p60 and 1080p max-throughput benchmarks.
