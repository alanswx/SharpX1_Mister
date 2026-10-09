# Sharp X1 core bring-up TODO

This list is based on the current RTL, the existing Verilator harness, and
cross-checking against the local MAME Sharp X1 driver. X Millennium is now
downloaded and its Turbo control code inspected; an isolated declaration-fixed
libretro build now executes Arcus. Original phase coalescing progresses to
garbled scenes; an isolated pending-retention control repeats the black handler
state. Neither establishes gameplay or the physical chip contract.
See `CORE_STATUS.md` for confirmed device and wiring gaps.
See [the implementation and test plan](IMPLEMENTATION_PLAN.md) for dependency
ordering, test coverage, and acceptance gates. These checklist phases are broad
work buckets; the plan gives the execution order, including base-X1 floppy
support before optional Turbo extensions.

## Active goal: items 1–6 and Turbo Z (October 6)

The [DMA-build hardware feature matrix](HARDWARE_DMA_FEATURE_MATRIX_STATUS.md)
records six exact 40/80-column graphics/text/PCG cases before and after warm
reset on the separately fitted DMA revision, six native reset/input observations
and both bounded actual OSD reset entries. Full-device, native-gameplay,
writable/owned-SD reset, audio/physical-input and Turbo Z gates remain open.

The [Turbo Z palette storage foundation](TURBO_Z_PALETTE_STORAGE_STATUS.md)
now passes nine independent-clock/accepted-enable profiles, each exhausting
4096 addresses, three components and sixteen nibble values. It is standalone:
native ASIC registers, arbitration, renderer integration and fitted/hardware
palette qualification remain open; Z2 and the Turbo Z work group are not done.

The [Turbo DIP increment](TURBO_DIP_STATUS.md) now supplies configurable
`1FFx` readback. Exhaustive decoder checks and fast real-CPU cold/warm F1
checks pass; a repeated native two-second probe confirms F1 reads but no FDC
transaction in its initial trace. Complete longer native boot diagnosis,
configuration-bound snapshots, other clock/profile checks and source-bound
Quartus/hardware acceptance before treating boot-device selection as closed.
The longer F1 native probe repeats the disk-read error and executes a DMA
setup while that renderer profile has DMA disabled. The separate
[X3/DMA follow-up](DMA_X3_NATIVE_STATUS.md) passes both complete generated
transfer matrices and fast cold/warm native-command-shape diagnostics;
Its partial FDC-transfer X3 snapshot now passes exact continuation and clock-
profile rejection. Native gameplay, combined Kanji ownership and hardware
remain open; the rejected old-runner dual-drive native-state
attempt is retained rather than bypassed.
The subsequent [two-drive snapshot increment](DUAL_SNAPSHOT_STATUS.md)
passes original protected A/B continuation and media/profile rejection,
plus committed writable A-first/B-first checkpoints with exact exported-media
continuation and protection overrides. A native sixteen-second Arcus checkpoint
resumes to 32 seconds with all five RAM/CPU dumps matching fresh execution;
the actual final frame remains black, not gameplay. Owned-host/interrupted-write
snapshots and hardware remain open.
The [active renderer observation](VIDEO_OBSERVATION_STATUS.md) narrows Arcus's
black output to selected white PCG text masked by blackclip, with varied
graphics underneath; local X Millennium agrees on mask-after-priority behavior.
Do not change that behavior merely to expose graphics. Investigate native PCG
programming and interrupt/input progression. CRTC/PCG/sample diagnostics pass
base delay-aware and X3 fast/delay-aware; exploratory Enter/Space continuation
to 50 seconds still gives a black actual frame, not gameplay.
The [interrupt-progression follow-up](ARCUS_INTERRUPT_STATUS.md) observes
only handler opcode fetches during a native 100 ms continuation. Existing
local MAME now executes with matching supplied ROMs and reaches the same
black-screen handler state. Two X Millennium cold runs progress further, but
two separate pending-retention controls repeat the same black handler state;
this isolates its phase-coalescing policy's effect, not hardware correctness.
Resolve that contract with stronger evidence; do not simply slow its clock.

The user requested completing the six remaining work groups below and Turbo Z. None is
declared finished by the standalone SIO increments. Execute local gates in
order, retain original regression failures/evidence, and push verified
checkpoints. Physical acceptance requires MiSTer. October 8: the user released
mister126/mister14 and the misterubuntu build host, keeping mister192 reserved.
The [initial mister126 matrix](HARDWARE_126_STATUS.md) records native game-start,
bounded OSD reset and a fresh single-clock all-corner fit; broader hardware and
optional-device gates remain open.
The [current-RBF/video matrix](HARDWARE_VIDEO_MATRIX_STATUS.md) now adds six
native-title observations, Shanghai's tile board, exact hardware RGB matching
for six original 40/80-column text/graphics/PCG IPLs, and a retained-IPL PCG
warm reset. Commercial controls/audio, optional devices and broader reset/disk
qualification remain open.
The [native B follow-up](NATIVE_DRIVE_B_STATUS.md) now observes a real drive-1
selection and protected CROSS Chase boot on mister126, with failed short/late
input trials preserved. An actual-board-frequency simulator profile and its
asset-free keyboard/mailbox/generated A/B matrix pass; B writes/disk sets and
broader native/hardware acceptance remain open.
The cached Apple-container Quartus 17 runtime and installation are available
locally (rechecked October 6); use frozen-source
builds and record synthesis, fit and timing separately.

| Work group | Execution/acceptance still needed |
|---|---|
| 1. SIO | Owned serial read/write reset drain, idle Send Break and 12 actual-CPU stopped-CE ACK/handler/FIFO/RETI chip-reset cases pass separately; add channel/short-pulse and concurrent multi-device reset service; trace schematic clocks/modem/Ready/decode before opt-in shared-machine integration; finish remaining modes and native serial diagnostics |
| 2. DMA | Reset/video/restart/comparison, search/stop and actual-CPU fast/delay-aware profiles pass; opt-in completion/restart IRQ has shared-machine IM2/HALT/RETI and snapshot acceptance; broaden concurrent-service/reset/savable gates, integrate Ready/mixed restart IRQ and variable timing, resolve sequential non-Byte stop; broaden payload/Ready/DAM/native Turbo IPL and hardware acceptance |
| 3. Kanji/Turbo video | CPU latch/ROM/glyph paths with synthetic fixtures, then authorized native fonts; complete attribute/PCG/text combinations, ASIC behavior and native Turbo/400-line software |
| 4. Timing/hardware | Narrow audited CDC/reset/mux constraints, current-source Quartus refit and positive setup/hold/recovery; hardware bandwidth/video/audio and Main/OSD reset verification |
| 5. Disk/software | Format/density/HD/media-change contracts; native metadata qualification; Arcus/Bastard playability; delay-aware and hardware game matrix |
| 6. Base completeness/CI | Asset-free diagnostic CI now passes hosted execution; finish keyboard/sub-CPU, cassette and PPI functions; exact PCG/scanline/audio fidelity; BASIC compatibility and provenance |
| 7. Turbo Z | RGB12 output/capture foundation passes exhaustive capture/wrapper and snapshot checks; implement/qualify Z0–Z9 model, palette/multi-mode, text, FM, HD, Kanji/devices, capture and native/hardware gates |

No legacy notices or private assets may be removed/bundled to claim completion.
The new standalone [DMA service engine](DMA_SERVICE_STATUS.md) passes 4,096
arbitration and 2,048 status-vector cases, plus twelve connected CPU/DMA
completion/IM2/RETI profiles. Native
interrupt-control programming, IOR/Ready, restart service and shared-machine
IRQ integration remain required; the machine still rejects IRQ configuration.
The subsequent [DMA completion command path](DMA_COMMAND_IRQ_STATUS.md)
passes 36,864 real-register cases and twelve actual-CPU WR4/vector/RR0/RETI
profiles, plus owned-pair stopped-CE/WAIT resets. It is device-only and opt-in;
Ready/restart IRQ and shared-machine priority/ACK integration remain open.
The [shared-machine completion increment](DMA_IRQ_MACHINE_STATUS.md) now
connects that opt-in path: connected DMA/CTC priority/nested RETI tests and
four actual shared-CPU IM2/HALT/RR0 profiles pass on fast/delay-aware builds.
Subsequent reset guard, real shared-CPU DMA-over-CTC/queued CTC nesting and
native handler-service snapshots with cross-profile rejection now pass.
Real CPU/MR16 three-device pending now passes fast/delay-aware cold repeats,
with ordered keyboard make/break and a failing priority-bypass negative control.
Broader concurrent service/reset, native firmware, Ready/restart IRQ and
hardware gates remain required; no work group is marked complete.
The device-only [Ready/IOR increment](DMA_READY_IRQ_STATUS.md) adds a separate
`READY_IRQ=1` profile with independent IOR/IP/IUS, B7 release and real CPU
handler/transfer checks. Existing machine profiles remain Ready-disabled;
Byte/Burst owned WAIT-held and delayed-grant transitions now retain service
without aborting a pair; Continuous suppression, AF/AB and exact resumed
data pass directed tests. Broader live/late-arm timing, restart, integration
and native/hardware gates remain. Primary auto-restart/EOB prose requires an
independent terminal event with clear EOB status; see the same status document.
The subsequent [restart-EOB IRQ profile](DMA_RESTART_IRQ_STATUS.md) now retains
that event separately: 4,608 register cases and three real-CPU two-block
IM2/ACK/RETI cases pass. Owned/stopped-CE resets and the EOB-trigger negative
control are covered. Mixed Ready/match restart, native/machine integration and
physical qualification remain required; no work group is marked complete.
The [reload-buffer follow-up](DMA_RELOAD_BUFFER_STATUS.md) fixes an actual
post-auto-reload first-destination redirection bug. Both-direction, three-block
buffer updates and delayed actual BUSACK release now pass device tests;
DMA serialized state advances independently to revision 7. Mixed causes and
native/hardware/shared-machine restart service remain open.
The [real-CPU handler matrix](DMA_HANDLER_BUFFER_STATUS.md) now adds eighteen
both-direction Byte/Burst/Continuous buffered profiles at CE=1/4/7: three real
blocks/IM2 handlers/RETIs, CPU payload/guard checks and observed address separation.
The [executing reload-seam snapshot](DMA_RELOAD_SNAPSHOT_STATUS.md) now passes
both-direction non-IRQ shared-machine continuation and a failing original-bug
control. Restart-handler snapshots and mixed/native/hardware service remain open.
The subsequent [shared restart-service profile](DMA_RESTART_MACHINE_STATUS.md)
now passes executing-handler/pre-ACK snapshots with profile rejection, actual
CPU buffered-address service in all three modes/both directions, and twelve
A/B sector-boundary DRQ cases on both timing models; the clock-matched fast
board profile also passes all eighteen memory/FDC cases. Ready/mixed causes,
restart-specific concurrent/reset/owned-SD snapshots, native and hardware
qualification remain open; no work group is marked complete.
The [DMA board qualification revision](DMA_BOARD_BUILD_STATUS.md) now passes
the explicit completion/restart capabilities through the single-clock wrapper;
existing board revisions remain DMA-disabled.
The subsequent `818b0de` fit now passes all eight constrained corners, and
eighteen generated memory/A/B restart programs pass CPU-driven actual RGB
checks on mister126. Exact physical timing/count instrumentation, concurrent/
reset/writable/native gates remain open; this does not complete DMA or Turbo Z.
The [Kanji contract audit](KANJI_CONTRACT_STATUS.md) now derives a tested
first-level physical ROM address decoder from the model-20/30 schematic,
covering all 131,072 bytes. Its connected standalone 128 KiB dual-clock ROM
storage now passes exhaustive synthetic reads, exact ordered uploads, malformed
stream rejection and retained warm/short-reset checks at three clock ratios.
The subsequent explicit `TURBO_KANJI` profile connects storage to shared-machine
index-5 loading and CPU high-speed CG access; renderer/ASIC selection, native
assets and Z storage remain required.
Static inspection of a published hardware monitor now identifies a native
high-speed `1400..140F` Kanji read sequence through selector-cell writes.
The [optional CG selector output](KANJI_CONTRACT_STATUS.md#hardware-monitor-establishes-a-separate-high-speed-cg-access-sequence)
passes 524,352 synthetic cases with default isolation and level-2 rejection;
shared-machine ROM/ACK/WAIT/loader integration and native execution remain required.
It does not resolve the independent `0E80..83` protocol conflicts.
The subsequent [connected ROM/WAIT backend](KANJI_CG_ACCESS_STATUS.md) passes
exhaustive reads at three ratios, delayed-valid/window/clock/reset cases and
a failing validity-bypass negative control. Six actual-CPU IN/INI profiles
pass cold/warm connected selector/ROM qualification. The opt-in shared-machine
loader/profile now executes original CPU INI checks across all banks/halves
on fast/delay-aware cold/warm runs. An executing CPU snapshot resumes with
exact final dumps, additive sync counts and bidirectional profile rejection.
The nominal X3 fast/delay-aware matrix and same-clock default/X3 opt-in
snapshot isolation also pass. Five whole-machine pending-read reset profiles
pass, including short pulses, stopped clocks and CPU-programmed closed HSYNC;
an asynchronous-cancellation negative control fails as expected.
Nine shared-loader rejection/recovery profiles now pass: real CPU FF reads
after malformed uploads, fresh pattern recovery and native pending-read reset
without reloading the recovered ROM; an orphan-strobe-gating negative control
fails as expected. Hosted CI through `191009a` is green;
the subsequent loader target requires its own completed hosted run.
Native assets, broader clock/reset coverage and rendering remain required.
The supplied model-40 Kanji members now match pinned MAME hashes; the explicit
converter passes every address against an independent interleave oracle. A
private inferred candidate passes bounded X3 fast/delay-aware CPU cold/warm
reads, not rendered glyphs or a hardware-chip identity claim. Supplied Z Kanji files are 306,176-byte
tool exports with an arbitrary second-level filename, not raw ROM images;
retain strict physical-loader size rejection and qualify conversion separately.
The standalone first-level glyph-source decoder now passes 4,194,304 pin
combinations/all 131,072 physical bytes; the schematic and local X Millennium
agree on PCG-over-Kanji priority, unlike MAME's renderer. A priority-bypass
negative control fails. Shared rendering, upstream enable/raster phase and
native pixel checks remain required; defaults and the recommended RBF are unchanged.
The separate [Kanji rendering experiment](KANJI_RENDER_STATUS.md) now connects
physical ROM pixels under a provisional X Millennium row policy. Ten-case
40/80-column, low/high-scan, loaded/missing-ROM and retained warm-reset matrices
pass fast/delay-aware (1,536,000 checked pixels each); the private inferred
model-40 candidate passes fast rendering. Actual RGB snapshot continuity and
CPU-only/render profile rejection pass. The full attribute cross-product, ASIC/native
software, Z second-level storage and hardware gates remain open.
The subsequent fourteen-case mixed-source matrix passes fast/delay-aware
actual pixels: real CPU PCG initialization/readback, PCG-with-K7 priority,
ANK/Kanji/absent-level-2 adjacency, all colors/reverse, 40/80 columns, both
scan rates, warm reset, paired-PCG/Kanji exits and four expansion/underline
policies. Each matrix checks 2,101,760 pixels. Per-cell width/height, blinking,
the remaining attribute/row cross-product and simultaneous ROM selection
remain required. Native Arcus with the supplied Turbo IPL still ends at the
FD0 search screen in two repeatable eight-second runs with unchanged assets,
not accepted gameplay, native glyph rendering or a proven missing-chip diagnosis.
The [current-source Quartus retry](CURRENT_SOURCE_QUARTUS_STATUS.md) records
the preserved parse failure and explicit-generate fix. Local default/native
DMA and actual-CPU IRQ regressions pass. The new single-clock frozen build now
completes fit/assembly and all eight constrained timing corners, with unchanged
artifact/input hashes and 49% ALMs. It is the recommended experimental test
RBF, not physical/full timing acceptance or a passing X3 build. The
[tester handoff](TESTER_HANDOFF.md) covers cold keyboard, disks and both Main/
OSD reset commands; no work group is marked complete from this build.
Turbo Z is now explicitly part of the requested goal. Its Z0–Z9 milestones
and acceptance gates are tracked in [TURBO_Z_PLAN.md](TURBO_Z_PLAN.md).
It remains a separate capability profile; progress must not imply support
for unimplemented hardware or promotion of historical game evidence.
The RGB12 port advances simulator states to v12. Fresh baseline Xevious,
Druaga, Mappy, Galaga and Shanghai gameplay qualifications and the full
delay-aware baseline suite exit zero. The standalone [FM foundation](TURBO_Z_FM_STATUS.md)
passes bus/timer/stereo/mixer checks at three master frequencies, but is not
connected to the machine. The expanded 21-target hosted retry passes on
`abda8ee`, using pinned Verilator 5.044 after 5.020 exceeds the DMA compilation
limit even with Clang. No RTL assertions or simulated durations were reduced.
A later [22-target run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37515820620)
passes on `421f5c9`, including actual CPU/FM. The [23-target run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37522951169)
passes on `c621133`, including twelve SIO IRQ-reset cases. The newer DMA
automatic-restart matrix is locally qualified and the
[subsequent 23-target run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37529441225)
passes on `d203dd5`. The
[24-target comparison run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37531002075)
passes on `b893582`. The
[24-target Byte-stop run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37531976718)
passes on `4261ee6`. The
[25-target pure-Byte-search run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37533028668)
passes on `1f692b3`. The
[25-target search-restart run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37533835690)
passes on `b890f93`. The
[25-target non-Byte-search run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37535229239)
passes on `953c076`. The
[25-target match-pipeline run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37536491304)
passes on `78888a7`. The
[27-target service/vector run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37537567836)
passes on `6151c0b`. The
[29-target native-command run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37539251783)
passes on `2bb779a`. The
[31-target shared-completion run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37540523729)
passes on `a666232`. The
[33-target reset/nesting/snapshot run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37541237934)
passes on `b048041`. The
[35-target keyboard/address run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37542263824)
passes on `328d58c`. Later Kanji hosted gates remain separate.
See [source-bound checks](TURBO_Z_RGB_STATUS.md).

## Current priorities 1–4 (October 5 checkpoint)

These are acceptance gates, not four completed checkboxes.

| Priority | Confirmed increment | Still required |
|---|---|---|
| 1. Turbo video | X3 enables/raster mapping/16-row ANK; bounded high-speed PCG selector, frozen HSYNC-window transactions and CPU ANK8/16 selection pass focused simulation; HPS snapshot seam and X3 PPI level crossing tested, including real-CPU cold/warm polling | Route/timing/CDC/reset signoff and refit; exact ASIC selector/WAIT phase, text expansion/underline, Kanji CPU/glyph paths and native/hardware acceptance |
| 2. Native games | Five v11 baseline titles pass, including Galaga firing and Shanghai pair removal using native cursor feedback; old timed-replay failure preserved | Native Arcus/Bastard playability, Turbo firmware/video and multi-disk continuity; polling-phase diagnosis, delay-aware and hardware gameplay (Arcus A1/B2 remains exploratory) |
| 3. CTC/DMA/SIO | CTC/IM2/ACK/keyboard; standalone DMA and actual CPU/DMA tests; opt-in shared-machine bus/FDC DRQ, generated A/B transfer/count/protection/CRC, owned/pending-SD reset and bounded GRAM/PCG tests; standalone SIO formats/FIFO/collisions, first/all-RX/TX/CTS/DCD IRQ and actual-CPU IM2 pass | DMA native/partial-metadata/short-reset/DAM/IRQ/search/exact timing acceptance; SIO native reset arming/remaining external sources/x1/break/live configuration/machine integration; physical daisy-chain timing |
| 4. D88 robustness | Bounds/A/B ACK/eject/protected writes; CRC/READ ADDRESS; 75 metadata/short-reset direct groups and both complete frozen fast/delay-aware CPU matrices; five v11 native-control titles pass | Broader native metadata/disk-change qualification; safe format contract, density/HD mechanics, physical HPS epochs |

Turbo Z is a separate planned profile, not implied by these increments. Its
manual-based feature/acceptance breakdown is in [TURBO_Z_PLAN.md](TURBO_Z_PLAN.md)
and Phase 5 below. New X3 hardware artifacts currently fail timing; do not
replace the previous timing-positive experimental RBF without a reviewed fit.
The [Turbo II manual acceptance matrix](TURBO_IMPLEMENTATION_PLAN.md#primary-turbo-ii-textvideo-acceptance-contract)
adds the documented row/scan combinations, underline graphics suppression
and expansion placement gates; these are not yet completed behavior.
The original [standalone DMA slice](DMA_STATUS.md) now has a separate,
opt-in shared-machine integration; ordinary Turbo/X3 and board profiles remain
disabled. Native firmware and remaining DMA acceptance gates are still open.
Fresh v05 five-game qualification finished after the CRC increment: four pass,
Shanghai fails its pair assertion;
the prior v04 results must not be promoted to current-RTL acceptance.
See [high-speed PCG](TURBO_HIGH_SPEED_PCG_STATUS.md),
[CPU/DMA bus diagnostic](DMA_CPU_BUS_STATUS.md) and
[metadata publication](D88_WRITE_METADATA_STATUS.md) for exact test scopes.
New PCG/metadata model state requires v07, the later X3 PPI crossing v08,
and current digital text-raster work v09;
fresh v05 game results remain source-bound
historical acceptance, not acceptance of these later changes.
See [X3 PPI crossing](TURBO_PPI_CDC_STATUS.md) for functional checks and the
still-required source-bound refit; the frozen `15a0655` Quartus worker excludes it.
The [digital text-raster increment](TURBO_TEXT_RASTER_STATUS.md) now implements
provisional SCRN b2 expansion/b7 reserved underline/background mixing, with
graphics suppression and independent line color. All 512 policy combinations
and the prior mixer assertions pass, as do standard-scan 80×20 CPU pixels.
Corrected-source standard-scan 40×10 expansion and delay-aware high-scan
40×20 underline CPU pixel checks also pass. The R9=31/R5=0 CRTC extra-row
fix passes 36 focused cases and the original enable-equivalence tests;
expanded high-scan 80×12 now passes all 640×384 CPU pixels and periods with
both graphics pages initialized through DAM. Full-matrix/mode-exit gates
now pass all 16 cases on the frozen v09 renderer. Native/ASIC/attribute
acceptance remains open. The subsequent [X3 reset-release change](X3_RESET_RELEASE_STATUS.md)
has unit/PCG, CPU polling, expanded-pixel, retained-font warm-reset and base
snapshot/timing coverage; source-bound refit/CDC and physical reset remain open.
Do not mark text/underline/400-line/native acceptance complete from those units.
SIO's inspected primary programming/FIFO/IRQ contract and ordered original
tests are recorded in [SIO_REGISTER_CONTRACT.md](SIO_REGISTER_CONTRACT.md).
A subsequent standalone polled 5–8-bit N/E/O engine passes 108 dual-channel
formats (x16/x32/x64; 1/1½/2 TX stops), pin/FIFO/error/buffering/reset and
simultaneous access tests at CE=1/4/7; [SIO status](SIO_ASYNC_STATUS.md)
records the subset. The separate [interrupt wrapper](SIO_IRQ_STATUS.md)
passes connected priority/nesting, stopped-CE held ACK and actual-CPU IM2/RETI
tests at the same rates. Explicitly armed first-character RX/error locks,
CTS/DCD snapshots and their actual-CPU reset commands now pass too.
Native reset arming, remaining external sources, x1/break/live configuration
and machine integration remain open.
October 6: opt-in [functional SIO WAIT/Ready](SIO_FLOW_STATUS.md) passes pin
handshakes and actual-CPU 100-edge IN/OUT stalls at CE=1/4/7. Default SIO flow
remains off; exact pin/opposite-channel/DMA and machine response persistence
are not qualified.
Subsequent [standalone SIO/DMA tests](SIO_DMA_STATUS.md) pass A/B RX/TX,
byte/burst Ready pacing, stopped-enable read recovery, terminal readback and
framing-lock/Error Reset recovery. Opt-in Ready now inhibits repeated DMA
reads of a locked error word. Actual CPU/SIO/DMA ownership together, exact
pin timing and machine integration remain open.
The subsequent [actual CPU/SIO/DMA diagnostic](SIO_DMA_CPU_STATUS.md) passes
both channels at CE=1/4/7: continuous RX/TX real grants and PC isolation,
CPU byte/count assertions, and CPU-driven burst error inspection/Error Reset.
Its new IM2 profile passes one SIO error handler/ACK/RETI after burst release
and 80 stopped-enable ACK edges, preserving DI checks. Broader IRQ/BUSRQ
phases, reset/daisy-chain and schematic-qualified machine integration remain
open; DMA's own IRQ engine is still missing. This is not native/hardware acceptance.
The reset extension now passes twelve A/B source-read/destination-write cases
at CE=1/4/7, with stopped advancement, retained short reset, one drained pair,
real CPU reboot and subsequent complete diagnostics. Reset during IRQ service
and actual machine serial integration remain open; see [reset contract](SIO_DMA_CPU_STATUS.md#warm-resetdrain-extension).
Both complete frozen fast/delay-aware metadata CPU matrices now pass.
Four v05 native-control titles pass; Shanghai's expected-pair assertion failed
with unchanged inputs and retained evidence. None qualifies later v10 RTL.
Current model state is v12 after adding the RGB12 output port; reject older
snapshots, do not convert them. Existing v11 evidence remains source-bound.
The separate [shared-machine DMA subset](DMA_MACHINE_STATUS.md) now connects
real CPU ownership, DRQ pacing, shared decode and retained reset drain.
Generated A/B read/write/protected/CRC and actual-machine owned-reset checks
pass. Eight subsequent pending-SD held-reset cases and bounded GRAM/PCG targets
now pass too. It remains opt-in, with native firmware, broader
reset/metadata/DAM targets,
IRQ/search/exact timing and fitted/hardware qualification still open.
The completed [frozen PCG/metadata fit](TURBO_PCG_METADATA_QUARTUS_BUILD.md)
has positive same-clock machine paths but fails cross-domain setup/recovery
at all eight corners and hold at five. Narrow CDC/mux constraints and a
current-source refit remain required; assembly is not timing closure.

## Continuation steps 1–5 after `95c181c`

| Step | Current result | Next acceptance gate |
|---|---|---|
| 1. Timing/CDC | Frozen `15a0655` fit/path/retained-state audit completed; same-clock machine setup passes; real CDC/reset and mux-alternative failures classified | Review narrow first-stage recognition, held-bus bounds and mux exclusivity; refit current source; do not globally cut SYS↔VID paths |
| 2. DMA | Opt-in machine integration passes fast/delay-aware RAM/A/B read/write/protection/CRC/count cases, four owned and eight pending-SD reset cases, RAM-under-IPL and bounded GRAM/PCG checks | Partial metadata/short-reset/pending-PCG/DAM targets, native Turbo IPL continuity, unsupported functions and fitted/hardware acceptance |
| 3. Kanji/video | Existing ANK/expanded-text checks retained; Kanji attribute storage is not glyph support | Implement documented CPU latches/ROM mapping and glyph halves with synthetic assets; qualify expanded-attribute/PCG/native combinations |
| 4. SIO | Standalone formats/FIFO/IRQ/error/service, opt-in flow and A/B SIO/DMA pacing pass; combined CPU ownership/error recovery plus directed SIO IM2 ACK/handler/RETI and stopped-CE ACK pass at CE=1/4/7 | Native reset arming/remaining external sources, x1/break/live configuration, exact WAIT/Ready, broader DMA/reset/IRQ phases, multi-device qualification, schematic clocks/pins and machine integration |
| 5. Native software | Five v11 baseline titles pass movement/firing/pair checks; Shanghai feedback prepares the same pair and passes unchanged assertions, preserving old failure | Broader/delay-aware/hardware gameplay, polling-phase diagnosis, Arcus/Bastard playability; hardware unavailable |

The v11 batch uses source `95c181c`, base SYS32/VID28,571,428 Hz, fast
simulation, original 16-second cold boot and unchanged title/control durations.
Executable SHA-256 is
`ee270b8052a350528c0d16f69da119a4576769ad0fa026ae9b4bd29b8d9507c7`.
Outputs are private/ignored `verilator/obj_dir_v11_fast/native-requalification/`;
progress log is `/tmp/x1-v11-native-qualification.log`. The original batch has
four passes and the timed-replay Shanghai failure. Subsequent native feedback
passes its unchanged pair assertion; see [evidence](SHANGHAI_FEEDBACK_STATUS.md).
Preserve each frozen runner; do not rebuild historical v05.

## Phase 0 — make simulation trustworthy

- [x] Repair the Verilator Makefile continuation and clean rules.
- [x] Add a headless Verilator target that does not require SDL/OpenGL.
- [x] Advance simulation time and independently schedule the checked-in board clocks.
- [ ] Correct/verify the board PLL video frequency (currently 28.571428 MHz).
- [x] Add opt-in one-clock simulation, fractional enables and enabled CRTC;
  prove CRTC 40/80 phase equivalence and focused diagnostics.
- [x] Resolve single-clock short gameplay-input regression by preserving the
  MR16 timer's 32 MHz virtual tick rate; retain the original movement test.
- [ ] Audit slower MR16 instruction timing, broaden software compatibility and
  obtain timing/hardware signoff before changing the default configuration.
- [x] Investigate and fix cold-start PS/2 receive/firmware turnaround: F make at 25 ms,
  break at 45/47 ms, I at 60 ms and break at 80/82 ms, then J at 100 ms and
  break at 120/122 ms gives only F/J responses in both baseline and single.
  Firmware LED transmit on disconnected output pins consumed I. Explicit
  receive-only firmware profile now passes all six cold and steady responses,
  overlapping keys and Caps/Shift polling in both clock models; original
  bidirectional failure remains reproduced. See `KEYBOARD_STATUS.md`.
- [x] Build opt-in single revision with positive analyzed setup/hold/recovery
  and no unconstrained clocks; external I/O constraints/hardware remain open.
- [x] Make the simulator load `bios/ipl_x1.hex` through the shared ioctl path.
- [ ] Add deterministic reset, clock, and frame-count command-line options.
- [x] Add cycle/reset-duration/video-frequency options and a timing/reset regression.
- [x] Add deterministic warm-reset pulses and repeated IPL-overlay/HALT recovery
  tests with retained ROM/RAM; keep physical Main/OSD dispatch validation separate.
- [x] Add optional FST traces and JSON results.
- [ ] Add VCD/FST trace selection and a small smoke-test script.
- [x] Establish nonzero HS/VS with an actual renderer and IPL-programmed CRTC.
- [ ] Resolve all Verilator warnings instead of relying on broad suppression.
- [x] Document Verilator 5.x headless and new SDL builds/play commands.
- [x] Verify hosted CI for asset-free diagnostic fixtures. A read-only,
  immutable-checkout-pinned workflow is now configured under
  `.github/workflows/diagnostics.yml`; all selected targets pass locally
  (Verilator 5.044, logs `/tmp/x1-sio-dma-reset-suite.log`,
  `/tmp/x1-sio-reset-guard.log`, `/tmp/x1-ci-local-extra.log`).
  [Hosted run 37479171527](https://github.com/alanswx/SharpX1_Mister/actions/runs/37479171527)
  passed all 16 selected targets on implementation commit `0e4e021`.
  The [expanded run 37497785084](https://github.com/alanswx/SharpX1_Mister/actions/runs/37497785084)
  passes all 21 targets on `abda8ee`, including full DMA and standalone FM.
  This is not private-media/native firmware, Quartus/hardware acceptance or
  full repository license clearance.

## Phase 1 — prove the existing machine boots

- [x] Verify the active top-level is the intended X1 model, not the stale
  legacy wrapper accidentally selected by the simulator.
- [x] Confirm reset fetch, IPL overlay and RAM through a self-checking Z80 diagnostic.
- [ ] Validate wait states and cycle timing against hardware/reference traces.
- [x] Confirm allocated 64 KiB main RAM, 2 KiB text/attribute banks,
  2 KiB per PCG plane and 16 KiB per GRAM plane; RAM/GRAM diagnostics pass.
- [x] Boot the checked-in IPL and capture native IPL/game frames.
- [ ] Resolve IPL/BASIC licensing/provenance and verify BASIC compatibility.
- [x] Boot one native D88 game (CROSS Chase) and verify repeatable PS/2 movement.
- [ ] Add memory/I/O bus assertions for unmapped accesses and contention.
- [ ] Compare CPU-visible behavior against MAME traces for a short boot window.

## Phase 2 — complete the base X1 peripherals

- [ ] Finish the 8255/PPI port map and joystick/parallel-port behavior.
- [x] Verify PPI mode-0 reset, direction, output latches, split port-C input
  direction and BSR; verify both PSG joystick inputs and mirrored/register-mask reads.
- [x] Correct MiSTer-to-X1 joystick direction/button order; exhaust all 64
  combinations in a board-adapter regression. Hardware input remains untested.
- [ ] Finish the MR16 keyboard/sub-CPU command set and verify repeat,
  modifiers, reset/device-command behavior and full interrupt interactions.
- [x] Retain repaired MR16 firmware execution; test mailbox E7/E8, PS/2 ASCII,
  IM1 make/break IRQs and native-game controls.
- [ ] Validate the CRTC timing, 40/80-column text, attributes, and character ROM.
- [ ] Validate 320/640 graphics modes, palette behavior, and GRAM banking.
- [x] Correct one-master-edge HBlank/RGB mismatch and compare every pixel of
  CPU-programmed 40/80 text, 320/640 graphics and palette/priority mixtures in
  baseline and single-clock models. See `VIDEO_STATUS.md`; attributes, PCG,
  mode transitions and hardware acceptance remain separate gates.
- [x] Add CPU-programmed color/reverse/address-wrap, double-width/height and
  three-plane PCG pixel fixtures at both widths; delay-aware baseline/single
  and fast runs pass. Both live width switches and firmware-driven blink
  phases pass in baseline/single and fast; exact scanline timing, character
  ROM authenticity and hardware acceptance remain open. See `VIDEO_STATUS.md`.
- [x] Test individual GRAM planes, all DAM write masks, read-clear and ordinary
  port isolation; observe native 320×200 game colors.
- [ ] Validate PCG writes/readback and the documented PCG wait behavior.
- [x] Implement beam-addressed ANK/three-plane PCG reads and single-byte
  writes through a synchronized video-domain transaction, with CPU WAIT.
- [x] Test PCG readback via Z80, plane independence, low-port mirrors,
  ROM write protection, held-bus single writes, reset and three clock ratios.
- [ ] Validate exact soft-sync/scanline timing and optional AUTO_WAIT trap
  against hardware; test PCG raster images and Turbo high-speed addressing.
- [ ] Complete cassette transport and baud/timing behavior.
- [x] Connect PSG audio output and verify deterministic 1 kHz WAV waveform.
- [ ] Verify noise, envelopes, full music and hardware audio/clock behavior.
- [x] Verify all three tone channels, volume mute, repeatable noise with period
  scaling, all 16 envelope shapes and 4.096/8.192 ms envelope periods in simulation.
- [ ] Compare game music/noise/envelope fidelity to a reference or hardware,
  including zero-period quirks and output-port direction semantics.

## Phase 3 — storage and X1 Turbo support

- [ ] Implement the floppy controller and disk-image adapter (D88/2D/2HD as
  applicable), including write protection and drive status.
- [x] Integrate WD1793-family replacement and read-only base 2D D88 adapter;
  verify native IPL loads CROSS Chase byte-exactly through the controller.
- [ ] Verify exact MB8877 errors/status/timing, density/motor behavior and writes.
- [x] Add two independently mounted A/B D88 images through one controller,
  retained physical heads/shared registers, per-drive motor hold/protection,
  serialized rescans and ACK-drained request ownership. Generated CPU A/B
  reads/writes and connected pending-write/reset/malformed/eject tests pass.
  Exact index/mechanics, selection latency, HPS replacement and hardware remain
  open. See `DUAL_DISK_STATUS.md`; no complete Arcus/disk-set claim.
- [x] Verify generated D88 variable/multi-sector reads, seek/side/RNF/not-ready,
  sticky lost-data, write protection and byte-exact cross-block write/readback.
- [x] Add drive/density decode, motor hold and 300 rpm index/head-load tests.
- [ ] Validate deleted-data/format/force-interrupt/metadata/CRC edge cases,
  including conditional force-interrupt sources, abort during host SD I/O,
  malformed/eject/reset transfers, drive B and applicable 2HD/2DD media.
- [x] Implement selected-sector normal/deleted mark and B0 CRC repair after
  all payload ACKs, separate header RMW/per-block index publication, split
  metadata blocks, deterministic write-underrun zeros and retained short-reset
  cancellation. Original 75-group unit passes CE=1/8 and CE=1; shared-machine
  matrix/native/hardware acceptance remain separate. Unsupported WRITE TRACK
  now reports write-fault rather than a successful no-op; no formatter claim.
- [x] Preserve D88 byte-7 deleted marks in the sector index and report Read
  Sector record type; generated CPU payload/status-clearing, READ ADDRESS,
  mixed multi-sector and byte-8 isolation checks pass. Deleted writes and
  metadata/density behavior remain open. The later CRC latch requires v05.
- [x] Separate bad-ID search from data-CRC completion; direct generated-media
  tests cover bounded exhaustion, duplicate recovery, sticky multi-sector CRC,
  READ ADDRESS CRC/C-to-sector/lost-data and pending-CRC cleanup at two CE rates.
  Fast and delay-aware baseline machine suites also pass. See
  [CRC increment](D88_CRC_STATUS.md); fresh native/game acceptance,
  exact rotational/pin timing remain separate gates. Valid duplicate writes
  now pass with byte-exact media preservation, cross-block readback and host
  protection at both CE rates; this does not repair D88 CRC/deleted metadata.
- [x] Fix busy `$D0` falsely raising completion INTRQ; add idle/busy `$D0/$D8`,
  subsequent normal completion, status acknowledgement and reset regression.
- [x] Cross-check Fujitsu MB8877A Type IV bits and status acknowledgement;
  implement `$D1/$D2` ready edges, `$D4` index edges and `$D8` persistence,
  with mask cancellation/re-arming and reset tests. Exact pin timing remains open.
- [x] Drain pending sector SD reads/writes across `$D0` and controller reset;
  test before/during ACK, stable LBA/write-buffer samples and fresh commands.
  Already accepted writes can commit; stalled-host/eject/remount/scanner reset
  and hardware fault injection remain open.
- [x] Correct ACK draining when CPU/FDC enables stop during reset; reproduce
  the missed-handshake regression with CE stopped in the transport fixture.
- [x] Add simulator D88 structural preflight and original malformed-media CLI
  tests; reject unsupported scanner layouts separately from corrupt images.
- [x] Add strict D88-only bounds/rejection to shared RTL; bypass host preflight
  in direct scanner tests covering header/table/count/payload errors, index
  overflow, selected-volume bounds, eject/replacement and scanner/controller
  pending-read reset/ACK draining. Invalid media stay not-ready, no raw fallback.
- [ ] Verify malformed direct MiSTer mounts and physical media changes; extend
  replacement during writes and all parser phases. Permanently stalled hosts
  remain safely quarantined; safe cancellation/timeouts need a transport contract.
- [x] Extend connected FDC tests to active A eject before write ACK and during
  ACK-high, including CE-stopped reset and unchanged B. Accepted writes drain
  to the test host's retained old media. Real HPS replacement epochs, physical
  mounts, rollback and exhaustive scanner-phase coverage remain open.
- [ ] Implement DMA bus arbitration and verify Z80 DMA transfers.
- [x] Qualify opt-in shared-machine pending payload SD read/write reset on A/B
  before/during ACK: stopped CPU/FDC enables, stable old transport, retained
  native diagnostic reboot and 256 fresh pairs. Check both whole images before
  and after reboot; short released pulses and metadata publication remain open.
- [x] Qualify opt-in shared-machine GRAM/selected PCG DMA in fast and delay-aware
  simulation: 576/96 pairs, 36/6 real grants, CPU counters/readback, both GRAM
  pages/boundaries, three planes and real PCG WAIT. DAM, pending-PCG reset,
  exact native timing and hardware remain open; see [evidence](DMA_MACHINE_STATUS.md#october-6-pending-sd-reset-and-video-target-qualification).
- [x] Extend whole-machine resets to 64 payload/single-block/split-metadata held and
  short-pulse cases, plus five PCG-owned profiles with exact one-write drain
  and an 80-edge physically stopped-video WAIT. The original four RAM reset
  cases and full delay-aware baseline also pass. Intermediate split-header
  mark/CRC images are checked before retry; partial CPU payload/Ready loss,
  DAM, native and hardware remain
  open. See [reset checkpoint](DMA_MACHINE_STATUS.md#october-6-reset-extension-checkpoint).
- [x] Exercise real CPU-executed DMA register streams and a single-owner unit
  mux at CE=1/4/7, WAIT-stretched raw/accepted register writes, both transfer
  directions, count/readback/CONTINUE and drained read/write reset. This is
  not connected shared-machine/FDC arbitration; see `DMA_CPU_BUS_STATUS.md`.
- [x] Expose actual CPU wrapper BUSRQ/BUSACK/refresh pins and verify 18
  WAIT/ownership/release/reset cases plus three enable-rate controls.
  [CPU seam audit](CPU_BUSREQ_AUDIT.md); machine request stays inactive until
  DMA and shared-bus arbitration are implemented.
- [ ] Add CTC/SIO behavior and interrupt priority/acknowledgement tests.
- [x] Implement and test standalone idle/no-pending-data SIO Send Break on A/B
  at CE=1/4/7, including stopped ticks/enables and reset isolation. Busy/queued
  TX and receive-break behavior remain unsupported; full SIO/machine acceptance
  is not complete. See [bounded contract](SIO_ASYNC_STATUS.md#october-6-idle-send-break-increment).
- [x] Add opt-in Turbo CTC with enable-driven timers/counters, schematic-based
  CTC-before-keyboard arbitration, stable vectors/single mailbox consumption,
  nested channel IRQs and decoded RETI. Unit, connected bridge, real MR16
  stretched ACK and CPU IM2/cold-input tests pass in both clock profiles.
  ASIC alias decode, exact pin/phase timing and hardware remain open; SIO is
  still absent. See `CTC_STATUS.md`.
- [ ] Implement X1 Turbo high-resolution/400-line behavior.
  Graphics raster/page addressing is implemented separately from text MA;
  nominal X3 enable timing and 16-row ANK now have focused simulation coverage.
  Exact clock/switching hardware, Kanji, text expansion, CPU font selection,
  underline and high-speed PCG remain open. See `TURBO_VIDEO_CLOCK_STATUS.md`;
  this does not close the 400-line milestone.
- [x] Implement bounded Turbo high-speed PCG and CPU ANK16 selection with
  retained selector shadows, frozen bundled requests, one-write semantics
  and provisional HSYNC service. Original unit/CPU tests pass; fallback,
  ASIC/WAIT timing, Kanji, refit and native acceptance remain open.
- [x] Add separate opt-in 42.954540 MHz X3 video profile with enabled CRTC,
  2/3-edge high/low dot cadence, phase/reset/width tests, sixteen-row ANK
  loader and synthetic pixel tests. Exhaust ordinary/paired PCG addresses.
  Native Arcus high-scan periods now match nominal geometry; its screen remains
  garbled, not playable. FPGA fitted frequency/hardware need separate evidence.
- [x] Separate graphics RA from text MA; implement low/repeated/even-odd GRAM
  page/raster addresses. Exhaustive address unit and sixteen CPU-written RGB
  cases pass in fast baseline Turbo, with focused delay-aware single coverage.
  Clock/font/hardware gates remain separate; latest RBF predates this change.
- [x] Add explicit experimental Turbo foundation: independent GRAM access/display
  pages, 96 KiB GRAM, separate KVRAM, blackclip and 32 KiB IPL. CPU/boundary/DAM/
  warm-reset and actual RGB tests pass; no complete Turbo model claim.
  See `TURBO_STATUS.md` and `TURBO_IMPLEMENTATION_PLAN.md`.
- [ ] Implement Kanji ROM readback and the Turbo/TurboZ extended video paths.
- [ ] Add optional EMM/expanded RAM and SASI/HDD support if the target core
  promises Turbo/TurboZ compatibility.

## Phase 4 — MiSTer integration and validation

- [x] Produce an initial main-project Quartus 17 RBF; record failed timing,
  utilization and source hashes. This is not timing closure or hardware proof.
- [x] Load the source-bound single-clock timer checkpoint on MiSTer, observe
  native CROSS Chase title/playfield and remote-key start; retain hardware PNGs
  and unchanged disposable disk hashes. This is not full hardware validation.
- [x] Observe directional remote-input response on the latest hardware build:
  live cyan player moves (23,17) to (21,14) with unchanged life/level display.
- [ ] Verify exact single-event two-direction movement, unshifted Caps Lock
  behavior, physical inputs and audio on hardware, beyond rapid remote bursts.

- [x] Wire MiSTer HPS keyboard, joystick, read-only floppy and IPL/reset OSD;
  route actual RGB/audio and elaborate the wrapper with lint.
- [ ] Reproduce/close the reported Reset/Reset-and-close needing core reload
  on hardware; test both actions from title, gameplay and disk loading. See
  `RESET_STATUS.md`; MiSTer is unavailable while travelling.
- [ ] Verify SDRAM/GRAM bandwidth and video timing on hardware.
- [ ] Review PCG bundled-data CDC placement/max-delay constraints and reset
  release with Quartus timing tools; simulation does not verify metastability.
- [ ] Add keyboard, joystick, cassette, floppy, and reset OSD controls.
- [x] Add new SDL gameplay frontend and native-booted checkpoint regression.
- [x] Warm-reboot a running native game without ROM reload or disk remount in
  baseline and single-clock simulation; retain the original movement regression.
- [ ] Build a reference test matrix: IPL, BASIC, text, graphics, PSG, tape,
  floppy, and representative commercial software.
- [x] Establish release-bound repeatable player-control checks for Druaga,
  Xevious, Mappy and Galaga, plus Shanghai cursor/selection/legal-pair removal, after
  native IPL/D88 boot in fast baseline simulation.
  See `COMMERCIAL_COMPATIBILITY.md`; 5/5 bounded commercial control gate, not full
  compatibility, delay-aware gameplay or hardware validation.
- [ ] Record known deviations from MAME/X Millennium and gate regressions on
  stable screenshots, bus traces, and audio hashes.

## Phase 5 — Turbo Z (researched roadmap, not implemented)

See [Turbo Z specification, sources and acceptance plan](TURBO_Z_PLAN.md).
Finish base Turbo first; keep Z-specific detection/ports behind a separate
capability profile. The existing `TURBO=1` build is not Turbo Z support.

- [ ] Define CZ-880 model/BIOS/font/DIP/readback contracts; distinguish ZII/ZIII.
- [ ] Widen simulator and FPGA RGB paths for true 12-bit analog color.
- [ ] Implement analog enable, text/graphics palettes and palette readback.
- [ ] Implement/test 640x400/8, 640x200/64, 320x400/64,
  320x200/64 (two screens) and 320x200/4096 (one screen) multi-modes.
- [ ] Implement Z text priority, transparency, blackclip and output rules.
- [ ] Integrate standard stereo YM2151 FM, CTC/IRQ and PSG mixing.
- [ ] Qualify switchable dual 2HD/2D drives and native HD software.
- [ ] Add second-level Kanji, mouse/serial and RTC/control-processor behavior.
- [ ] Research/implement capture quantization/inversion, mosaic, chroma key,
  extra scroll and superimpose/telopper, with a deterministic test video source.
- [ ] Validate native Z software, pending-operation resets, Quartus/CDC and
  physical video/input/audio. EMM/SASI remain separately scoped expansions.
