#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PIXEL_FORMAT="bgra8"
DURATION="5"
WIDTH="1920"
HEIGHT="1080"
FPS="60"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pixel-format)
      PIXEL_FORMAT="$2"
      shift 2
      ;;
    --duration)
      DURATION="$2"
      shift 2
      ;;
    --width)
      WIDTH="$2"
      shift 2
      ;;
    --height)
      HEIGHT="$2"
      shift 2
      ;;
    --fps)
      FPS="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

swift build -c release

SERVICE_NAME="com.syphon26.samples.$(id -u).$$"
SERVICE_BIN="$ROOT_DIR/.build/release/Syphon26ControlPlaneService"
PRODUCER_BIN="$ROOT_DIR/.build/release/Syphon26SampleProducer"
CONSUMER_BIN="$ROOT_DIR/.build/release/Syphon26SampleConsumer"
PLIST="${TMPDIR:-/tmp}/syphon26-sample-${SERVICE_NAME}.plist"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${SERVICE_NAME}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${SERVICE_BIN}</string>
    <string>--mach-service</string>
    <string>${SERVICE_NAME}</string>
  </array>
  <key>MachServices</key>
  <dict>
    <key>${SERVICE_NAME}</key>
    <true/>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
PLIST

cleanup() {
  set +e
  if [[ -n "${PRODUCER_PID:-}" ]]; then
    kill "$PRODUCER_PID" 2>/dev/null
    wait "$PRODUCER_PID" 2>/dev/null
  fi
  launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null
  rm -f "$PLIST"
  set -e
}
trap cleanup EXIT

launchctl bootstrap "gui/$(id -u)" "$PLIST"
sleep 0.8

"$PRODUCER_BIN" \
  --mach-service "$SERVICE_NAME" \
  --duration "$DURATION" \
  --width "$WIDTH" \
  --height "$HEIGHT" \
  --fps "$FPS" \
  --pixel-format "$PIXEL_FORMAT" &
PRODUCER_PID=$!

sleep 0.5

"$CONSUMER_BIN" \
  --mach-service "$SERVICE_NAME" \
  --duration "$DURATION" \
  --pixel-format "$PIXEL_FORMAT"

wait "$PRODUCER_PID"
PRODUCER_PID=""
