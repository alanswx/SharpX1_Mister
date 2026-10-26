# X Millennium macOS reference runner

October 26, 2026: X Millennium (libretro port) now builds and runs headless
on macOS through our own minimal libretro frontend, `tools/xmil-cli`. It is a
**secondary** reference next to the [Common Source build](CSP_MAC_REFERENCE_STATUS.md),
mainly for X1 turbo / Turbo Z behaviour. No X Millennium code, ROM, font or
disk is copied into this repository or into FPGA RTL.

**X Millennium's font and text rendering must not be used as evidence of
hardware behaviour** unless the run uses the hardware-faithful option set
below and real ROM fonts (the runner enforces the latter). Its renderer is an
emulator's interpretation, not a measurement; several of its options and
fallbacks exist only for host display convenience (listed below).

## Build

Reference checkout (ignored, read-only): `references/emulators/xmil-libretro`,
revision `b07506c0cae31d260db28cb079148857d6ca2e93`. It is never built in place;
`git status` there stays clean (checked after every build in `build.sh`).

```sh
tools/xmil-cli/build.sh            # default output_files/xmil-cli/build-b07506c0cae3
```

The script exports the pinned revision with `git archive` into
`BUILD_DIR/src`, builds `libretro/` with the upstream Makefile, and compiles
the frontend. `output_files/` is already ignored. No source patch is applied.
Core compiler line (recorded in `BUILD_DIR/build.json`):

```
cc -Wno-implicit-function-declaration -Wno-int-conversion
   -Wno-incompatible-pointer-types -Wno-implicit-int
   -DXMIL_CLI_TURBOZ -DXMIL_CLI_BANKMEM -include tools/xmil-cli/xmil_overlay.h
```

- The four `-Wno-*` flags downgrade errors that modern Apple clang raises for
  the K&R-era sources; the 8 remaining upstream warnings (format strings with
  `\0`, an unused comparison, dangling else, missing return in `xmil_loop`)
  were reviewed and left alone.
- `xmil_overlay.h` (our file) defines `SUPPORT_TURBOZ` and `SUPPORT_BANKMEM`,
  which the libretro `compiler.h` lacks (it defines only `SUPPORT_OPM`).
  `pccore.c:123-130` then calls `scrnmng_setcolormode()`, which the libretro
  port does not implement; the overlay maps it to `SUCCESS` because that
  port always renders to its fixed 16-bpp RGB565 surface (`scrnmng_getbpp()`
  is constant 16 and the 4096-colour palette entries already exist in
  `vram/palettes.c`). Without this the link fails, or a stub returning
  failure would silently drop the model back to `ROM_TYPE 2`.
- `XMIL_TURBOZ=0` / `XMIL_BANKMEM=0` build without either flag.

Build outputs on this machine (Apple clang, macOS 27): core
`x1_libretro.dylib` SHA-256 `e522d05648a2ff588ee01ea2e6292a9ddb2d0d5daf5bb9a9403f460a23ca5617`,
frontend `xmil-cli` `8b09d645bcc1f599eb01439d1958fd4c81ae8387dbb25002b5d385b32e7148cb`.
`SUPPORT_TURBOZ` works at runtime: `effective_rom_type` reads back 3 and
Kohakuiro shows its 4096-colour title (below). `SUPPORT_BANKMEM` compiles; no
run here exercised bank memory, so it is not qualified.

## Frontend

```
xmil-cli --core x1_libretro.dylib --work NEW_DIR --ms N
  [--model x1|turbo|turboz] [--monitor standard|high] [--boot 2d|2hd] [--opm on|off]
  --ipl-x1 F --ipl-turbo F --font8 F --font16 F --kanji F
  [--fdd0 DISK] [--fdd1 DISK] [--keys SCRIPT] [--ini KEY=VALUE]...
  [--frame MS OUT.png]... [--final OUT.png] [--wav OUT.wav] [--allow-virtual-fonts]
```

- `dlopen`s the core and implements only the libretro calls it needs
  (environment: system/save/content directories, RGB565, variables left
  unset). The core reads `xmil.cfg` and fonts from the *current directory*
  (`libretro/dosio.c:14`, `font/font.c:120`) and IPLs from
  `<system>/xmil/IPLROM.X1[T]` (`io/memio.c:104-110`), so the frontend creates
  a new work directory, copies the ROMs there, writes `xmil.cfg`, and
  `chdir`s into it.
- Disks are copied into `work/media/fdd0.<ext>` before mounting: the core
  mounts images read-write, and its content-path parser splits on spaces
  (`libretro.c` `parse_cmdline`). Drive 1 is mounted after core start-up with
  the exported `diskdrv_setfddex`. In all runs below the private copies were
  still byte-identical afterwards.
- Model/monitor are xmil.cfg keys: `IPL_TYPE` 1/2/3 = X1 / X1 turbo / Turbo Z;
  `Resolute` is the DIP byte, where bit 0 **set = standard 15 kHz** and clear
  = high resolution 24 kHz (`libretro/sysmenu.c:84-92`), bit 2 = 2HD boot.
- Time is the core's own frame length: after each `retro_run` the frontend
  adds `corestat.framebaseclock / 4 MHz` (`pccore.c` `pccore_exec`). Observed
  16.13 ms frames at 15 kHz and 18.37 ms at 24 kHz. X Millennium's CRTC timing
  is itself approximate (see `references/README.md`), so emulated ms are only
  comparable with our core to within that approximation.
- Keys: script lines `MS down|up KEY`, `MS tap KEY [HOLD_MS]` (default 80 ms),
  `MS type TEXT [GAP_MS]`; `#` comments. Names are X Millennium's PC-98-style
  serial keys (`return`, `space`, `a`..`z`, `0`..`9`, `f1`..`f10`, `shift`,
  `ctrl`, `grph`, `kana`, `at`, `colon`, ..., or `raw:HEX`), sent through the
  exported `keystat_senddata` at the first frame boundary at or after `MS`.
  The libretro keyboard path is not used because its table omits several X1
  keys (`@ [ ] ; :`).
- PNG: 640x400 RGB, converted from the core's RGB565 output. 200-line modes
  are presented as 400 lines with every second line black (see `skipline`).
- WAV: 44.1 kHz stereo from the core's audio callback. **The WAV timeline is
  not emulated time**: the libretro port emits a fixed 735 frames per
  `retro_run` (`libretro.c` `SNDSZ`) whatever the frame length, so an 85 s
  high-resolution run gives a 77.1 s WAV. Use it for presence/content only.
- Tape: not supported. `--tape` is refused, because `io/cmt.c` in this
  revision is a stub (`cmt_read` returns 0).
- JSON on stdout: core path/SHA-256, model, effective `ROM_TYPE`, every
  xmil.cfg line written, effective `xmilcfg` bytes read back, ROM/disk
  hashes, font check, key events sent, frames, emulated ms, outputs. Core
  chatter goes to stderr.

### Fonts: real ROM files only

Without a file the core substitutes, silently: its embedded ANK
(`font/font.c:108-115`), `FNT0816.TMP`/`FNT1616.TMP` beside the expected name
(`font/fontx1.c:19-22`), or glyphs synthesised from host font data
(`font/font.c:121-123` calling `makex1font`, `font/fontmake.c`). The runner
therefore requires all three font files, and after core start-up compares the
core's live `font_ank` (2048 B), `font_txt` (4096 B) and level-1 `font_knjx1t`
(3666 glyphs, both halves) with the supplied files byte for byte, and checks
that no `FNT*.TMP` exists in the work directory. Any difference exits with
status 3. `--allow-virtual-fonts` skips the refusal for experiments but
records `"real_rom_fonts": false` in the JSON. Negative checks: with no
fonts the run is refused (status 2); with `--allow-virtual-fonts` the core
created `FNT0816.TMP` and `FNT1616.TMP`; with the raw 256-KiB `boot3.rom`
passed as `--kanji` (wrong size) the core synthesised `FNT1616.TMP` and the
runner exited 3.

### Options set, and options that depart from hardware

The runner writes every emulation/display key explicitly (also echoed in the
JSON `xmil_cfg`; `--ini` appends overrides and is recorded too):

| Key | Value | Why |
| --- | --- | --- |
| `IPL_TYPE` | 1/2/3 | model |
| `Resolute` | DIP byte | monitor / boot media |
| `OPMsound` | 1 | FM board present, as in our release core (`pccore.c:114-117` forces it for Turbo Z anyway) |
| `DispSync` | true | draw at end of display period (`pccore.c:204,228`) |
| `Real_Pal` | true | apply palette changes per raster (`vram/palettes.c:372`); the default `false` latches one palette per frame, which is not hardware behaviour |
| `skipline` | false | see below |
| `skplight` | 0 | unused when `skipline` is false |
| `Seek_Snd` | false | no synthetic drive-seek sound mixed into audio (`fdd/fdd_mtr.c:71,97`) |
| `s_NOWAIT`, `SkpFrame` | false, 0 | host pacing; unused by the libretro loop |

The libretro core variables `x1_analog`, `X1_GUI_controller`, `X1_GUIJOY_PAS`
(`libretro.c:323-332`) only affect input/menu and are left at defaults.

Departures from hardware found in this revision:

- `skipline`/`skplight` (`vram/palettes.c:394`, `:109-111`, `:148-150`,
  `:184-186`): for 200-line modes X Millennium draws each raster twice on a
  400-line surface and fills the second line with black (`false`) or a dimmed
  copy (`true`, brightness `skplight`/256). Neither is hardware pixel data.
  Compare 15 kHz frames on even output lines only.
- Font fallbacks above (`font/font.c:108-123`, `font/fontx1.c:19-22`).
- `Real_Pal=false` default (one palette per frame).
- `Seek_Snd`: synthetic seek noise.
- RGB565 output: 4-bit-per-gun Turbo Z colours fit exactly; no loss for
  8-colour modes.

No font smoothing or "modern screen" text options exist in this revision
(searched `vram/`, `font/`, `libretro/`); later hacked builds may differ and
are not covered.

## ROM names and assets

| Expected name | Where | Used here | Bytes | SHA-256 |
| --- | --- | --- | --- | --- |
| `system/xmil/IPLROM.X1` | X1 IPL | tester `boot2.rom` | 4096 | `e6295a523008688421991b651ab61de392b28c67bec9efbf040b0004e4b70a2a` |
| `system/xmil/IPLROM.X1T` | X1 turbo/Z IPL | `software/turbo-firmware/212895703175-ipl.x1t` (= first 32 KiB of tester `boot.rom`) | 32768 | `212895703175665be8544daa55b65da1aebcf1e9a2db65bcc1622e564b802b71` |
| `./FNT0808.X1` | 8x8 ANK | local Neo Kobe "X1turbo [ROM]" `FNT0808.x1` | 2048 | `2ce875255d64002589831e68825fbb36b7827be538dd030ffabb907b3c07610b` |
| `./FNT0816.X1` | 8x16 ANK | tester `ank16.X1` (= last 4 KiB of `boot.rom`) | 4096 | `e356dd1992708d2bdf03d4029ba07a8177158e1cb0eac145f881ed8dcdae35d8` |
| `./FNT1616.X1` | 16x16 Kanji, Shift-JIS order | converted from tester `boot3.rom` | 306176 | `dc6454fb1981a76cf8753bad0161ce598092c728f8c59a944bcf980e7db928f4` |

There is no CG/PCG or sub-CPU ROM file in this core. ROMs stay in ignored or
scratch directories and are never committed.

`FNT1616.X1` format: X Millennium reads a 306176-byte Shift-JIS ordered
file (32 bytes per glyph, left/right bytes interleaved per row) and maps it
to its X1 turbo half-major layout (`font/fontx1.c` `x1knjcpy`). Our
`boot3.rom` (SHA-256 `30540b94...6b`) is the Z-chip permutation of the
model-40 level-1 set with level 2 zero. `tools/xmil-cli/prepare_xmil_kanji.py`
(original code, no font data) inverts both permutations and writes level 1
(JIS rows 21-4F, 3666 glyphs); level 2 is zero, as in `boot3.rom`. Its
comparison against the local X Millennium-format `FNT1616.x1` files (Neo Kobe
"X1turbo [ROM]" `bb40a2bf...` and "X1turboZ" `40c080b7...`): 3390 glyphs equal,
276 differ, all in JIS rows 24 and 30-4F with neither side blank, so the
address mapping agrees and the differing glyphs are different drawings
(revision or source). Which one matches a real Turbo ROM is not established.
The X1 "Set 3" file and the Z `KANJI2.rom` match only 1-2 glyphs (different
layouts/contents).

## Acceptance runs

Command: `tools/xmil-cli/acceptance.sh ROM_DIR AOKI_D88 TESTER_DISKS NEW_OUT`
(ROM_DIR holds the five files above). Disks: Aoki Ookami to Shiroki Mejika
(Turbo).d88 `255076915c63682e...`, tester `Kohakuiro1.d88` `05360cb6...`,
`Kohakuiro2.d88` `8437e502...`, `Galaga.2d` `75dc785e...`. All five runs:
`real_rom_fonts` true. A first run with an earlier frontend build (differing
only in JSON reporting) produced byte-identical PNGs, so these runs repeat.

| Case | Model / monitor | Seen |
| --- | --- | --- |
| Aoki, 50 s | turbo / high (24 kHz) | Title with large Kanji logo and the 4-line Kanji quotation, all glyphs clean 16-line |
| Aoki, Return at 55 s, `1` at 62 s | turbo / high | Menu `どれにします？（1-3）1` with three Kanji options |
| Aoki, Return at 64 s, 80 s | turbo / high | Character Making table: names, six attributes all 0, ages 20/18/17/15/13, `5人の能力を自動的に設定しますか？` |
| Aoki, same keys | turbo / standard (15 kHz) | Same title (reached by 45 s), menu and Character Making table, same layout. Kanji rows occupy 8 rasters; each glyph appears to show alternate rows of the 16-row pattern (vertically decimated, legible but broken strokes). Not traced in the source; treat as X Millennium's interpretation |
| Kohakuiro (2 disks), 60/100/120 s | turboz / high | 4096-colour mansion picture (60 s), then the `琥珀色の遺言` / 1920 SERIES title logo (100-120 s) |
| Kohakuiro control, 60 s | turbo / high | The same picture garbled into colour stripes: the Turbo Z palette path is what makes the title correct |
| Galaga, 30/60 s | x1 / standard | Galaga title, `PUSH SPACE TO GAME START`, then attract-mode formation |

The FM WAVs (`aoki_*.wav`) contain non-zero audio; their timing is not
emulated time (above) and they were not compared with our core.

## Limitations

- Not compared pixel-for-pixel with the FPGA core or CSP; these runs only
  show the reference reaches the same screens.
- 15 kHz Kanji rendering, emulated-time scale, CRTC timing, audio timing and
  FDC timing are X Millennium's approximations, not hardware evidence.
- Tape, bank memory, 2HD boot and the X1 IPL's own behaviour beyond Galaga
  are unexercised. Kanji level 2 glyphs are blank (none in our source).
- The frontend relies on exported core symbols and the start of the
  `CORESTAT`, `PCCORE` and `XMILCFG` structures of this revision; another
  revision needs those checked again.
- Built and run only on macOS (CommonCrypto, `.dylib`).
