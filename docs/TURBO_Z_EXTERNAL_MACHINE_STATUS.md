# External full-font machine integration

October 15 retained-reset follow-up: [real F/R and reset/no-reset controls](Z_FONT_RETAINED_RESET_STATUS.md)
now qualify bounded post-HALT retained IPL/font/VRAM on fd9a0850. Three
simulation cases check 18,570 actual CPU reads; nine actual Main/mrext frames
match 1,920,000 control pixels. Main's keyboard reset chord plus R reaches a
post-readback magenta marker at both widths; R without reset and a wrong last
expected byte fail the unchanged warm oracle. No warm upload is requested;
all compiler inputs/RBF remain unchanged. OSD-menu, owned/stopped-clock reset,
native fonts, broader raster/device behavior and timing closure remain open.
Earlier checkpoint statements below retain their dated scope.

October 15 CPU-completion follow-up: a [new post-check visible marker](Z_FONT_CPU_COMPLETION_STATUS.md)
closes final CPU-readback observability for separate 80/40-column RBF-load
controls. Four simulation cases pass 184 traced reads/768,000 control pixels;
five actual MiSTer cases match 1,024,000 pixels, including two one-byte failing
IPLs rejected by the unchanged completion oracle. Source-bound fd9a0850 is
reused with all 428 compiler inputs unchanged; no new Quartus flow. Older
IPLs retain their original scope. Physical warm-reset causality, native fonts,
wider modes and timing closure remain open.

October 15 second repair: the [actual HPS error-recovery gate](Z_FONT_HPS_UPLOAD_STATUS.md)
adds real decoder/ACK framing and four exact rejecting controls. New RBF
fd9a0850 builds; actual valid/oversized-retry/short-retry controls match
640,000 pixels/full DDR with Main responsive. Native CROSS Chase shows a
populated field. This supersedes c6 as the current source-bound RBF; timing,
native font conversion and broader raster/physical gates remain open.

October 15 [hardware follow-up](TURBO_Z_EXTERNAL_HARDWARE_STATUS.md) supersedes
the "current-source" build statements at the October 14 checkpoint below.
The initial RBF exposed a final-SPI-ACK deadlock after an exact physical
256-KiB upload. The repaired frontend passes 39 unit cases, the complete
five-case machine gate and full Quartus build; RBF `c6a2ac02…` matches 768,000
actual MiSTer pixels across cold/post-reset-request 80/40-column frames.
Timing and native-font/broader-mode gates remain open.

October 14, 2026. Separate default-off `TURBO_Z_EXTERNAL_FONT` experiment and
`sharpx1_turbo_z_font` board revision. This reaches the combined-machine and
full-board-build stages of the [external font plan](TURBO_Z_EXTERNAL_FONT_PLAN.md).
Native Turbo Z/font/ASIC and physical acceptance remain separate gates.

| Requested stage | Current result |
| --- | --- |
| 1. Machine/DDR/CPU/renderer wiring | Implemented; actual CPU font and three-plane VRAM reads pass. |
| 2. Reset/upload/rebuild lifecycle | Owned writer/read drains, blocked START, short-image rejection/retry and retained rebuild pass. |
| 3. Whole-machine regression | Generated CPU/pixel and final ordinary regression pass. |
| 4. Native font and broader raster policy | Open; no native conversion or wider ANK/PCG/size acceptance inferred. |
| 5. Combined Quartus/physical gates | Repaired full fit/RBF and bounded physical DDR/pixels pass; timing still fails. |

## Machine contract

`rtl/sharpx1.v` now connects the existing highest-cell selector and PCG CPU
service to the full 256-KiB DDR frontend through the fair font arbiter. The
256-KiB simulation ROM is excluded from this profile. All three CPU VRAM ports
use the captured writer address/data and one committed strobe. The selector
observes that same commit, including 37FF/27FF/3FFF, rather than repeated raw
OUT levels. Text, attribute, Kanji half and glyph reach the real renderer as
one committed cache packet. Existing ANK/PCG source paths remain connected.
The shared manifest includes these default-off modules; their older standalone
header comments describe their original qualification scope.

`rtl/x1_z_kanji_machine.sv` owns the lifecycle without resetting transport or
CDC toggles. A pause immediately stops CPU enables and new write admissions.
An accepted writer finishes publication and its one VRAM commit before CPU
reset or cache invalidation. Its held request is explicitly retired even when
the CPU is stopped. Cache invalidation drains its held read/publication, then
the arbiter drains before frontend cancellation and upload permission.
SYS, VID and the DDR service must continue until their owned work drains;
stopping either clock intentionally retains backpressure.

A launch-initialized descriptor journal changes on the same edge as the
retained VRAM commit. After reset or font replacement, synchronous journal
reads refill every complete retained cell before CPU/video release. Partial
cold cells remain invalid; no uninitialized VRAM byte becomes valid metadata.
This uses additional on-chip memory and provisional refill-before-write WAIT,
not measured ASIC visibility or native write latency.

Missing/short/invalid fonts hold consumer reset. Index 5 accepts exactly
262,144 ordered physical bytes; START and WR are blocked until the consumers
and transport are quiescent. Full-image commit waits for all commands to drain.
An incomplete replacement revokes readiness; a new complete transaction can
recover without IPL/VRAM reupload. Ordinary warm reset retains font readiness.
Cold FPGA configuration initializes it false; no runtime DDR-loss detection or
native power/battery policy is supplied. DDR write response acknowledges command
acceptance; the interface supplies no physical-persistence fence.

The experimental core reservation is byte 30000000–3003FFFF (word base
06000000). Local framework inspection finds scaler buffers at 20000000 and
optional arcade framebuffer at 24000000; this revision leaves framebuffer off
and rejects MISTER_FB. No other X1 DDR client is enabled. A read-only October 14 check of the user-
provided MiSTer at 10.0.2.14, through misterubuntu, confirms kernel
`mem=511M memmap=513M$511M` and System RAM 00000000–1FEFFFFF. The backing
range lies outside Linux RAM. Kernel is 6.18.38-MiSTer; the active MacPPC7300
core is preserved. No core load/reset/input or DDR transaction test was sent.
Evidence `/tmp/x1-z-font-mister14-memory-map.log`, SHA:
`31820aee4dc77a9f312e5dbe18d1b964c15008a01faff8235c0fedd6a7f869b8`.
This verifies the memory carveout, not the new core's physical DDR operation.
Wrapper font addresses
at/above 262144 become an invalid sentinel before narrowing the 27-bit HPS
address, preventing high-bit aliasing. The OSD exposes the separate physical
font loader; existing board revisions leave the feature disabled.

The profile requires Turbo/X3/Kanji/render, excludes DMA/single-clock and the
combined video/FM/RTC/SIO/cassette experiments, and has no C++ snapshot model
or ordinary runner target. It is not a native Z identity. Ordinary C++ runners
have deterministic inactive DDR inputs. The default generated base/Turbo v17
state audit passes all eight original headers/serializers exactly, with the
same sixty inherited warnings and no new warnings. Initial integration exposed
two traced write aliases in base state; conditionalizing the Z-only aliases
repaired this without changing snapshot bytes or version. Failed audit evidence
is retained in `x1-machine-fdc-default-state-9ddz2rzj` / `gdoy_nr2`; current pass
is `x1-machine-fdc-default-state-1epbd84l`, log
`/tmp/x1-z-font-default-state-final.log`.

## Frozen simulation gates

Run `make -C verilator test-machine-z-external-font` and
`make -C verilator lint-wrapper-turbo-z-font`. Wrapper lint is an interface
check using the existing PLL stand-in, not Quartus or hardware acceptance.

The first complete-machine gate `x1-z-external-machine-gwdsg7jr` passes two
boots, 64 font IN samples, all original backing bytes, one exact 640x400 frame
and a DDR corruption control. Expanded gate `x1-z-external-machine-o7bd3bu8`
adds 80/40-column retained rendering, ANK/PCG CPU routes and short-font recovery.
The subsequent five-case gate `x1-z-external-machine-pkokpbfv` passes six complete
boots and four interrupted boots, 208 actual CPU IN samples, 12,358 committed
VRAM writes, and six exact frames (1,152,000 pixels). Each positive records
328,929 real mock-DDR reads and 524,304 byte writes, including the short upload.
Its controls fail exactly at `Z_EXTERNAL_CPU_ORACLE`,
`Z_EXTERNAL_EARLY_RESET_UPLOAD` and `Z_EXTERNAL_REBUILD_VALIDITY`.
No compiler/global-timeout failure is accepted as a negative.
Terminal JSON SHA-256:
`840328bbed0af7e155b2f2559e4c30922ea2914a2022a741f6a9341b46331bdd`.
Read-only independent review `x1-z-external-review-fbaib58n` rechecks all frozen
inputs/executables/logs/artifacts, all 12,358 intended CPU commits and every
pixel; PNGs are regenerated outside original evidence and match byte-for-byte.
Review SHA-256:
`7b090f078a33afdbaa9799abe899880a96f8ad15ecdbd77f79d73012ed50b931`.
Those gates precede the ordinary-state alias repair; the current-source rerun
with visibly changed replacement-font pixels also passes below.

The sixty connected compiler warnings are inherited CPU/MR16/CRTC/FDC
PINMISSING(5), MISINDENT(1), WIDTHTRUNC(23), WIDTHEXPAND(26),
CASEINCOMPLETE(1), CASEX(4); no new service warnings occur. Standalone service
lint reviews three intentionally unconnected observation/WAIT outputs and
three launch-only declaration initializations, then passes strict -Wall with
only PINCONNECTEMPTY/PROCASSINIT disabled. Raw and reviewed logs remain in
`/tmp/x1-z-font-service-strict-lint.log` and
`/tmp/x1-z-font-service-reviewed-lint.log`. No functional warning is waived.
SYS is 32 MHz; VID uses 23,280-ps periods (rounded X3, approximately
42.955326 MHz). Tests do not independently qualify nominal X3 frame frequency.

The **final current-source gate** is terminal zero: session `87292`, folder
`x1-z-external-machine-0gobqu2p`, log
`/tmp/x1-z-external-machine-frozen-final.log`. It imports its emitter/oracle
from the captured source graph before generating assets. All five cases pass:
six complete boots, four interrupted boots, **280 actual CPU IN samples**
(including 72 new text/Kanji/attribute-alias VRAM readbacks), 12,358 commits,
657,858 mock-DDR reads, 1,048,608 byte writes and six exact frames / 1,152,000
pixels. Every byte of both full uploaded backing images is checked. The first
two frames match; the changed-font replacement frame differs and matches its
own exact RGB oracle, so retained old glyphs cannot pass. The three controls
retain the same exact failure markers above.

Final terminal SHA-256:
`77a44e7e1538260f59f1d1818fbcf0006e61ac0e20adfc06bbbc32a6af49c7e3`.
Current machine SHA `06923b59…`; coordinator `06c04b6d…`.
Independent read-only review `x1-z-external-review-zyky8esq` verifies current/
frozen sources, all five IPL images against the captured emitter, all executables/
logs/artifacts, the identical sixty-warning inventories, exact CPU commit and
read/address ledgers and all six original/replacement frames. PNGs regenerated
outside original evidence match byte-for-byte. Review SHA:
`87cf4cbd0bd7391961b4181b06e694ec66a8762e97c7dc8bcf51897e7e7ce652`.
Earlier changed-font gate `gdt9sa9j` / review `9a7_y8sb`, and 140-read gate
`t0xyayb7`, remain preserved; they are not substituted for this final run.


Final ordinary `headless`, `run CYCLES=200000` and `test` commands all return
zero with the unchanged current runner SHA
`afcf97118840dd9373cc84bb4d89a5c6baf55192c4bcfcefc92628cf50412d77`.
The final test log contains 164 PASS lines and 28 JSON reports; all recorded
main-runner hashes agree. Base/external-font/DMA wrapper lints pass, and
`git diff --check` is clean. New nested timer recipes create their output
parent directories, repairing the clean-tree test prerequisite failure.
Review `x1-z-font-default-final-review.json` also verifies all 428 current board
inputs unchanged and hashes the build/run/test/state/lint evidence. SHA:
`8a2bffa05aef6959bc308aada62b1ec543f577300266fde32fd71f9cc0ca51d4`.
Logs `/tmp/x1-z-font-default-{headless,run,test}-final.log`; the earlier failed
missing-directory attempt and earlier mixed-source pass remain preserved.


## Quartus and remaining acceptance

**Current-source build gate PASS; timing gate FAIL; hardware feature gate
UNEXECUTED.** Full Quartus 17.0.2 Build 602 Lite compile on `misterubuntu`:
`quartus_sh --flow compile sharpx1 -c sharpx1_turbo_z_font`, top `sys_top`,
device 5CSEBA6U23I7, seed 1, two low-priority threads. Session `35333` is
terminal zero after 24m52s, 170 flow warnings. Remote frozen directory:
`/tmp/x1-z-font-board-syksUXgN`; local `x1-z-font-board-i9gmhvn7`.

Fit uses **25,512 ALMs**, 37,215 registers, **534/553 M10Ks** (19 spare),
4,319,336 memory bits, 32 DSPs and 4 PLLs. Actual fitted video PLL is
945 MHz / 22, approximately 42.954545 MHz; SYS remains 32 MHz. This is a
fitted frequency, not a physical clock measurement. Map confirms both complete
65,536-byte glyph banks, the 2,048x32 journal and retained writer-known memory;
the 256-KiB simulation ROM is absent from this elaborated profile.

RBF:
[sharpx1_turbo_z_font_52be576d.rbf](../output_files/z-font-20261014-52be576d/sharpx1_turbo_z_font_52be576d.rbf),
4,187,468 bytes, SHA-256
`52be576dd7cc74d6009f89bd7f280f47d43ee3cb92cc79d7efdf3a93f093771a`.
The ignored output directory also contains the
[manifest](../output_files/z-font-20261014-52be576d/manifest.json), fit/timing
summaries, complete source snapshot, raw build/path evidence, simulation and
ordinary-state reviews, and read-only MiSTer memory-map evidence.
Manifest SHA:
`6c368187c30d12e2b7ca516c326d94e39bf552fd41eb95926e649de33fb9d98b`.

All 428 frozen inputs match the current working tree and were verified before
compile. Source archive SHA:
`57799209ae2457b78994e80bba0fc3a1e26c7e88cc10562918b9190412adae47`.
Post-build review verifies 427 unchanged inputs and explicitly checks the sole
Quartus-generated QPF date/revision rewrite; actual post-build QPF and build_id
hashes are saved. All 59 retrieved build/audit files match their manifest.
Evidence archive SHA:
`27dcd377429d22c6517a70d8f25fdd966bc800dc53008501a5f645be5ce90f8a`.
No source normalization or state-byte conversion bypasses these checks.

The reporting-only `quartus_z_font_paths.tcl` sidecar (session `31234`,
terminal zero) uses original SDC and records clocks, unconstrained ports,
cache-register inventory and both slow-100C / fast-minus40C paths. It adds
no exceptions or clock-group cuts. Current fitted results in ns:

| Check | Slow 100C | Fast -40C |
| --- | ---: | ---: |
| Global setup | -14.978 | -7.101 |
| Global hold | +0.182 | -0.045 |
| Global recovery | -8.570 | -4.015 |
| Global removal | +0.815 | +0.311 |
| Same-clock SYS setup | +5.548 | +10.613 |
| Same-clock VID setup | +7.034 | +15.129 |
| SYS-to-VID / cache-target setup | -10.859 | -5.291 |
| VID-to-SYS setup | -9.378 | -4.863 |

Worst global setup is HDMI data to X3 output. Cache held-cell-to-visible paths
have ordinary edge checks without qualified bundle limits. Reset recovery
includes writer-IDLE to video-reset-release pipes. The fast hold failures are
measurement snapshot held_data[59]/[44] to destination_data in `dimensions_to_sys`.
Positive same-clock setup does not qualify these crossings/reset paths. The
flow also reports unconstrained ports and declines to calculate design MTBF
because timing is unmet. Timing/CDC placement and hardware acceptance remain
open; no bad path is declared safe from these reports.

Ordinary X3 generated state is additionally checked against unchanged HEAD
in `x1-machine-fdc-default-state-b2ft0ntx`, log
`/tmp/x1-z-font-x3-state.log`: all four headers/serializers match with the same
sixty warnings. Together with base/Turbo this gives **12/12 exact files**;
this is a generated-state audit, not runtime snapshot conversion/qualification.

Earlier prototype full compile `46389` remains preserved in
`/tmp/x1-z-font-board-RBcNDcMC`, retrieved `x1-z-font-board-_08vrlhp`.
It fit at 25,740 ALMs / 534 M10Ks with RBF `d454e315…`, but precedes the
wrapper address guard and ordinary-state alias repair and is superseded by
the current RBF. Intermediate `x22j7daY` was cancelled while queued, before
any compile, to include the repair; its inputs/cancellation record remain.
No timeout restart and no job started here remains live.

Native font conversion and broader high/low-scan/row/size/ANK/PCG policies
remain open. Local MAME's inspected conversion is for earlier four-chip,
128-KiB half-major fonts, and its Turbo Z entry is commented out. The available
local model-40 candidate is not an IC65/IC66 source; it is not relabeled,
truncated or padded into a Z font. Simulation uses generated physical bytes.

At this October 14 checkpoint only read-only MiSTer memory/core inspection
occurred: the 30000000–3003FFFF
range is outside Linux RAM, and the active MacPPC7300 core/media/configuration
remain untouched. No load/reset/input or new DDR transaction was executed.
Main/OSD dispatch, actual DDR/cache operation, physical pixels/input/audio,
native software and wider DMA/FM/RTC/SIO/FDC coexistence are unqualified.
The separate October 15 follow-up above now supplies bounded physical DDR,
renderer and native-game evidence; it does not close the other gates here.
