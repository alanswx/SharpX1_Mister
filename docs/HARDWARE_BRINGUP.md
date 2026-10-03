# MiSTer hardware bring-up

## 2026-10-03 — first native game boot

User explicitly released MiSTer for X1 testing. SSH to `root@mister.local`
worked; the existing Main command FIFO and mrext service were reused without
installing or restarting services. The previous SharpMZ core/media/config were
not overwritten. `scripts/mister_x1.py` stages a unique RBF, setname, config,
IPL and disposable D88 copy under `/media/fat/games/SharpX1/HWTest/`.

First load: compensated timer checkpoint `f45918d`, built in
`output_files/quartus-qOsoLktO/`, RBF SHA-256
`b2ca0708fc679a7babb52bd29dfec994839f5f429dac7b5c67a2b2799866886b`.
Board mode is single clock, existing 28,571,428 Hz PLL output; CPU/FDC and PSG
average rates are 4/2 MHz, MR16 timer uses 32 MHz virtual ticks. Frequency was
not measured on hardware. IPL was converted from checked-in hex to 4096 bytes,
padding the absent final byte with FF; its actual transfer and hashes are in
the ignored deployment manifest. MGL transfers IPL and disk, then resets.

Local evidence directory: `output_files/X1HW_20261003T132233Z_b2ca0708/`.
Remote setname: `X1HW_20261003T132233Z_b2ca0708`.
The first 320x200 screenshot shows CROSS Chase's native title/instructions;
subsequent remote-key screenshots show the running playfield, enemies, mines
and player. This establishes native IPL/disk game boot and remote keyboard
start response through the board wrapper, not just a successful RBF load.
Host-delayed before/after shots span game deaths/level transitions; they do
**not** independently establish exact I/J displacement. The closer on-device
burst captures reduce that delay but still sample the game's blinking player.
Movement equivalence remains demonstrated in simulation, not a hardware gate.

Disk copy SHA-256 before and after testing:
`2fb70389737a7d54bff5a746b581343385ebde115cefb77ded32c473dcde97ec`.
Status config is zero (writes protected). `chmod 444` was requested, but this
FAT mount still reports executable/writable mode bits; do not claim filesystem
read-only protection from chmod. Neither the input image nor the remote copy
changed. Private media, derived IPL and screenshots stay ignored locally.

## Latest source-bound revision

The conditional-interrupt machine in commit `658e27f` was separately fitted as
`output_files/quartus-atzbOrkj/` and loaded under
`X1HW_20261003T134207Z_9126a87a`. RBF SHA-256:
`9126a87ab79ce45c7875bc110c316b20fc7c0e2b5e47c3e0e48781abf46b2851`.
Its native title screenshot is byte-identical to the first hardware title;
remote input reaches `LEVEL 01`. A delayed screenshot labelled `playfield`
actually shows the post-death `Press key` prompt; filenames are requests, not
proof of screenshot contents. The latest disk hash remains unchanged and the
16-byte per-test config is confirmed zero. Core setup/hold/recovery are
+8.761/+0.244/+10.174 ns; external timing and hardware limits still apply.

The subsequent `burst_134828536471` sequence captures a live playfield.
It sends shifted I/J/K/L through mrext in a short on-device loop. Frames 8 and
9 show the cyan player at 8x8 text cells (23,17) and (21,14), respectively;
the life/level display remains unchanged. Positions were checked from actual
PNG pixels (11 cyan glyph pixels in each cell), not inferred from key dispatch.
This establishes directional remote-input response on the latest hardware
revision. It is not the simulation's exact one-up/one-left timing gate:
inputs can repeat/overlap and the player blinks. Unshifted Caps Lock behavior,
physical keyboards and a controlled single-event displacement test remain open.
Frames 8/9 SHA-256 are
`b5e8cc5f07ec7e69dd385245dbe4887b370174cd51665912a4438e4b41d0ce32` /
`228d5cd431914e3f2bb09ca269bcadb5efccefeca8eae08977d4de7cb5de9808`.

## Transport-fix hardware follow-up

The shared transport changes in `4d22dc3` pass synthetic pending-read/write
abort/reset tests and fresh baseline/single-clock native gameplay in simulation.
On 2026-10-03 at approximately 14:20 UTC, a follow-up SSH check could no longer
resolve `mister.local`; an mDNS lookup also produced no address. No new RBF,
config or disk copy was deployed in that attempt. The conditional-interrupt
hardware evidence above remains evidence of the earlier checkpoint only.
The transport revision still needs a new native board boot and, separately,
fault-injection verification during host I/O. Do not infer either from synthesis.

## Repeating a test

```sh
python3 scripts/mister_x1.py deploy /absolute/path/to/source-bound.rbf /absolute/path/to/test.d88
python3 scripts/mister_x1.py key 57
python3 scripts/mister_x1.py capture output_files/X1HW_TIMESTAMP_HASH playfield
python3 scripts/mister_x1.py burst output_files/X1HW_TIMESTAMP_HASH 57 23 36
```

Key codes are Linux input codes: Space 57, Caps Lock 58, I 23, J 36.
Deployment refuses existing test/core/config names, verifies remote asset
hashes before loading, and captures via Main's `screenshot` command. It never
replaces a standard installed core or reuses original media for writes.

## Limits

Screenshots verify a frame reaching Main's capture path, not physical HDMI/VGA
signal quality, measured pixel clock, audio fidelity or timing signoff. Writes,
eject/reset during I/O, real controllers and full sub-CPU compatibility remain
open. FDC INTRQ/DRQ pins are not routed in this base machine; local MAME also
does not wire these callbacks in its base-X1 configuration (Turbo adds DMA DRQ).
Do not add a Z80 FDC interrupt connection just to retain diagnostic logic.
Controller force-interrupt unit tests remain valuable, but an RBF boot cannot
prove an optimized-away INTRQ output. See `QUARTUS_BUILD.md` for source-bound
build identities and incomplete constraints.
