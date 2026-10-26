#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Acceptance runs for the X Millennium reference runner (docs/XMIL_REFERENCE_STATUS.md).
# Usage: tools/xmil-cli/acceptance.sh ROM_DIR AOKI_D88 TESTER_DISK_DIR NEW_OUT_DIR [BUILD_DIR]
#   ROM_DIR holds IPLROM.X1, IPLROM.X1T, FNT0808.X1, FNT0816.X1, FNT1616.X1
#   (private assets; never commit them).
set -eu
TOOL_DIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$TOOL_DIR/../.." && pwd)
R=$1; AOKI=$2; G=$3; O=$4
X=${5:-$REPO/output_files/xmil-cli/build-b07506c0cae3}
mkdir "$O"
run() { "$X/xmil-cli" --core "$X/x1_libretro.dylib" --ipl-x1 "$R/IPLROM.X1" \
  --ipl-turbo "$R/IPLROM.X1T" --font8 "$R/FNT0808.X1" --font16 "$R/FNT0816.X1" \
  --kanji "$R/FNT1616.X1" "$@"; }

for mon in high standard; do
  run --work "$O/w_aoki_$mon" --ms 85000 --model turbo --monitor "$mon" --fdd0 "$AOKI" \
    --keys "$TOOL_DIR/examples/aoki_charmake.keys" \
    --frame 50000 "$O/aoki_${mon}_title.png" --frame 63000 "$O/aoki_${mon}_menu.png" \
    --frame 80000 "$O/aoki_${mon}_charmake.png" --wav "$O/aoki_$mon.wav" \
    > "$O/aoki_$mon.json" 2> "$O/aoki_$mon.err"
done
run --work "$O/w_kohaku" --ms 120000 --model turboz --monitor high \
  --fdd0 "$G/Kohakuiro1.d88" --fdd1 "$G/Kohakuiro2.d88" \
  --frame 60000 "$O/kohaku_60.png" --frame 100000 "$O/kohaku_100.png" \
  --frame 120000 "$O/kohaku_120.png" > "$O/kohaku.json" 2> "$O/kohaku.err"
# Control: the same disks on the X1 turbo model (no Turbo Z palette).
run --work "$O/w_kohaku_turbo" --ms 60000 --model turbo --monitor high \
  --fdd0 "$G/Kohakuiro1.d88" --fdd1 "$G/Kohakuiro2.d88" \
  --frame 60000 "$O/kohaku_as_turbo_60.png" > "$O/kohaku_turbo.json" 2> "$O/kohaku_turbo.err"
run --work "$O/w_galaga" --ms 60000 --model x1 --monitor standard --fdd0 "$G/Galaga.2d" \
  --frame 30000 "$O/galaga_30.png" --frame 60000 "$O/galaga_60.png" \
  > "$O/galaga.json" 2> "$O/galaga.err"
ls "$O"/*.png
