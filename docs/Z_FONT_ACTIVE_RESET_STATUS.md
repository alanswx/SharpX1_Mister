# External-font reset during CPU traffic

October 15, 2026. Test-only follow-up to the completed
[post-HALT retained-reset gate](Z_FONT_RETAINED_RESET_STATUS.md). Machine RTL,
compiler inputs and source-bound fd9a0850 RBF remain unchanged. The complete
simulation gate and actual Main/mrext matrix both pass.

`make -C verilator test-machine-z-font-active-reset` freezes the full shared
machine, emitter, oracle and executable before its matrix. Real PS/2 F starts
the existing cold diagnostic, including its 46 checked CPU reads. Instead of
HALT, it enters a sustained loop: three idempotent highest-cell writes followed
by sixteen CPU font reads and immediate comparisons. The first checked
iteration publishes yellow corner ink; subsequent iterations retain that frame.
The writes preserve exact text/Kanji/ATTR bytes, so there is no variable expected
state to forgive when reset interrupts a transaction.

Real R without reset must leave the active loop running and reject the same
magenta recovery oracle used after reset. A subsequent reset and real R select
the existing retained reader, which checks all 6,144 VRAM bytes before its only
write changes the marker to magenta. The matched failing ROM changes only the
last expected retained byte, 57FF: 02 → 03; its frame must remain yellow.
No warm asset upload, host state forcing or RAM/VRAM repair is permitted.

The executed matrix contains owned-write80, owned-read80, owned-write40 and
bad-final-byte owned-write80. The bench observes actual writer/arbiter and DDR
ownership, captures the pre-reset CPU address/WAIT and held font word, then
stops both DDR replies and VID. A write must delay CPU reset and commit once
after services resume. A CPU read may reset its consumer immediately, but its
delayed DDR response must drain without delivery. Cancelled reads are recorded
separately from completed CPU reads; exact completed values/ports and the
cancelled next port are checked. Retained journal/cache reconstruction must
complete before CPU execution resumes. Full font DDR must remain unchanged.

The initial frozen development run `x1-z-font-active-4mhn4iv9` is rejected:
its write case passed, but its read checker incorrectly tested WAIT after
reset disabled the CPU port. The corrected fixture captures that evidence
before reset. The original failed inputs/logs remain preserved. A timeout or
compile failure cannot count as a matched rejecting control.

Simulation uses SYS 31,250-ps and rounded X3 VID 23,280-ps periods. Hardware
reuses the existing SYS32/fitted VID42.954545-MHz RBF, whose original-SDC
timing still fails. The current RBF cannot expose the exact owned transaction
at the physical reset edge. Physical results qualify Main keyboard-chord
reset under firmware traffic, with exact owned/stopped-service evidence
confined to simulation. Main OSD-menu reset, electrical timing, native fonts,
other raster modes and ongoing disk/IRQ/DMA/device coexistence remain open.


## Accepted evidence

Frozen `x1-z-font-active-cmu3g_zf`, terminal SHA-256
`f21518ab4e74f19ff6bb8fdc7af150eecd413c8279d69f90945b9dc335285f5d`; executable SHA-256
`6b32d69f36093b5330e2f1538b1feceb4ecacde86848581998cbc2720c12835e`. All 127 inputs remain unchanged. All 60 warnings
match the earlier gates after path normalization; no new fixture warning.
The new Make/CI gate is wired; hosted CI was not run.

| Simulation case | Completed reads | Active completed reads | Drain commits | Cancelled reads |
| --- | ---: | ---: | ---: | ---: |
| 80 / write / bad=0 | 8,638 | 2,448 | 1 | 0 |
| 80 / read / bad=0 | 8,630 | 2,440 | 0 | 1 |
| 40 / write / bad=0 | 8,638 | 2,448 | 1 | 0 |
| 80 / write / bad=1 | 8,638 | 2,448 | 1 | 0 |

All twelve frames match 2,688,000 exact control pixels. Every completed read
keeps its exact expected value and port; the cancelled pending read is separate,
not a completed payload. It occurs one SYS event after reset at the captured
current port, matching the next expected read after the completed prefix.
The supplementary review also checks every active write payload, the first
sixteen verified reads before yellow publication and real E4/00/E6 keyboard
command sequences. The initial failed development run is archived with the
accepted inputs/logs/frames; it does not count as a rejecting control pass.

## MiSTer results

[Actual screenshots](../output_files/X1Active_20261015T184644Z/screenshots.html),
[manifest](../output_files/X1Active_20261015T184644Z/manifest.json),
[final audit](../output_files/X1Active_20261015T184644Z/final-audit.json).

Three unique MGLs use the existing fd9a0850 core, local synthetic font and
simulation-qualified generated IPL. F is sent through mrext's real Linux-key
path. After active capture, R without reset must preserve yellow. The harness
then sends Main LeftCtrl+LeftAlt+RightAlt (without Shift) through temporary
uinput, waits, and sends R. No reload/upload/mount is requested between phases.
The physical HPS SPI and CPU pins are untraced; read completion is inferred
from simulation-qualified firmware control flow and its post-check marker.

| MGL | Active F | R without reset | Main chord + R |
| --- | --- | --- | --- |
| 01_Active80 | 256,000 exact / yellow | 256,000 exact / rejects recovery | 256,000 exact / magenta |
| 02_Active40 | 128,000 exact / yellow | 128,000 exact / rejects recovery | 128,000 exact / magenta |
| 03_BadActive80 | 256,000 exact / yellow | 256,000 exact / rejects recovery | 256,000 exact / rejects recovery |

All nine PNGs match **1,920,000 pixels** without crop, scale or
tolerance. Active/no-reset PNGs are byte-identical; bad warm PNG also remains
identical. Final audit verifies all eleven unique staged files, all 127
qualification inputs, 428 unchanged compiler inputs, unchanged RBF and fresh
full font DDR hash `d18c7cb9c91d05b3d70e9061ce0ef36d2976960e1bb74984f3ef85fd17d7032b`.
Manifest SHA-256 `8e8f74593ea9b57c3a25286f8acfababde4f85357432a7b4bd1410a6f978a2f8`;
qualification archive SHA-256 `90a034832da7636b641e7e3b4bf72af7f6bde57514f4ebd0afba3d590b3cf312`.
No new Quartus run or ordinary regression was needed for diagnostic-only edits;
the existing 164-PASS ordinary runner executable remains unchanged.

To repeat: load `_Computer/X1Active_20261015T184644Z/01_Active80.mgl` or `02_Active40.mgl`,
press F, wait for yellow, and check that R alone preserves it. Send
LeftCtrl+LeftAlt+RightAlt, release, then R: successful retained readback gives
magenta. `03_…` deliberately stays yellow. The board is left on that intentional
negative. All jobs started here are terminal; earlier evidence is preserved.
Physical exact ownership/stopped-clock behavior, OSD-menu reset, native fonts,
wider raster/device matrices and timing closure remain open.
