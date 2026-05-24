# Syphon26 Examples

## Simple Server

`Syphon26SimpleServer` is the minimal producer example. It creates a Metal-backed Syphon26 stream, renders a changing clear color into a Syphon26 drawable, and publishes that drawable through the control plane.

## Simple Client

`Syphon26SimpleClient` is the minimal consumer example. It attaches to the first visible Syphon26 stream unless `--stream-id` or `--stream-name` is provided, waits on the shared event when required, and reports observed frame sequences.

## Simple Server App

`Syphon26SimpleServerApp` is the AppKit control-panel version of the server. It can choose resolution and frame rate automatically from the current display or manually from UI fields, pick BGRA8 or RGBA16F, preview the generated texture, and show stream ID, published frames, client count, actual publish FPS, sync mode, and transport diagnostics. The generated texture includes colored edges, corner blocks, color bars, grid lines, a center cross, and a moving frame marker so cropping, orientation, channel order, format, and dropped/repeated frames are easy to spot.

## Simple Client App

`Syphon26SimpleClientApp` is the AppKit control-panel version of the client. It lists visible Syphon26 servers/streams, connects to a selected server, previews the received texture on the GPU, supports automatic or manually expected resolution and frame-rate checks, and shows observed FPS, frame size, repeated reads, sequence, sync mode, and diagnostics.

## Run Both

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_simple_pair.sh --duration 5 --width 1920 --height 1080 --fps 60
```

The pair script gives the server and client the same stream name, so the client does not accidentally attach to another visible Syphon26 stream on a shared control-plane service.

Run the UI pair:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_simple_ui_pair.sh
```

Export double-clickable UI apps into the local development tree at `dist/Syphon26 Apps`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/export_simple_ui_apps.sh
```

Use `INTEGRATION.md` for the app-embedding flow.
