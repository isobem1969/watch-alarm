#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
swiftc -module-cache-path "$TEMP_DIR/cache" "$ROOT/Shared/AlarmDocument.swift" "$ROOT/Tests/main.swift" -o "$TEMP_DIR/core-tests"
"$TEMP_DIR/core-tests"
