# Runtime X1 / X1 Turbo model

October 20, 2026. The release core (`sharpx1_turbo_z_font_single`) is one
TURBO build with an OSD **Model** option (`O[3]`: X1 Turbo / X1). The machine
samples `model_x1` during reset; changing the option resets the machine.

## What X1 mode changes

X1 mode leaves the Turbo hardware built and gates it off:

| Turbo feature | X1 mode |
|---|---|
| Z80 DMA (1F8x) | Not decoded; the DMA never owns the bus |
| Main CTC (1FA0–1FA3) | Not decoded (passes the daisy chain through) |
| DIP switches (1FF0) | Not decoded (reads FF) |
| SCRN (1FD0) / BLACK (1FE0) | Writes ignored; held at reset value 0 (low scan, X1 graphics paging, no high-speed PCG, no 16-row ANK) |
| Kanji plane at 3800–3FFF | Becomes the text-plane mirror again, as on the X1 |
| Kanji display | Off, even for Kanji codes left in VRAM by an earlier Turbo session |
| CG read tail | Off |
| IPL | 4 KiB; the index-3 X1 IPL when loaded, else the main IPL's first 4 KiB |

Kept in both modes: the YM2151 FM board and its CTC (the real board plugs into
a plain X1), the interrupt daisy chain the FM CTC needs, the keyboard
interrupt path, tape, and both disk drives.

The X1 IPL has its own 4-KiB slot (index 3): OSD `Load X1 IPL`, MGL
`<file type="f" index="3">`, or `boot2.rom` (Main's index 0x80). Switching
models never needs a ROM reload. Nothing is embedded; the repository's
`bios/ipl_x1.hex` was used for tests.

The OSD **Boot device** (`O[5:4]`) drives the Turbo DIP at 1FF0 at run time:
2D `F1`, 2DD `F3`, 2HD `F5`, SASI `FF` (MAME's encoding; bit 0 = interlace
off). Default 2D matches the previous fixed `F1`. 2HD and SASI media are not
implemented, so those settings only change what the IPL looks for.

## Simulation

`make -C verilator test-model-select` (X3 FM/DMA runner, `X1_MODEL_SELECT`):

- A real-Z80 program reads 1FF0 and writes 3000 then 3800, reading 3000 back.
  Turbo: DIP `F1`, text `11` (3800 went to the Kanji plane). X1: DIP `FF`,
  text `22` (3800 mirrored onto text). The X1 assertions fail without gating.
- With both IPLs loaded, X1 mode shows the X1 IPL's screen ("IPL is under
  preparing") identical to an X1 IPL in the main slot; Turbo mode shows the
  Turbo IPL ("IPL is set for device").
- CROSS Chase (D88) boots to the same frame (`29653d6f7e8c2a7f`) in both.

The full `make test`, `test-fast`, OSD config, wrapper lints and the FM, DMA,
cassette, RTC/keyboard and CTC regressions pass.

## Hardware

Build seed 10 (`quartus-linux-97p2xIJ1`), RBF
`281c6730dc1084af2d387daa6122c347ca9f3b1e55dae6c8a160c012bb964265`:
21,397 ALMs (51%), 437/553 M10K, 0 failing paths in all 32 timing reports.
Seeds 2 and 6 fit with 1 and 9 small framework-side failures (HDMI output,
DDR interface hold; worst −0.137 ns). MiSTer 192,
`_Computer/X1MERGE_20261020` (`x3merge.rbf`). `X1*.mgl` add the X1 IPL as
index 3; the model is switched through the OSD.

Turbo mode (default): see `DMA_BOARD_BUILD_STATUS.md` (October 20).

X1 mode, switched through the OSD after each MGL load (screenshots confirm
`Model: X1` and the machine resets):

| Title | X1 mode |
|---|---|
| Galaga (raw 2D) | X1 IPL ("IPL is under preparing"), load counter, title screen |
| Tetris, Mappy | Title screens |
| Zero Fighter (K01 tape) | Attract screen at 150 s |
| Zeliard, Xanadu II, Sorcerian, Gall Force, Ys II, Relics, Silver Ghost, Valis, Dione | Do not boot (blank, an earlier Turbo IPL message, or garbage). All boot normally in Turbo mode; most use Turbo hardware (DMA, Kanji, Turbo video). Whether each would run on a plain X1 is not established. The simulator agrees for Gall Force (`dm05`, garbage by 30 s) |

Switch the model only after the MGL has finished loading its files, or the
X1 IPL may not be in its slot yet. Without an X1 IPL, X1 mode runs the main
(Turbo) IPL's first 4 KiB, which shows nothing; X1 mode needs the X1 IPL.

Audio is not verified: the capture currently returns no audio for any build.
