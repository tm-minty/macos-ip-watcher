#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
MODE="${2:-native}"
APP_NAME="IPWatch"
APP_DIR="$ROOT/dist/$APP_NAME.app"

if [[ "$MODE" == "universal" ]]; then
  build_args=(--arch arm64 --arch x86_64)
  case "$CONFIG" in
    release) BIN_DIR="$ROOT/.build/apple/Products/Release" ;;
    debug)   BIN_DIR="$ROOT/.build/apple/Products/Debug" ;;
    *) echo "unsupported config: $CONFIG" >&2; exit 1 ;;
  esac
else
  build_args=()
  BIN_DIR="$ROOT/.build/$CONFIG"
fi

echo "==> Building ($CONFIG, $MODE)…"
swift build -c "$CONFIG" ${build_args[@]+"${build_args[@]}"} --package-path "$ROOT"

echo "==> Packaging $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

echo "==> Signing (ad-hoc)…"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || echo "codesign skipped"

echo "==> Zipping for transfer…"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ROOT/dist/$APP_NAME.app.zip"

echo "==> Done:"
echo "    app: $APP_DIR"
echo "    zip: $ROOT/dist/$APP_NAME.app.zip"
