# Sharp X1 for MiSTer

An experimental Sharp X1 FPGA core for MiSTer, with machine RTL, inherited
Nise X1 hardware, firmware sources, and a Verilator simulation harness.
The project is in bring-up. CROSS Chase now boots from D88 through the native
IPL and is playable in Verilator. This does not establish full X1 compatibility
or a release-ready FPGA core. An optional single-clock checkpoint also boots
the game on MiSTer and responds to remote start/directional input; see
[hardware bring-up evidence](docs/HARDWARE_BRINGUP.md) for the limited scope.
The [current hardware matrix](docs/HARDWARE_VIDEO_MATRIX_STATUS.md) includes
six native-title tests and exact captured RGB checks for base 40/80-column
text, graphics and PCG. A separate [DMA candidate](docs/DMA_BOARD_BUILD_STATUS.md)
passes eighteen bounded CPU-driven hardware diagnostics; other optional
devices and full Turbo Z remain unqualified on hardware.
The [DMA-build feature matrix](docs/HARDWARE_DMA_FEATURE_MATRIX_STATUS.md)
adds exact base-video pixels before/after retained-asset warm reset and tracks
the remaining physical and unimplemented-feature gates.

## Current status

The separate [RTC/X3/DMA/Kanji/FM profile](docs/RTC_DMA_KANJI_FM_STATUS.md)
now passes elapsed/reset, six keyboard and four active RTC/FDC/DMA checks.
Actual CPU-programmed mixed PSG/FM sound also cold-repeats exactly with
four DMA pairs. These are separate bounded gates, not full device contention,
native games, Turbo Z or new board/hardware acceptance.

The separate [DMA/Kanji bus diagnostic](docs/DMA_KANJI_MACHINE_STATUS.md)
now passes eight real-CPU ownership/payload/reset cases and its rejecting
default-profile control. It fixes a blocked upload-start invalidating a live
font during reset drain. Renderer/RTC/FDC/native-game and hardware coexistence
remain open; no ordinary runner or board enables the combination.

The separately named non-savable `rtc-x3-dma-kanji` follow-up now passes ten
original pixel and six keyboard cases, plus four actual CPU RTC/FDC/DMA cold/
warm transfers. Elapsed/warm calendar and four rejection gates also pass.
Pixels and active disk/clock tests are separate bounded gates. Protected native
cold/repeats now finish: Arcus transfers 57,344 bytes by DMA but ends on a black
frame, and Bastard stays at its title. Neither is gameplay/hardware acceptance.

Repeated Kanji DMA during rendered frames now passes the ten-case pixel matrix:
1,536,000 exact RGB pixels, 18,549 late bus pairs and repeated CPU payload
verification. A one-byte uploaded-font corruption is rejected by the same CPU
program. See the [active-display gate](docs/DMA_KANJI_MACHINE_STATUS.md#repeating-dma-during-actual-kanji-frames);
native and physical compatibility remain open.

The frozen post-PCG-reset [combined Z matrix](docs/TURBO_Z_COMBINED_STATUS.md)
now passes all 120 cases and 8,960,000 independently regenerated RGB pixels.
Its source binding is `d2df8a1`, not current RTC/D88/native/hardware acceptance.

The [Turbo Z Kanji physical decoder](docs/TURBO_Z_KANJI_STORAGE_STATUS.md)
now passes all 262,144 first/second-level byte addresses against the CZ-880
ROM pins. It is standalone; machine level-2 storage and native glyph support
remain open. The [line-buffer audit](docs/TURBO_Z_LINE_BUFFER_STATUS.md)
also records the newly retrieved NEC capture-memory reference and remaining
implementation gates, not a functioning digitizer.

The standalone Turbo Z line-buffer prototype now passes two independent-clock
storage/replay/reset profiles and a wrong-cycle DIN negative. It is outside
the machine; ADC/IC58/GRAM capture and hardware remain unimplemented or unqualified.

Large concatenated D88 files now mount when their selected first volume fits
the controller's address space. Host/scanner and real Z80 read/write checks
pass, preserving all trailing volumes. Selected volumes still must be below
1 MiB; this is not 2HD support or new hardware acceptance. See
[disk evidence](docs/DISK_STATUS.md#concatenated-container-admission-repair).

The default-off [Turbo Z effect CPU prototype](docs/TURBO_Z_EFFECT_CPU_STATUS.md)
now passes actual Z80 position/mosaic/chroma/scroll register storage and
AEN/DAM/neighbor/warm-reset tests. Native read/reset policies remain provisional;
no capture or rendered effects, board capability or Z identification is added.

The default-off [shared RTC profile](docs/RTC_MACHINE_STATUS.md) passes actual
Z80 EC..EF elapsed seconds, retained-IPL warm reset, six real PS/2 keyboard
cases with clock/mailbox polling, and bounded memory-DMA reset/upload checks.
Its source-derived controller uses an extended ROM and independently ticking
serial clock; the [restricted assembler](docs/RTC_COMMAND_STATUS.md#reproducible-restricted-source-rebuild-not-an-rtc-fix)
also reproduces all 4,096 inherited ROM bytes without AASM. Negative controls
reject clock-storage loss, missing keyboard input and inadmissible uploads.
`make -C verilator rtc` is a separate non-savable runner requiring an explicit
8-KiB controller upload; ordinary runners and all boards remain RTC-disabled.
Native year/leap/power policy, full device coexistence and hardware remain open.
The separate `rtc-x3` runner passes bounded elapsed/reset and keyboard checks;
it does not change any default or qualify native Turbo Z. Ordinary-clock
short reset during RTC/keyboard polling also passes three keys and a rejecting
no-reset control, without asset reupload.
The separate `rtc-x3-kanji` combination now passes ten synthetic CPU/pixel
cases plus elapsed-time, retained-IPL reset and six-key/absent-key gates;
native game/font and hardware acceptance remain open.

Protected sixteen-second Arcus/Bastard cold/repeat probes finish deterministically
on the qualified 28.571428-MHz RTC checkpoint: Bastard reaches its title;
Arcus displays a garbled high-scan dialog. Neither is gameplay acceptance or
an X3-clock test. See [software evidence](docs/COMMERCIAL_COMPATIBILITY.md).

The experimental handoff revision's early/fitted HDMI pin guard now accepts
five exact observed whole-bank profiles, not arbitrary per-bit alternatives.
Native mapped guard loading and historical-fit active-path preservation pass;
fresh fitting and timing/hardware acceptance remain open. See
[scope and evidence](docs/HDMI_MODE_STATUS.md#exact-whole-bank-earlypacked-contract-qualification).
The new `4cd18ed` source-bound handoff flow fits and assembles, but final STA
fails a Tcl helper scope dependency. The local repair preserves the exact
constraint scope in three load contexts. A native same-fit diagnostic now passes
independent scope/path-preservation auditing, but global setup still fails
(-9.918 ns); fresh full-flow and hardware qualification remain open.
Its generated RBF is unqualified and has not been deployed.
The fresh `048d996` handoff flow also fits and assembles, but final STA refuses
a newly fitted whole-bank D/ASDATA pin profile. Its guard stays strict; native
inventory now identifies that exact fourth profile, and mocked scope/negative
checks pass. Native same-fit active-path preservation now passes independent
384-report auditing, but global setup remains -9.962 ns; a fresh full flow
and timing/hardware acceptance are still required.
The fifth `3c6242e` fit now also passes independently audited same-fit
preservation across 384 reports. Global setup still fails at -9.659 ns;
fresh full-flow, CDC/MTBF/I/O and hardware acceptance remain open.
No newly accepted hardware build is implied.

For a blank screen on first launch, see [IPL loading](docs/IPL_LOADING.md):
the RBF does not bundle the boot ROM. Load a matching raw `.rom` through
**Load IPL**, or configure `boot.rom`/an explicit MGL upload. A game disk alone
is not sufficient; base X1 and Turbo require different IPL sizes.

The experimental X3 [coherent CRTC write transport](docs/CRTC_WRITE_CDC_STATUS.md)
now commits held CPU/DMA RS/data packets in the video domain. Real-CPU,
owned-DMA reset and sixteen delay-aware video cases pass. Ordinary paths stay
unchanged; fresh combined-Z pixels, Quartus timing and native/hardware
acceptance remain open. Exact fitted CRTC inventory and independent
eight-corner auditing now pass synchronous consumer and bounded held-packet
paths. Raw request/ACK inputs and whole-core timing remain open; this is not
a timing-qualified RBF.
A separate unselected packet-only constraint passes completed-fit before/after
auditing without changing raw input reports. Global setup/hold still fail
at HDMI-OSD/video-selected output paths. All five fresh ordinary commercial
gameplay collectors now pass again; this does not establish Turbo/Z gameplay.
The [HDMI mode investigation](docs/HDMI_MODE_STATUS.md) now checks the actual
inherited output policy in 72 static cases and records fitted selector routing.
Mode-sensitive STA, safe switching and physical output remain open.
Installed Intel clock-primitive simulation now passes steady selection checks;
asynchronous switch observations reinforce the need for a safe handoff. The
local Main reference can change framebuffer selection at runtime.
The simulation-only glitch-free clock-control candidate passes eighteen
running/stopped-source native-model and independent waveform checks. Matching
clock/data handoff, FPGA integration and physical acceptance remain open.
A separate acknowledged-handoff controller now passes twelve native-model
tagged-data/reset/stopped-clock cases and an unsafe-selector negative. It is
now connected through a default-off framework option. Six native extracted-
register cases now pass 4,994 exact output checks, including stopped pixel-enable
reset-abort/retry recovery. The controller fixes both reset waiting on stopped
video readiness and stale completion after an aborted epoch. All 96 native
reset-phase/rate/readiness cases and twelve clock-handoff cases pass.
Existing revisions leave it disabled; the separate `sharpx1_turbo_z_handoff`
revision completes its corrected-source full Quartus flow, but global
eight-corner setup/hold still fail (-47.082/-1.806 ns). Independent full-board
auditing passes 208 bounded stage/witness/native-gate rows and exact first-stage
fanout, without new timing exceptions. Raw input, held output data, MTBF/I/O
and physical acceptance remain open; the new RBF is also unqualified.
An exact first-stage-only candidate now preserves the bounded chains and
previously reported held-mode paths in an eight-corner before/after probe.
Global diagnostics still fail (-18.252/-0.062 ns after the candidate). Only the
separate handoff revision selects it; fresh fitting/MTBF and held-mode/data
qualification remain required. No ordinary board default is changed.
Complete held-mode discovery now audits 1,584 timing rows at eight corners.
It identifies a separate native-VID csync consumer (`dv_hs1`), which the first
gated-output-edge checks cannot qualify. Its setup still fails -7.247 ns;
no blanket held-mode exception is added. See the HDMI investigation for the
output/native-video/control-domain inventory and unchanged-artifact evidence.
The new selected-input fit fails its STA scope guard because fitting creates
a source replica feeding the gate-enable first stage. Connectivity discovery
confirms the changed driver; replication/equivalence and fresh timing still
need qualification. The guard is not weakened and this flow is not accepted.
The next candidate prevents replication only on the gate-enable source with
a documented synthesis attribute. Local scope/isolation tests pass; native
qualification now repeats all 96 reset profiles and six actual-policy
profiles (4,994 exact words and 198 first-edge holds) on this new controller
hash. The fresh source-bound full flow is fitting; replica scope and timing
are not yet accepted. No MiSTer is loaded.
That flow now completes zero but still fails setup (-18.201 ns); no design
MTBF is calculated. A newer experimental-only csync path acknowledges the
policy actually consumed by native HS. Six normal and six delayed-policy
native profiles pass, and the matching no-echo control fails as intended.
Ordinary static policy tests still pass; new source-bound fitting and physical
acceptance remain required. No old RBF qualifies this newer framework.
Its subsequent fit completes but the native inventory rejects a second-stage
replica: HS and the echo use different physical samples. A narrow replication-
prevention directive now protects their shared sample; fresh normal/skew
native checks pass. New fitting must prove the topology; timing and hardware
remain unqualified, with no broader exceptions or ordinary-default changes.
The protected-sample fit has now completed. Its native inventory and
independent 320-report audit pass the exact topology and 912 synchronous
stage/consumer rows (+19.594/+0.230 ns minimum setup/hold). Raw crossings and
global setup still fail; this is not timing closure or a qualified tester RBF.
See [the fitted evidence](docs/HDMI_MODE_STATUS.md#single-sample-fit-and-native-all-corner-inventory).
An unselected 29-pair held-output-mux proposal now passes independent native
before/after auditing while preserving other mode/raw-input timing. Global
setup still fails -12.149 ns; no new RBF or hardware acceptance is inferred.
Fresh native tests also pass 5,030 known/correct visible outputs with inactive
banks poisoned to X. Fitted inactive-bank discovery covers all 51 physical
targets without adding exclusions; active-route and physical qualification
remain open.
An exact-pin inactive-branch probe now excludes 848 inactive rows
while preserving 6,400 active/raw/held-mode rows. The active HDMI -0.106 ns
setup violation remains visible; joint-proposal fitting and hardware remain
unqualified.
The joint probe now verifies both proposals together, preserving 5,472 other
rows while budgeting the held controls. Only the separate handoff revision
selects them for a fresh experimental fit. Global setup still fails -10.797 ns
at PCG download/reset write gating; ordinary boards remain unchanged.
Twelve PCG helper profiles now additionally pass accepted-stage cancellation
with stopped VID and earlier CPU reset release, without stale writes on
restart. This is reset-test coverage, not a timing-path fix or hardware pass.
The subsequent source repair uses the existing local video reset alone for
PCG write permission, retaining ordinary reset behavior. Fresh X3 continuation
and actual old-state rejection pass with revision-3 snapshot identity; fitted
write-enable timing and current-machine pixels/hardware remain unqualified.
The fresh full ordinary delay-aware regression also finishes zero with 143
PASS reports and an unchanged runner hash; Turbo/Z native and hardware
acceptance remain separate. See [baseline evidence](docs/BASELINE_V17_STATUS.md).
The fresh fast/snapshot/SDL suite also passes (140 reports); eighteen logged
video cases match the delay-aware run. All five fresh ordinary native-boot
gameplay collectors now finish zero, with thirty native-prefix state hashes
and all 646 frozen inputs independently checked. Optional Turbo/Z and
hardware gates remain open; see [the current game evidence](docs/BASELINE_V17_STATUS.md#fresh-five-title-launch-after-local-reset-repair).

Its isolated real-PLL controller maps/fits; a fitted-feedback audit led to an
explicit falling-edge closure witness. Current native cases pass, while raw
crossings, full-board timing and physical switching remain open. All 96 bounded
isolated-controller timing rows pass eight corners; that smaller PLL probe is
not qualification of the board's default faster HDMI clock.

The experimental X3 [text-blink crossing](docs/VIDEO_BLINK_CDC_STATUS.md)
now uses two video-domain samples. Delay-aware 40/80-column blink pixels and
snapshot checks pass; ordinary profiles retain their direct path. Fresh
five-title ordinary gameplay tests also pass. The new source fits and its
reported blink stage/consumer paths pass eight-corner timing. Overall setup
still fails; the complete combined-Z matrix and physical/native acceptance
remain open.

An experimental-only [SYS VSYNC synchronizer](docs/VSYNC_SYS_CDC_STATUS.md)
now passes nine local clock combinations and two failing-control checks.
Ordinary revisions are unchanged. Fresh FPGA timing, separate HPS/measurement
crossings and physical/native acceptance remain open.
Its subsequent source-bound fit completes and the reported VSYNC stage/consumer
paths pass all eight corners. Overall setup/hold still fail; raw input scope,
separate crossings, I/O and hardware acceptance remain open.

See the [chip-by-chip implementation survey](docs/CORE_STATUS.md) for the
current wiring audit and [downloaded hardware manuals](references/manuals/README.md)
for schematics and machine documentation.
The [Turbo Z effect-control audit](docs/TURBO_Z_EFFECT_CONTROL_STATUS.md)
now includes a standalone exhaustively tested programming decoder. Actual
capture, mosaic/key/scroll rendering and input-video integration remain unimplemented.
Its follow-up adds a tested digital ADC pin adapter, not an analog digitizer
or connected capture pipeline.
The [RTC command diagnostic](docs/RTC_COMMAND_STATUS.md) now reproduces correct
date/time storage but stalled seconds in fast and delay-aware real-CPU tests.
Its ordinary acceptance correctly fails; a running/persistent clock remains
unimplemented, not qualified by static EC..EF readback.
Its standalone calendar backend now passes 351,748 arithmetic/invalid-state
cases and three negative controls; timebase and command integration remain open.
A separate oscillator-event counter backend now passes 1,201,499 edge checks;
the machine's clock producer and serial/MCU integration are still missing.
A standalone CZ-880 P1/T1 serial frontend now passes 137,050 edge checks and
three wrong-pin controls. Its documented pin mapping is not yet connected to
the replacement controller; machine elapsed-time acceptance still fails.
A nominal SYS-clock enable source now passes five frequency profiles with
connected serial/calendar consumers. No additional clock domain is introduced;
controller integration and physical clock/persistence remain open.
An original real-MR16 diagnostic now programs and reads all 40 RTC bits through
proposed replacement GPIO wiring, including two seconds with controller CE
stopped. The inherited firmware/mailbox driver and ROM budget remain open.
A default-off MR16 response-retention experiment now passes that driver at
five enable cadences; ordinary keyboard/IRQ checks pass with it disabled.
Enabled reset/IRQ/snapshot/hardware and actual mailbox integration remain open.
The standalone [SIO clock-event adapter](docs/SIO_EDGE_CLOCK_STATUS.md) now
preserves serial edges and sampled RX data across enable gaps; independent
queue tests and real CTC/SIO diagnostics pass. Shared event routing is opt-in;
native clock waveforms, pin CDC and serial/mouse acceptance remain open.
The standalone [SIO bus decoder](docs/SIO_DECODE_STATUS.md) now passes exhaustive
address/control checks and real Z80 neighboring-port/DAM/enable isolation,
alongside the existing CPU IRQ/flow/reset diagnostics. It is not yet connected
to ordinary or hardware profiles. A new default-off shared-machine profile is
qualified separately below.
The new [SIO interrupt-chain bridge](docs/SIO_CHAIN_STATUS.md) checks nested
service ownership and stable ACK vectors. A new actual-CPU/real-SIO/DMA/CTC
fixture passes nested IM2, received bytes, DMA payload and retained-program
reset/reboot at three enable divisors. The subsequent
[shared-machine SIO increment](docs/SIO_MACHINE_STATUS.md) adds conservative
decode, event-clock routing and SIO → DMA → CTC → keyboard arbitration;
generated IPL-driven CPU/RX/WAIT/retained-reset checks pass with DMA present
and absent. Native clock/pin CDC, mouse/software, snapshots of an enabled SIO
profile and FPGA integration remain open. Existing board/C++ profiles stay off.
An [asynchronous ×1 extension](docs/SIO_X1_STATUS.md) adds externally
bit-synchronized RX/TX diagnostics; fractional-stop/native timing remains open.
The [FM decoder increment](docs/FM_DECODE_STATUS.md) adds conservative address/
bus qualification and real-CPU neighboring-port tests with JT51. A new
[default-off shared FM CPU bus](docs/FM_MACHINE_STATUS.md) passes generated
IPL busy/status/WAIT/DAM/DMA/reset checks at three clocks. Opt-in signed
[PSG/FM audio](docs/FM_MACHINE_AUDIO_STATUS.md) and an FM-enabled FPGA revision
are now implemented and fitted; native IRQ and physical sound remain open.
The [live-audio owned-DMA reset test](docs/FM_OWNED_RESET_STATUS.md) also passes
at three clocks. Ordinary profiles keep FM disabled.
The [CZ-851 selector audit](docs/SIO_MACHINE_WIRING_AUDIT.md) now adds verified
DTRB polarity/source switching and documents the differing CZ-880 drawing;
CZ-851 CTC1-to-A-alternate and CTC2-to-B routes are now traced and tested with
distinct-rate real CTC/SIO diagnostics. Physical pulse width, pin CDC, CZ-880
routing and native shared-machine qualification remain open. Native clock acceptance
also needs the [two-phase CTC contract](docs/CTC_PIN_TIMING_AUDIT.md):
native ZC output release follows a falling clock, not the next rising CE.
Strengthened experimental Z graphics, paired-text and single-text matrices
now pass 24/12/16 cold/warm
cases respectively; see the [graphics](docs/TURBO_Z_PAIRED_VIDEO_STATUS.md),
[paired text](docs/TURBO_Z_TEXT_COMPOSITION_STATUS.md) and
[single text](docs/TURBO_Z_SINGLE_TEXT_STATUS.md) evidence. These exact
simulation frames do not establish native Z or physical FPGA acceptance.
A separate [experimental Z video board profile](docs/TURBO_Z_BOARD_BUILD_STATUS.md)
now enables the combined palette/multi-mode/text paths for FPGA qualification;
existing revisions remain off. Wrapper lint and six combined custom/warm pixel
cases pass. The FPGA flow fits but fails reported setup/recovery timing; it is
not a hardware-qualified candidate. Timing and hardware gates are tracked separately.
The [palette ownership reset correction](docs/TURBO_Z_OWNER_RESET_STATUS.md)
now gives the experimental X3 owner independent two-edge reset releases;
stopped-clock/connected-RAM tests and all six fresh custom/warm pixel cases pass,
The fresh full baseline suite and snapshot checks also pass. The new fit
completes but fails setup/recovery/hold timing; native/physical acceptance remains open.
A [narrow held-snapshot constraint](docs/TURBO_Z_SNAPSHOT_TIMING_STATUS.md)
passes fresh-fit eight-corner payload checks and is selected by the
experimental Z revision; overall setup/recovery/hold and CDC/HDMI gates remain open.
The [PCG bundle-window audit](docs/PCG_BUNDLE_TIMING_STATUS.md) passes base and
high-speed PCG/font/reset checks at SYS=32 MHz as well as inherited ratios;
completed-fit PCG request/response bounds pass all eight corners. The first
integrated refit fails the request inventory gate because early RAM endpoints
differ from fitted endpoints. Both explicit representations now pass native
inventory checks, and the revised completed-fit request probe passes all eight
corners. Request/response bounds are selected only by the experimental Z revision.
The corrected refit fits, but final STA rejects two router-duplicated CPU
response captures. Replica-aware inventory checks now pass and the subsequent
full flow finishes zero. Fresh all-corner PCG and snapshot payload audits now
pass, including both CPU capture replicas. Overall setup/hold/recovery still
fail; native/physical acceptance remains open. The
[reset-input experiment](docs/VIDEO_RESET_TIMING_EXPERIMENT.md) preserves all
reported stage/downstream paths and is selected only for experimental Z;
its fresh-fit and physical gates remain open.
The selected-constraint fresh fit now completes and passes reported PCG,
snapshot and core release paths at eight corners. Overall setup and scaler
recovery still fail; the [scaler audit](docs/SCALER_RESET_TIMING_AUDIT.md)
also identifies excluded raw-input timing coverage. Native/physical gates
remain open; this is not a timing-qualified Turbo Z RBF.
The experimental scaler now has opt-in independent two-edge reset releases
for its three clock domains. GHDL helper tests pass and the modified scaler
analyzes; ordinary revisions retain inherited releases. Fresh FPGA timing
and physical acceptance remain open.
The first scaler-reset fit succeeds, but final STA rejects a now-absent PCG
state replica. Revised native inventory and strict mocked checks pass;
the corrected guard still requires a fresh flow and all-corner audits.
The corrected flow now completes zero; PCG, snapshot and reported scaler
stage/downstream timing pass eight-corner checks. Overall setup/hold/raw-reset
recovery remain negative. An analysis-only mux candidate preserves real
HDMI and SYS/VID failures; no timing-qualified Turbo Z RBF is claimed.
The six-pin scaler input experiment preserves all reported stage/downstream
timing and gives positive constrained recovery at eight corners. Experimental
Z now selects that scope and the narrow mux aliases for a fresh fit;
setup/hold, CDC/I/O and physical/native gates remain open.
The selected refit now completes with positive reported recovery and active
HDMI pipeline timing, but overall setup/hold still fail on newly visible
VSYNC samplers and other crossings. The full ordinary local suite passes;
no timing-qualified or hardware/native Turbo Z claim is made.
The [summary table](docs/CHIP_IMPLEMENTATION_TABLE.md) and
[chip reuse survey](docs/CHIP_REUSE.md) describe available replacement sources
and the remaining integration work.
The [implementation and test plan](docs/IMPLEMENTATION_PLAN.md) defines the
base-X1 milestones, architecture decisions, and acceptance gates.

There are two machine implementations in this tree:

| Path | Role today |
| --- | --- |
| `rtl/sharpx1.v` | Shared machine instantiated by MiSTer and the headless simulator. |
| `rtl/sharpx1_legacy.v` | Inherited Nise X1 implementation retained as a reference. |

Both builds now use the machine sources in `rtl/machine.qip`.
The legacy implementation enables an X1 Turbo subset and FZ80 CPU through
source macros; its presence does not imply complete Turbo compatibility.
An explicit, opt-in `TURBO=1` foundation now adds two graphics pages, separate
Kanji attribute RAM, blackclip controls and a 32 KiB IPL aperture to the shared
machine. CPU diagnostics and actual RGB tests cover these extensions. It is
**not full Turbo support**: Kanji, full DMA, SIO and native Turbo
firmware acceptance remain open. An
experimental [graphics raster increment](docs/TURBO_RASTER_STATUS.md) separates
text/graphics addresses and adds repeated/alternating-page raster mapping;
the new opt-in [X3 clock/font increment](docs/TURBO_VIDEO_CLOCK_STATUS.md)
adds enable-driven nominal high/low-scan timing and a validated 16-row ANK
loader. Synthetic pixel tests pass; native Arcus remains garbled/not playable.
Exact hardware timing, remaining text/PCG/Kanji functions and FPGA acceptance
remain open. The previous published RBF predates these increments. The earlier
opt-in [CTC increment](docs/CTC_STATUS.md) adds enable-driven timers/counters,
IM2 vectors, CTC-before-keyboard arbitration and stable stretched ACKs;
focused unit/CPU/real-MR16 tests pass, not exact hardware timing. See the
[Turbo status](docs/TURBO_STATUS.md) and [implementation plan](docs/TURBO_IMPLEMENTATION_PLAN.md).
An unchanged user-supplied 32 KiB Turbo IPL now executes to an IPL disk-search
screen; see [native firmware evidence](docs/NATIVE_TURBO_FIRMWARE_STATUS.md).
This does not establish native Turbo game or complete firmware compatibility.
The [Turbo DIP readback increment](docs/TURBO_DIP_STATUS.md) adds an explicit
static 2D-floppy boot profile instead of unmapped `FF` (SASI in local MAME).
Actual native IPL reads now return `F1`; the bounded probe still does not
reach FDC transfers or establish game boot. Hardware/snapshot gates remain open.
The longer F1 probe now reaches native DMA setup and a disk-read error; a
separate [X3/DMA follow-up](docs/DMA_X3_NATIVE_STATUS.md) passes full generated
fast/delay-aware transfer matrices. Native gameplay and combined Kanji/DMA
qualification remain open.
The [two-drive snapshot increment](docs/DUAL_SNAPSHOT_STATUS.md) passes
generated A/B CPU/DMA continuation and ordered-media rejection, preserving
the single-drive header. Committed writable A-first/B-first checkpoints also
pass exact exported-media continuation and read-only protection overrides.
A native Arcus checkpoint resumes to 32 seconds with all five RAM/CPU dumps
matching fresh execution, but its screen remains black, not gameplay.
The same chain reaches 48 seconds; [read-only graphics observation](docs/VIDEO_OBSERVATION_STATUS.md)
finds populated planes/palettes, not a proven cause of the black screen.
The [interrupt comparison](docs/ARCUS_INTERRUPT_STATUS.md) finds only handler
opcode fetches in a native continuation; two existing-local-MAME cold runs
reach the same black handler state. X Millennium progresses to garbled scenes,
but an isolated pending-retention control reproduces that stall; the physical
CTC overlap contract remains open. This is not gameplay acceptance.
Owned-host/interrupted-write qualification remains open.
An original [standalone DMA subset](docs/DMA_STATUS.md) now passes register,
transfer, count/readback and ownership tests. That standalone checkpoint did
not connect the shared machine or establish native DMA compatibility.
The [real CPU/DMA unit diagnostic](docs/DMA_CPU_BUS_STATUS.md) passes
18 ownership/register/reset cases. A subsequent separate, opt-in
[shared-machine DMA increment](docs/DMA_MACHINE_STATUS.md) connects real CPU
ownership and FDC DRQ pacing. Generated A/B reads, writes, CRC repair,
protection and owned-pair reset tests pass; native firmware and full DMA
functions remain open. Ordinary Turbo/X3 and board defaults do not enable it.
Further [pending-SD reset and video-target checks](docs/DMA_MACHINE_STATUS.md#october-6-pending-sd-reset-and-video-target-qualification)
pass eight held-reset A/B read/write cases, including stopped-enable ACK drain
and native diagnostic reboot. Fast/delay-aware GRAM/selected PCG transfers pass
CPU count/readback and isolation checks. Broader reset/metadata/DAM/native timing
and hardware gates remain open.
The [reset extension](docs/DMA_MACHINE_STATUS.md#october-6-reset-extension-checkpoint)
passes 64 held/pulsed payload/single-block/split-header metadata cases and five PCG-owned
reset profiles, including a stopped-video WAIT and exact one-write drain.
The full delay-aware baseline regression also completes successfully.
Partial CPU payload/Ready loss and native firmware remain open; no hardware
signoff is implied.
The [DMA automatic-restart increment](docs/DMA_AUTO_RESTART_STATUS.md) passes
40 standalone groups through 65,537-byte boundaries, real shared-CPU buffer
updates without LOAD in both directions, and fast/delay-aware machine tests.
IRQ, pure search, non-Byte Stop on Match and variable timing remain unsupported;
default profiles keep DMA off.
A [sequential comparison increment](docs/DMA_COMPARE_STATUS.md) now reports
real masked/sticky match status: 6,144 unit cases and 12 actual shared-CPU
profiles pass, including delay-aware/fast agreement. A subsequent
[Byte-mode stop increment](docs/DMA_BYTE_STOP_STATUS.md) completes the matching
write and stops without another read; 10,240 standalone comparison/stop cases
pass. The subsequent [pure Byte search increment](docs/DMA_PURE_SEARCH_STATUS.md)
performs no destination writes and passes 10,240 additional cases, including
memory/I/O, WAIT/reset and long-count rollover. Read-only
[Byte search automatic restart](docs/DMA_SEARCH_RESTART_STATUS.md) also passes
unit and actual-CPU fast/delay-aware buffer/count/status tests, with zero
destination writes. [Non-stopping Burst/continuous pure search](docs/DMA_NONBYTE_SEARCH_STATUS.md)
now passes distinct counts/Ready ownership and twenty real-CPU profiles on
fast and delay-aware builds; total search mask cases are 14,336.
An actual [pure-search match-stop pipeline](docs/DMA_SEARCH_STOP_STATUS.md)
adds real extra-read and Ready-loss behavior; 24,576 search cases and twenty
actual-CPU fast/delay-aware stop profiles pass.
Sequential non-Byte Stop on Match
and IRQ/service remain open. DMA serialized state has a distinct revision;
ordinary non-DMA v12 snapshots and defaults remain unchanged.
The separate [DMA service foundation](docs/DMA_SERVICE_STATUS.md) passes
4,096 arbitration cases, 2,048 status-vector cases and twelve connected real-CPU/DMA
IM2/HALT/handler/RETI profiles, including stopped-enable held ACKs. It is not
yet wired into machine DMA or native interrupt programming.
The subsequent [completion-IRQ command path](docs/DMA_COMMAND_IRQ_STATUS.md)
adds an explicit device-only `COMPLETION_IRQ=1` profile: 36,864 register/vector
cases and twelve real-CPU WR4/IM2/RR0/RETI cases pass. Machine/board defaults
still disable it; Ready/restart interrupts and shared-machine IRQ remain open.
The subsequent [shared-machine completion IRQ increment](docs/DMA_IRQ_MACHINE_STATUS.md)
adds an explicit `TURBO_DMA_IRQ=1` profile with schematic-qualified DMA/CTC
ownership and isolated nested RETI. Four generated CPU/IM2/HALT/RR0/RETI
profiles pass on fast and delay-aware runners. Defaults remain disabled;
native firmware, broader reset/concurrent-service and hardware gates remain open.
Its subsequent reset guard prevents an old held ACK from selecting a new
device after reset. Real-CPU nested DMA/CTC tests and native-handler snapshot
continuity/cross-profile rejection pass; this still does not establish full
DMA/Turbo compatibility or hardware reset acceptance.
The directed three-device DMA/CTC/real-MR16 pending profile also passes on both
timing models, with ordered keyboard make/break and cold repeat checks.
The device-only [Ready/IOR increment](docs/DMA_READY_IRQ_STATUS.md) adds
`READY_IRQ=1`, independent IOR/IP/IUS and B7 release. Existing machine/board
profiles do not enable it. Byte/Burst owned Ready events now drain a real
pair before service; directed WAIT/grant/mask checks pass. Restart IRQ and
native/hardware gates remain open.
The separate [auto-restart EOB IRQ profile](docs/DMA_RESTART_IRQ_STATUS.md)
retains a terminal event without setting EOB status. Register-stream and
real-CPU two-block ACK/RETI checks pass at CE=1/4/7; mixed causes,
shared-machine integration and native/hardware acceptance remain open.
The [reload-buffer correction](docs/DMA_RELOAD_BUFFER_STATUS.md) keeps the
already-loaded destination independent of later starting-buffer writes, with
both-direction and delayed-grant tests. DMA states need fresh revision-7
execution; ordinary non-DMA v12 profiles remain unchanged.
The [real-CPU restart handler matrix](docs/DMA_HANDLER_BUFFER_STATUS.md) adds
three-block buffered-address checks in both directions and all transfer modes;
shared-machine/native/hardware restart service remains open.
The [executing reload snapshot](docs/DMA_RELOAD_SNAPSHOT_STATUS.md) now confirms
revision-7 flag/counter/buffer serialization in both directions on the non-IRQ
shared machine; restart-handler and hardware snapshots remain unqualified.
The subsequent [shared restart-service profile](docs/DMA_RESTART_MACHINE_STATUS.md)
adds actual CPU handler snapshots and A/B sector-boundary IRQ/DRQ acceptance
in both directions/all three bus modes. It is separately opt-in; mixed causes,
native firmware, reset races and hardware remain open.
The separate [DMA board qualification revision](docs/DMA_BOARD_BUILD_STATUS.md)
now enables that subset on the single-clock FPGA wrapper. Fitting, timing and
hardware acceptance must be recorded separately; it does not change existing
board revisions or the recommended RBF.
Its source-bound `818b0de` Quartus 17.0.2 fit now passes all eight constrained
timing corners, and all eighteen generated memory/A/B restart diagnostics pass
actual CPU-driven RGB checks on mister126. This is bounded DMA acceptance, not
full DMA, native Turbo/Z software or physical timing signoff; see the same report.
The [Kanji contract audit](docs/KANJI_CONTRACT_STATUS.md) adds an exhaustive
schematic-derived first-level address component and a separately tested 128 KiB
dual-clock ROM loader. Synthetic byte/read/reset checks pass; the opt-in shared
CPU/loader path is now connected, but glyph rendering remains incomplete and
Turbo Z requires its separate larger ROM path. No private font data is included.
An optional, default-disabled high-speed CG Kanji selector now passes exhaustive
physical addressing/isolation tests, informed by static inspection of a
published hardware monitor. Its [ROM/WAIT backend](docs/KANJI_CG_ACCESS_STATUS.md)
now passes connected synthetic tests and six cold/warm actual-CPU profiles.
The separate opt-in `turbo-kanji` shared-machine profile adds physical-ROM
loading and native CPU CG/INI checks; it is not a native glyph renderer or
an enabled FPGA capability. X3 fast/delay-aware CPU checks, executing snapshots
and five pending-read reset cases also pass. Default profiles stay unchanged.
An [explicit private model-40 conversion](docs/KANJI_CONTRACT_STATUS.md#executed-explicit-model-40-conversion-and-cpu-read-candidate)
passes exhaustive synthetic layout checks and bounded shared-CPU candidate
reads. It is not native glyph rendering or hardware chip-identity acceptance.
The schematic-derived standalone glyph-source decoder now passes 4,194,304
pin combinations, including PCG-over-Kanji priority and absent-level-2 isolation.
The separate [opt-in Kanji renderer](docs/KANJI_RENDER_STATUS.md) now passes
ten actual-RGB cases on fast/delay-aware models and bounded private candidate
rendering, with exact rendered snapshot continuation. ASIC row/phase, the full
attribute cross-product and native/hardware gates remain open; board defaults stay unchanged.
The subsequent mixed-source matrix passes fourteen fast/delay-aware cases:
actual ANK/PCG/Kanji pixels, all colors/reverse, mode exits, warm reset and
bounded global expansion/underline. Per-cell height/width, blinking and
remaining cross-products still need qualification.
A bounded [high-speed PCG increment](docs/TURBO_HIGH_SPEED_PCG_STATUS.md)
adds selector shadows, frozen HSYNC-window access and CPU ANK8/16 selection.
Original unit/CPU tests pass; ASIC fallback/WAIT phase, Kanji and hardware
timing remain open, not full 400-line compatibility.
The [X3 PPI crossing](docs/TURBO_PPI_CDC_STATUS.md) adds two-stage VSYNC/VDISP
level sampling only in the X3 profile; asynchronous and real-CPU cold/warm
tests pass. It has not been refitted and does not establish timing closure.
A further [digital text-raster increment](docs/TURBO_TEXT_RASTER_STATUS.md)
implements provisional global vertical expansion and reserved underline/gap
mixing. Focused units, standard-scan 80×20 / expanded 40×10 CPU pixels,
expanded high-scan 80×12 (640×384), and delay-aware high-scan 40×20
underline pixels pass. All 16 documented row/width/mode-exit cases now pass
on the frozen v09 checkpoint, not complete Turbo text/Kanji compatibility.
The subsequent [X3 reset-release increment](docs/X3_RESET_RELEASE_STATUS.md)
keeps CPU phase intact and releases video reset on its own clock. Unit/PCG,
CPU polling, expanded pixels and retained-font warm-reset checks pass; refit
and physical reset remain open. It advances the model to v10.
The optional `turbo-video-savable` simulator target now supports fast X3
single-drive diagnostic continuations with model-profile rejection; it does
not enable dual-drive snapshots or replace delay-aware/hardware checks.
Turbo Z is a separate capability target with a
[manual-based roadmap](docs/TURBO_Z_PLAN.md), including analog multi-color
video, stereo FM, HD disks and capture effects. Its first
[RGB12 output foundation](docs/TURBO_Z_RGB_STATUS.md) connects full-color
capture and wrapper interfaces while preserving digital colors. Analog palette
rendering now has a separate opt-in full-color experiment; a
[multi-mode extension](docs/TURBO_Z_MULTIMODE_STATUS.md) passes generated
wide/tall/selected-screen pixel and retained-reset checks under an explicitly
provisional reduced-color policy. Native ASIC compatibility, internal/text
palettes and other Z devices remain incomplete; ordinary board defaults do
not enable these experiments.
A further [internal-palette experiment](docs/TURBO_Z_INTERNAL8_STATUS.md)
connects programmable 640x400/8 graphics. CPU-written identity/custom pixels,
retained warm reset and custom cold cross-store isolation pass; native
ASIC/priority and combined hardware gates remain open.
A separate [FM foundation](docs/TURBO_Z_FM_STATUS.md) passes
JT51 busy/timers, stereo notes, fractional enables and signed mixing at three
master frequencies; CPU decode/IRQ, native sound and hardware remain open.
The standalone [Z palette storage](docs/TURBO_Z_PALETTE_STORAGE_STATUS.md)
passes exhaustive RAM tests and a six-M10K/39-ALM Quartus probe; native palette
registers/ownership/renderer integration remain open. Newly retrieved primary
programming diagrams expose an access-gating conflict recorded in the
[palette contract audit](docs/TURBO_Z_PALETTE_CONTRACT.md). A subsequent
screen-programming chapter corroborates normal explicit write/read sequences
and adds cold-initialization, retained-reset and fixed-black text requirements;
the standalone RAM now implements the external cold identity image and tests
retained reset, but native register/internal/text palette behavior remains open.
A separate [external-palette transaction adapter](docs/TURBO_Z_PALETTE_ACCESS_STATUS.md)
connects selector/write/read operations to that RAM. The opt-in
[CPU-only palette experiment](docs/TURBO_Z_PALETTE_CPU_STATUS.md) now executes
those transactions through the shared Z80, including retained warm reset and
a disabled-profile negative control. Upper read bits, general native decode,
DMA/beam ownership and rendering remain gates; ordinary profiles and RBFs
are unchanged. This is not full Turbo Z support.
The [functional palette ownership path](docs/TURBO_Z_PALETTE_OWNER_STATUS.md)
now waits for real video blanking and passes actual-CRTC CPU cold/warm checks,
including a corrected 40-column guard and retained late-IN responses. Native
ASIC timing and display integration remain unqualified.
The [sequential Z GRAM fetch buffer](docs/TURBO_Z_GRAM_FETCH_STATUS.md) now
passes all-address/five-layout bank/parity and synchronous-read tests using
the real machine RAM primitive. CRTC, pixel and palette integration remain open.
An initial [connected 4096-color experiment](docs/TURBO_Z_VIDEO_STATUS.md)
now passes exhaustive standalone shifter checks and all 64,000 shared-CPU
identity/custom-palette pixels with correct periods. Retained-reset pixels now
pass with post-reset I/O proving no refill; this is not a completed Z renderer
or a new RBF.
Its retained-reset test exposes a [PPI/DAM control-write corruption](docs/DAM_TRANSACTION_STATUS.md).
The transaction-bound correction passes standalone/CPU tests and requires
fresh **v13** snapshots; earlier v12 snapshots and game qualifications remain
historical. Fixed full-pixel/reset tests and the preceding complete default
baseline suite pass. Fresh v13 commercial requalification and a source-bound
Turbo single-clock Quartus refit are recorded separately. The fresh source-9748410
RBF now fits and passes all eight constrained timing corners; hardware deployment
is pending. See [the source-bound artifact/evidence](docs/HARDWARE_126_STATUS.md).
The subsequent [CPU/display pin audit](docs/TURBO_Z_PALETTE_CONTRACT.md#cpudisplay-pin-reconciliation-table-4-22)
corrects a shared renderer/oracle significance error. Connected all-4096-index
checks and corrected identity/custom retained-reset pixels pass. Earlier
pixel images remain historical; the corrected full-color four-case matrix passes.
The preceding default v13 baseline suite now finishes successfully. A separate
[reduced-format experiment](docs/TURBO_Z_MULTIMODE_STATUS.md) compiles and
passes expanded shifter checks and all sixteen frozen identity/custom
cold/warm wide/tall/selected-screen pixel cases. Reduced native palette-bank
policy remains open; the separate
640x400 internal-palette experiment now passes all four cold/warm
identity/custom isolation cases, not complete Turbo Z support.
The new [text-palette CPU increment](docs/TURBO_Z_TEXT_PALETTE_STATUS.md)
passes nine unit profiles and five actual-CPU controls, including all six-bit
values, DAM isolation and warm retention without refill. It is opt-in,
non-savable and not connected to text RGB or priority; board defaults are unchanged.
The [paired-screen fetch/shifter](docs/TURBO_Z_PRIORITY_CONTRACT.md#executed-paired-screen-fetchshifter-increment)
now preserves two independent indices and passes all-address/color-pair unit
checks at three clocks. CPU priority controls and actual two-screen composition
remain unconnected; these units do not establish native priority or a Z RBF.
The subsequent [priority CPU/ordering increment](docs/TURBO_Z_PRIORITY_CPU_STATUS.md)
connects opt-in `1FC0` reads/writes and passes real-Z80 all-byte/reset/isolation
checks plus the complete layer-order truth table. Stored priority now crosses
with the held video controls; actual-CPU cold/warm sweeps and stopped-clock
recovery pass at three clock ratios. The decoder is not yet connected to
rendered composition; opacity/native/hardware remain open.
The subsequent [paired-screen graphics connection](docs/TURBO_Z_PAIRED_VIDEO_STATUS.md)
now builds with captured priority and bank selection before palette lookup.
The first 64,000-pixel paired case passes; the wider actual-CPU RGB matrices
are in progress. Opaque/analog text, native opacity
and physical acceptance remain incomplete. Existing board revisions are unchanged.
An opt-in [analog text composition follow-up](docs/TURBO_Z_TEXT_COMPOSITION_STATUS.md)
now connects raw glyph color and retained text palette to paired ordering.
Its first 64,000-pixel text-between-screens case passes; the complete cold/warm
matrix is running. Intensity mapping is provisional.
Current snapshots require v16 after the optional shared FM bus/model increment;
regenerate old states from native execution, never convert them.
The [single-screen text follow-up](docs/TURBO_Z_SINGLE_TEXT_STATUS.md) now
builds for both 320x200/4096 and selected-bank 320x200/64, with captured mode
eligibility and documented single-screen ordering. Both initial 64,000-pixel
probes pass; the complete cold/warm matrix is running.
Native intensity/opacity and hardware remain open.
The [reverse-text regression](docs/TURBO_Z_REVERSE_TEXT_STATUS.md) now passes
all 64,000 pixels through bank-1-front/text-between warm reset without refill;
full attribute and native/hardware acceptance remain open.
The [complete default v14 delay-aware baseline](docs/BASELINE_V14_STATUS.md)
now exits zero. It does not enable the optional Turbo Z experiments or establish
new native-game/Quartus/hardware acceptance. A subsequent
[text-opacity coverage audit](docs/TURBO_Z_TEXT_OPACITY_COVERAGE.md) narrows older
graphics-on-top evidence; corrected full/paired text-visible warm windows now
pass all 64,000 pixels and require every nonzero text color.
The [fresh v14 commercial qualification](docs/COMMERCIAL_COMPATIBILITY.md)
previously passed all five bounded native gameplay gates on the frozen ordinary
fast runner: Druaga, Xevious, Mappy and Galaga movement, Galaga firing,
and Shanghai cursor/matching-pair removal. Original media and frozen support
files remain unchanged. This is not optional Turbo Z, delay-aware gameplay
or current-source hardware acceptance.
After shared SIO integration, [both complete ordinary v15 suites](docs/BASELINE_V15_STATUS.md)
and fresh v15 native boot/gameplay qualification of all five titles pass again.
The serial profile remains off in that ordinary game runner; generated enabled
SIO diagnostics are qualified separately, not by those game results.
The preceding optional shared FM bus increment required v16. Its full ordinary fast suite,
snapshot tests and [fresh five-game native qualification](docs/COMMERCIAL_COMPATIBILITY.md)
pass. The delay-aware baseline also passes (140 PASS reports), and the
source-bound Quartus refit completes successfully.
The v15 passes above remain historical. See [FM integration status](docs/FM_MACHINE_STATUS.md).
The standalone [signed PSG conversion/mixer](docs/PSG_FM_MIX_STATUS.md)
passes 2,236,486 scalar checks. Genuine concurrent JT49/JT51 waveform,
pitch/panning and reset-repeatability tests pass at three master frequencies;
the [shared signed audio path](docs/FM_MACHINE_AUDIO_STATUS.md) now passes
actual CPU-programmed cold/warm captures and C++ stereo WAV checks.
Default unsigned audio is unchanged; native FM IRQ/analog/hardware gates remain.
Current snapshots require v17; its [full ordinary fast suite passes](docs/BASELINE_V17_STATUS.md),
as do its delay-aware suite and all five fresh native-game qualifications.
The [separate FM-enabled FPGA build](docs/FM_BOARD_BUILD_STATUS.md) fits and
passes all eight constrained timing corners. Its [experimental FM RBF](output_files/quartus-linux-Iypv1tpH/source/output_files/sharpx1_turbo_fm.rbf)
is retrieved locally; unconstrained I/O/native/physical gates remain open.
Existing board revisions stay unchanged and no MiSTer is loaded.
The [latest fitted Turbo single-clock RBF](output_files/quartus-linux-c70iRYNK/source/output_files/sharpx1_turbo_single.rbf)
builds on Quartus 17.0.2, binding `832766f`. Its reported Slow 1100 mV
100 C corner passes; supplemental eight-corner acceptance remains pending.
It is byte-identical to the earlier `0009dd1` artifact, whose eight-corner
results remain source-bound history. See [the current refit audit](docs/FM_MACHINE_STATUS.md#completed-source-bound-refit).
It is not deployed or hardware-qualified and does not enable Z/X3/DMA/Kanji/SIO/FM.

The headless simulator has been compiled with Verilator 5.044 on macOS.
The timing/reset regression passes. A 200,000-system-cycle run reports:

```text
time_ps=6250000000 sys_edges=200000 video_edges=178571
reset_edges=64 cpu_enables=24992 delayed_sys_edges=200000
```

This verifies clock scheduling, reset/divider phase, delayed events, and
repeatability. Additional diagnostics now verify Z80 fetch, RAM patterns,
writes beneath IPL, overlay switching and loader bounds. The shared renderer
produces native IPL and game rasters. Native floppy boot, keyboard interrupts,
repeatable player movement, and a deterministic PSG tone are verified.
Focused regressions also cover PPI mode-0 behavior, both joystick inputs,
all three PSG tones, noise and all 16 envelope shapes. MiSTer joystick bit
order is corrected; physical controller behavior is still untested.
ANK/PCG readback and single-write transactions now have CPU and asynchronous
clock tests. CPU WAIT covers the synchronized transaction; exact native
scanline waits and PCG raster compatibility remain unverified.
See [bring-up progress](docs/BRINGUP_PROGRESS.md) for changes and remaining gates.

Private commercial-game test preparation and the top-32 shortlist are documented
in [test media](docs/TEST_MEDIA.md). Locally extracted disks remain ignored
assets; their presence is not proof of compatibility or gameplay.
The deleted-data/v04 checkpoint requalified repeatable native gameplay-control
evidence for five commercial titles in fast baseline simulation: Druaga,
Xevious, Mappy, Shanghai and Galaga, including legal tile-pair removal and
native firing/projectile travel. See the
[commercial compatibility matrix](docs/COMMERCIAL_COMPATIBILITY.md) for the
bounded checks and remaining compatibility gates; this is not hardware signoff.
The subsequent [ID/data CRC increment](docs/D88_CRC_STATUS.md) passes direct
controller and fast/delay-aware machine regressions and requires snapshot v05.
Fresh CRC/v05 Xevious, Druaga, Mappy and Galaga native/control qualifications
pass, including Galaga firing. Shanghai's native pair check failed and its
evidence is retained; it is not a fifth v05 pass. The five-game v04 evidence
is historical. Subsequent
[D88 metadata publication](docs/D88_WRITE_METADATA_STATUS.md) and PCG changes
require v07 and separate acceptance. The subsequent X3 PPI increment requires
v08, text-raster work v09, and X3 reset release v10. Current CPU/DMA integration
requires v11; the subsequent RGB12 output boundary requires v12. Do not
convert or patch old snapshots; v11 gameplay evidence below is historical.
The v11 baseline qualification now passes all five titles. Shanghai's timed
replay missed its fixed pair coordinates; [native cursor feedback](docs/SHANGHAI_FEEDBACK_STATUS.md)
prepares the same pair and passes the unchanged removal/repeatability checks.
The original failure is preserved. This does not establish Turbo/hardware play.
An original [standalone SIO slice](docs/SIO_ASYNC_STATUS.md) now passes
two-channel polled 5–8-bit N/E/O pin, FIFO/error and buffering tests at CE=1/4/7:
108 formats cover x16/x32/x64 and 1/1½/2 TX stops, plus simultaneous accesses.
A separate [SIO IRQ wrapper](docs/SIO_IRQ_STATUS.md) passes nested service,
held ACK/vector and actual-CPU IM2/RETI tests at the same enable rates, now
including explicitly armed first-character/error locking and CTS/DCD snapshots.
A separate opt-in [functional WAIT/Ready experiment](docs/SIO_FLOW_STATUS.md)
passes pin tests and actual-CPU stalled IN/OUT tests at those rates; it does
not establish exact pin timing. A subsequent [standalone SIO/DMA fixture](docs/SIO_DMA_STATUS.md)
passes A/B RX/TX Ready-paced transfers, count readback and stopped-enable recovery;
it fixes repeated copies of a locked error character in the opt-in flow model.
A further [actual CPU/SIO/DMA diagnostic](docs/SIO_DMA_CPU_STATUS.md) passes
real grants, continuous RX/TX, CPU count/data checks and CPU-driven burst
error inspection/reset on both channels at CE=1/4/7. Its new IM2 profile
passes one genuine SIO error ACK/handler/RETI after burst release, including
80 stopped-enable ACK edges. Broader IRQ/reset/multi-device service and
exact pin handshakes remain open; DMA's own IRQ engine is still absent.
Its warm-reset extension also passes twelve owned serial read/write cases:
retained short request, stopped enables, one-pair drain, reboot without reload
and fresh byte/count checks. IRQ-service reset and machine integration remain open.
A bounded [idle Send Break increment](docs/SIO_ASYNC_STATUS.md#october-6-idle-send-break-increment)
now passes A/B pin/register/reset tests at CE=1/4/7 with serial ticks stopped.
A [standalone transmitter-disable correction](docs/SIO_TX_DISABLE_STATUS.md)
now finishes an already-started character when WR5 Transmit Enable clears,
retains queued data and resumes it after re-enable. Its expanded pin test
passes 504 disable/resume cases across 108 formats at each of CE=1/4/7,
including complete parity/stop timing and a failing old-RTL control.
Original pin/format/IRQ/
CPU/flow/reset/DMA regressions pass; no shared-machine SIO is added.
Queued/busy break and receive-break detection remain unsupported.
A [standalone automatic-enable increment](docs/SIO_AUTO_ENABLE_STATUS.md)
adds WR3 CTS/DCD gating with software-enable AND, receive restart and
1,512 actual CTS drop/resume format cases. All twelve related SIO targets
pass; exact modem phases, IRQ/Ready combinations and machine wiring remain open.
A [standalone RTS correction](docs/SIO_RTS_STATUS.md) now retains asynchronous
RTS until the active character and queued data drain. Its 3,024 pin/format
cases and idle/reset/isolation checks pass with all thirteen related SIO targets.
A [five-or-less transmit correction](docs/SIO_SHORT_TX_STATUS.md) now decodes
documented one- through five-bit payloads per byte. Its 7,908 encoding/format/
control cases and all fourteen related SIO targets pass; machine wiring and
native/physical acceptance remain open.
The [machine-wiring audit](docs/SIO_MACHINE_WIRING_AUDIT.md) records the
native SIO/0 clock selector, mouse/modem controls, model differences and
event-preserving clock/decode/daisy-chain integration gates.
The SIO wrappers are not connected to the machine; native reset arming,
remaining external sources, x1/full break/exact WAIT/Ready and full
multi-device arbitration remain open.
A separate [CPU/SIO interrupt-reset profile](docs/SIO_IRQ_STATUS.md#october-6-actual-cpu-interrupt-service-reset-checkpoint)
passes 12 stopped-enable held-ACK/handler/FIFO/RETI reset cases, retained-program
reboot and fresh interrupts/TX pins. Concurrent multi-device and short-pulse
service reset remain open.
Asset-free [diagnostic CI](.github/workflows/diagnostics.yml) is configured
for the standalone SIO/DMA, D88, reset, bus-ownership and joystick fixtures.
[Hosted run 37479171527](https://github.com/alanswx/SharpX1_Mister/actions/runs/37479171527)
passes all 16 targets on commit `0e4e021`. It does not run private media,
native firmware, Quartus or hardware acceptance.
The expanded workflow adds idle Send Break, original DMA register/CPU units
and exhaustive RGB12 capture. The 19-target GCC run timed out compiling DMA
even at host `-O0`; it did not execute that simulator. Clang/C++20 with Ubuntu's
Verilator 5.020 also exceeds that compile limit. The successful 21-target retry pins
Verilator 5.044, selects Clang explicitly and adds standalone FM. It keeps
per-target limits and all original assertions/simulated durations.
[Hosted run 37497785084](https://github.com/alanswx/SharpX1_Mister/actions/runs/37497785084)
passes all 21 targets on `abda8ee`, including full DMA and FM waveform checks.
This remains asset-free diagnostic acceptance, not complete machine support.
[The 22-target follow-up](https://github.com/alanswx/SharpX1_Mister/actions/runs/37515820620)
passes on `421f5c9`, adding actual CPU/FM. SIO interrupt-reset is the next
added target: [the 23-target run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37522951169)
passes on `c621133`, including all twelve SIO service-reset cases. The newer
automatic-restart DMA matrix still needs its own hosted result.
The simulator window now offers optional [live joystick keys](docs/PLAYING.md):
arrows, Space (button 1) and Ctrl (button 2), through `--joystick-keys`.
Independent CPU-programmed 40/80-column text and 320/640 graphics rasters now
pass after correcting a one-edge HBlank/RGB qualification offset; see
[video coverage and remaining gates](docs/VIDEO_STATUS.md).
The previous video-alignment single-clock RBF is locally available at
`output_files/quartus-IwtYVtRu/source/output_files/sharpx1_single.rbf`.
It predates the new disk/keyboard/Turbo work and has not been tested on MiSTer;
see [source-bound build evidence](docs/QUARTUS_BUILD.md).
The new experimental foundation RBF is
`output_files/quartus-t7wQxGHo/source/output_files/sharpx1_turbo_single.rbf`.
It fits with positive constrained-path timing at eight analyzed corners;
external I/O, CDC and hardware acceptance remain open. See the
[Turbo build report](docs/TURBO_QUARTUS_BUILD.md); it is not full Turbo support.
This RBF predates the subsequent CTC/IRQ increment; do not attribute the new
CTC tests to that artifact.
The CTC-only experimental checkpoint RBF is
`output_files/quartus-CEhveaur/source/output_files/sharpx1_turbo_single.rbf`.
All 333 FPGA inputs match implementation commit `0115a38`; constrained paths
pass all eight analyzed corners. It has not been tested on MiSTer. See the
[CTC build report](docs/CTC_QUARTUS_BUILD.md) for hashes and remaining signoff gaps.
The previous two-image/CTC experimental RBF is
`output_files/quartus-JC4BFj9f/source/output_files/sharpx1_turbo_single.rbf`.
All 334 FPGA inputs match `ffc1c1c`; constrained paths pass all eight analyzed
corners at 48% ALM usage. It has not been tested on MiSTer. See the
[two-image build report](docs/DUAL_DISK_QUARTUS_BUILD.md).
The current experimental single-clock test RBF is
`output_files/quartus-linux-ZOMREvtv/sharpx1_turbo_single.rbf`.
The native Quartus 17.0.2 build binds `5a40859`; all eight constrained timing
corners pass at 49% ALMs. CROSS Chase boot/input and bounded observations of
both OSD resets now pass on mister126. It includes the static DIP fix but
does not enable X3/DMA/Kanji/SIO/FM or establish full Turbo/Z support.
The older `quartus-5ge19D0o` artifact and its evidence remain preserved.
See [current hardware/build results](docs/HARDWARE_126_STATUS.md) and
[tester handoff](docs/TESTER_HANDOFF.md) for hashes and remaining gates.
The newer X3 video/font candidate assembled but **fails timing at all eight
corners**; it is not a replacement timing-closed hardware candidate. See the
[X3 build audit](docs/TURBO_VIDEO_QUARTUS_BUILD.md) and
[font RAM correction status](docs/TURBO_VIDEO_CLOCK_STATUS.md).
The [font-BRAM refit](docs/TURBO_VIDEO_BRAM_QUARTUS_BUILD.md) confirms 49% ALMs
and true font RAM, but still fails setup/recovery at every corner. It binds
`f7875af`, not the later deleted-data storage changes; no hardware deployment
has occurred.
The later [coherent-snapshot refit](docs/TURBO_VIDEO_CDC_QUARTUS_BUILD.md)
binds `c0d1042`, retains the new measurement registers and still uses four
font M10Ks at 49% ALMs. It also fails setup/recovery at all eight corners
and hold at three; it is not hardware signoff or a build of current HEAD.
The completed [PCG/metadata fit audit](docs/TURBO_PCG_METADATA_QUARTUS_BUILD.md)
binds `15a0655`: 49% ALMs, 393 M10Ks, eight M10Ks for the dual-read font.
Same-clock machine paths pass all eight corners, but setup/recovery fail
all eight and hold fails five. It excludes newer PPI/text/reset/DMA changes;
the timing-failed RBF is not a deployment-ready replacement.

MiSTer now wires keyboard, joystick, disk, RGB and audio paths and
offers IPL/D88 OSD entries. Disk writes default to protected; enabling them
does not override read-only media. Generated D88 tests cover reads, safe writes,
protection, variable sector sizes, seeking, sides and error/status cases.
The new [two-image disk increment](docs/DUAL_DISK_STATUS.md) adds separate A/B
mount slots, independent head/motor state and owner-stable host transfers.
Generated A/B read/write tests pass in both clock profiles; selecting media
requires a not-ready rescan interval. This increment is in the latest
experimental RBF, but has not been tested on MiSTer or accepted as complete
disk-set compatibility.
See [disk verification and limits](docs/DISK_STATUS.md).
Focused tests cover pending SD read/write abort/reset and stable request
addresses. Shared RTL now rejects unsafe D88 header/table/sector layouts and
quarantines replacement/ejection until outstanding host ACK drains. Direct RTL
tests bypass simulator preflight and verify not-ready/recovery. A host that
never completes still remains quarantined; physical mounts/writes are unverified.
The initial Quartus 17 build produced an RBF, but **timing does not close**;
The optional single-clock checkpoint has positive analyzed timing and a native
hardware game boot. See [build evidence](docs/QUARTUS_BUILD.md) and
[hardware observations](docs/HARDWARE_BRINGUP.md); neither is full signoff.
The checked-in PLL specifies 28.571428 MHz,
not the 28.636 MHz in comments; correcting and verifying that clock remains
open. Hardware boot is separately observed, not inferred from simulation.

An opt-in [single-clock experiment](docs/CLOCK_EXPERIMENT.md) replaces the
CRTC fabric clock with an enable and derives average CPU/PSG rates from one
video-rate master. It boots the game and passes focused diagnostics and the
original two-direction gameplay regression after compensating the MR16 timer.
The MR16 instruction rate is still slower. The baseline remains
the default; do not advertise the experiment as fully compatible.
The frozen single-clock timer checkpoint builds an RBF with positive analyzed
core timing and no
unconstrained clocks; incomplete external I/O constraints and hardware testing
still prevent full signoff. A source-bound build including the silent-abort fix
has the same RBF because INTRQ has no board-visible fanout. The later conditional
interrupt revision has its own successful fit and native hardware boot. Check
the source-bound report before testing an RBF.
The later SD-transport abort/reset checkpoint also builds with positive analyzed
core timing; its hardware retest is pending because `mister.local` stopped
resolving. Earlier hardware observations do not validate this new RBF.
The cold-start F/I/J keyboard loss is fixed with an explicit receive-only MR16
firmware profile matching the one-way HPS input path; see
[cause, original reproducer and tests](docs/KEYBOARD_STATUS.md).
The reported OSD reset/reload-only issue is tracked in
[reset recovery](docs/RESET_STATUS.md). A current stopped-enable SD handshake
reset bug is reproduced and fixed; physical OSD reset acceptance remains open.

## Play CROSS Chase locally

The acquired game disk and a native-booted checkpoint are present locally,
but are ignored testing assets, not bundled redistributable files. With SDL2
installed:

```sh
make -C verilator play
```

Use **I/K/J/L** to move up/down/left/right and **Space** to fire. Close the
window to quit. The checkpoint has Caps Lock off, as the game expects lowercase
letters. Simulation runs roughly ten times slower than real time on this host.
The new SDL frontend displays real core RGB; live audio playback is not provided
(WAV capture is available). See [play and verification instructions](docs/PLAYING.md)
for checkpoint regeneration, asset permissions, and the gameplay regression.

## Build and run the headless simulator

Install Verilator 5.x, GNU Make, and a C++ compiler supporting the timing runtime
(C++20). The tested build uses the installed Verilator runtime; SDL and OpenGL
are not required for the headless target.

Run these commands from the repository root:

```sh
verilator --version
make -C verilator headless
make -C verilator run CYCLES=200000
make -C verilator test
```

The executable is `verilator/obj_dir_headless/Vtop`. `make -C verilator` builds
the same target. `CYCLES` counts 32 MHz system-clock cycles; omitting
it runs 2,000,000 cycles. Run from the `verilator` directory if invoking the
executable directly, since existing RTL asset paths may be relative.

The event scheduler advances time in picoseconds and drives independent system
and video clocks. Reset lasts 64 system cycles by default. The final JSON result
reports clock/reset/CPU-enable counts, sync transitions, and a provisional video
hash. Examples:

```sh
cd verilator
./obj_dir_headless/Vtop --cycles 4096 --reset-cycles 17 --trace /tmp/x1.fst
./obj_dir_headless/Vtop --cycles 4096 --video-hz 28636360
```

The default video frequency matches the current board PLL (28,571,428 Hz).
FST tracing is optional. `--rom` loads raw binary or whitespace-separated hex
through ioctl; `--ram`, `--load-address` and `--entry` offer explicit debug
execution. `--disk` attaches protected D88 media; `--disk-output NEW_COPY`
explicitly enables simulator writes and exports a new file without modifying
the input. Existing output paths are rejected. `--keys` supplies timestamped
PS/2 set-2 bytes, `--frame` captures actual RGB pixels to PPM, `--bus-trace`
writes CSV and `--dump` saves main/text/attribute RAM. `--audio` captures mono
48 kHz WAV. `--joya`/`--joyb` set raw active-low X1 joystick pin bytes (default
`0xff`); explicit values override saved inputs when restoring a snapshot.
Repeated `--joy-at MS A|B BYTE` schedules raw joystick pin changes relative
to this run/restore, including during reset. See
[scheduled input acceptance](docs/JOYSTICK_SCHEDULE_STATUS.md); continuous
delay-aware Xevious cold boot/start/right movement and exact-repeat checks now
pass without snapshots. Other titles and Turbo/Z/hardware gates stay separate.
Repeated `--reset-at MS` with `--reset-for-us US` inject warm machine resets,
relative to this run/restore, without reloading the core or assets.
Key scripts contain `milliseconds hex-byte` lines and now support `#` full-line
and inline comments; malformed non-comment lines are rejected. JSON
`ps2_bytes_sent` counts completed simulated serial bytes during this invocation,
not game-accepted keys. The old parser silently stopped at comments, invalidating
several commented-script probes; this was a runner bug, not a proven firmware bug.
`make interactive` builds the delay-aware SDL frontend; `make fast`
builds a clocked, savable SDL model. Example early native boot capture:

```sh
./obj_dir_headless/Vtop --cycles 64000000 --rom ../bios/ipl_x1.hex \
  --disk ../references/software/private-downloads/cross-chase/Xchase_x1.d88 \
  --keys tests/cross_boot.keys --frame obj_dir_headless/native.ppm
```

The game image is an ignored local testing asset, not a bundled release;
see [software provenance](references/software/README.md). A raster of
“IPL is under preparing” is not a successful disk/game boot.
`make -C verilator lint` exposes inherited warnings;
`-Wno-fatal` allows bring-up but does not certify correct wiring.

```sh
make -C verilator clean
```

This removes only the headless build directory. The old `verilator/obj_dir`
contains tracked generated sources and must be preserved.

The old GUI sources and Visual Studio project remain for reference. Their
Makefile path references missing SDL/OpenGL ImGui backends and requires further
repair before it is usable.

## FPGA project

The target is MiSTer's DE10-Nano Cyclone V. The main project records Quartus
17.0/17.0.2; `sharpx1_Q13.qpf` is a historical Quartus 13.1 project.
With the appropriate Quartus tools installed, the main compile invocation is:

```sh
quartus_sh --flow compile sharpx1
```

The installed Apple-container build is available through
`bash scripts/build_quartus.sh`; the initial main-project build completed
synthesis/fitting/assembly but failed timing. Optional single-clock checkpoints
have positive constrained-path timing and a separately observed native hardware
game boot; full timing/hardware signoff remains open. The FPGA top is
`sys_top`; core integration is in `sharpx1.sv`. Add machine dependencies to
`rtl/machine.qip`, shared with simulation; board dependencies belong in `files.qip`.
Quartus output goes into `output_files/`.

The native Linux host `misterubuntu` is also configured; see
[remote build instructions](docs/REMOTE_BUILD_HOST.md). Its helper defaults
to toolchain preflight, with source-hashed builds explicitly requested.
The MiSTer at `mister` is currently reserved by another user; do not deploy
or run hardware tests until it is released.
The subsequently released `mister126` has protected game-test MGLs and
[October 8 hardware/build results](docs/HARDWARE_126_STATUS.md); `mister192`
remains reserved. These checks do not qualify the missing Turbo/Z devices.

Development checkpoints are pushed to
[alanswx/SharpX1_Mister](https://github.com/alanswx/SharpX1_Mister).
The local `alanswx` remote is the default push destination; `origin` retains
the original upstream repository. Private test disks and snapshots are not pushed.

## Repository layout

| Location | Contents |
| --- | --- |
| `sharpx1.sv` | MiSTer HPS, reset, clock, OSD, and video integration. |
| `rtl/` | Machine, CPU, memory, address decode, and sub-CPU RTL. |
| `rtl/legacy/` | Inherited Nise X1 peripherals and original platform code. |
| `rtl/tv80/` | TV80 Z80 implementation used by the newer machine path. |
| `sys/` | MiSTer framework and board support. |
| `bios/` | Existing ROM assets and firmware/reference assembly sources. |
| `verilator/` | Simulation wrapper, headless runner, and historical GUI sources. |
| `docs/SHARP_X1_TODO.md` | Phased bring-up and compatibility checklist. |
| `references/README.md` | Emulator reference locations and retrieval status. |

## Bring-up priorities and references

The simulator timing, memory, loader, graphics bus, firmware keyboard/IRQ and
PSG paths have focused coverage; one native game boots and responds to input.
Next broaden compatibility, verify exact PCG raster/wait timing and floppy edge cases,
and synthesize/test on MiSTer. The
[base machine contract](docs/BASE_X1_CONTRACT.md) records connected interfaces
and current limits.
Turbo features need separate coverage. See the [bring-up checklist](docs/SHARP_X1_TODO.md)
for the remaining work and [AGENTS.md](AGENTS.md) for development guidance.

The existing local MAME checkout is at
`../FM-7_MiSTer_alanswx/refs/mame`; its X1 driver is
`src/mame/sharp/x1.cpp`. It provides a useful behavior reference, with its own
known limitations. X Millennium is now cloned locally under ignored
`references/emulators/` and its Turbo control code inspected.
Both local MAME and an isolated declaration-accommodated X Millennium build
now execute Arcus; their interrupt-policy comparison and limits are recorded
in [the reference investigation](docs/ARCUS_INTERRUPT_STATUS.md).
Neetan remains a candidate reference. See
[reference notes](references/README.md) for links and status.

The sibling `../SharpMZ_MiSTer/verilator/` demonstrates a headless simulation
workflow. Its machine RTL is VHDL and uses GHDL synthesis before Verilator;
this X1 project's Verilog/SystemVerilog sources do not need that conversion.

## Attribution and licensing

The root [LICENSE](LICENSE) contains GPL version 2. Individual inherited files
also carry their own notices. In particular, `rtl/sharpx1_legacy.v` credits
Tatsuyuki Satoh and includes non-commercial and redistribution restrictions.
The root license alone does not resolve those conflicting inherited notices;
their status needs clarification before distributing derived releases.
Preserve file-level attribution and notices when changing source.

Existing BIOS and firmware assets require their own provenance review. Use
appropriately authorized machine images for bring-up and record their origin
and hashes when creating reproducible tests.
