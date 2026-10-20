# Runtime X1 / X1 Turbo / X1 Turbo Z model

October 20, 2026. The release core (`sharpx1_turbo_z_font_single`) is one
TURBO build with an OSD **Model** option (`O[7:6]`: X1 Turbo / X1 /
X1 Turbo Z; it was `O[3]`, X1 Turbo / X1, before the Turbo Z merge). The
machine samples `model_x1` and `model_z` during reset; changing the option
resets the machine. See [Turbo Z mode](#turbo-z-mode) below.

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

## Turbo Z mode

October 20, 2026. The release core now also builds the Turbo Z video set
(`X1_TURBO_Z_VIDEO_EXPERIMENT`: palette, multi-mode, internal eight-colour,
text palette and priority), formerly only in the retired
`sharpx1_turbo_z_video_single`. `TURBO_Z_RUNTIME` samples `model_z` in reset:

- **X1 Turbo Z**: the Z registers (1FB0 mode, 1FC5 control, 1FC0 priority,
  1FB9–1FBF text palette, 10xx–12xx palette data) decode, so software can
  enable 4096/64-colour and two-screen video.
- **X1 Turbo** (default) and **X1**: they do not decode; the Z mode register
  stays 0 and video is the ordinary digital path.

The previous build-time exclusions are lifted:

- **DMA.** The Z registers decode CPU cycles only (`z_io_read/write` exclude
  `dma_owner`), and their retained read replies are masked during DMA
  ownership, as for FM and SIO. A DMA transfer to or from those ports
  neither changes a Z register nor reads one. This is a provisional policy:
  native Z DMA-to-palette behaviour is not documented.
- **External Kanji font.** Nothing in the two paths conflicted (both use the
  CRTC character-start strobe as an input); the guard was an unqualified
  combination and is removed.

The Z behaviour itself is still the documented provisional implementation
(see `TURBO_Z_VIDEO_STATUS.md` and related); capture, mosaic, chroma and
scroll effects are not built, and no native Z software has been run.

### Simulation

`turbo-x3-release(-fast)` is the release-parity runner: X3 single master,
FM + FM CTC, DMA with completion/restart IRQ, the Z set, runtime X1 and Z
models (`--model-x1`, `--model-z`).

- `test-machine-z-release`: the 45 existing Z CPU/pixel cases (full,
  wide64, tall64, dual64 both screens, internal8, each identity/custom and
  cold/warm; paired64 with text at six priorities cold/warm; single-screen
  text at four priorities; reverse attributes) pass exactly with `--model-z`.
  The same full-colour program without `--model-z` differs in all 64,000
  pixels (digital video).
- `test-z-dma-isolation` (new): a real Z80 writes 1FC0 and reads it back;
  the real DMA then writes 16 bytes to 1FC0–1FCF and reads 1FC0 to memory.
  1FC0 keeps the CPU value and the DMA reads FF; without `--model-z` the CPU
  does not reach 1FC0. Removing the DMA exclusion from the write decode, or
  from the read decode and the retained reply, fails the test.
- The DMA IRQ fixtures (`test-x3-fm-dma-irq` set) pass in both X1 Turbo and
  Turbo Z mode; `test_model_select.py` passes on the new runner;
  `make test` and the CPU-only Z palette/text/priority profiles pass.

### Build

Seeds 10 and 3 (`quartus-linux-ckCYfUI1`, `-GSsaPB4m`): 0 failing paths in
all 32 inventory reports for both. Seed 10: 21,905 ALMs (52%), 443/553
M10K (was 21,397 / 437); RBF
`b8cf96ef9cef4e2c4760438b69c21850adcbbae42213a80dc161fbdfcb83c9c2`.
Seed 3: 21,787 ALMs, RBF `c10aa683…`. Only the 8-entry internal palette is
left as registers (Info 276004, inappropriate RAM size).

### Hardware (MiSTer 192, `_Computer/X1Z_20261020`, `x3z.rbf` = seed 10)

The simulator's Z pixel programs, wrapped in an IPL that copies them to 8000
(`Zfull_custom.mgl`, `Zpaired_text.mgl`; the MGLs also load the ANK16 and
Kanji fonts, without which the release core's screen stays black), were
captured through the KVM and compared with the simulator's expected frames
(320x200 sampled from the 1448x1080 capture; mean worst-channel error):

| Program | Model | vs expected | vs control |
|---|---|---|---|
| Full colour, custom palette | X1 Turbo | — | digital image; 31.1 vs the simulator's digital frame (capture noise floor) |
| Full colour, custom palette | X1 Turbo Z | 30.0 | 142.6 vs identity palette |
| Paired 64-colour + text, priority 1A | X1 Turbo Z | 26.2 | 113.0 vs priority 10 |

A first attempt reused RAM from the X1 Turbo run, so the program took its
warm-reset path (no palette programming) and matched the identity palette
instead (31.7); the IPL now clears the marker on every reset.

Title sweep on the same RBF (same MGL media as the October 20 merge sweep;
screenshot 40 s after load, or after the OSD model change at 15 s; tape at
150 s):

| Model | Result |
|---|---|
| X1 Turbo | All 12 disk titles and the K01 tape as in the previous merge build; DM05 (black at 40 s) and FM03 (Kanji prompt) match that build's screenshots exactly |
| X1 Turbo Z | All 12 disk titles and the tape boot (Ys II, Xanadu II, Sorcerian, Tetris, Gall Force menu, Mappy, Valis, Galaga, Zero Fighter...), with ordinary digital colours. These titles do not use the Z registers; this checks that DMA disk loading and Kanji/FM coexist with Z decode on |
| X1 | OSD shows `Model: X1`; Galaga boots through the X1 IPL, the K01 tape runs, DM01 does not boot (Turbo title), as before |
