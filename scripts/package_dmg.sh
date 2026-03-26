#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="BlockBook.app"

resolve_version() {
    local version=""

    version=$(sed -n 's/^let blockBookVersion = "\(.*\)"$/\1/p' "$ROOT_DIR/Package.swift" | head -n 1)

    if [[ -z "$version" ]] && git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        version=$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || true)
        version=${version#v}
    fi

    if [[ -z "$version" ]]; then
        version="1.0.0"
    fi

    printf '%s\n' "$version"
}

ensure_create_dmg() {
    if command -v create-dmg >/dev/null 2>&1; then
        return
    fi

    if ! command -v brew >/dev/null 2>&1; then
        echo "create-dmg kurulu degil ve Homebrew bulunamadi." >&2
        exit 1
    fi

    brew install create-dmg
}

"$ROOT_DIR/scripts/build_app.sh"
ensure_create_dmg

VERSION=$(resolve_version)
DMG_PATH="$DIST_DIR/BlockBook-$VERSION.dmg"
SHA_PATH="$DMG_PATH.sha256"
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/blockbook-dmg.XXXXXX")

cleanup() {
    rm -rf "$STAGING_DIR"
}

trap cleanup EXIT

rm -f "$DMG_PATH" "$SHA_PATH"

ditto "$DIST_DIR/$APP_NAME" "$STAGING_DIR/$APP_NAME"

create-dmg \
    --volname "BlockBook" \
    --window-size 660 400 \
    --icon-size 128 \
    --icon "$APP_NAME" 180 170 \
    --hide-extension "$APP_NAME" \
    --app-drop-link 480 170 \
    "$DMG_PATH" \
    "$STAGING_DIR"

shasum -a 256 "$DMG_PATH" > "$SHA_PATH"

echo "Created $DMG_PATH"
echo "Created $SHA_PATH"
