#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

swift build

MODULE_DIR="$(find .build -path '*/debug/Modules' -type d | head -n 1)"
if [[ -z "$MODULE_DIR" ]]; then
  echo "Syphon26 Swift module directory was not found" >&2
  exit 1
fi

swiftc -swift-version 6 \
  -enable-upcoming-feature ExistentialAny \
  -typecheck \
  -I "$MODULE_DIR" \
  Examples/APIUsage/SwiftCompileOnly.swift

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
clang -fsyntax-only \
  -x objective-c \
  -fobjc-arc \
  -fmodules \
  -isysroot "$SDK_PATH" \
  -mmacosx-version-min=14.0 \
  -I include \
  Examples/APIUsage/ObjCCompileOnly.m

for header in include/Syphon26/*.h; do
  clang -fsyntax-only \
    -x objective-c \
    -fobjc-arc \
    -fmodules \
    -isysroot "$SDK_PATH" \
    -mmacosx-version-min=14.0 \
    -I include \
    -include "$header" \
    /dev/null
done
