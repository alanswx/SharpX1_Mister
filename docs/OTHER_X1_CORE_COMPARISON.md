# Comparison with the closed-source SharpX1_20260601 core

October 18, 2026 (UTC). The user supplied `SharpX1_20260601_01.rbf`
(SHA-256 `4148d362fd0b32a71853c47bf9dfbe178ae3d3bfdbbc5d1bf48c38f79055b27f`,
from `SharpX1_20260601_01 (1).zip`). No source is available. It was loaded on
user-authorized **MiSTer 192** as `/media/fat/_Computer/OtherX1_20260601_01.rbf`.
Media copies are read-only in `/media/fat/games/SharpX1/compare-20261018/`.
No config file was written; one native screenshot remains in
`/media/fat/screenshots/SharpX1/`. Evidence PNGs and hashes:
`output_files/OTHER_X1_CORE_20261018/` (ignored).

This is a black-box feature survey through the OSD and a few boots. It is not a
compatibility measurement and does not inspect that core's implementation.

## Observed OSD (core version string `SharpX1 v260601`)

| Item | Values observed |
| --- | --- |
| Model | X1, X1 Turbo (runtime selectable) |
| Turbo boot | 5/3-inch 2D, 2DD, 2HD, 2DD IBM; 8-inch 2D256, 2D256 IBM, 1S128 IBM; SASI HDD |
| Debug bus | Off, On |
| Aspect ratio | Original, Full Screen |
| Video standard | NTSC, PAL |
| Demo tint | White, Red, Green, Blue |
| FDC submenu | Mount Drive A/B D88 `*.D88`; Mount A/B 2D `*.2D`; Mount A/B DSK `*.DSK`; Eject A/B |
| Tape submenu | Load Tape `*.TAP`; Eject Tape |
| Reset | Reset; Reset and close OSD |
| System page | Standard framework page, including "Define SharpX1 buttons" (joystick mapping) |

The core boots straight to the X1 IPL device prompt with no ROM loaded from
the SD card, so its IPL/fonts are embedded in the bitstream. "Reset and close
OSD" reset the machine but left the OSD open in two attempts.

## Executed checks on MiSTer 192

| Case | Result |
| --- | --- |
| Galaga D88 (`d0cdeb82…`), drive A, IPL `F`/`0` | Title screen reached |
| Galaga raw 2D (`75dc785e…`, 327,680 bytes), drive A, OSD reset | Title screen reached |
| Hydlide TAP (`6b15e091…`, `TAPE` header, 8 kHz), IPL `C`, two attempts | `Program load error` |

The tape failure is inconclusive: this image may need BASIC rather than IPL
CMT boot, and only one image was tried. No gameplay, audio, joystick, Turbo,
2HD, DSK, write or reset-retention checks were run on that core.

## Our current OSD (`sharpx1.sv`)

Aspect ratio, `F0` IPL load, Turbo ANK load (Turbo revisions), physical Kanji
font load (font revision), `S0`/`S1` D88 drives A/B, disk write protection,
Reset and Reset-and-close. Model/clock profiles are separate RBF revisions.

## Gaps relative to that core (proposed work, not defects)

1. **Raw 2D (and possibly DSK) disk images.** Raw 2D is now implemented by
   extension on the shared mount ([status](RAW_2D_DISK_STATUS.md)); DSK is
   still open. Original note: our machine selects the vendor
   controller's strict `D88_ONLY` mode. Per the user's direction, use one mount
   entry per drive (for example `S0,D882D ,Drive A;`) and select the format
   from the extension index. Stock Main sends
   `user_io_ext_idx(...) << 6 | (menusub+1)` through `FIO_FILE_INDEX` before
   each generic `S` mount, so `ioctl_index[7:6]` is 0 for D88 and 1 for 2D.
   Two-letter extensions match space-padded. Do not copy the separate
   per-format entries.
2. **Cassette/TAP loading.** We have no tape OSD entry or CMT image path.
3. **Turbo boot-switch selection** (2D/2DD/2HD/8-inch/SASI) and runtime
   X1/X1 Turbo model selection. Ours uses build revisions; a boot-switch
   option needs Turbo DIP/IPL behavior and media support (2HD remains open).
4. **Built-in IPL convenience.** We require an SD-loaded IPL. Embedding
   private ROMs is not acceptable for redistribution; a generated or
   explicitly licensed boot ROM would be needed instead.
5. **Joystick mapping.** Their system page offers button definitions; our
   CONF_STR has no `J` entry.
6. **Video standard NTSC/PAL and demo tint.** Low priority; the original X1 is
   NTSC-timed and "demo tint" has no known native counterpart.
7. **SASI HDD.** Optional scope (see `SHARP_X1_TODO.md`).
