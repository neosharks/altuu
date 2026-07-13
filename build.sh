#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/Altuu.app"
MACOS_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"
BIN="$MACOS_DIR/Altuu"

echo "==> Cleaning"
rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RES_DIR"

SDK="$(xcrun --show-sdk-path)"

echo "==> Compiling Swift sources"
swiftc \
    -sdk "$SDK" \
    -target arm64-apple-macos14.0 \
    -swift-version 5 \
    -O \
    -framework AppKit \
    -framework ScreenCaptureKit \
    -framework CoreGraphics \
    -framework ApplicationServices \
    -framework ServiceManagement \
    -o "$BIN" \
    "$ROOT"/Sources/*.swift

echo "==> Assembling bundle"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

if [ -f "$ROOT/build_assets/AppIcon.icns" ]; then
    cp "$ROOT/build_assets/AppIcon.icns" "$RES_DIR/AppIcon.icns"
    echo "   bundled AppIcon.icns"
fi

echo "==> Code signing"
SIGN_KC="$HOME/.altuu-signing/signing.keychain-db"
SIGN_ID="Altuu Dev"
[ -f "$SIGN_KC" ] && security unlock-keychain -p alttab "$SIGN_KC" >/dev/null 2>&1 || true
if [ -f "$SIGN_KC" ] && codesign --force --deep --sign "$SIGN_ID" --keychain "$SIGN_KC" "$APP" >/dev/null 2>&1; then
    echo "   signed with stable identity '$SIGN_ID' (TCC grant survives rebuilds)"
else
    codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
    echo "   ad-hoc signed (fallback — re-grant needed after each rebuild)"
fi

echo "==> Built: $APP"
