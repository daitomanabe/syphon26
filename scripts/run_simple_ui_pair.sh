#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

STREAM_NAME="Syphon26 Simple UI Server"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name|--stream-name)
      STREAM_NAME="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

swift build -c release

SERVICE_NAME="com.syphon26.simple-ui.$(id -u).$$"
SERVICE_BIN="$ROOT_DIR/.build/release/Syphon26ControlPlaneService"
SERVER_APP="$ROOT_DIR/.build/release/Syphon26SimpleServerApp"
CLIENT_APP="$ROOT_DIR/.build/release/Syphon26SimpleClientApp"
PLIST="${TMPDIR:-/tmp}/syphon26-simple-ui-${SERVICE_NAME}.plist"

echo "Syphon26 Simple UI pair"
echo "  service: ${SERVICE_NAME}"
echo "  stream:  ${STREAM_NAME}"

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
  rm -f "$PLIST"
  set -e
}
trap cleanup EXIT

launchctl bootstrap "gui/$(id -u)" "$PLIST"
for _ in {1..30}; do
  if launchctl print "gui/$(id -u)/$SERVICE_NAME" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
sleep 1.0

"$SERVER_APP" --mach-service "$SERVICE_NAME" --name "$STREAM_NAME" --auto-start &
SERVER_PID=$!
sleep 0.8
"$CLIENT_APP" --mach-service "$SERVICE_NAME" --stream-name "$STREAM_NAME" --auto-connect &
CLIENT_PID=$!

wait "$SERVER_PID"
SERVER_PID=""
wait "$CLIENT_PID"
CLIENT_PID=""
