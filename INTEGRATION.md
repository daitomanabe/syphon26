# Syphon26 Integration Guide

Syphon26 Phase 1 is a SwiftPM library for Metal-native macOS apps. It is designed to be embedded by Swift/AppKit/Metal applications that can share a Syphon26 control-plane service.

Classic Syphon interoperability is not part of this integration path.

## Add The Package

Add Syphon26 as a Swift Package dependency:

```swift
.package(url: "https://github.com/daitomanabe/syphon26.git", branch: "main")
```

Then add the product to your app target:

```swift
.product(name: "Syphon26", package: "syphon26")
```

Your app needs:

- macOS 14 or newer.
- Metal.
- A shared Syphon26 control-plane Mach service reachable by both the producer and consumer processes.

## Control Plane

Cross-process Syphon26 sharing uses the `Syphon26ControlPlaneService` executable target. Producer and consumer apps must use the same Mach service name.

Default name:

```swift
Syphon26.defaultControlPlaneMachServiceName
```

For development, use the local simple pair script:

```bash
scripts/run_simple_pair.sh --duration 5 --width 1920 --height 1080 --fps 60
```

For an app distribution, bundle or install a launchd service that runs:

```bash
Syphon26ControlPlaneService --mach-service com.syphon26.control-plane
```

The launchd plist must declare the same name under `MachServices`. Apps then create a control plane with:

```swift
let controlPlane = Syphon26ControlPlane()
```

or with an explicit service:

```swift
let controlPlane = Syphon26ControlPlane(machServiceName: "com.example.yourapp.syphon26")
```

## Minimal Server

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

// Encode your Metal render pass into drawable.texture here.

try server.presentDrawable(drawable, commandBuffer: commandBuffer)
commandBuffer.commit()
```

## Minimal Client

```swift
import Metal
import Syphon26

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let controlPlane = Syphon26ControlPlane()

let client = try Syphon26Client(
    configuration: Syphon26ClientConfiguration(
        device: device,
        preferredPixelFormats: [.bgra8Unorm, .rgba16Float],
        controlPlane: controlPlane
    )
)
try client.start()

if let frame = try client.copyLatestFrame() {
    if frame.requiresGPUWait {
        let commandBuffer = queue.makeCommandBuffer()!
        try frame.encodeWait(on: commandBuffer)

        // Encode your Metal work that samples frame.texture after the wait.

        commandBuffer.commit()
    }
    frame.close()
}
```

## Simple Examples

Build the examples:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release
```

Run both examples with a temporary launchd-managed control plane:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_simple_pair.sh --duration 5 --width 1920 --height 1080 --fps 60
```

Run the executables manually when a control-plane service is already available:

```bash
.build/release/Syphon26SimpleServer --duration 0
.build/release/Syphon26SimpleClient --duration 5
```

## Fast-Path Rules

- Render directly into `Syphon26ServerDrawable.texture` when possible.
- Publish with the command buffer that contains the producer writes.
- Do not call CPU texture readback APIs in the frame loop.
- Do not implement Syphon26 transport by screen or window capture.
- Keep stream names stable for the lifetime of a server instance.
- Use diagnostics to report fallback mode, missed frames, repeated reads, and GPU wait time.
