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
