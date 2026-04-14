#!/usr/bin/env bash
# Vendor the latest bloom wasm bundle into fugue.
#
# Usage:
#   bin/update-bloom.sh [path-to-bloom-checkout]
#
# Expects bloom to be already built — run `wasm-pack build --target web --release`
# in the bloom repo first.
set -euo pipefail

BLOOM_DIR="${1:-../bloom}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
VENDOR_DIR="$REPO_ROOT/assets/vendor/bloom"

if [ ! -d "$BLOOM_DIR/pkg" ]; then
  echo "error: no pkg/ at $BLOOM_DIR" >&2
  echo "       cd into the bloom repo and run: wasm-pack build --target web --release" >&2
  exit 1
fi

SHA="$(git -C "$BLOOM_DIR" rev-parse HEAD)"
DIRTY=""
if ! git -C "$BLOOM_DIR" diff-index --quiet HEAD --; then
  DIRTY=" (dirty)"
fi

# Only copy the files fugue actually needs. wasm-pack generates extras
# (README, .d.ts, package.json, bloom_bg.js glue) that we don't use, plus
# a .gitignore that would stop git from tracking anything here.
mkdir -p "$VENDOR_DIR/pkg"
cp "$BLOOM_DIR/pkg/bloom.js"       "$VENDOR_DIR/pkg/bloom.js"
cp "$BLOOM_DIR/pkg/bloom_bg.wasm"  "$VENDOR_DIR/pkg/bloom_bg.wasm"
cp "$BLOOM_DIR/pkg/LICENSE"        "$VENDOR_DIR/pkg/LICENSE"

echo "$SHA$DIRTY" > "$VENDOR_DIR/VERSION"

echo "vendored bloom pkg/ from $SHA$DIRTY"
echo
echo "review and commit:"
echo "  git -C $REPO_ROOT add assets/vendor/bloom"
echo "  git -C $REPO_ROOT commit -m 'bump bloom to ${SHA:0:10}'"
