#!/bin/bash
set -e

# Determine Android build root
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TOP="${ANDROID_BUILD_TOP:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
DIFFS_DIR="$SCRIPT_DIR/diffs"

if [ ! -d "$DIFFS_DIR" ]; then
    echo "[-] Error: diffs directory not found at $DIFFS_DIR" >&2
    exit 1
fi

echo "==> Applying device/google/trogdor tree patches from diffs/..."

find "$DIFFS_DIR" -type f -name "*.patch" | sort | while read -r patch_file; do
    rel_repo="$(dirname "${patch_file#$DIFFS_DIR/}")"
    target_repo="$TOP/$rel_repo"

    if [ ! -d "$target_repo" ]; then
        echo "[-] Skipping $rel_repo (directory not found)"
        continue
    fi

    patch_name="$(basename "$patch_file")"
    echo -n "--> $rel_repo: $patch_name... "

    # Check if already applied (reverse check)
    if git -C "$target_repo" apply --reverse --check "$patch_file" &>/dev/null; then
        echo "Already applied."
    elif git -C "$target_repo" apply --check "$patch_file" &>/dev/null; then
        git -C "$target_repo" apply --whitespace=nowarn "$patch_file"
        echo "Applied cleanly."
    else
        echo "FAILED to apply cleanly!"
        git -C "$target_repo" apply --check -v "$patch_file" || true
    fi
done

echo "==> All tree patches processed."
