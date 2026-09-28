#!/usr/bin/env bash
set -euo pipefail

# Renders documentation screenshots off-screen from the real SwiftUI views
# using mock data (RFC 5737 ranges), so no personal IPs appear.
#
# Usage: make-screenshots.sh [output-dir]

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/docs/screenshots}"
TMPDIR_BIN="$(mktemp -d)"
BIN="$TMPDIR_BIN/ipwatch-snapshot"

SOURCES=(
  "$ROOT/Sources/IPWatch/Models.swift"
  "$ROOT/Sources/IPWatch/IPService.swift"
  "$ROOT/Sources/IPWatch/NetworkMonitor.swift"
  "$ROOT/Sources/IPWatch/SharedStore.swift"
  "$ROOT/Sources/IPWatch/AppState.swift"
  "$ROOT/Sources/IPWatch/ContentView.swift"
  "$ROOT/Widget/IPWatchWidget.swift"
  "$ROOT/Widget/RefreshIntent.swift"
  "$ROOT/tools/Snapshot.swift"
)

echo "==> Compiling snapshot tool…"
xcrun swiftc -parse-as-library -O \
  -framework SwiftUI -framework AppKit -framework WidgetKit \
  -framework AppIntents -framework ServiceManagement \
  -framework Network -framework SystemConfiguration \
  -o "$BIN" "${SOURCES[@]}"

echo "==> Rendering…"
"$BIN" "$OUT"
rm -rf "$TMPDIR_BIN"
