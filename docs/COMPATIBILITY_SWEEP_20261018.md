# MiSTer 192 disk compatibility sweep (October 18, 2026)

Media: every `.d88`/`.2d` in the user's `~/Downloads/Sharp X1/` (MiSTer
software-list copies). They were copied read-only to 192 as
`/media/fat/games/SharpX1/HWTest/X1COMPAT_20261018/Tnn.*`; the name/SHA-256
map is in `output_files/COMPAT_20261018/manifest.tsv`. Core:
`sharpx1_turbo_z_font_single` (single 42.95 MHz X3 master). Boot assets:
native Turbo IPL `21289570…`, ANK16 `e356dd19…`, synthetic physical Kanji
font `d18c7cb9…`. Procedure per title: MGL load, about 40 s wait, raw mrext
capture, Space, a second capture. This is a boot and first-screen check, not
gameplay acceptance.

## First pass (RBF `be628ed5…`, commit `a94991b`)

| ID | Title | Media | Result |
| --- | --- | --- | --- |
| T01 | dB-BASIC | raw .2d | Menu ✓ |
| T02 | HuBASIC CZ-8CB01 | d88 | BASIC `Ok` ✓ |
| T03 | Alien Egg | d88 | Boots; double-width text garbled ✗ |
| T04 | Conan | d88 (392,368) | IPL falls back to CMT ✗ |
| T05 | Dr. Slump | raw .2d | Title and gameplay ✓ |
| T06 | Jail Break | d88 (403,648) | CMT fallback ✗ |
| T07 | JEL | raw .2d | Menu ✓ |
| T08 | Mabel's Mansion | d88 (392,368) | CMT fallback ✗ |
| T09 | Mole Mole 2 | d88 (359,728) | CMT fallback ✗ |
| T10 | Morita Kazuo no Othello | d88 | Loads, then returns to IPL ✗ |
| T11 | Oushou | d88 | Title and menu ✓ |
| T12 | Senryaku Rengou Kantai | d88 | Title ✓ |
| T13 | Storm (A+B) | d88 ×2 | CMT fallback ✗ |
| T14 | TNT Bomb Bomb | d88 | Title ✓ |
| T15 | Zion | d88 (356,464) | CMT fallback ✗ |

## Diagnosis and fixes (commit `8dfe7b1`)

- **CMT fallbacks (6 titles):** all six images mark their 84 unused
  track-table slots with the volume end instead of zero. The strict D88
  scanner rejected that, so the drive stayed not-ready. In strict modes an
  offset equal to the volume size now means "absent track", which matches CSP
  and xmil. Offsets beyond the end, into the header, or out of order are still
  rejected.
  - Simulation (fast X3 single runner, native Turbo IPL): Conan and Mabel's
    Mansion (18 sectors per track) now reach their title screens.
- **Alien Egg:** it uses double-width ANK (attribute bit 7). The
  external-font (Z Kanji) renderer reloaded a glyph on every cell, so the odd
  cell showed the left half again ("P" appeared as "FF", "D" as "CC").
  - Only Kanji cells now reload per cell.
  - New exact-pixel double-width cases (80 and 40 columns) failed before the
    fix and pass after it.
  - The ordinary (non-Z) renderer is unaffected.
- **Othello:** reproduces in simulation. It loads, then returns to "IPL is
  set for device" with the CPU back in the IPL ROM and RAM filled with C3.
  Not yet diagnosed; this needs a bus trace.

## Second pass (RBF `70d66e14…`, commit `8dfe7b1`)

Build `quartus-linux-hfEdpY6G`: zero failing paths in all 32 eight-corner
reports. The eight titles that did not pass were rerun on 192:

| ID | Title | Result |
| --- | --- | --- |
| T03 | Alien Egg | `SPEED [0-9] ?` in correct double-width characters ✓ |
| T04 | Conan | Title ✓ |
| T06 | Jail Break | Title ✓ (Kanji text is noise with the synthetic font) |
| T08 | Mabel's Mansion | Title, then in-game after Space ✓ |
| T09 | Mole Mole 2 | Title, then game screen ✓ |
| T10 | Othello | Still returns to IPL ✗ |
| T13 | Storm (A+B) | Boots; its Kanji text is noise with the synthetic font |
| T15 | Zion | Title ✓ |

Overall, 14 of 15 boot sets reach a title, menu or prompt. Kanji-heavy
screens needed a native Kanji ROM; the synthetic test font shows noise there.
With the model-40 level-1 image (`scripts/prepare_z_kanji.py`), Jail Break
and Storm now render readable Japanese on 192; see
`docs/TURBO_Z_KANJI_STORAGE_STATUS.md`.
Evidence (PNGs, contact sheets, SHA-256 list): `output_files/COMPAT_20261018/`.

## Othello (image problem, not a core bug)

On the X3 single runner it cycles every ~4.78 s: the IPL loads the boot
program (`1E00`), then 0.34 s later the program re-enables the IPL ROM
(`1D00`) and the IPL boots again. The disk image is standard 2D D88 with no
status or deleted flags. On the **base-X1** headless runner with the MAME-set
base IPL (`ipl.x1`, `0513077c…`, from `~/Downloads/x1.zip`), it also stays at
"IPL is loading" after 40 s (2,274 disk requests). So the turbo IPL is not the
cause.

Reference check with MAME 0.283 (`~/Downloads/mame0283-arm64`, run headless
through `scripts/mame_x1_headless.sh`; the 80C48 sub-CPU is undumped in MAME):

| Driver | ROMs | Othello | Control |
| --- | --- | --- | --- |
| `x1` | `x1.zip` (MAME set) | Never gets past "IPL is under preparing" (blank screen alternates) | HuBASIC `Ok`, Alien Egg `SPEED [0-9] ?` ✓ |
| `x1turbo` | `ipl.x1t` (SHA-1 `44620f57…`, matches MAME); base ANK; 8x8 and Kanji placeholders | Same loop as our core: "IPL is set for device" ↔ "IPL is loading モリタ ノ オセロ", period ~7.5 s | HuBASIC `Ok` ✓ |

Because MAME fails the same way while the control disks boot, the
`Morita Kazuro no Othello` image (SHA-1 `b7d5df1f…`) is most likely a bad or
protection-stripped dump. It is not in MAME's `x1_flop` software list
(`moritash` is the separate Shogi title), so no verified dump is available to
compare. The ~4.8 s versus ~7.5 s period reflects different FDC/drive timing
models; both run the same load-and-restart path. No core change is planned
unless a verified dump boots elsewhere. Snapshots:
`output_files/COMPAT_20261018/mame/`.
