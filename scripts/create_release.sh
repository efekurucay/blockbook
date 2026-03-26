#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TAG="${1:-v1.0.0}"
VERSION="${TAG#v}"
RELEASE_NOTES_PATH="$ROOT_DIR/RELEASE_NOTES.md"

ensure_release_notes() {
    if [[ -f "$RELEASE_NOTES_PATH" ]]; then
        return
    fi

    cat > "$RELEASE_NOTES_PATH" <<EOF
## What's New
- Initial release of BlockBook

## Installation
1. Download \`BlockBook-$VERSION.dmg\`
2. Open the DMG and drag BlockBook to Applications
3. Grant Accessibility permission when prompted
4. Launch BlockBook from Applications

## Requirements
- macOS 13.0 or later
- Accessibility permission (System Settings → Privacy & Security → Accessibility)

## Verification
Verify the download integrity:
\`shasum -a 256 -c BlockBook-$VERSION.dmg.sha256\`
EOF
}

if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Bu komut bir git repository icinde calistirilmali." >&2
    exit 1
fi

"$ROOT_DIR/scripts/package_dmg.sh"
ensure_release_notes

if ! git -C "$ROOT_DIR" rev-parse "$TAG" >/dev/null 2>&1; then
    git -C "$ROOT_DIR" tag -a "$TAG" -m "Release $TAG"
fi

gh release create "$TAG" \
    "$ROOT_DIR"/dist/BlockBook-*.dmg \
    "$ROOT_DIR"/dist/BlockBook-*.dmg.sha256 \
    --title "BlockBook $TAG" \
    --notes-file "$RELEASE_NOTES_PATH" \
    --latest
