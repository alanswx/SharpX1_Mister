# October 8: current-RBF games and exact base-video matrix

Only released **mister126 / 10.0.2.126** was used, through misterubuntu.
mister192 was not contacted. mister14 remains unused. This extends the
[initial hardware matrix](HARDWARE_126_STATUS.md), not a full feature signoff.

The RBF is the existing source-bound single-clock partial Turbo build,
SHA-256 `a0a03761ef9db2bf2a9a14ec5c281175cb02a33d7eaa07978551fe1f393260d3`,
frozen source `5a40859092902b9fbbcfc551b2b3291bbd9ff695`, board master
28.571428 MHz. This turn did not rebuild it or enable optional devices.

## Current-RBF native game MGLs

On mister126 browse `_Computer/X1Matrix_20261008T233657Z/`:

| MGL | Visually inspected observation after input |
|---|---|
| `01_CROSS_Chase.mgl` | Live playfield |
| `02_Galaga.mgl` | GAME START; not yet qualified as live play |
| `03_Druaga.mgl` | Populated maze and player, advancing timer |
| `04_Mappy.mgl` | Populated stage with player/enemies |
| `05_Xevious.mgl` | Populated AREA 1 with aircraft/projectiles |
| `06_Shanghai.mgl` | 144-tile board and pointer; tile removal untested |

These replace neither earlier MGLs nor installed cores. Each has separate
disposable media and a zero-status config requesting write protection. All
six IPL/disk hashes are unchanged after their runs. Screenshots record a
30-second native boot, Space/Enter/1 input, then directional/Space input.
Screen progression does not prove physical-controller support, input-specific
movement, sound fidelity, or five fully playable commercial games.
An additional Galaga cold run with `1` alone returns to its title; following
the displayed Space instruction reaches level selection. Another Space leaves
only LEVEL-1 displayed after eight seconds, not a qualified live playfield.
These additional failed/incomplete trials are preserved as actual PNGs.

The first run's long setnames appear truncated in Main status; the names still
distinguish the six cases. The reusable script now uses short unique setnames
to avoid config/name ambiguity. No write-protection claim rests on FAT chmod.

Ignored actual PNGs and manifest:
`output_files/X1Matrix_20261008T233657Z/`.

## CPU-loaded diagnostic video MGLs

On mister126 browse `_Computer/X1Matrix_20261008T234256Z/`:

| MGL | Native dimensions | Exact matching pixels |
|---|---|---:|
| `graphics-40.mgl` | 320 × 200 | 64,000 |
| `text-40.mgl` | 320 × 200 | 64,000 |
| `pcg-40.mgl` | 320 × 200 | 64,000 |
| `graphics-80.mgl` | 640 × 200 | 128,000 |
| `text-80.mgl` | 640 × 200 | 128,000 |
| `pcg-80.mgl` | 640 × 200 | 128,000 |

**576,000 pixels, zero mismatches.** Actual MiSTer RGB8 PNGs are compared
against simulation P6 images without resizing, cropping or color tolerance.
A wrong-reference control (80-column graphics versus text) fails as expected.
Comparison checks PNG CRC, dimensions, filter reconstruction and all RGB bytes.

These original diagnostic IPLs use a real CPU LDIR to copy the existing
`8000`-origin video fixtures from IPL into RAM, then jump there. No debug RAM
injection, private font, patched state or game bytes are used. The CPU initializes
CRTC, PPI, VRAM/attributes, graphics planes/palettes or beam-addressed PCG and
finishes with `VID!`. Simulation qualifies the new IPL-entry path against
RAM-entry execution in all six cases. Frozen board-frequency fast runner:
`a1856502ff297238a9b0d79cfcc8ea2f294095bda08e03c1ae7c259d613522e8`.
Existing pixel-formula tests independently qualify the fixture patterns.

An additional Ctrl+Left Alt+Right Alt warm reset of the 80-column PCG case,
without load_core or another IPL upload, returns to the exact same PNG:
`072f7dc56c7370318d4972855152f466c2aebefa1141a942c3f436f259222202`.
Its additional 128,000 pixels also match. This is one bounded diagnostic reset,
not reset-during-disk-write or all Main/OSD conditions.

Ignored evidence:
`output_files/X1Matrix_20261008T234256Z/` (manifest, PNGs, pixel comparison),
`output_files/hardware-video-ipl/` (original IPLs and reference images).

## Reproduction

Coordinate availability before using `--execute`; never use mister192.

```sh
python3 scripts/mister_matrix.py --host mister126 --execute
cd verilator
python3 tests/test_video_modes.py obj_dir_v12_board_single_fast/Vtop \
  --emit-ipl ../output_files/hardware-video-ipl
python3 tests/test_video_ipl.py obj_dir_v12_board_single_fast/Vtop \
  ../output_files/hardware-video-ipl
cd ..
python3 scripts/mister_matrix.py --host mister126 --execute \
  --video-ipl output_files/hardware-video-ipl
python3 scripts/compare_video_png.py ACTUAL.png REFERENCE.ppm
```

The matrix script reuses already-staged isolated assets and the exact pinned
RBF. It does not install services or overwrite media/config/core files. The
current seeded asset paths are on mister126; mister14 requires separate staging.

## Feature acceptance still required

| Feature | Hardware status |
|---|---|
| CPU/RAM, VRAM, GRAM/palette, ANK, CRTC, PCG at 40/80 columns | Bounded original static diagnostics above pass; full native timing/attributes not implied |
| Native A disks and keyboard | Six current-RBF screen observations; protected media unchanged |
| Native B boot and OSD reset | Prior bounded acceptance; see linked initial matrix/native B status |
| Writable/format/density/two-disk sets; reset during loading/writes | Not qualified by these protected single-disk tests |
| Joystick/physical keyboard, PSG audio, VGA/HDMI/measured clocks | Physical input/listening/external measurement still required |
| X3/400-line, DMA/IRQ/Ready/restart, Kanji renderer, SIO | Not enabled in this RBF; require separately implemented/source-bound hardware profiles |
| FM, full Turbo Z palette/modes/HD/level-2 Kanji | Incomplete; cannot claim hardware feature acceptance |
| Cassette, remaining PPI/sub-CPU/native BASIC | Further implementation/diagnostic/native acceptance remains |

No work group is declared complete.
