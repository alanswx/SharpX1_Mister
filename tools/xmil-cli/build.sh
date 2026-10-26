#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Build the pinned X Millennium libretro core and the headless xmil-cli
# frontend outside the source tree.  The reference checkout is only read
# through `git archive`; nothing is built or written inside it.
#
# Usage: tools/xmil-cli/build.sh [BUILD_DIR]
# Environment:
#   XMIL_REF     reference checkout (default references/emulators/xmil-libretro)
#   XMIL_REV     pinned revision (default b07506c0cae31d260db28cb079148857d6ca2e93)
#   XMIL_TURBOZ  1 (default) adds SUPPORT_TURBOZ through xmil_overlay.h
#   XMIL_BANKMEM 1 (default) adds SUPPORT_BANKMEM through xmil_overlay.h
#   JOBS         make parallelism (default 8)
set -eu

TOOL_DIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$TOOL_DIR/../.." && pwd)
XMIL_REF=${XMIL_REF:-$REPO/references/emulators/xmil-libretro}
XMIL_REV=${XMIL_REV:-b07506c0cae31d260db28cb079148857d6ca2e93}
XMIL_TURBOZ=${XMIL_TURBOZ:-1}
XMIL_BANKMEM=${XMIL_BANKMEM:-1}
JOBS=${JOBS:-8}
BUILD_DIR=${1:-$REPO/output_files/xmil-cli/build-$(printf %.12s "$XMIL_REV")}

case "$BUILD_DIR" in
  "$XMIL_REF"|"$XMIL_REF"/*) echo "build dir must be outside the reference checkout" >&2; exit 2 ;;
esac

actual=$(git -C "$XMIL_REF" rev-parse "$XMIL_REV^{commit}")
if [ "$actual" != "$XMIL_REV" ]; then
  echo "revision mismatch: $actual" >&2; exit 2
fi

mkdir -p "$BUILD_DIR"
rm -rf "$BUILD_DIR/src"
mkdir "$BUILD_DIR/src"
git -C "$XMIL_REF" archive --format=tar "$XMIL_REV" | tar -x -C "$BUILD_DIR/src"

# Modern clang rejects several K&R-era constructs by default; downgrade only
# those diagnostics.  The overlay is force-included ahead of every file.
DEFS=""
[ "$XMIL_TURBOZ" = 1 ] && DEFS="$DEFS -DXMIL_CLI_TURBOZ"
[ "$XMIL_BANKMEM" = 1 ] && DEFS="$DEFS -DXMIL_CLI_BANKMEM"
CORE_CC="cc -Wno-implicit-function-declaration -Wno-int-conversion \
-Wno-incompatible-pointer-types -Wno-implicit-int$DEFS \
-include $TOOL_DIR/xmil_overlay.h"

make -C "$BUILD_DIR/src/libretro" -j"$JOBS" CC="$CORE_CC" > "$BUILD_DIR/core-build.log" 2>&1 || {
  tail -40 "$BUILD_DIR/core-build.log" >&2; exit 1; }
cp "$BUILD_DIR/src/libretro/x1_libretro.dylib" "$BUILD_DIR/x1_libretro.dylib"

cc -std=c11 -O2 -Wall -Wextra -I"$BUILD_DIR/src/libretro" \
  -o "$BUILD_DIR/xmil-cli" "$TOOL_DIR/xmil_cli.c" -ldl -lz

{
  echo "{"
  echo "  \"xmil_rev\": \"$XMIL_REV\","
  echo "  \"turboz\": $XMIL_TURBOZ,"
  echo "  \"bankmem\": $XMIL_BANKMEM,"
  echo "  \"core_cc\": \"$(echo "$CORE_CC" | tr -s ' ')\","
  echo "  \"core_sha256\": \"$(shasum -a 256 "$BUILD_DIR/x1_libretro.dylib" | cut -d' ' -f1)\","
  echo "  \"cli_sha256\": \"$(shasum -a 256 "$BUILD_DIR/xmil-cli" | cut -d' ' -f1)\""
  echo "}"
} > "$BUILD_DIR/build.json"
cat "$BUILD_DIR/build.json"
git -C "$XMIL_REF" status --short | sed 's/^/reference checkout change: /' >&2
