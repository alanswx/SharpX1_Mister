# External-font Main OSD reset qualification

October 15, 2026. Hardware follow-up to the accepted
[active-traffic reset gate](Z_FONT_ACTIVE_RESET_STATUS.md). The six-case hardware
matrix and final audit pass. The existing fd9a0850 RBF,
all 428 Quartus inputs and all 127 frozen simulation inputs remain unchanged.
No new simulation or Quartus build is needed for this orchestration-only work.

`scripts/mister_z_font_osd_reset.py` stages six unique MGL/config cases from
the existing generated ROMs and synthetic physical-order font. Both OSD entries
are tested with good80, good40 and a one-byte wrong-last-retained-compare80 ROM.
No Main configuration, installed binary, earlier deployment, private disk or
native font is modified. Each case makes one initial load request; retained
phases use only mrext keyboard/capture calls and read-only status/DDR observations.

## Dispatch and controls

The wrapper advertises `T[0],Reset` and `R[0],Reset and close OSD`. The inspected
local Main generic-menu implementation opens on the first selectable option,
wraps Up through the final Exit and reset options, and pulses the selected
status bit. Three Up taps select Reset; two select Reset-and-close, independent
of the preceding font/profile options. The local Main checkout is a read-only
navigation reference, not established as the source of the installed binary.
Its hashes and the actual installed binary hash are recorded separately.

For every case:

1. Load its MGL and send real F. Existing qualified software fills VRAM, checks
   its cold reads and enters sustained checked font reads/idempotent VRAM writes.
   Only the first checked iteration publishes yellow corner ink.
2. Open OSD, navigate to the selected reset entry, close with F12 without Enter,
   then send real R. This no-selection control must preserve yellow and reject
   the unchanged magenta recovery oracle.
3. Reopen, navigate and press Enter. For T Reset, close F12 and send R.
   For R Reset-and-close, send R directly, with no extra F12.
4. Software must compare all 6,144 retained text/Kanji/ATTR bytes before its only
   VRAM write publishes magenta. The bad ROM changes only expected IPL byte 57FF
   from 02 to 03 and must keep yellow under the same oracle.

The installed Main has no `/tmp/OSD_VISIBLE` marker enabled. No global logging
setting is changed. The T sequence requires explicit F12 before R can select
software. Positive R cases require automatic menu closure for R to reach software. Core/setname
must stay unchanged. Raw mrext PNGs show core video, not the OSD overlay; menu
selection is inferred from these bounded input/control outcomes.

This is hardware input/dispatch qualification, not a new CPU simulator gate.
Its software and exact yellow/magenta references come from the prior frozen
four-case simulation, with 34,544 completed reads and twelve exact frames.
The hardware harness rechecks frozen ROM and PNG hashes before deployment.
It refuses retries of a partial case and checks its own/decoder source hashes.
Failed/partial evidence must remain separate from a new deployment.

## Results and evidence

Accepted directory `output_files/X1OSD_20261015T190610Z/` contains the unique deployment,
source bindings, copied prior immutable qualification archive and raw PNGs.
Corrected stage 10741 and matrix 66295 are terminal zero; final audit passes.

| Case | Active | No Enter + R | Selected reset + R |
| --- | --- | --- | --- |
| 01_T_good80 | 256,000 exact / yellow | 256,000 exact / rejects warm | 256,000 exact / magenta |
| 02_T_good40 | 128,000 exact / yellow | 128,000 exact / rejects warm | 128,000 exact / magenta |
| 03_T_bad80 | 256,000 exact / yellow | 256,000 exact / rejects warm | 256,000 exact / rejects warm |
| 04_R_good80 | 256,000 exact / yellow | 256,000 exact / rejects warm | 256,000 exact / magenta |
| 05_R_good40 | 128,000 exact / yellow | 128,000 exact / rejects warm | 128,000 exact / magenta |
| 06_R_bad80 | 256,000 exact / yellow | 256,000 exact / rejects warm | 256,000 exact / rejects warm |

Eighteen actual raw PNGs match **3,840,000 pixels**, with no crop, scale or
tolerance. Four positive warm frames accept the unchanged recovery oracle;
six no-selection frames and both bad-final-byte warm frames reject it.
All six no-selection PNGs are byte-identical to active; both bad warm PNGs
are also byte-identical. The fixture's physical read completion is inferred
from its previously qualified control flow and post-check marker, not pin traces.

[Actual screenshots](../output_files/X1OSD_20261015T190610Z/screenshots.html),
[manifest](../output_files/X1OSD_20261015T190610Z/manifest.json),
[final audit](../output_files/X1OSD_20261015T190610Z/final-audit.json),
[supplemental review](../output_files/X1OSD_20261015T190610Z/supplemental-review.json).

All sixteen staged files, 127 simulation inputs and 428 compiler inputs pass
hash checks. RBF and installed Main hashes remain unchanged; six per-case and
one final full DDR reads match `d18c7cb9c91d05b3d70e9061ce0ef36d2976960e1bb74984f3ef85fd17d7032b`.
Manifest SHA-256 `03360a1e074f27231aef674ef99d51d8e4c95a28cb914cd9f6f405707c0d120e`;
hardware driver SHA-256 `8922eeab54c6fab08251d5d2662cceb5a98dfd37de8141b198757cdb9b12c692`.
The copied prior qualification archive remains
`90a034832da7636b641e7e3b4bf72af7f6bde57514f4ebd0afba3d590b3cf312`; its four-case simulation/failed development
artifacts retain their original scope. No new simulator or Quartus flow was run.

The first attempt `X1OSD_20261015T190220Z` is rejected. Its extra pre-readback
checker incorrectly required active yellow while OSD still blocked R. The fresh
PNG is all black. Source inspection shows CRTC programming retains reset,
while Turbo SCRN resets to zero and this renderer admits Kanji only in high
scan. The keyboard shell restores SCRN only after F/R selects a path. The
corrected test closes T's menu before R and checks the original exact post-
readback frame. No oracle was changed to accept the failed intermediate image.
Failed manifest, driver, three PNGs and log are preserved separately and copied
into the accepted output. The driver refuses automatic retries of partial cases.

To repeat from the current accepted state:

```sh
python3 scripts/mister_z_font_osd_reset.py stage --previous output_files/X1OSD_20261015T190610Z/manifest.json
# Use the new EVIDENCE directory printed by stage:
python3 scripts/mister_z_font_osd_reset.py matrix output_files/NEW_DIRECTORY
python3 scripts/mister_z_font_osd_reset.py audit output_files/NEW_DIRECTORY
```

For manual use, load an accepted MGL, press F and wait for yellow. F12, Up
three times, Enter selects Reset; close F12 before R. F12, Up twice, Enter
selects Reset-and-close; send R directly. Positive readback gives magenta.
`03_T_bad80` and `06_R_bad80` intentionally keep yellow. MiSTer is left on
`X1OSD_20261015T190610Z_06`. All jobs started here are terminal.

SYS32 / fitted VID42.954545 MHz remain configured build frequencies, not a
physical measurement. Exact physical transaction ownership/reset edge, stopped
clocks, native font conversion, wider raster modes/device coexistence and
electrical timing/closure remain open. Original-SDC Quartus timing still fails.
