# DMA single-clock FPGA qualification revision

October 16 local `sharpx1_turbo_z_font` timing follow-up:
**build PASS, selected snapshot payload timing PASS, global timing FAIL,
hardware UNEXECUTED**. The font-only loader admits the measured 74-bit logical
synthesis inventory and retains the original exact 72-bit fitted/STA guard.
No RTL, existing shared SDC or other board assignment changes. Native
synthesis warning 330000 is removed, with the original 159-warning set retained.

Local Quartus 17.0.0 build 595, seed 1, completes in 14m08s / 171 stage warnings:
25,525 ALMs, 37,234 registers, 534/553 M10Ks, 32 DSPs/four PLLs. New RBF SHA
`c783fb3ee0c9e0a8ea424b32bb1fa2dc12a7d7aaae34994bab0aaf7a0071a720`.
The 429-input manifest SHA is
`1d02bc33d1437f687780c77f33f40ddd37c04efa11c365c56fbaa06d6fcb9912`.
Fitted SYS/VID remain 32/42.954545 MHz, not physical frequency measurements.
All eight selected timing corners pass: 1,152 exact rows, minimum setup/hold
+20.504/+0.498 ns, maximum data delay 12.876 ns; actual path relationships
remain 31.25 ns maximum / zero minimum. No analysis-only exception is added.

Main slow setup/recovery remain −15.149/−8.300 ns; hold/removal +0.194/+0.830 ns.
Across eight corners, reported global minimum hold/removal are +0.080/+0.333 ns,
but setup/hold I/O constraints remain incomplete and MTBF is not calculated.
No timing closure or hardware qualification. Effective-assignment/source/
report/preservation audits pass in `TIMING_FONT_20261016T2302/`; original and
corrected completed builds remain exact. See [the detailed gate](EXTERNAL_FONT_TIMING_STATUS.md).
MiSTer remains with the user and was not accessed. DMA and other revisions
retain their existing qualification status.

October 16 separate `sharpx1_turbo_z_font` base-text candidate:
**build PASS, slow-corner timing FAIL, bounded native hardware PASS**.
Local installed Quartus 17.0.0 build 595 completes map/fit/ASM/STA in 16m11s,
seed 1, 171 stage warnings; 25,228 ALMs, 37,234 registers, 534/553 M10Ks,
32 DSPs/four PLLs. RBF SHA
`4c0a95f2cc91c91df46eff8e3b22577b809fa6247725bd91294c3db1ce300a23`.
The 428-input manifest, generated build ID, reports and QPF/QSF effective
assignment audit pass in `output_files/BASE_TEXT_20261016T1524/build-audit.json`.
Unmodified original SDC, Slow 1100mV 100C: setup −15.031 ns, recovery
−8.167 ns, hold +0.251 ns; this flow does not execute fast-corner analysis
and reports incompletely constrained hold requirements. No timing closure.
Fitted SYS/VID remain 32/42.954545 MHz, not physically measured. Unmodified
base/Turbo arithmetic cold-repeats; base Main R/T reset and LIST/RUN pass
without warm upload/remount. Independent audit checks 21 raw mrext captures
and 245,760 exact pixels, remote payloads/Main/full font DDR. See
[the bounded implementation gate](BASE_TEXT_COMPATIBILITY_STATUS.md).
This changes neither the DMA revision nor other disabled board profiles.

Same-RBF native graphics follow-up: [bounded PSET/LINE](BASIC_NATIVE_GRAPHICS_STATUS.md)
passes five Main-R-boot hardware cases and 15 raw PNGs / 168,960 exact pixels,
including repeats, missing Enter and a one-pixel-wrong control. Independent
audit checks reference logical pixels and retained source/remote/Main/DDR
hashes. No FPGA input, timing constraint or enabled-device change; timing
still fails. Wider native graphics and SAVE/LOAD remain open.

October 15 Main OSD reset follow-up: [both menu commands](Z_FONT_OSD_RESET_STATUS.md)
now pass the bounded external-font hardware gate at 80/40 columns. Six cases
produce eighteen raw PNGs matching **3,840,000 exact control pixels**. Menu
navigation without Enter and two wrong-final-byte controls reject the unchanged
readback oracle. T Reset closes with F12 before R; R Reset-and-close needs no
extra F12. No warm load/upload/mount or keyboard reset chord is requested.
All 127 qualification inputs, 428 compiler inputs, RBF/Main and font DDR hashes
pass. This reuses fd9a0850; no new Quartus or simulation run. Physical owned
phase, stopped clocks, native fonts, wider modes/devices and timing closure
remain open. Earlier checkpoint statements retain their dated scope.

October 15 active-traffic reset follow-up: [owned simulation and Main reset controls](Z_FONT_ACTIVE_RESET_STATUS.md)
pass. Four simulation cases check 34,544 completed CPU reads and 2,688,000
control pixels, including an exactly cancelled pending read and one-commit owned
write drains with DDR/VID service stopped. Three actual MiSTer cases produce
nine PNGs matching **1,920,000 pixels** at 80/40 columns;
Main's keyboard chord recovers retained VRAM after the firmware traffic loop.
No-reset and wrong-final-byte controls reject the unchanged magenta oracle.
The exact physical owned phase is unobserved. RBF/compiler inputs are unchanged;
OSD-menu reset, native fonts, wider modes and timing closure remain open.
Earlier checkpoint statements below retain their dated scope.

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

## October 15 malformed font upload recovery

Separate `sharpx1_turbo_z_font`: **full build PASS, timing FAIL, hardware
recovery PASS (bounded)**. The actual HPS decoder/ACK gate passes full,
oversized, short and gapped uploads/retry plus four exact rejecting controls.
All 39 frontend cases, five machine cases and wrapper lint pass. Ordinary
build/run/test is terminal zero with 164 PASS reports and unchanged executable.

Current RBF `fd9a085061a5fa5f6cc3c929a37f5b266d2391b5dd1b14752f3d8f794db83692`:
Quartus 17.0.2, seed 1, 17m34s/170 warnings; 25,384 ALMs, 37,244 registers,
534/553 M10Ks, 32 DSPs/four PLLs. Frozen 428-input source and remote QPF audits
pass; only the frontend differs from c6. Evidence and RBF are in
`output_files/X1ErrorDrain_20261015T145753Z/rebuild/`.
Original SDC slow setup −14.851 ns/recovery −8.257 ns, fast hold −0.098 ns
at measurement snapshot bit 4. Same-clock SYS/VID setup +8.258/+9.540 ns;
SYS/VID and VID/SYS bundles −10.952/−9.488 ns. No cuts added.
Actual MiSTer valid/oversized-retry/short-retry frames match 640,000 pixels
and full DDR hashes; Main handles the oversized-only case and subsequent load
without a Linux reboot. Physical error/readiness flags are not observed.
[HPS recovery scope](Z_FONT_HPS_UPLOAD_STATUS.md).

## October 15 external-font hardware repair

Separate `sharpx1_turbo_z_font`: **full build PASS, bounded hardware pixels
PASS, timing FAIL**. Initial `52be576d…` physically uploads all 256 KiB but
stalls Main at the terminal SPI ACK. Its disabled evidence is retained. The
frontend repair releases WAIT after the last backend command and separately
guards excess writes. Its 39-case gate includes the old-condition rejection;
the five-case machine CPU/pixel gate and wrapper lint also pass.

Current repaired RBF:
`c6a2ac021173a18fa1f45ac2ea0d9ed8b2a44db1979db1d18de549125afc3880`.
Quartus 17.0.2 full flow, seed 1, 16m14s, 170 warnings; 25,419 ALMs,
37,216 registers, **534/553 M10Ks**, 32 DSPs/four PLLs. All 428 captured
inputs match locally; the remote QPF rewrite is explicitly audited. No other
compiler source differs from the previous snapshot. Original-SDC slow setup
-14.956 ns/recovery -8.277 ns; fast hold -0.084 ns at measurement snapshot
bit 47. No new timing exceptions. Fitted SYS/VID are 32/42.954545 MHz,
not physically measured.

On user-authorized mister14, actual raw mrext captures match all **768,000**
pixels in 80/40-column cold and post-reset-request frames. Native Turbo IPL
also reaches Galaga/Mappy/Xevious titles with the synthetic full font loaded.
Retained-VRAM reset causality, native Kanji, wider native software, physical
signals/audio and timing remain open. See [hardware scope, RBF and evidence](TURBO_Z_EXTERNAL_HARDWARE_STATUS.md).

## October 14 current-source external-font board build

Separate `sharpx1_turbo_z_font` (not the DMA revision): **full build PASS,
timing FAIL, hardware feature UNEXECUTED**. Quartus 17.0.2 Build 602 Lite,
5CSEBA6U23I7, `sys_top`, seed 1. Final compile session `35333` is terminal zero
in `/tmp/x1-z-font-board-syksUXgN` after 24m52s / 170 warnings. Fit: 25,512 ALMs,
37,215 registers, 4,319,336 memory bits, **534/553 M10Ks**, 32 DSPs, 4 PLLs.
Current-source RBF SHA:
`52be576dd7cc74d6009f89bd7f280f47d43ee3cb92cc79d7efdf3a93f093771a`.
[RBF and evidence manifest](../output_files/z-font-20261014-52be576d/manifest.json).

Original-SDC slow 100C setup -14.978 ns / recovery -8.570 ns. Fast -40C hold
-0.045 ns in dimensions-to-SYS measurement bits 59/44. Same-clock SYS/VID setup
+5.548/+7.034 ns is positive, but HDMI data, cache payload bundles, measurement
snapshot and reset-release paths still require qualification. No new timing
exceptions/cuts. Video PLL fits at 945 MHz / 22 (42.954545 MHz), SYS 32 MHz;
not hardware frequency measurements. Source/post-QPF metadata and all 59
retrieved evidence files pass hash review; archive SHA `27dcd377…`.

Complete-machine five-case gate passes 280 actual CPU IN reads, 12,358 commits
and six exact frames / 1,152,000 pixels, including retained and changed-font
rebuilds, owned writer/CPU-read cancellations, upload rejection/retry and three
exact controls. Required ordinary regression and 12 exact generated base/Turbo/
X3 state files pass. Read-only mister14 memory inspection verifies the backing
range outside Linux RAM; active MacPPC7300 is preserved. No new core load,
reset, input or physical DDR test. Native font/broader-mode acceptance remains
open. See [current full status](TURBO_Z_EXTERNAL_MACHINE_STATUS.md).


## Earlier October 14 prototype (superseded by current build above)

The **prototype** `sharpx1_turbo_z_font` full Quartus 17 compile succeeds and
produces an RBF (not the DMA revision). Device 5CSEBA6U23I7, seed 1:
25,740 ALMs, 37,196 registers, 4,319,336 memory bits and **534/553 M10Ks**
(19 spare), 32 DSPs, 4 PLLs. Remote `/tmp/x1-z-font-board-RBcNDcMC`, session
`46389`, terminal zero, 22m37s, 170 flow warnings. RBF SHA-256:
`d454e3153e37ffbec210f09207e84fdda3123aaed51dd6eb60a5ec0ed43bbef5`.
This snapshot precedes the wrapper address guard and ordinary-state alias
repair. The corrected current-source compile in
`/tmp/x1-z-font-board-syksUXgN` (session `35333`) has since passed; the prototype
is not qualification of those repairs.

**Timing gate FAIL / hardware gate UNEXECUTED.** Original SDC, slow 100C:
worst setup -15.250 ns (HDMI data to X3 output), hold -3.469 ns (HDMI),
recovery -8.279 ns (consumer reset release). Reporting-only sidecar also checks
fast -40C. Same-clock SYS/VID setup minima are +7.909/+7.576 ns at slow 100C,
but SYS-to-VID held-cache payload/visible paths have no qualified bundle
constraints (-11.067 ns under the ordinary edge checks), and VID-to-SYS paths report -10.119 ns. These are observed path
classes, not exceptions or CDC acceptance. The fitted PLL is 945 MHz / 22,
approximately 42.954545 MHz; SYS remains 32 MHz. No false paths or clock-group
cuts were added. Native fonts and hardware captures remain open; no MiSTer
connection/load occurred.

All 58 retrieved prototype reports/RBF/clock/path/source-evidence files match
manifest hashes in local temporary `x1-z-font-board-_08vrlhp/evidence`.
Archive SHA `36156552c21baadd675f2da66edfc09db51dfbb3adcf86496b7d030351fa55e8`.
Post-build review verifies 427 inputs unchanged and explicitly checks only
Quartus's generated QPF date/revision metadata rewrite; generated build_id is
hashed separately. Full current scope is in
[external-font machine status](TURBO_Z_EXTERNAL_MACHINE_STATUS.md).


October 14 integration follow-up: the separate default-off
[external-font machine profile](TURBO_Z_EXTERNAL_MACHINE_STATUS.md) now connects
DDR, committed VRAM writes and renderer packets, with owned reset/upload drains
and retained-cache reconstruction. Complete-machine synthetic CPU/80/40-column
pixel gates pass, including CPU VRAM readback and changed-font replacement.
The corrected-source full Quartus build/RBF passes at 534 M10Ks / 25,512 ALMs.
Timing fails and physical feature acceptance remains open.
Native font conversion, broader text policies and physical acceptance stay open.
Earlier standalone-only scope statements below describe those checkpoints.


## October 14 standalone font-cache resource gate

Current cache follow-up: [committed-half qualification](TURBO_Z_CACHE_HALF_STATUS.md)
records the source `e9671fb7…` RAM-inference repair and both source-bound
Quartus 17.0.2 map/fit results: descriptor bit 22 uses 138 M10Ks/3,715 ALMs/
4,314 registers; caller-half mode uses 138 M10Ks/3,717 ALMs/4,327 registers.
Sixty current-source component/CPU cases pass. These are isolated virtual-pin
component fits, with warnings retained; no main-project STA, combined fit,
board RBF or hardware result is added. The initial fit below remains historical.
The later [cached VRAM writer](TURBO_Z_VRAM_WRITE_STATUS.md) passes eighteen
connected CPU/VRAM/cache cases outside all board revisions. No Quartus build
has run for its known-mask/VRAM/cache combination; neither earlier cache fit
establishes its combined area, timing or physical CDC. No new MiSTer result.
The subsequent [cache-renderer adapter](TURBO_Z_CACHE_RENDER_STATUS.md)
passes eighteen unit/connected cases and ten actual CRTC/RGB frames in a
separate simulation fixture. No Quartus build runs for this combination and
no board revision, timing result, RBF or hardware evidence changes.

The separate [full-glyph cache/publication component](TURBO_Z_CACHE_STATUS.md)
completes a source-bound Quartus 17.0.2 standalone fit on `misterubuntu`:
138 M10Ks, 3,720 ALMs and 4,318 registers. This is a virtual-pin component
probe, outside the machine manifest and all board revisions. No main-project
flow, STA/CDC closure, board RBF or MiSTer deployment is performed for it.
The existing DMA revision and hardware-qualified RBF are unchanged. Cache
integration, source-bound board fitting/timing and physical gates remain open.
Subsequent standalone [font service/lifecycle components](TURBO_Z_FONT_SERVICE_STATUS.md)
pass 35 strict simulation/fault runs with the unchanged cache/frontend/backend.
They have no new combined fit, board RBF, timing/CDC or hardware result; every
board profile remains unchanged.
The subsequent [real-CPU service boundary](TURBO_Z_CPU_SERVICE_STATUS.md)
passes its connected component fixture only. It adds no board fit, timing/CDC,
RBF or hardware result and does not alter the qualified DMA revision.

## October 10 current-source build gate

Latest follow-up: the frozen `aa05dd2f7bbedc2491f2de9eeb72624002dd3e4a`
handoff revision starts on the idle host at 10:35:07 UTC and finishes at
10:43:50 UTC, **exit 3**. Synthesis, fitting and assembly finish; the agent's
terminal report records 20,596 ALMs, 34,009 registers and 393 RAM blocks.
Final STA refuses `completed_generation~DUPLICATE` as an unreviewed source
replica before loading the held/inactive constraints. The partial setup/hold
numbers (-21.246/-15.799 ns) are therefore **not** a completed constrained
audit. No timing guard is broadened and no hardware deployment is performed.
The unaccepted RBF SHA-256 is
`7461c9454ace92c6708c5a4f7fe779805a8493e4df5ac6fe10ed3441f308ff09`.
Frozen source root is
`output_files/quartus-linux-I30pZ0zU/source` on the build host; input-manifest
SHA-256 is
`f4d50a76350604f5ce2aa33814486b5d0acfbfd08c0ba4abc2c1fab441245fc1`.
The agent reports all 410 checkout inputs match that manifest, with only
generated QPF rewriting in the snapshot. Reporting-only fitted replica
inspection and independent artifact review remain follow-up gates; this build
does not contain the subsequent experimental wide-D88 changes.

The latest guarded idle-host check permits a fresh Quartus 17.0.2 full flow
at 08:02:29 UTC, source `3c6242e771446dc11843cc8f4b7d4c58430b8f17`.
This is the separate `sharpx1_turbo_z_handoff` revision, **not** a rebuild or
new qualification of the DMA single-clock revision below. Frozen remote root:
`/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-VlAoOluh/source`;
input-manifest SHA-256:
`5643c4693d104110957118b0b62b93ccb13fcd1b836d7434a61bec9a5a841219`.
Launcher PID 1836585/session 39592 and live synthesis/fitting were observed;
local log `/tmp/x1-quartus-3c6242e-handoff-local.XhSvnjgI`. The full flow now
terminates **exit 3** at 08:15:43 UTC: final STA rejects an unreviewed
whole-prefetch D/ASDATA profile. Fitting precedes this failure; the guard is
not loosened and there is no full-flow timing or hardware acceptance.
The terminal source/artifact audit completes: all 408 checkout inputs match
the frozen manifest; only generated QPF metadata/revision differ in the build
snapshot. Direct fitted-summary readback confirms 20,605 ALMs and 393 RAM
blocks. The unaccepted RBF SHA-256 is
`7f6a2009cbebe2caa34fec785bd39a19da0ba58e4f970f2ca80b9f0384d5a993`.
Partial STA setup/hold is -10.317/-2.636 ns, not a completed constrained audit.
Native fitted-profile discovery remains pending because other actual fitters
occupy the host; no guard is broadened or failed artifact deployed.
The C++ RTC/X3/Kanji profile
does not enable those devices in this board revision. Older outputs and
other cores/media are preserved; no MiSTer is loaded or reset.

## Earlier DMA source-bound qualification

October 8, 2026. `sharpx1_turbo_dma_single` is a separate opt-in FPGA revision,
inheriting `sharpx1_turbo_single` and enabling the existing shared-machine DMA,
completion IRQ and EOB-only restart IRQ. SYS/video use the checked-in actual
28,571,428 Hz PLL output and enables. Existing revisions remain DMA-disabled.
This is not full DMA, native Turbo firmware or Turbo Z support.

The wrapper passes the three capability parameters together under
`X1_TURBO_DMA_RESTART`. Invalid combinations without single-clock Turbo
foundation, or with X3 video, are rejected. No framework, clock constraints,
private assets, device engine, reset drain or interrupt bridge are changed.
The Linux and Apple-container build helpers accept this revision explicitly.

Both baseline and DMA-profile wrapper lint pass (Verilator 5.044); inherited
framework warnings remain, log `/tmp/x1-dma-board-wrapper-lint.log`. Shell
syntax checks pass. The native Quartus 17.0.2 full flow completed from frozen
commit `818b0de28e6a3331e3894fd0313369bad618e534`, in build-host directory
`output_files/quartus-linux-mlCE5xen/`. Input-manifest SHA-256 is
`0ea6cc295cca21472203cb1a08cf8e56ebd66c8d3fc4dfd3ec68700c7ba00d99`.
Build started 00:23:55 UTC October 9 and finished 00:31:08 UTC, exit zero,
123 warnings. Fit uses 20,947 ALMs (50%), 394 RAM blocks (71%), 3,143,582
memory bits. Its hierarchy report retains the DMA engine/service, IRQ bridge
and reset guard. Quartus warns that reset-guard `pending` powers
up high despite the RTL initializer (`18061`/`18010`). Do not suppress this or
claim cold-start equivalence from the RTL initializer; physical startup/reset
must be qualified. Inherited framework mode-array/CDC warnings remain too.

The shared-machine clock-matched simulator previously passed six memory and
twelve A/B FDC restart cases; see [exact scope](DMA_RESTART_MACHINE_STATUS.md).
That is not fitted or hardware evidence. The dedicated wrapper lint target
uses the same PLL interface stand-in as the other wrapper checks.

```sh
make -C verilator lint-wrapper-turbo-dma
ssh misterubuntu 'cd /home/alans/mister/SharpX1_Mister && QUARTUS_REVISION=sharpx1_turbo_dma_single bash scripts/build_quartus_linux.sh --check'
# Only after checking for competing Quartus jobs:
ssh misterubuntu 'cd /home/alans/mister/SharpX1_Mister && QUARTUS_REVISION=sharpx1_turbo_dma_single bash scripts/build_quartus_linux.sh --build'
```

The candidate is locally available at
[sharpx1_turbo_dma_single.rbf](../output_files/quartus-linux-mlCE5xen/sharpx1_turbo_dma_single.rbf),
SHA-256 `c1d83e6bc7218a5736d3c8cf4505cc3eb69d4c75c4ca958a5106f3c698bc8ca3`.
Supplemental all-corner STA and path reports each exit zero, with RBF hash
unchanged. Every local input matches the original 359-file manifest.
Post-build snapshot verification intentionally reports a mismatch for
`sharpx1.qpf`: Quartus added notices/date and the requested revision, preserving
the original revision. All other 358 inputs, including RTL/QSF/SDC/assets,
match. The failed checksum command remains recorded, not rewritten as a pass.
Generated QPF SHA-256 is
`c7c997185f5007e626d8fa70fa8ebac07a56b6f622f43194e262f37a2adac4a5`.

| All eight models, constrained checks | Worst slack (ns) |
|---|---:|
| Setup | 0.649 |
| Hold | 0.052 |
| Recovery | 4.153 |
| Removal | 0.434 |
| Minimum pulse width | 1.122 |

Zero unconstrained clocks, but 3 input ports / 7 input paths and 44 output
ports / 50 output paths remain unconstrained. No global clock cuts or timing
constraint changes were made. Inherited CDC/PLL/external-I/O and physical
qualification are not closed by these positive numbers. Original STA reports
are preserved before supplemental analysis. Local ignored reports/logs are
under `output_files/quartus-linux-mlCE5xen/`.

Actual CPU-driven hardware diagnostics need visible RGB success/failure markers: the existing
RAM-completion-only simulation fixtures do not prove hardware success from a
black screen. Protected disposable A/B media, restart/RETI, native boot/input,
owned/pending-SD reset and broader video/audio must be tested separately.
Do not contact or use reserved mister192. The recommended previously qualified
experimental RBF remains `quartus-linux-ZOMREvtv/sharpx1_turbo_single.rbf`.

## Visible CPU diagnostics

`test_dma_visible_ipl.py` now emits eighteen original, 32 KiB IPLs based on
the existing memory/A/B restart programs. A real CPU prologue programs PPI,
40-column CRTC and palette/VRAM. Pending/failure stays red; green is published
only after the original buffered-address/payload/guard/status and three-handler
assertions. GRAM power-up data cannot affect the uniform palette marker.
No machine debug writes, forced IRQ/grants or private assets are used.
The six default memory and twelve default FDC fixture byte streams are unchanged.

All eighteen pass the board-matched 28,571,428 Hz fast runner
`3058ff48dce8da0527ffc8afe7a21b47c584a0871c473f5b3c121ee673e67004`:
exact CPU completion/counts, unchanged generated disk images and 1,152,000
green pixels. The completion-only control stays red with zero pairs. The
earlier isolated first-destination-buffer bug control produces CPU `EE` after
eight pairs and all 64,000 red pixels; production RTL is untouched.
Outputs: ignored `output_files/dma-visible-818b0de/`; logs
`/tmp/x1-dma-visible-ipl.log`, `/tmp/x1-dma-visible-bug-negative.log`.
The separate SYS32/video28,571,428 Hz delay-aware visible matrix also completes
all eighteen cases, checking another 1,152,000 green pixels and the same CPU
counts/guards/status/unchanged disks. Its frozen executable SHA-256 is
`a8601ef7abbdee9871fd706a426a060e819966420d85f16e5bd48bbbc036d287`;
outputs `output_files/dma-visible-timing-818b0de/`, log
`/tmp/x1-dma-visible-ipl-timing.log`. This is independent-clock simulation,
not board-frequency delay-aware or physical acceptance.

```sh
make -C verilator test-machine-dma-restart-visible
```

`scripts/mister_dma_matrix.py` stages unique MGLs/configs, verifies RBF/IPL/disk
hashes, accepts only mister126/mister14 and defaults to no core loading.
`--execute` loads each test and records actual PNGs, requiring exact 320×200
green pixels and unchanged disposable disks. It refuses incomplete local
fixture qualification. The hardware matrix completed on released
mister126 in `/media/fat/_Computer/X1DMA_20261009T003346Z/`, with local evidence
under ignored `output_files/X1DMA_20261009T003346Z/`. All eighteen cases pass:
six memory and twelve A/B sector-boundary restart programs, all three bus modes
and both programmed transfer directions. Each captured PNG is exactly 320×200
green; all 1,152,000 captured pixels match. Disposable generated A/B image hashes
remain unchanged after every case. Log `/tmp/x1-dma-hardware-matrix.log`.

The actual CPU program verifies payload/buffer isolation/guards, DMA/FDC status,
live-counter readback and three genuine IM2 handlers followed by RETI before
publishing green. Hardware grant/pair counts and exact bus/IRQ pin timing were
not independently instrumented: those quantities remain simulation evidence.
These are cold MGL/core/IPL loads, not power-cycle/physical-keyboard, concurrent
interrupt, OSD-reset/owned-SD drain, writable-media or native Turbo acceptance.
The recommended general native-game test RBF remains the DMA-disabled artifact;
this is a separately qualified bounded DMA diagnostic candidate.

The same first memory IPL also runs on the earlier DMA-disabled RBF
`a0a03761…` as an independent hardware negative. Its captured 320×200 PNG is
exactly red, not success; generated disks stay unchanged. Evidence:
`output_files/X1DMA_20261009T004022Z/`, log
`/tmp/x1-dma-hardware-disabled.log`. This does not measure hardware pair counts
or identify every possible red-screen cause. `--disabled-control` runs only
that case and explicitly expects red; the normal matrix still requires green.

The native matrix helper now accepts explicit RBF path/hash and an optional
single-title selector; its earlier defaults and observation-only verdict stay
unchanged. A protected CROSS Chase trial on the DMA candidate completes:
native title at 30 seconds, then keyboard input reaches "Press key" and a
populated playfield. Actual PNGs were inspected, not inferred from filenames.
Evidence `output_files/X1Matrix_20261009T004105Z/`, log
`/tmp/x1-dma-native-cross-hardware.log`; copied disk/ROM hashes stay unchanged.
This is native boot/input progression, not exact movement, game music, long
compatibility, physical keyboard or native Turbo firmware acceptance. No five
commercial games are newly qualified by this single homebrew trial.
## October 10 fitted-profile follow-up

The subsequent source repairs remove the raw-reset bypass into palette
selection D inputs and add an opt-in two-stage HDMI measurement synchronizer.
Their local tests pass; see `HDMI_MEASUREMENT_CDC_STATUS.md`. These do not
alter the completed fifth-fit audit or qualify this DMA revision/new RBF.
The fresh source-bound `aa05dd2` handoff build's initial 10:30:32-UTC check
finds active DSPPC604 shell/fitter PIDs 2001830/2002631. No flow is launched
or competitor disturbed at that check; native follow-up remains pending.

The separately fitted `3c6242e` Z-handoff full flow's fifth physical HDMI
profile now passes native reporting-only discovery and independent original
artifact/source preservation auditing. The experimental guard recognizes
only that complete observed pattern; five scoped positives, 100 invalid
scope controls and 16,379 mixed-pattern rejections pass locally. See
[exact evidence and remaining gates](HDMI_MODE_STATUS.md#fifth-fitted-profile-discovery-and-guarded-scope-complete).
This does not qualify the DMA board or a new RBF: same-fit preservation,
full-flow constrained timing and hardware remain open. No MiSTer is loaded.

The new `--fit-3c6242e` auditor separately binds all eleven original/staged
hashes and the exact pin profile. Its synthetic 384-report/preservation and
36 provenance/actual-source rejecting checks pass alongside historical gates.
The native same-fit attempt at 09:33:45 UTC is not launched because another
project's actual synthesis is active; no native result comes from that attempt.

The subsequent idle-host same-fit run finishes at 10:06:42 UTC, zero errors/
warnings. Independent exact-source/artifact auditing passes 384 reports,
928 held-budget and 6,624 active/raw/mode rows unchanged; 848 inactive rows
remain excluded, not passed. Global setup **still fails at -9.659 ns**
(hold +0.010 ns). See the native fifth-profile evidence in
`HDMI_MODE_STATUS.md`. This does not qualify this DMA board, a fresh full
flow or any new RBF. Original artifacts are preserved; no MiSTer is loaded.

The exact `9cc1141` fit's reporting-only whole-bank inventory subsequently
finishes on the idle host at 16:19:39–16:19:43 UTC, exit zero, no errors/warnings.
It uses an isolated fitted database and no SDC, not a compile or timing pass.
Local evidence: `/tmp/x1-9cc-prefetch-inventory-N9cG4eJw/`; raw log SHA-256
`4c7f6fbd6d356f18fe57c0e242b683b33fafd28ef0e54ac171f98857fb015942`.
Main independently checks the terminal record and exact before/after manifests:
415 source inputs, five artifacts and 511 original database files are unchanged.

The whole prefetch bank has 24 keepers, 72 pins and 24 canonical registered
drivers. Its complete observed input vector is:

- ASDATA: `hs`, `vs`, `de`, data bits 0/1/5/7/12/16/17/19/23.
- D: data bits 2/3/6/9/10/11/13/14/15/18/21/22.
- Physical prefetch keepers absent: data bits 4/8/20; output aliases remain
  4←0, 8←12, 20←16.

The output bank has 27 keepers/133 pins/85 driver records; no target replicas
appear. This vector differs from the six allowed profiles and is not permission
to mix arbitrary per-bit alternatives. The exact seventh-bank proposal now
passes all seven complete profile vectors, 140 fault checks and all 1,048,569
mixed-profile rejections before any cut. Original Tcl session exits zero;
log `/tmp/x1-hdmi-inactive-data-seven-profile.log`, SHA-256
`a285e6d53adadf922c893cafd7bed52d353ac59db1aef393365377a3152452e2`.
Candidate `b80a0946ca3b310f8e87254f587c26d9414292df24ddf247fd283cc1ab2dd6ad`
and fixture `2cc95faf7eb8d585abee11b27e08e27063cce9c4c4462c3f6e3fc69abaf70064`
remain unchanged afterward. The log creation-to-final-write span is 3,563
seconds, not a separately timed process measurement. No cases are removed.

The exact eleven-file/384-report context auditor passes synthetic preservation
and rejecting controls, but that is not native TimeQuest acceptance. Native
same-fit launch is deferred at 17:33:10 UTC because PID 2352689 is fitting
SunSparcStation20; no competing job is launched. The prepared isolated study
rejects escaping/database symlinks and preserves originals. Same-fit path
preservation remains next. Strict production constraints are unchanged;
complete constrained timing, a fresh full flow and hardware acceptance remain
open. The assembled `9cc1141` RBF is still unaccepted and not deployed.
