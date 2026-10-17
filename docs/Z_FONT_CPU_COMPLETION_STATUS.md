# External-font CPU-visible completion diagnostic

Later October 15: [separate retained-reset controls](Z_FONT_RETAINED_RESET_STATUS.md)
now prove bounded post-HALT Main keyboard-chord reset causality and retained
IPL/font/VRAM at both widths, with real no-reset and wrong-table negatives.
The new IPLs and nine hardware PNGs do not retroactively strengthen the older
firmware/images below; other reset paths, native fonts and timing remain open.

October 15, 2026. Earlier hardware font-pattern frames could appear before the
CPU's final VRAM comparisons. A new cold-only diagnostic publishes a visible
corner marker only after those comparisons. This strengthens the bounded
hardware oracle without changing machine RTL or the source-bound fd9a0850 RBF.
The complete four-case simulation gate and five-case physical matrix pass.
Actual Main/mrext PNGs provide the completion marker and matched rejecting
controls at both widths; 1,024,000 hardware control pixels match exactly.

## Diagnostic contract

`test_z_font_completion.py` derives an original 32-KiB IPL from the existing
external-font CPU fixture. The 8-byte retained-RAM branch is disabled so that
unspecified physical cold RAM cannot skip initialization. All three 2,048-byte
VRAM planes are always initialized by the actual CPU. The original 46 reads
remain: ANK and PCG, two 16-row font probes at opposite ends of the complete
physical-order store, then twelve VRAM reads across four selected cells.

The positive IPL preserves every original device/VRAM comparison, table
location and failure target. Its success HALT site jumps to a reserved
zero-filled IPL tail at 7F00. That tail
writes ATTR=7 to cell zero, which previously had ATTR=0, through real OUT 2000.
It then HALTs. The synthetic glyph has nonzero rows, so its white corner ink
is distinguishable from the pre-completion frame. No marker is poked into RAM,
DDR or rendered output by the test host.

A matched rejecting IPL differs by one byte: the expected value of the final
IN 2FFE comparison is XORed with one. Its CPU traffic and returned values stay
the same, but it must branch to failure before the marker. Both configurations
use the unchanged positive completion pixel oracle. The failing control must
reject that oracle and separately match the complete pre-marker image.

`make -C verilator test-machine-z-font-completion` freezes 125 inputs including
the source graph, runner, oracle and emitters before building one executable.
Four cold runs cover 80/40 columns with the passing and failing IPLs. Exact
read values/ports, final RAM status, one HALT, 6,153 pre-marker commits and
6,154 positive commits are required. The marker's final commit must occur
after the last observed CPU read. Full RGB12-derived pixels must match their
independent cell/raster/font oracle; there is no crop, resize or tolerance.
SYS period is 31,250 ps; VID period 23,280 ps is the fixture's rounded X3 clock,
not a physical frequency measurement. Neither short reset nor retained-cache
reconstruction is exercised by this cold-only gate.

The initial frozen run `x1-z-font-completion-yrg0a31a` is preserved as failed:
its CPU read/count/pixel checks passed, then a checker mistake expected ATTR
select 4 instead of select 2. The corrected full matrix passes in
`x1-z-font-completion-611hbrfy`; no assertion was removed or pixel loosened. It checks 184 CPU reads and 768,000
pixels across four cases, including controls. Only the good IPLs match the
unchanged completion oracle. Positive/negative ROMs differ at exactly byte
1003 (`02` → `03`). Terminal report SHA-256:
`4daaf4680a86de9a772409d5f690c3761c7fa36987d44e9d668b26f89ea7fe80`.
Frozen executable SHA-256:
`88b6a1aae0f92249f840bd65397fc8cc143f4de8b3503613e9142e27f4da4e82`.
The diagnostic introduces no Verilator warnings; inherited MR16/TV80/FDC/CRTC/
video/clock/PPI diagnostics are recorded. All 60 warnings match the previous
whole-machine gate inventory exactly after normalizing the frozen directory.
Implicit nets, multiple drivers,
unoptimized loops and latches forbidden. Current gate is local, not evidence
of a completed hosted CI run.

## Physical results

Hardware qualification uses unique MGLs and actual raw mrext captures on
10.0.2.14, reusing the exact fd9a0850 RBF. Evidence is in
`output_files/X1Done_20261015T155523Z/`. Each case reloads the RBF, uploads its
qualified IPL and unchanged complete synthetic font, requests MGL startup
reset, then captures. Board clocks are configured SYS 32 MHz / fitted VID
42.954545 MHz, not measured frequencies.

| MGL | Dimensions | Exact control pixels | Unchanged completion oracle |
| --- | --- | ---: | --- |
| `01_Complete80` | 640×400 | 256,000 | Accepts |
| `02_BadLastCompare80` | 640×400 | 256,000 | Rejects |
| `03_Complete40` | 320×400 | 128,000 | Accepts |
| `04_BadLastCompare40` | 320×400 | 128,000 | Rejects |
| `05_RepeatComplete80` | 640×400 | 256,000 | Accepts |

All **1,024,000 control pixels** match, including two full unmarked images
from the one-byte rejecting controls. The passing images have the expected
white corner ink; negative images do not accidentally reuse a passing frame.
The repeated 80-column passing PNG is byte-identical to the first capture.
[Actual PNG gallery](../output_files/X1Done_20261015T155523Z/screenshots.html),
[manifest](../output_files/X1Done_20261015T155523Z/manifest.json) and
[final audit](../output_files/X1Done_20261015T155523Z/final-audit.json).

Final audit passes all five PNGs, all 16 staged files, 125 qualification inputs,
all 428 original compiler inputs, the unchanged RBF and fresh complete DDR
readback (SHA `d18c7cb9…`). Manifest SHA-256:
`d0061422acc4335790a6f733d0f4164572e527ac6f781461d7e3e83a84cb8cd0`.
The archive preserves both the accepted source/runner/oracle/emitter/trace
set and initial checker failure; archive SHA-256
`b896da7b2bd03611642504c9010e45cf594a20bd6c04174f8ccfb7caf9942b9f`.
The existing ordinary executable remains unchanged from the earlier 164-PASS
regression; this diagnostic-only continuation did not rerun those tests.

Physical CPU completion is inferred from qualified control flow and the visible
marker, not a measured CPU bus count or native pin-timing trace. These new
IPLs close the earlier final-readback observability gap for these separate
RBF-load controls; they do not retroactively strengthen the older IPLs or
malformed-retry frames. No FPGA source changed, so no additional Quartus run
was needed. Original-SDC timing still fails as recorded for fd9a0850.

All jobs started here are terminal. The MiSTer is left on the repeated
80-column diagnostic, setname `X1Done_20261015T155523Z_05`; earlier cores,
configs, media and frozen manifests remain preserved. Native fonts, broader
raster policies, post-marker instruction completion, physical warm-reset
dispatch/retention, ongoing multi-device coexistence and timing closure remain
separate gates.
