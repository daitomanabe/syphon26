#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

DURATION="5"
WIDTH="1920"
HEIGHT="1080"
FPS="60"
PIXEL_FORMAT="bgra8"
PRINT_EVERY="120"
STREAM_NAME="Syphon26 Simple Server"

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --pixel-format)
      PIXEL_FORMAT="$2"
      shift 2
      ;;
    --name|--stream-name)
      STREAM_NAME="$2"
      shift 2
      ;;
    --print-every)
      PRINT_EVERY="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

swift build -c release

SERVICE_NAME="com.syphon26.simple.$(id -u).$$"
SERVICE_BIN="$ROOT_DIR/.build/release/Syphon26ControlPlaneService"
SERVER_BIN="$ROOT_DIR/.build/release/Syphon26SimpleServer"
CLIENT_BIN="$ROOT_DIR/.build/release/Syphon26SimpleClient"
PLIST="${TMPDIR:-/tmp}/syphon26-simple-${SERVICE_NAME}.plist"
SERVER_LOG="${TMPDIR:-/tmp}/syphon26-simple-server-${SERVICE_NAME}.log"
CLIENT_LOG="${TMPDIR:-/tmp}/syphon26-simple-client-${SERVICE_NAME}.log"
SERVER_DURATION="$(python3 -c 'import sys; print(float(sys.argv[1]) + 1.0)' "$DURATION")"

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
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
  fi
  if [[ -n "${CLIENT_PID:-}" ]]; then
    kill "$CLIENT_PID" 2>/dev/null
    wait "$CLIENT_PID" 2>/dev/null
  fi
  launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null
  rm -f "$PLIST" "$SERVER_LOG" "$CLIENT_LOG"
  set -e
}
trap cleanup EXIT

launchctl bootstrap "gui/$(id -u)" "$PLIST"
sleep 0.8

"$CLIENT_BIN" \
  --mach-service "$SERVICE_NAME" \
  --duration "$DURATION" \
  --attach-timeout 10 \
  --pixel-format "$PIXEL_FORMAT" \
  --stream-name "$STREAM_NAME" \
  --print-every "$PRINT_EVERY" >"$CLIENT_LOG" 2>&1 &
CLIENT_PID=$!

sleep 0.2

"$SERVER_BIN" \
  --mach-service "$SERVICE_NAME" \
  --duration "$SERVER_DURATION" \
  --width "$WIDTH" \
  --height "$HEIGHT" \
  --fps "$FPS" \
  --name "$STREAM_NAME" \
  --pixel-format "$PIXEL_FORMAT" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

set +e
wait "$CLIENT_PID"
CLIENT_STATUS=$?
CLIENT_PID=""
wait "$SERVER_PID"
SERVER_STATUS=$?
SERVER_PID=""
set -e

cat "$CLIENT_LOG"
cat "$SERVER_LOG"

if [[ "$CLIENT_STATUS" -ne 0 ]]; then
  exit "$CLIENT_STATUS"
fi
if [[ "$SERVER_STATUS" -ne 0 ]]; then
  exit "$SERVER_STATUS"
fi
