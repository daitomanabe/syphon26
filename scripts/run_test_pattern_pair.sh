#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

duration="1"
fps="60"
width="1280"
height="720"
orientation="normal"
gui="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration)
      duration="$2"
      shift 2
      ;;
    --fps)
      fps="$2"
      shift 2
      ;;
    --width)
      width="$2"
      shift 2
      ;;
    --height)
      height="$2"
      shift 2
      ;;
    --orientation)
      orientation="$2"
      shift 2
      ;;
    --gui)
      gui="1"
      shift
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 64
      ;;
  esac
done

cd "$ROOT_DIR"

swift build --product Syphon26ControlPlaneService
swift build --product Syphon26TestPatternServerApp
swift build --product Syphon26TestPatternClientApp

bin_dir="$(swift build --show-bin-path)"
run_id="$(date +%Y%m%d-%H%M%S)-test-pattern-$$"
run_dir="$ROOT_DIR/benchmark-reports/test-pattern/$run_id"
log_dir="$run_dir/logs"
mkdir -p "$log_dir"

service_name="com.syphon26.test-pattern.$(date +%Y%m%d%H%M%S).$$"
plist_path="$run_dir/$service_name.plist"
server_ready="$run_dir/server.ready"
server_summary="$run_dir/server.json"
client_summary="$run_dir/client.json"

cat > "$plist_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$service_name</string>
  <key>ProgramArguments</key>
  <array>
    <string>$bin_dir/Syphon26ControlPlaneService</string>
    <string>--xpc-mach-service</string>
    <string>$service_name</string>
  </array>
  <key>MachServices</key>
  <dict>
    <key>$service_name</key>
    <true/>
  </dict>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$log_dir/service.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>$log_dir/service.stderr.log</string>
</dict>
</plist>
PLIST

cleanup() {
  set +e
  if [[ -n "${server_pid:-}" ]]; then
    kill "$server_pid" 2>/dev/null
    wait "$server_pid" 2>/dev/null
  fi
  if [[ -n "${client_pid:-}" ]]; then
    kill "$client_pid" 2>/dev/null
    wait "$client_pid" 2>/dev/null
  fi
  launchctl bootout "gui/$(id -u)" "$plist_path" >/dev/null 2>&1
}
trap cleanup EXIT

launchctl bootstrap "gui/$(id -u)" "$plist_path"

common_args=(
  --service-name "$service_name"
  --width "$width"
  --height "$height"
  --fps "$fps"
  --duration "$duration"
  --orientation "$orientation"
)

if [[ "$gui" == "1" ]]; then
  "$bin_dir/Syphon26TestPatternServerApp" "${common_args[@]}" >"$log_dir/server.log" 2>&1 &
  server_pid="$!"
  sleep 0.5
  "$bin_dir/Syphon26TestPatternClientApp" "${common_args[@]}" >"$log_dir/client.log" 2>&1 &
  client_pid="$!"
  python3 - <<PY
import json
print(json.dumps({
  "status": "ok",
  "mode": "gui",
  "serviceName": "$service_name",
  "runDir": "$run_dir",
  "serverPID": int("$server_pid"),
  "clientPID": int("$client_pid")
}, indent=2, sort_keys=True))
PY
  wait "$server_pid"
  wait "$client_pid"
else
  "$bin_dir/Syphon26TestPatternClientApp" \
    --smoke \
    "${common_args[@]}" \
    --summary "$client_summary" \
    >"$log_dir/client.log" 2>&1 &
  client_pid="$!"

  "$bin_dir/Syphon26TestPatternServerApp" \
    --smoke \
    "${common_args[@]}" \
    --hold-seconds 1 \
    --ready-file "$server_ready" \
    --summary "$server_summary" \
    >"$log_dir/server.log" 2>&1 &
  server_pid="$!"

  deadline=$((SECONDS + 10))
  while [[ ! -f "$server_ready" ]]; do
    if [[ "$SECONDS" -gt "$deadline" ]]; then
      printf 'server did not become ready; see %s\n' "$log_dir/server.log" >&2
      exit 1
    fi
    sleep 0.05
  done

  wait "$client_pid"
  wait "$server_pid"

  python3 - <<PY
import json
from pathlib import Path
server = json.loads(Path("$server_summary").read_text())
client = json.loads(Path("$client_summary").read_text())
status = "ok" if client.get("textureOpened") and client.get("framesObserved", 0) > 0 else "failed"
print(json.dumps({
  "status": status,
  "serviceName": "$service_name",
  "runDir": "$run_dir",
  "server": server,
  "client": client
}, indent=2, sort_keys=True))
raise SystemExit(0 if status == "ok" else 1)
PY
fi
