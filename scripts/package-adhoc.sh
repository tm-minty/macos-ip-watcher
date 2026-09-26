#!/usr/bin/env bash
set -euo pipefail

# Builds the app + widget extension from the committed Xcode project, ad-hoc
# signs them (no Apple account required) and produces dist/IPWatch.app.zip.
#
# No Ruby / xcodeproj gem needed: IPWatch.xcodeproj is committed. Regenerate it
# with `make xcode-regen` only if you change the target file lists.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="IPWatch"
DERIVED="$ROOT/.build/xcode-adhoc"
APP="$DERIVED/Build/Products/Release/$APP_NAME.app"

echo "==> Building (ad-hoc signed)…"
xcodebuild -project "$ROOT/IPWatch.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" PROVISIONING_PROFILE_SPECIFIER="" build

echo "==> Packaging…"
mkdir -p "$ROOT/dist"
rm -rf "$ROOT/dist/$APP_NAME.app" "$ROOT/dist/$APP_NAME.app.zip"
ditto "$APP" "$ROOT/dist/$APP_NAME.app"
ditto -c -k --sequesterRsrc --keepParent "$ROOT/dist/$APP_NAME.app" "$ROOT/dist/$APP_NAME.app.zip"

echo "==> Done:"
echo "    app: $ROOT/dist/$APP_NAME.app"
echo "    zip: $ROOT/dist/$APP_NAME.app.zip"
