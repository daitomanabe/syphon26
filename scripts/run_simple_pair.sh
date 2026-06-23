#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

cd "$ROOT_DIR"

frames="${1:-6}"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/syphon26-simple-pair.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

scripts/verify_control_plane.sh > "$tmp_dir/control-plane.json"
swift run Syphon26SimpleServer --frames "$frames" --json > "$tmp_dir/server.json"
swift run Syphon26SimpleClient --frames "$frames" --json > "$tmp_dir/client.json"

state_file="$tmp_dir/file-control-plane.json"
swift run Syphon26SimpleServer --frames "$frames" --json --state-file "$state_file" --hold-seconds 5 > "$tmp_dir/cross-server.json" &
server_pid="$!"
for _ in $(seq 1 100); do
  if [ -f "$state_file" ]; then
    break
  fi
  sleep 0.05
done
swift run Syphon26SimpleClient --json --state-file "$state_file" --timeout-seconds 5 > "$tmp_dir/cross-client.json"
wait "$server_pid"

python3 - "$tmp_dir/control-plane.json" "$tmp_dir/server.json" "$tmp_dir/client.json" "$tmp_dir/cross-server.json" "$tmp_dir/cross-client.json" "$frames" <<'PY'
import json
import sys

control_path, server_path, client_path, cross_server_path, cross_client_path, frames_raw = sys.argv[1:7]
expected_frames = int(frames_raw)

control = json.load(open(control_path))
server = json.load(open(server_path))
client = json.load(open(client_path))
cross_server = json.load(open(cross_server_path))
cross_client = json.load(open(cross_client_path))

assert control["serviceName"] == "com.syphon26.control-plane", control
assert control["schemaVersion"] == 1, control

assert server["role"] == "simple-server", server
assert server["transportScope"] == "in-process", server
assert server["publishedFrames"] == expected_frames, server
assert server["registeredStreamCount"] == 1, server

assert client["role"] == "simple-client", client
assert client["transportScope"] == "in-process", client
assert client["publishedFrames"] == expected_frames, client
assert client["receivedFrames"] == expected_frames, client
assert client["registeredStreamCount"] == 1, client
assert client["registeredConsumerCount"] == 1, client

assert cross_server["transportScope"] == "cross-process-iosurface-file-control-plane", cross_server
assert cross_server["publishedFrames"] == expected_frames, cross_server
assert cross_server["textureOpened"] is True, cross_server
assert cross_client["transportScope"] == "cross-process-iosurface-file-control-plane", cross_client
assert cross_client["publishedFrames"] == expected_frames, cross_client
assert cross_client["receivedFrames"] == 1, cross_client
assert cross_client["textureOpened"] is True, cross_client
assert cross_client["streamID"] == cross_server["streamID"], (cross_server, cross_client)

print(json.dumps({
    "status": "ok",
    "expectedFrames": expected_frames,
    "serverStreamID": server["streamID"],
    "clientReceivedFrames": client["receivedFrames"],
    "crossProcessStreamID": cross_client["streamID"],
    "crossProcessTextureOpened": cross_client["textureOpened"],
    "transportScope": client["transportScope"],
}, sort_keys=True))
PY
