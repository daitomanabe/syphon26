#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DEST_DIR="${1:-$ROOT_DIR/dist/Syphon26 Apps}"
VERSION="${SYPHON26_APP_VERSION:-0.1.0}"

SERVER_APP_NAME="Syphon26 Simple Server"
CLIENT_APP_NAME="Syphon26 Simple Client"
SERVER_PRODUCT="Syphon26SimpleServerApp"
CLIENT_PRODUCT="Syphon26SimpleClientApp"
HELPER_PRODUCT="Syphon26ControlPlaneService"

swift build -c release

mkdir -p "$DEST_DIR"
rm -rf \
  "$DEST_DIR/${SERVER_APP_NAME}.app" \
  "$DEST_DIR/${CLIENT_APP_NAME}.app" \
  "$DEST_DIR/Helpers"
rm -f \
  "$DEST_DIR/Run Simple UI Pair.command" \
  "$DEST_DIR/README.txt"
mkdir -p "$DEST_DIR/Helpers"

write_info_plist() {
  local plist_path="$1"
  local app_name="$2"
  local executable="$3"
  local bundle_identifier="$4"

  cat > "$plist_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${executable}</string>
  <key>CFBundleIdentifier</key>
  <string>${bundle_identifier}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${app_name}</string>
  <key>CFBundleDisplayName</key>
  <string>${app_name}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST
}

copy_app() {
  local product="$1"
  local app_name="$2"
  local bundle_identifier="$3"
  local app_dir="$DEST_DIR/${app_name}.app"
  local executable_path="$app_dir/Contents/MacOS/$product"

  mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
  cp "$ROOT_DIR/.build/release/$product" "$executable_path"
  chmod +x "$executable_path"
  write_info_plist "$app_dir/Contents/Info.plist" "$app_name" "$product" "$bundle_identifier"
  codesign --force --deep --sign - "$app_dir"
  codesign --verify --deep --strict --verbose=2 "$app_dir"
}

copy_app "$SERVER_PRODUCT" "$SERVER_APP_NAME" "ws.daito.syphon26.simple-server"
copy_app "$CLIENT_PRODUCT" "$CLIENT_APP_NAME" "ws.daito.syphon26.simple-client"

cp "$ROOT_DIR/.build/release/$HELPER_PRODUCT" "$DEST_DIR/Helpers/$HELPER_PRODUCT"
chmod +x "$DEST_DIR/Helpers/$HELPER_PRODUCT"

cat > "$DEST_DIR/Run Simple UI Pair.command" <<'COMMAND'
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
STREAM_NAME="${1:-Syphon26 Simple UI Server}"
SERVICE_NAME="com.syphon26.simple-ui.$(id -u).$$"
SERVICE_BIN="$APP_DIR/Helpers/Syphon26ControlPlaneService"
SERVER_BIN="$APP_DIR/Syphon26 Simple Server.app/Contents/MacOS/Syphon26SimpleServerApp"
CLIENT_BIN="$APP_DIR/Syphon26 Simple Client.app/Contents/MacOS/Syphon26SimpleClientApp"
PLIST="${TMPDIR:-/tmp}/syphon26-simple-ui-${SERVICE_NAME}.plist"

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

echo "Syphon26 Simple UI pair"
echo "  service: ${SERVICE_NAME}"
echo "  stream:  ${STREAM_NAME}"

launchctl bootstrap "gui/$(id -u)" "$PLIST"
for _ in {1..30}; do
  if launchctl print "gui/$(id -u)/$SERVICE_NAME" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
sleep 1.0

"$SERVER_BIN" --mach-service "$SERVICE_NAME" --name "$STREAM_NAME" --auto-start &
SERVER_PID=$!
sleep 0.8
"$CLIENT_BIN" --mach-service "$SERVICE_NAME" --stream-name "$STREAM_NAME" --auto-connect &
CLIENT_PID=$!

wait "$SERVER_PID"
SERVER_PID=""
wait "$CLIENT_PID"
CLIENT_PID=""
COMMAND
chmod +x "$DEST_DIR/Run Simple UI Pair.command"

cat > "$DEST_DIR/README.txt" <<README
Syphon26 Simple UI Apps

Double-click "Run Simple UI Pair.command" to start a temporary Syphon26 control plane, then launch both apps connected to the same stream.

You can also open these apps directly:
- ${SERVER_APP_NAME}.app
- ${CLIENT_APP_NAME}.app

Direct app launch uses the default control plane service:
${SYPHON26_CONTROL_PLANE_SERVICE:-com.syphon26.control-plane}

Exported by:
scripts/export_simple_ui_apps.sh
README

echo "Exported Syphon26 UI apps to:"
echo "$DEST_DIR"
