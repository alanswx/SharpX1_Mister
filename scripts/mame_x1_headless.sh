#!/usr/bin/env bash
# Run MAME's x1/x1turbo headless on one disk and save periodic PNG snapshots.
# Reference-emulator comparison only; ROMs and media are never copied into git.
#
# Usage: scripts/mame_x1_headless.sh DRIVER DISK OUTDIR [SNAP_EVERY] [MAX_FRAME]
#   DRIVER   x1 or x1turbo
#   DISK     .d88/.2d image (opened through a read-only copy)
#   OUTDIR   work directory; snapshots land in OUTDIR/snap/<name>/NNNN.png
# Environment:
#   MAME     MAME binary (default ~/Downloads/mame0283-arm64/mame)
#   ROMPATH  directory holding x1.zip and/or x1turbo/ (default OUTDIR/roms)
# x1turbo needs ipl.x1t (software/turbo-firmware/212895703175-ipl.x1t matches
# MAME's SHA-1). Missing turbo fonts/Kanji may be placeholders; MAME then warns
# about wrong checksums and text output is not representative.
set -euo pipefail
DRIVER="${1:?driver}"; DISK="${2:?disk}"; OUT="${3:?outdir}"
EVERY="${4:-300}"; MAXF="${5:-3600}"
MAME="${MAME:-$HOME/Downloads/mame0283-arm64/mame}"
ROMPATH="${ROMPATH:-$OUT/roms}"
mkdir -p "$OUT/media" "$OUT/snap" "$OUT/cfg" "$OUT/nvram"
name="$(basename "${DISK%.*}" | tr -c 'A-Za-z0-9_\n' '_')"
ext="${DISK##*.}"
media="$OUT/media/$name.$ext"
cp "$DISK" "$media"; chmod 444 "$media"
cat > "$OUT/snap.lua" <<'LUA'
local every = tonumber(os.getenv("SNAP_EVERY"))
local maxf = tonumber(os.getenv("MAX_FRAME"))
local f = 0
emu.register_frame_done(function()
  f = f + 1
  if f % every == 0 then manager.machine.video:snapshot() end
  if f >= maxf then manager.machine:exit() end
end)
LUA
rm -rf "$OUT/snap/${DRIVER}_$name"
SNAP_EVERY="$EVERY" MAX_FRAME="$MAXF" "$MAME" "$DRIVER" -rompath "$ROMPATH" \
  -flop1 "$media" -skip_gameinfo -video none -sound none -nothrottle \
  -snapshot_directory "$OUT/snap" -cfg_directory "$OUT/cfg" \
  -nvram_directory "$OUT/nvram" -window -autoboot_script "$OUT/snap.lua" \
  -snapname "${DRIVER}_$name/%i"
for f in "$OUT/snap/${DRIVER}_$name"/*.png; do
  printf '%s %s\n' "$(shasum -a 256 "$f" | cut -c1-12)" "$f"
done
