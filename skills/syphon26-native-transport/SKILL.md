---
name: syphon26-native-transport
description: Use when implementing, porting, or reviewing a macOS Swift/AppKit/Metal app that should use Syphon26 native transport, Syphon26Server, Syphon26Client, Syphon26ControlPlane, or a launchd-managed Syphon26 control-plane service. Trigger for requests to integrate Syphon26 into another app, replace classic Syphon.framework with Syphon26, build producer/client sample apps, validate Syphon26 performance, or prevent CPU readback/window-capture based frame sharing.
---

# Syphon26 Native Transport

Use Syphon26 as a native Metal frame-sharing transport, not as a classic Syphon compatibility bridge.

## Core Contract

- Do not import, link, bundle, or require `Syphon.framework`.
- Do not implement a classic Syphon bridge unless the user explicitly asks for bridge work.
- Use the SwiftPM product `Syphon26` from `https://github.com/daitomanabe/syphon26.git`.
- Require macOS 14+ and Metal.
- Make all producer and consumer processes share the same `Syphon26ControlPlaneService` Mach service.
- Keep the frame hot path on Metal textures backed by Syphon26 transport resources.
- Avoid CPU texture readback and avoid screen/window capture as transport.

## SwiftPM Setup

Add the package:

```swift
.package(url: "https://github.com/daitomanabe/syphon26.git", branch: "main")
```

Add the product to the app target:

```swift
.product(name: "Syphon26", package: "syphon26")
```

For cross-process sharing, run a launchd-managed control-plane service. Apps can use the default:

```swift
let controlPlane = Syphon26ControlPlane()
```

Use an explicit service only when the app owns a private namespace:

```swift
let controlPlane = Syphon26ControlPlane(machServiceName: "com.example.app.syphon26")
```

## Producer Pattern

Create one stable server for a stable output description. Recreate it only when immutable properties such as size or pixel format change.

```swift
import Metal
import Syphon26

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let controlPlane = Syphon26ControlPlane()

let server = try Syphon26Server(
    configuration: Syphon26ServerConfiguration(
        name: "My Syphon26 Stream",
        appName: "MyApp",
        device: device,
        width: 1920,
        height: 1080,
        pixelFormat: .bgra8Unorm,
        syncMode: .automatic,
        controlPlane: controlPlane
    )
)
try server.start()

let drawable = try server.acquireDrawable()
let commandBuffer = queue.makeCommandBuffer()!

// Encode producer Metal rendering directly into drawable.texture.

try server.presentDrawable(drawable, commandBuffer: commandBuffer)
commandBuffer.commit()
```

Rules:

- Render directly into `Syphon26ServerDrawable.texture` when possible.
- Call `presentDrawable(_:commandBuffer:)` with the same command buffer that contains producer writes.
- Publish one final composited texture per frame.
- Keep stream names stable.
- Call `server.stop()` during app shutdown.

## Consumer Pattern

List native Syphon26 streams through the control plane:

```swift
let streams = try controlPlane.streams()
```

Connect by stream ID when the user selects a source:

```swift
import Metal
import Syphon26

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let controlPlane = Syphon26ControlPlane()

let client = try Syphon26Client(
    configuration: Syphon26ClientConfiguration(
        device: device,
        streamID: selectedStream.streamID,
        preferredPixelFormats: [.bgra8Unorm, .rgba16Float],
        controlPlane: controlPlane
    )
)
try client.start()

if let frame = try client.copyLatestFrame() {
    let commandBuffer = queue.makeCommandBuffer()!
    if frame.requiresGPUWait {
        try frame.encodeWait(on: commandBuffer)
    }

    // Encode Metal work that samples frame.texture.

    commandBuffer.addCompletedHandler { _ in
        frame.close()
    }
    commandBuffer.commit()
}
```

Rules:

- Prefer `copyLatestFrame()` semantics for live visuals.
- If `frame.requiresGPUWait` is true, encode the wait before sampling `frame.texture`.
- Keep the frame alive until GPU work that samples the texture is complete.
- Close frames after GPU completion, not immediately after encoding if the texture is still referenced.
- Disconnect or rebuild the client when the stream disappears, source selection changes, or pixel format is unsupported.

## AppKit And Output Windows

For AppKit tools, make Syphon26 publishing independent of window focus and visibility:

- Do not depend on `MTKView.currentDrawable` for the actual published transport frame when robust background publishing is required.
- Prefer an offscreen Metal render target or `Syphon26ServerDrawable.texture` for publishing.
- Keep preview windows passive; they should not steal key/main focus.
- If an external fullscreen output exists, preserve fullscreen intent separately from currently available screens.

Use the `appkit-passive-output-window` skill as well when the task involves preview, fullscreen, display routing, or non-fronting AppKit output windows.

## Anti-Patterns

Reject or rewrite these approaches:

- `import Syphon`
- `SyphonServer`, `SyphonClient`, `SyphonMetalServer`, or `SyphonServerDirectory` as the primary implementation.
- `CGWindowListCreateImage`, `CGDisplayStream`, `CGContextDrawImage`, `getBytes`, `CVPixelBufferLockBaseAddress`, `replaceRegion`, or vImage conversion inside the frame loop.
- Recreating the server every frame.
- Publishing from a preview window screenshot.
- Blocking the producer behind slow consumers.
- Exposing raw IOSurface IDs, XPC handles, or shared-memory pointers as app-facing public API.

## Validation

Run local validation after implementation:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

For the Syphon26 repo itself, use the bundled sample pair:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_simple_pair.sh --duration 5 --width 1920 --height 1080 --fps 60
```

For performance claims, require same-machine, same-session comparisons against classic Syphon. Fixed-FPS tests prove stability; max-throughput tests prove speedup. Do not claim `syphon26-mixer` or another app is faster until that specific app is benchmarked under equal input count, resolution, pixel format, and display state.

Check profiler output for forbidden CPU capture/readback symbols when optimizing:

- `CGWindowListCreateImage`
- `SLWindowListCreateImage`
- `CGContextDrawImage`
- `CVPixelBufferLockBaseAddress`
- `getBytes`
- `replaceRegion`
- `vImage`

## Prompt Template For Other Implementations

When asked to hand this off to another agent or repo, give a compact directive:

```md
Use Syphon26 native transport only. Do not use Syphon.framework or a classic Syphon bridge. Add the SwiftPM `Syphon26` product, run or bundle a shared `Syphon26ControlPlaneService`, publish by rendering into `Syphon26ServerDrawable.texture`, consume with `Syphon26Client.copyLatestFrame()`, honor `frame.encodeWait(on:)`, and close frames only after GPU usage completes. Keep all frame transfer on Metal/IOSurface and reject CPU readback, screen capture, or window capture in the frame loop.
```
