# Turbo digital text expansion and reserved underline rasters

October 5, 2026. Bounded increment after PPI checkpoint `ac170be`.
Not native BASIC, a Kanji implementation or hardware/ASIC acceptance.

## Evidence and provisional hardware policy

Visually read the existing Sharp CZ-856C BASIC reference scan: PDF 200–202
(printed 2-163–165), PDF 214 (2-177); user manual PDF 91 (printed 80).
[Inventory and hashes](../references/manuals/README.md).
The archive's web page returned 403 and PDF viewer failed; the already
downloaded local primary scans were rendered successfully. No new copy.

`WIDTH` permits 40/80 columns and 10/12/20/25 rows; high scan excludes
10 rows. `KSEN` controls enabled cells and underline color in 10/20-row
text-only modes; elsewhere its color operation is equivalent to palette
entry 1. The exact gap position and ASIC bit timing are not specified there.

The existing local X Millennium `io/crtc.h`/`.c`, `vram/makescrn.c`,
`make15.c`, `make24.c`, `makechr.c`, `maketxth.c`, `makemix.c` were inspected
read-only, not compiled/run/copied. They identify SCRN b2 global vertical
expansion, b7 underline mode and KVRAM b5 cell selection; their mixer routes
the line through digital palette entry 1. It models two logical gap rows
(one underline, one blank), with high-scan output doubling the gap.
MAME's Kanji-only underline and alternative SCRN b2 interpretation do not
settle ASIC behavior. This increment follows the explicit provisional
X Millennium policy, not an invented hardware confirmation.

## Implementation scope

`x1_text_raster.sv` is original combinational logic. Only the experimental
Turbo profile connects SCRN b2/b7; base behavior is unchanged. Global vertical
expansion divides the CRTC raster before font lookup and inherited double-height
phase selection. Underline mode suppresses all GRAM pixels, not merely those
behind the line. Eight/16-row ANK is followed by one/two underline rasters and
one/two blank rasters; expansion repeats each source raster. KVRAM b5 selects
the line, palette 1 colors it, palette 0 colors the background. Color/reverse/
blink glyph mixing remains outside the reserved gap; blackclip remains after
the normal priority/palette stage. Pipeline state is reset deterministically.

This does not implement Kanji selection, prove attribute double-height parity
with global expansion, impose a BASIC row-count limit on arbitrary CRTC values,
change graphics storage/readback, or validate mid-scan mode changes. Compatible
non-underline font wrapping is retained. State format advances to **v09**;
older states must be rejected, never patched or converted.

## Verification gates

Original 512-combination `text_raster_tb` covers both scan rates, global
expansion, underline mode, cell enable and every five-bit raster. The focused
unit passes all 512 cases (`/tmp/x1-v09-text-unit-final.log`), with the new
fixture's width warnings corrected rather than suppressed. The prior
blackclip/glyph-address mixer regression also passes unchanged assertions
(`/tmp/x1-v09-text-unit-and-mixer.log`). Machine pixel checks are still running;
these units do not establish that integration gate.
`test_turbo_text_raster.py` executes an original Z80 ROM, uses real DAM writes
to initialize all three GRAM planes to FF, real text/attribute/KVRAM writes,
contrasting graphics/background/underline palette entries and reverse cells.
It checks every actual RGB pixel and HS/VS periods over one full simulated
second. The ANK16 font is an original generated pattern, not private bytes.

Confirmed machine results **before the later CRTC boundary fix**:

| Case | Result |
|---|---|
| Fast X3, standard scan 80×20 | All 640×200 actual pixels and periods pass: font/color/reverse, alternating K5 line cells, distinct palette-1 line / palette-0 gap/background, visible FF graphics suppressed. One second, 32,000,000 reference cycles, 48 frames, hash `85fd6826dd89eaa5`, HS=62.593750 us, VS=14.392906250 ms. `/tmp/x1-v09-text-low20.log`. |
| Prior fast base 80×25 | All 640×200 pixels/periods pass, unchanged hash `38336804c6381245`, original 200 ms. `/tmp/x1-v09-base-pixels.log`. |
| Prior delay-aware X3 ANK16, 40-column/raster 3 | All 320×400 pixels/periods pass with retained font and 120 ms/10 us warm reset, unchanged hash `8ec9d6393e3dde65`, original 200 ms. `/tmp/x1-v09-prior-ank16-warm.log`. |

Rebuilt delay-aware base timing/reset/CE/delayed-event/FST determinism passes;
fast base v09 snapshots pass continuity, rejected v08 header, clock mismatch
and SDL joystick checks (`/tmp/x1-v09-timing.log`, `/tmp/x1-v09-snapshot.log`).
Base and X3 wrapper lint pass with inherited warnings, not FPGA validation.

| Runner | SHA-256 |
|---|---|
| Delay-aware X3 | `51b59ec6275e9324d15e8c5765d55dd24b7f121b4f203b4c865d481cc0bce7b7` |
| Fast X3 | `c8a686b520d997f9ea65e3d97b0b6ada7ddaa51571ded1d1aa2333e6e7bcff84` |
| Fast base SDL/savable | `a96e1eb454d84648360dabb9036c9dd883230a094ba8c5ec97346339b5f0fbad` |
| Delay-aware base | `1521dbbf7be61778db37861c710c452467e8aabbac918630407f429c8a52c7a0` |

`make -C verilator test-text-raster` runs the policy and prior mixer units.
`test-text-raster-cpu` registers standard 80×20, expanded high-scan 80×12
and delay-aware high-scan 40×20 cases with unique ignored outputs; override
`TEXT_RASTER_TIMEOUT` on a busy host, not simulated duration/assertions.
`test-text-raster-matrix` adds all fourteen documented scan/row/width cases
(excluding unsupported high-scan 10 rows) and two standard-scan mode exits.
The full matrix now passes **16/16** cases
(`/tmp/x1-v09-text-full-matrix.log`): all fourteen documented scan/row/width
cases and both mode exits. Each case froze runner `7121b501...3692` and
retained a full second/every-pixel oracle; only the wall timeout was raised
to 7200 seconds on the contended host. This qualifies the v09 checkpoint's
digital policy, not later reset/DMA changes, native BASIC or ASIC timing.
The initial expanded high-scan 80×12 run failed the retained **384-line**
assertion: actual height 416, consistent with a repeated 32-raster first row.
An original output-only CRTC unit reproduces the defect at R9=31/R5=0:
expected 640 character enables per frame, actual 768, a full extra row.
Logs `/tmp/x1-v09-text-high12.log`, `/tmp/x1-v09-crtc-boundary-before.log`
retain the failures; no assertions/dimensions were relaxed. `W_ADJ_C` now
requires nonzero vertical adjustment before treating the raster count as an
adjustment completion. At zero adjustment, wrapping five-bit RA must not
create another frame return. The correction passes all **36** original
output-only cases: R9=7/15/31, R5=0/1/2/7, CE=1/4/7, checking exact frame
periods and active-raster counts (`/tmp/x1-v09-crtc-boundary-after.log`).
The original fractional-enable and 600,000-edge-per-width divided-clock /
enabled-CRTC comparisons also pass (`/tmp/x1-v09-clock-crtc-equivalence.log`).
A fresh one-second 384-line CPU/pixel test on the corrected model produced
the correct 640×384 dimensions but failed the pixel oracle on odd rasters
(`/tmp/x1-v09-text-high12-fixed.log`). This was a separate fixture error:
mode 01 interleaves GRAM pages 0/1, whereas the ROM filled only page 0.
The fixture now initializes both pages through real CPU/DAM writes before
restoring the CPU page. No expected dimensions, pixels, duration or period
tolerance changed. The later corrected-fixture frozen-runner result is listed
below; the CRTC unit alone was not promoted to that machine gate.
The first two-page attempt also retained the same mismatch: it attempted to
write SCRN while DAM was still active, so that OUT was redirected to graphics
RAM instead of the page latch (`/tmp/x1-v09-text-high12-both-pages.log`).
The ROM now exits DAM through a real IN before SCRN, re-enters with the PPI
C5 falling edge for the second fill, and exits again before restoring SCRN.
The unchanged every-pixel check subsequently passes; this corrects fixture setup,
not the machine's established DAM exclusion contract.
Pre-boundary low-scan 40×10 and underline-mode-exit completed their pixel
assertions, but have the executable-provenance limitation below; a frozen
corrected-source low-scan 40×10 and delay-aware high-scan 40×20 now pass;
details below.
Those initial scripts did not freeze Vtop and calculated its hash at completion;
concurrent rebuilds can therefore mislabel their executed binary. Preserve
those raw artifacts, but do not attribute their late hashes to corrected-source
acceptance. The fixture now copies/hashes a private executable in each unique
output folder **before** execution and rechecks it afterward; all new/final
qualifications use that frozen copy. Earlier successful baseline/80×20/ANK16
cases completed before replacement and retain the recorded hashes above.
After the CRTC correction, rebuilt base timing/reset/CE/delayed-event/FST
and v09 snapshot/SDL checks pass (`/tmp/x1-v09-boundary-timing.log`,
`/tmp/x1-v09-boundary-snapshot.log`), as does the actual X3 wrapper-lint target
(`/tmp/x1-v09-x3-boundary-lint.log`, inherited warnings). These are not a fit.

| Corrected-source runner | SHA-256 |
|---|---|
| Delay-aware X3 | `8843c280233620a1cd6545546ef063b0871ad80267a8851e65e16b5ef2eac7f4` |
| Fast X3 | `7121b5013da2387427483f4bc3bf012c5509d7d6bda40d4361bf539b874f3692` |
| Fast base SDL/savable | `560d80e5748000811b4690f14da84528efb710dc01a2168850cfebf54080c366` |
| Delay-aware base | `8e1458a9f354c881173f5c9dfa3cfc2abb1df28882f1b7d96f8ab12278e30ed1` |

Corrected-source machine results at checkpoint `29755e7`, with those frozen
runner hashes and original one-second / 32,000,000-cycle assertions:

| Case | Result |
|---|---|
| Fast X3 standard-scan 40×10, global expansion and underline | All 320×200 pixels pass, including reverse cells and separately colored line/gap; 43 frames, hash `6318324a232e06e5`, HS=62.562500 us, VS=16.270218750 ms. `/tmp/x1-v09-text-low10-frozen-final.log`. |
| Fast X3 high-scan 80×12, global expansion, both GRAM pages initialized via DAM | All 640×384 pixels pass; 25 frames, hash `8917c4ceac813725`, HS=41.718750 us, VS=20.024906250 ms. `/tmp/x1-v09-text-high12-page-dam.log`. Original ROM SHA-256 `966b87f3e95115ff0d8d785199738db2dcf799c7646753ed7cebaf7bc47ee7b7`; 4609 reset edges, 4545 download bytes. This is not a native BASIC row-setting procedure. |
| Delay-aware X3 high-scan 40×20, underline | All 320×400 pixels pass; 36 frames, hash `707e5a7d89b05a25`, HS=41.718750 us, VS=19.190500000 ms. `/tmp/x1-v09-text-high20-fixed.log`. This ROM initialized only GRAM page 0, so it does not independently prove suppression of FF on odd-page rasters; the updated matrix fixture initializes both. |
| Prior fast base 80×25, corrected CRTC | All 640×200 actual pixels/periods pass at the original 200 ms; nine frames, unchanged hash `38336804c6381245`, HS=62.718750 us, VS=16.181750 ms. Frozen base runner `560d80...c366`; `/tmp/x1-v09-base-boundary-pixels-final.log`. |
| Prior delay-aware X3 ANK16 40-column/raster 3, corrected CRTC and warm reset | All 320×400 pixels/periods pass at the original 200 ms with 120 ms/10 us reset and retained font; six frames, unchanged hash `8ec9d6393e3dde65`, HS=41.718750 us, VS=18.689875000 ms. Frozen X3 runner `8843c2...c7f4`; `/tmp/x1-v09-ank16-boundary-warm-final.log`. |

Mode exit deliberately leaves the same
CRTC programmed and verifies compatible glyph wrap / retained visible GRAM;
it is not execution of BASIC's full WIDTH mode-setting procedure.

Still required before full acceptance: positive/negative rows at both widths/scans,
mode exit and warm reset, blink/blackclip/priority/PCG/neighboring expanded
attributes, expanded/underline-specific warm resets, X3 snapshot
rejection/continuity and source-bound Quartus/CDC review. Base
snapshot and wrapper-lint results above do not establish those other gates.
The frozen `15a0655` build
does not include this renderer or the later PPI synchronizer.
