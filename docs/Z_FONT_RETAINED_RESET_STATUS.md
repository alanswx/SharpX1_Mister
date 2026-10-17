# External-font retained-asset reset qualification

October 15, 2026. New test-only firmware makes reset causality observable:
F/f initializes all three VRAM planes and publishes white corner ink before
DI/HALT. R/r sent without reset must leave that frame unchanged. After actual
reset, R/r selects a read-only pass over all 6,144 retained VRAM bytes before
publishing magenta corner ink. A bad final expected byte must prevent that
marker. Machine RTL and the source-bound fd9a0850 RBF are unchanged.
The full simulation gate and actual Main/mrext hardware matrix both pass.

## Firmware and oracle

The existing qualified cold diagnostic remains at its original addresses,
with an entry jump to a real E4/00/E6 mailbox keyboard loop at 7000. F enters
the cold diagnostic after DI/SP setup. R enters a separate retained reader at
7200. It uses original ioctl-loaded IPL comparison tables at 4000..57FF;
no cold-RAM sentinel determines the boot path. Both upper/lower-case input
are accepted; this does not qualify Caps retention or every keyboard key.

Cold execution still checks ANK, PCG, both end-of-store font probes and twelve
VRAM reads before setting the first marker. Warm execution reads every text,
Kanji and ATTR cell, including the previously marked ATTR=7 at cell zero.
It makes no VRAM write until the complete comparison succeeds; its only write
then changes cell-zero ATTR to 3. RAM status `WARM` and final HALT are observed
in simulation. A wrong-table control changes only byte 57FF from 02 to 03;
actual CPU readback remains unchanged and failure prevents publication.

`make -C verilator test-machine-z-font-warm-reset` freezes 126 inputs and one
executable before three cases: good80, good40 and bad-final-byte80. Each case
first delivers a real PS/2 R packet while the CPU remains in DI/HALT, observes
its MR16 key-buffer event and checks unchanged CPU/read/write counts. That
frame must reject the same warm oracle used after actual reset. After reset,
cache/journal retention is observed, all 6,144 actual CPU IN values/ports are
checked and the final marker must follow the last read. No host RAM/VRAM
repair, forced CPU state, translated-key injection or asset reupload is used.

Every case checks two traced CPU boots, 6,190 diagnostic reads, exactly
294,912 initially accepted IPL/font bytes and no later upload strobes.
Good cases require 6,155 committed VRAM writes; bad requires 6,154. Full
256-KiB DDR contents must still match the original synthetic font. Nine exact
frames total 1,920,000 pixels, including no-reset and failed-compare controls.
The gate uses SYS 31,250-ps / rounded X3 VID 23,280-ps periods. This is not a
native controller, caps-retention, disk/IRQ/DMA or physical timing test.

Accepted frozen evidence: `x1-z-font-warm-m_g5y0ve`, terminal SHA-256
`ad0d2ea55f8b1f2572d4936e2cbb0f52b8cfa553644f65fa9456932fd5305d1b`.
Executable SHA-256:
`3a8eb960b45872861d2b23389c04056a67443674b40341b9a07a342e6a956b77`.
All 60 inherited warnings match the earlier CPU-completion gate after path
normalization; the new fixture introduces no warnings. Hosted CI is not run.

## Preserved rejected development runs

The initial C command failed because the unchanged firmware consumes C as
joystick T3 when `JOY_EN` is set. The raw PS/2 packet and parity are valid;
MR16 trace follows 035C → 0372 → joy_emu/04E6 and the C entry at 0508, without
an ASCII mailbox event. F replaces C at the same 25-ms input timing. Firmware,
key timing and pixel assertions are not loosened to accept the fixture.
The initial timeout (`lehkoh1j`) and three bounded trace runs (`d16tpec_`,
`3agy8nls`, `xrpinh7t`) remain failed evidence. An intermediate compile typo
(`jlmfzlom`) is also preserved. None is counted as a rejecting control pass.

## Physical results

Unique files are staged in `output_files/X1Warm_20261015T165542Z/` and matching
MiSTer `_Computer/` / `games/SharpX1/HWTest/` folders. The helper sends real
Linux F/R key taps through mrext. LeftCtrl + LeftAlt + RightAlt is sent with
a temporary uinput keyboard, without Shift. The following R requests only
retained readback: no core reload, asset upload or disk mount is requested.
Main's keyboard chord is the reset path under test; this is not a test of
its OSD menu-reset dispatch or physical reset pins. Fitted board clocks remain
SYS 32 MHz / VID 42.954545 MHz, not measured frequencies.

All nine actual raw PNGs match **1,920,000 control pixels**, without cropping,
resizing or tolerance. Two positive warm frames match the post-readback oracle;
all three no-reset frames and the bad-last-byte warm frame reject it. Every
no-reset PNG is byte-identical to its cold PNG. Positive warm PNGs differ from
cold only as required by the magenta corner; the failing warm PNG stays white.

| MGL | Cold F | R without reset | Main reset + R |
| --- | --- | --- | --- |
| `01_Retained80` | 256,000 exact pixels, white | 256,000 exact pixels, rejects warm | 256,000 exact pixels, accepts warm |
| `02_Retained40` | 128,000 exact pixels, white | 128,000 exact pixels, rejects warm | 128,000 exact pixels, accepts warm |
| `03_BadFinalRetained80` | 256,000 exact pixels, white | 256,000 exact pixels, rejects warm | 256,000 exact pixels, rejects warm |

[Actual screenshots](../output_files/X1Warm_20261015T165542Z/screenshots.html),
[manifest](../output_files/X1Warm_20261015T165542Z/manifest.json) and
[final audit](../output_files/X1Warm_20261015T165542Z/final-audit.json).
Final audit passes nine PNG hashes, all eleven staged files, all 126 frozen
qualification sources, all 428 original compiler inputs, unchanged RBF and
complete fresh DDR readback (`d18c7cb9…`). Final manifest SHA-256:
`755a4bda7b851040fe8965b73b19ea2e5889b879463abe0c3ed8e9d055bb2ba7`.
Accepted and rejected development sources/traces are preserved in archive SHA
`7a61a21c71b54de74e10ce17ffca77da129c9646f7cfe35f0b43f83b4aa4b7a2`.
No additional Quartus run or ordinary regression was needed for test/IPL-only
changes; compiler inputs and the earlier 164-PASS executable remain unchanged.

To repeat on the MiSTer, open `_Computer/X1Warm_20261015T165542Z/01_Retained80.mgl`
or `02_Retained40.mgl`, press F and wait for white corner ink. R alone must
leave it white. Hold LeftCtrl+LeftAlt+RightAlt, release them, then press R: the
corner becomes magenta after all retained reads succeed. `03_…` deliberately
keeps white after reset. No asset load is requested between these phases.
The harness uses real Main/uinput/mrext input; the physical HPS SPI bus and CPU
pin counts are not traced. Exact hardware-read completion is inferred from
qualified firmware control flow and the post-check marker. Simulation separately
counts every upload and CPU read and forbids warm reupload/VRAM rewrite.

All jobs started here are terminal. MiSTer is left on the intentional
bad-last-byte control `X1Warm_20261015T165542Z_03`, white marker as expected;
use `01_…` or `02_…` for the passing diagnostic. Earlier cores/configs/media
and frozen manifests remain preserved. These are post-HALT keyboard-chord
resets with continuously running clocks; Main's OSD-menu reset, owned-transfer/
stopped-clock reset, native MCU/fonts, wider raster modes, ongoing multi-device
traffic, electrical timings and timing closure remain open.
