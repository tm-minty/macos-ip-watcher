#!/usr/bin/env bash
set -euo pipefail

# Builds the app + widget extension from the committed Xcode project, ad-hoc
# signs them (no Apple account required) and produces zips in dist/:
#   IPWatch.app.zip            universal (arm64 + x86_64)
#   IPWatch-arm64.app.zip      Apple Silicon only
#   IPWatch-amd64.app.zip      Intel only
# plus .sha256 checksums for each.
#
# No Ruby / xcodeproj gem needed: IPWatch.xcodeproj is committed.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="IPWatch"
DERIVED="$ROOT/.build/xcode-adhoc"
APP="$DERIVED/Build/Products/Release/$APP_NAME.app"

echo "==> Building (ad-hoc signed)…"
xcodebuild -project "$ROOT/IPWatch.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" PROVISIONING_PROFILE_SPECIFIER="" build

echo "==> Packaging universal…"
mkdir -p "$ROOT/dist"
rm -rf "$ROOT/dist/$APP_NAME.app" "$ROOT/dist/"*.zip "$ROOT/dist/"*.sha256
ditto "$APP" "$ROOT/dist/$APP_NAME.app"
ditto -c -k --sequesterRsrc --keepParent "$ROOT/dist/$APP_NAME.app" "$ROOT/dist/$APP_NAME.app.zip"
shasum -a 256 "$ROOT/dist/$APP_NAME.app.zip" | tee "$ROOT/dist/$APP_NAME.app.zip.sha256"

echo "==> Packaging per-architecture…"
"$ROOT/scripts/package-arch.sh" "$ROOT/dist/$APP_NAME.app" "$ROOT/dist"

echo "==> Done. Zips in $ROOT/dist:"
ls -1 "$ROOT/dist"/*.zip
