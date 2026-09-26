#!/usr/bin/env bash
set -euo pipefail

# Produces thin per-architecture zips from a universal .app bundle.
#
# Usage: package-arch.sh <path/to/IPWatch.app> <output-dir>
# Output: <output-dir>/IPWatch-amd64.app.zip, <output-dir>/IPWatch-arm64.app.zip (+ .sha256)

APP="${1:?usage: package-arch.sh <app> <outdir>}"
OUTDIR="${2:?usage: package-arch.sh <app> <outdir>}"
NAME="$(basename "$APP" .app)"

mkdir -p "$OUTDIR"

thin_binary() {
  local binary="$1"
  lipo -thin "$ARCH" "$binary" -output "$binary.thin"
  mv "$binary.thin" "$binary"
}

for ARCH in arm64 x86_64; do
  if [ "$ARCH" = "x86_64" ]; then LABEL="amd64"; else LABEL="arm64"; fi
  THIN_APP="$OUTDIR/$NAME-$LABEL.app"
  THIN_WIDGET="$THIN_APP/Contents/PlugIns/IPWatchWidget.appex/Contents/MacOS/IPWatchWidget"

  echo "==> building $LABEL"
  rm -rf "$THIN_APP"
  cp -R "$APP" "$THIN_APP"
  thin_binary "$THIN_APP/Contents/MacOS/$NAME"
  if [ -f "$THIN_WIDGET" ]; then
    thin_binary "$THIN_WIDGET"
  fi

  # Modifying the binaries invalidates the signature, so re-sign ad-hoc.
  codesign --force --sign - "$THIN_APP/Contents/PlugIns/IPWatchWidget.appex"
  codesign --force --sign - "$THIN_APP"

  ditto -c -k --sequesterRsrc --keepParent "$THIN_APP" "$OUTDIR/$NAME-$LABEL.app.zip"
  shasum -a 256 "$OUTDIR/$NAME-$LABEL.app.zip" | tee "$OUTDIR/$NAME-$LABEL.app.zip.sha256"
  rm -rf "$THIN_APP"
done
