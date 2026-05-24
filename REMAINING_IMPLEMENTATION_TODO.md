# Syphon26 Remaining Implementation TODO

This is the ordered implementation queue after the native in-process transport MVP.

## 1. Cross-process transport handoff

- [x] Add XPC payloads for IOSurface slot handoff.
- [x] Add XPC payloads for `MTLSharedEventHandle` handoff.
- [ ] Recreate client-side Metal textures from received IOSurfaces.
- [ ] Recreate client-side `MTLSharedEvent` from received handles.
- [ ] Route `Syphon26Server.start()` through the control plane when cross-process mode is enabled.
- [ ] Route `Syphon26Client.start()` through the control plane when attaching by stream ID.
- [ ] Validate one producer and one consumer through the XPC transport path.
- [ ] Validate 2, 4, 8, and 16 consumer fan-out through the XPC transport path.

## 2. Lifecycle cleanup and isolation

- [ ] Add stale producer cleanup when an XPC connection invalidates.
- [ ] Add stale consumer cleanup when an XPC connection invalidates.
- [ ] Add per-user isolation checks for the control-plane namespace.
- [ ] Define temporary/shared-state ownership and permissions.
- [ ] Add repeated create/destroy leak tests.
- [ ] Add repeated attach/detach leak tests.

## 3. Public API lock

- [ ] Review and lock `API_DESIGN.md`.
- [ ] Add Swift compile-only API examples.
- [ ] Add Objective-C compile-only API examples.
- [ ] Add Objective-C wrapper headers with nullability annotations.
- [ ] Add lightweight generic annotations where Objective-C collections are exposed.
- [ ] Mark bridge-related APIs explicitly out of scope for Phase 1.

## 4. Native samples

- [ ] Add minimal Metal producer sample.
- [ ] Add minimal Metal consumer sample.
- [ ] Add BGRA8 producer/consumer sample pair.
- [ ] Add RGBA16F producer/consumer sample pair.
- [ ] Add sample launch scripts for local app-to-app validation.

## 5. Production benchmark pass

- [ ] Run full Syphon26 app-to-app XPC benchmark matrix.
- [ ] Run classic Syphon matrix on the same machine in the same benchmark session.
- [ ] Publish JSON, CSV, environment metadata, and trace samples.
- [ ] Produce speedup tables for fixed-FPS and max-throughput modes.
- [ ] Run 30 minute 1080p60 stability test.
- [ ] Run 30 minute 4K60 stability test.
- [ ] Run 10 minute max-throughput stability test.
- [ ] Run memory growth and handle leak checks.

## 6. Deferred format work

- [ ] Keep NV12/P010 multi-plane support deferred until a real pipeline requires it.
- [ ] Document the exact requirements before adding multi-plane support.
