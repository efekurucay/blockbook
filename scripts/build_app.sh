#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="BlockBook"
APP_DIR="$ROOT_DIR/dist/BlockBook.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE_DIR="$ROOT_DIR/Assets.xcassets/AppIcon.appiconset"
SIGNING_IDENTITY="${BLOCKBOOK_CODESIGN_IDENTITY:--}"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/blockbook-build.XXXXXX")
ICONSET_DIR="$TMP_DIR/$APP_NAME.iconset"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

generate_app_icon() {
    mkdir -p "$ICONSET_DIR"

    cp -fX "$ICON_SOURCE_DIR/16.png" "$ICONSET_DIR/icon_16x16.png"
    cp -fX "$ICON_SOURCE_DIR/32.png" "$ICONSET_DIR/icon_16x16@2x.png"
    cp -fX "$ICON_SOURCE_DIR/32.png" "$ICONSET_DIR/icon_32x32.png"
    cp -fX "$ICON_SOURCE_DIR/64.png" "$ICONSET_DIR/icon_32x32@2x.png"
    cp -fX "$ICON_SOURCE_DIR/128.png" "$ICONSET_DIR/icon_128x128.png"
    cp -fX "$ICON_SOURCE_DIR/256.png" "$ICONSET_DIR/icon_128x128@2x.png"
    cp -fX "$ICON_SOURCE_DIR/256.png" "$ICONSET_DIR/icon_256x256.png"
    cp -fX "$ICON_SOURCE_DIR/512.png" "$ICONSET_DIR/icon_256x256@2x.png"
    cp -fX "$ICON_SOURCE_DIR/512.png" "$ICONSET_DIR/icon_512x512.png"
    cp -fX "$ICON_SOURCE_DIR/1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/$APP_NAME.icns"
}

swift build -c release --package-path "$ROOT_DIR"
BIN_DIR=$(swift build -c release --package-path "$ROOT_DIR" --show-bin-path)

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

rm -rf "$CONTENTS_DIR/_CodeSignature"
rm -f "$CONTENTS_DIR/CodeResources"
rm -f "$CONTENTS_DIR/Info.plist"
rm -f "$MACOS_DIR/$APP_NAME"
rm -f "$RESOURCES_DIR/$APP_NAME.icns"

cp -fX "$ROOT_DIR/AppBundle/Info.plist" "$CONTENTS_DIR/Info.plist"
cp -fX "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
generate_app_icon

if [[ -n "$SIGNING_IDENTITY" ]]; then
    codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR" >/dev/null
    echo "Built $APP_DIR (signed with $SIGNING_IDENTITY)"
else
    codesign --remove-signature "$MACOS_DIR/$APP_NAME" >/dev/null 2>&1 || true
    xattr -cr "$APP_DIR" 2>/dev/null || true
    echo "Built $APP_DIR (unsigned local build)"
fi
