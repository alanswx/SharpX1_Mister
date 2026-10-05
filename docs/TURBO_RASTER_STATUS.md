# Turbo graphics raster addressing increment

October 5, 2026. Shared active machine: `rtl/sharpx1.v`; base `TURBO=0`
is unchanged. This implements **graphics addressing**, not a finished
400-line video mode. Video clocks, fonts, PCG selection and Kanji rendering
are not changed by this increment. No new RBF or hardware acceptance is implied.

## Implemented address contract

Text/attribute/KVRAM continue to use CRTC MA[10:0]. The renderer exposes its
full five-bit RA separately, and original `rtl/x1_gram_address.sv` selects the
GRAM address. CPU/DAM addressing still uses `{SCRN[4], port[13:0]}`.

| SCRN b1:b0 | GRAM page | 16 KiB plane offset |
|---|---|---|
| 00 | b3 | `{RA[2:0], MA[10:0]}` |
| 10 | b3 | `{RA[2:0], MA[10:0]}` |
| 11 | b3 | `{RA[3:1], MA[10:0]}`; adjacent graphics rasters repeat |
| 01 | RA0, independent of b3 | `{RA[3:1], MA[10:0]}`; even/odd rasters use pages 0/1 |

Mode 01 follows the locally inspected X Millennium
`vram/make24.c:width80x25_400h`: it reads `gram + GRAM_BANK0` on even
lines and `gram + GRAM_BANK1` on odd lines, **not** `makescrn.disp1/disp2`.
The latter are swapped by b3 but used by its repeated-raster `200h` path.
This resolves the reference-code b3 question; it does not constitute ASIC
truth-table or electrical verification. Mode 10 retains the low-scan mapping
of that reference. Raster bit 4 wraps graphics storage rather than spilling
into text MA or the CPU bank. Display mode controls retain the existing
two-stage crossing, with live multi-bit switching still unqualified.

No emulator code, firmware or commercial-game bytes were copied into this
new GPLv2-only mapper/test. Existing renderer notices remain unchanged.

## Reproduction and scope

```sh
make -C verilator test-gram-address
make -C verilator test-turbo-raster
```

The address unit exhausts 256 SCRN bytes, 32 RA values and all 2048 MA
addresses: 16,777,216 combinations, also checking base isolation. It covers
RA7/8/15/16/31, page independence, ignored control bits and MA boundaries.

The CPU fixture uses real Z80 I/O to fill both graphics pages/three planes
with distinguishable page/raster/pixel patterns, selects an opposite CPU
access page, programs 25 rows of 16 rasters and then halts with `VID!`.
It checks every captured RGB pixel, not just hashes. All four SCRN modes,
two page selections and both widths form sixteen cases. These are original
diagnostic RAM programs, not native IPL/game boot evidence or copied rows.
Mode 01's output must be independent of b3; mode 11 must repeat adjacent
rasters. Low modes deliberately retain the eight-row wrap at RA8.

Each run lasts 1.8 seconds (57,600,000 32 MHz reference cycles); deterministic
RAM loading contributes to reset length, reported per fixture. Baseline
sys/video are 32,000,000 / 28,571,428 Hz; single is 28,636,364 Hz for both.
The fixture has 1792 old video-master edges per line and 448 total lines:
expected baseline HS about 62.72 us and VS 28.09856 ms. These are **not**
authentic high-scan timings. The period tolerance is one system sampling
edge plus 1 ps. Programs, executable hashes, clocks, delay scheduling and
frame hashes are printed; `--output` retains private/generated PPMs and RAM
programs beneath ignored simulation directories.

## Executed verification

The exhaustive address unit and registered blackclip regression pass. All
sixteen CPU raster cases pass in the **fast baseline Turbo** model, executable
SHA-256 `395045db4dc17a268c81f2b59b33a859b465a3aa071023f27740290bdb2ddda7`.
Every case reaches HALT, captures 19 completed frames and validates every RGB
pixel at the current-clock periods described above. Deterministic reset is
1255 system edges; no BIOS or private media is used. Retained artifacts are
under `verilator/obj_dir_turbo_fast/raster-checks/mode*-page*/`.

| Address mode / display page | 320x400 frame hash | 640x400 frame hash |
|---|---|---|
| 00 and 10 / page 0 | `f2ff93cb02594b25` | `e993ad61e922b325` |
| 00 and 10 / page 1 | `c756d8315c398b25` | `165956cb03aab325` |
| 01 / either b3 selection | `76c7a49260a26b25` | `f5fb5f794bd6b325` |
| 11 / page 0 | `e0aa09561ecc6b25` | `ba67633bd1e6b325` |
| 11 / page 1 | `4d15cb8e262e6b25` | `3262d0526368b325` |

Three additional CPU fixtures pass in **delay-aware single-clock Turbo**:
mode 01/b3=1 at both widths, and mode 11/page 1 at 40 columns. Their PPMs are
byte-identical to the corresponding baseline outputs. Executable SHA-256
`20a99ca30c9f5d98c4bcb997cb639ecfebbc97759c92982907d3811a99f4068e`;
reset 1256 edges, HS 62,577,777 ps, VS 28,034,844,088 ps. This is focused
cross-profile coverage, **not** a completed delay-aware sixteen-case matrix;
the `test-turbo-raster` target provides that remaining full reference run.

Turbo CPU banking/DAM/KVRAM/warm-reset tests also pass in the delay-aware
single profile. MiSTer-wrapper lint succeeds with inherited warnings; the
new address unit has no width warnings and adds no suppressions. Compile/lint
does not establish synthesis timing or hardware behavior.

## Remaining gates

- Transcribe the schematic clock/mode divider and implement enabled high/low
  dot/character rates with coherent reset/live-mode switching. Arcus's CRTC
  program should produce approximately 40.2286 us HS and 18.0224 ms VS in
  high scan, not the old-clock periods above.
- Add distinct 16-raster ANK, PCG expansion/pairs, Kanji ROM addressing and
  CPU font selection, with documented ROM layouts and bounds.
- Requalify asynchronous RAM/control/PCG crossings, pending transaction reset,
  all clock ratios and native commercial software. Arcus/Bastard gameplay
  remains unverified; previous screenshots are from an earlier executable.
- Synthesize the final video-clock architecture, analyze constrained corners
  and CDC, then measure native physical output separately from the scaler.

The latest published RBF still binds to `ffc1c1c`, before this mapper. Do not
attribute these new tests or address behavior to that artifact.
