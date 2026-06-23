#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

cd "$ROOT_DIR"

health_json="$(swift run Syphon26ControlPlaneService --health-check)"

printf '%s\n' "$health_json" | grep -q '"serviceName":"com.syphon26.control-plane"'
printf '%s\n' "$health_json" | grep -q '"schemaVersion":1'
printf '%s\n' "$health_json" | grep -q '"permissionToken":"syphon26.local-user"'
printf '%s\n' "$health_json" | grep -q '"bootIdentifier":"local-session"'

printf '%s\n' "$health_json"
