# Syphon26 Examples

## Simple Server

`Syphon26SimpleServer` is the minimal producer example. It creates a Metal-backed Syphon26 stream, renders a changing clear color into a Syphon26 drawable, and publishes that drawable through the control plane.

## Simple Client

`Syphon26SimpleClient` is the minimal consumer example. It attaches to the first visible Syphon26 stream unless `--stream-id` is provided, waits on the shared event when required, and reports observed frame sequences.

## Run Both

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_simple_pair.sh --duration 5 --width 1920 --height 1080 --fps 60
```

Use `INTEGRATION.md` for the app-embedding flow.
