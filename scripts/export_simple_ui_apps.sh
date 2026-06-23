#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

cd "$ROOT_DIR"

swift build --product Syphon26SimpleServerApp
swift build --product Syphon26SimpleClientApp
swift build --product Syphon26TestPatternServerApp
swift build --product Syphon26TestPatternClientApp

dist_dir="$ROOT_DIR/dist"
mkdir -p "$dist_dir"

create_app() {
  local product="$1"
  local bundle_name="$2"
  local executable_path
  executable_path="$(swift build --show-bin-path)/$product"
  local app_dir="$dist_dir/$bundle_name.app"

  rm -rf "$app_dir"
  mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
  cp "$executable_path" "$app_dir/Contents/MacOS/$bundle_name"
  chmod +x "$app_dir/Contents/MacOS/$bundle_name"

  cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$bundle_name</string>
  <key>CFBundleIdentifier</key>
  <string>com.syphon26.$bundle_name</string>
  <key>CFBundleName</key>
  <string>$bundle_name</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.2.0-dev</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
</dict>
</plist>
PLIST

  printf '%s\n' "$app_dir"
}

create_app "Syphon26SimpleServerApp" "Syphon26SimpleServerApp"
create_app "Syphon26SimpleClientApp" "Syphon26SimpleClientApp"
create_app "Syphon26TestPatternServerApp" "Syphon26TestPatternServerApp"
create_app "Syphon26TestPatternClientApp" "Syphon26TestPatternClientApp"
