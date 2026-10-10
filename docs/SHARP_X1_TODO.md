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

Held-mode follow-up: complete fitted discovery independently audits 1,584
rows across eight corners and finds the separate native-VID `dv_hs1` csync
consumer (-7.247 ns setup), alongside selected-output and SYS consumers.
Its coherent capture/epoch contract and clock-control fanout need separate
qualification; first-output-edge settling does not cover them. No new
exceptions or broad work-group completion are inferred. See
[the domain inventory](HDMI_MODE_STATUS.md#complete-held-mode-timing-discovery-not-acceptance).
The fresh `3a61604` selected-input flow fails STA when the fitter creates
`gate_request~DUPLICATE`, now driving `gate_request_meta`. No-SDC connectivity
discovery confirms first-stage-only fanout, not sequential equivalence.
Qualify replication prevention or exact physical-source handling before a
new flow; do not weaken the guard or call the failed build timing acceptance.
The new controller narrowly marks `gate_request` with the documented
`dont_replicate` synthesis attribute. Strict source/replica/fanout scope stays
unchanged; local static/negative tests pass. Fresh native and fitted evidence
is required for its new hash, not inherited from previous controller results.
Fresh native 96-case reset and six-profile connected-policy runs now complete
zero; independent current-source/hash audits pass (4,994 exact words and
198 first-edge holds). Eleven invalid policy-evidence controls pass in CI's
audit target. The source-bound `8685be0` full flow is fitting in a new snapshot;
final replica scope/timing and hardware are still open, not inherited passes.
The `8685be0` flow subsequently completes zero but still fails setup -18.201
ns (flow summary, not an independent eight-corner audit); MTBF is not calculated.
The newer experimental-only csync/epoch bridge now echoes the policy consumed
at real CE. Six normal profiles pass 5,030 words/10,273 native HS checks; six
synthetic delayed-policy profiles pass, and the matched epoch-only control
fails early-unblank. Ordinary static policy checks still pass. Fresh stage/
echo/raw-input timing and physical qualification remain open for this newer
framework; it is not a completed Turbo Z work group or a qualified RBF.
A new read-only fitted csync inventory/auditor covers all four new chains,
native HS/CE captures, ready consumers and separate raw/global timing. Its
320-report enumeration and invalid scope/provenance controls pass synthetically
in CI's inventory target. Native results remain pending the active fit; these
test passes do not complete timing or any hardware work group.
The `00cabd4` flow completes zero, still fails setup -18.551 ns, and the
native scope probe rejects a duplicated csync second stage. Connectivity
shows HS and the echo consume different copies. Only that shared sample now
gets replication prevention; repeated normal/skew native checks pass, but
fresh fitting and the strict native inventory must prove the physical repair.
No guard is weakened or failed timing report counted as passing.

The `ce2eba8` fit subsequently completes zero. Its native scope and independent
320-report audit now pass the single-sample topology and 912 synchronous
stage/consumer rows (+19.594/+0.230 ns minimum setup/hold). Raw crossings
remain -9.318 ns setup; global eight-corner setup/hold is -18.327/+0.009 ns.
The replication repair is verified on this fit, but the RBF remains timing-
unqualified and no physical gate is completed. Original artifacts remain
unchanged; see `HDMI_MODE_STATUS.md` for source/hash/provenance and exact scope.

The fresh full held-mode discovery audits 1,936 rows. A separate, unselected
29-pair held-output-mux delay proposal now passes a native before/after probe:
928 budgeted rows (+22.776/+29.856 ns minimum setup/hold), 1,008 other mode rows
and 64 raw input rows unchanged. Its earlier 8 ns/0 ns proposal failed and
remains preserved. The revised relationships derive from tested pre/post
closed-clock windows and installed Quartus latency semantics. Global setup
still fails -12.149 ns at inactive HDMI-to-video-selected data paths; no
ordinary clock-domain cuts or new board selection is made. Qualify clock
selection/closure and inactive data-branch sensitization before acceptance.

The current-fit gate/witness audit now passes 208 bounded rows at eight corners
(+2.148/+0.174 ns setup/hold), with original artifacts unchanged. Six native
inactive-bank-X profiles pass 5,030 known/correct visible-output checks through
existing transitions and blank/flush; a matched raw-selector control fails.
Fitted inactive-bank discovery independently audits 51 physical targets and
848 rows in 32 reports. Wrong-parent/output-alias setup still reports -12.149
and -7.999 ns; no exclusions are applied or board timing acceptance inferred.
Next derive exact clock-qualified pin scope and prove active routes unchanged.

The unselected inactive DATA-pin proposal now passes strict native before/after
auditing: 384 reports, 77 exact cuts, 848 original inactive rows explicitly
excluded (not passed), and 6,400 active/raw/held-mode rows unchanged. The active
HDMI setup violation -0.106 ns is preserved; original artifacts are unchanged.
Its fitted ASDATA packing and failed/intermediate scope probes are recorded
in `HDMI_MODE_STATUS.md`. Qualify this alongside the held-mode proposal before
fresh selection/fitting; no ordinary board, timing or hardware gate is complete.

Joint scope now passes independently: 928 held-mode budget rows, 848 inactive
rows explicitly excluded, and 5,472 other active/raw/mode rows unchanged in
384 native reports. Global setup still fails -10.797 ns at download/reset
gating of PCG RAM write enables; active HDMI -0.106 ns also remains visible.
Only the separate handoff revision now selects the two qualified proposals;
joint diagnostic and ordinary boards stay unchanged. Fresh fit/pin topology,
PCG local-reset/write gating, raw synchronizers and hardware remain next gates.

The PCG reset follow-up now passes all twelve helper clock/window profiles
with accepted stages 1/2 cancelled while VID is stopped. CPU reset release
cannot reopen writes before local VID release, and resumed clocks cannot
replay the cancelled transaction; fresh reads and font retention also pass.
Machine RTL is unchanged. This strengthens the cancellation prerequisite,
not the fitted reset-to-write-enable path or a hardware/timing acceptance
gate. See `PCG_BUNDLE_TIMING_STATUS.md` for exact counts and fixture hash.

The next source repair removes raw CPU-reset qualification of PCG RAM writes
in favor of the existing local VID reset. Ordinary reset behavior is unchanged;
separate-reset callers require coordinated asynchronous assertion. Fresh X3
snapshot continuation and rejection of an actual previous-runner state pass
with distinct revision-3 identity (bit 38). Fresh fitted RAM-WE source/timing
and the full current-machine video matrix remain required; older frozen
matrix results are historical, not qualification of the new source.
The next read-only native check now enumerates all twelve fitted PCG RAM WE
keepers, exact raw/local-reset sources and 64 corner reports. Its mocked
scope/negative regression passes in CI's target; no native timing pass is
claimed. Execute and independently audit it on the next completed fit.

A separate unselected csync input proposal now guards exactly four registered
source-to-first-stage pairs. Its scope tests pass 44 invalid cases without
partial cuts and keep every QSF unchanged. Native before/after preservation,
placement/MTBF and fresh fitting remain required; stage/consumer timing is
not excluded. See `HDMI_MODE_STATUS.md` for the bounded scope and provenance.
Fresh revision-3 X3 pending-CRTC snapshots now pass nine real CPU states and
90 byte-identical continuations with unmodified originals. The separate full
ordinary delay-aware suite is running, not completed; fresh fitting is still
waiting for an idle build host. These checks do not complete the broader
Turbo/Z native or physical acceptance gates.
The separate fresh full ordinary delay-aware suite now completes zero with
143 PASS reports and an unchanged final runner hash. Video/transition,
keyboard/reset, PSG, memory/bus, dual-media and disk/loader/helper checks pass;
this does not replace fresh Turbo/Z pixel, native software or FPGA gates.
The fresh full ordinary fast/snapshot/SDL suite also completes zero with
140 PASS reports and unchanged executable hash. Its eighteen video/transition
reports match the fresh delay-aware run. Five new release-bound native-boot
commercial collectors are now running from a checked frozen input tree;
they are started, not yet gameplay passes. See `BASELINE_V17_STATUS.md`.

Those five current-source collectors subsequently all terminate zero.
Independent inspection verifies thirty native-prefix reports/state hashes,
all original media/ROM/key hashes, six identical executable hashes, successful
control results and Galaga's separate firing result. The full 646-entry frozen
manifest still matches after completion. This closes the fresh ordinary
five-title requalification gate, not Turbo/Z gameplay, whole-game completion
or any physical/timing gate. See `BASELINE_V17_STATUS.md` for exact scope.

The runner now accepts scheduled external A/B joystick events. Focused
real-CPU input, reset, retained-B restore and pending-event save rejection
pass alongside existing clock/key/snapshot checks. Three new continuous
delay-aware Xevious cold boots now complete zero: native start/right movement,
changed RGB, exact repeatability and independently checked unchanged frozen
inputs pass without snapshots. The new full fast suite completes zero with
141 PASS reports; the baseline subsequently completes zero with 144 PASS
reports, unchanged runner and eighteen video/transition cases independently
matching fast. Continuous cold Druaga/Mappy/Galaga runs are now started, not
passed, from a separately checked frozen tree. See
`JOYSTICK_SCHEDULE_STATUS.md`. Other delay-aware titles, native Turbo/Z and
physical gates stay open.
Druaga and Mappy subsequently complete zero and pass independent actual
report/artifact and input audits; Galaga remains live. Together with Xevious,
three continuous delay-aware ordinary action-title controls now pass, not
Shanghai pair removal or native Turbo/Z/hardware acceptance.
Galaga subsequently also completes; all nine native runs, actual artifacts
and the final full frozen manifest pass independent inspection. Four continuous
delay-aware cold movement titles now pass including Xevious. Galaga firing/
travel and Shanghai continuous pair removal remain separate acceptance gates.

Fresh extracted native-policy runs now check 396 held-mode changes while
blanked with a closed output clock, including synthetic delayed-policy cases.
Minimum quiet time is 96,873 ps, above the three-control-period requirement;
independent source/hash audits pass. This strengthens controller evidence,
not fitted timing or hardware acceptance. See the native blank/closed-clock
section in `HDMI_MODE_STATUS.md`; the broad work groups remain incomplete.

The experimental [coherent CRTC transport](CRTC_WRITE_CDC_STATUS.md) now
passes four helper clock ratios, three real-CPU clock ratios, five owned-DMA
reset scenarios and all sixteen delay-aware X3 pixel cases. CPU/DMA WAIT
acknowledges actual MPU consumption, not merely packet capture. A missing
fixed-destination two-LOAD sequence in the new diagnostic was corrected;
DMA RTL was not changed. The baseline transcript reaches its final fixture
with 143 PASS reports; its outer exit status was lost during a tool reset and
is not invented. The PCG-replica follow-up full flow completes zero but still
fails reported setup -12.003 ns. The native CRTC follow-up resolves Quartus
name-expanded replica fanout using exact physical collections, retains all
MPU replicas, and qualifies the local video reset source. Independent auditing
passes 192 reports/43,056 synchronous rows (minimum +0.218 ns) and 144 held
packet rows (maximum physical delay 0.999 ns). Raw request/ACK input timing,
MTBF/placement and whole-core timing remain open; no qualified RBF is claimed.
The unselected nine-pair packet candidate passes a completed-fit before/after
probe: +1.120 ns constrained minimum, identical physical delay and unchanged
raw input reports. Global eight-corner setup/hold remain -12.003/-0.003 ns;
HDMI-OSD to video-selected output paths dominate. Mode-aware routing and a
fresh selected-candidate fit remain next, not whole-domain exclusions.
The [HDMI mode investigation](HDMI_MODE_STATUS.md) now passes 72 actual-source
static-policy cases and confirms fitted cfg10/cfg12 selector routing. The
conventional case-analysis call fails native Quartus; no mode timing or
safe-switching pass is inferred from command presence or static simulation.
Native follow-up explicitly reports case analysis unsupported. The local Main
reference toggles framebuffer mode at runtime, so fixed-until-reload timing
assumptions are invalid. Installed Intel primitive simulation now runs using
project-local verified ABI5 dependencies: 48 steady checks pass, while
asynchronous switch diagnostics produce two off-source rising edges and
three shortened intervals in the model, independently confirmed from VCD.
A device-supported safe clock/data handoff remains implementation work;
these observations are not measured physical glitches or a qualified RBF.
The simulation-only falling-edge ALTCLKCTRL candidate now passes eighteen
running/stopped-source native-model cases and independent waveform audits.
The requested selector is not an active-clock acknowledgement; coordinated
data selection/blanking, repeated requests, startup/reset, FPGA integration
and physical output remain open. No board default or RBF changes yet.
An unselected acknowledged handoff sequencer now passes twelve native-model
tagged-data cases, including stopped-high/low sources, queued reversal and
runtime reset. The raw-mode negative fails with verified exit 1. Actual
framework/OSD/DDR integration, reset-at-each-phase, placement/timing and
physical output remain required; this diagnostic is not an implemented
board fix. See [the handoff evidence](HDMI_MODE_STATUS.md).
The default-off `X1_HDMI_HANDOFF_EXPERIMENT` now connects held clock/data/csync
selection and transition blanking in the actual framework. A fresh post-switch
generation and actual `ce_pix`/DV epoch prevent premature unblanking. Twelve
native helper profiles and six extracted-register profiles (4,826 exact words)
pass; the actual raw-policy negative fails with exit 1. Default 72-case policy
checks still pass. No board QSF enables it, no new RBF exists, and full upstream
video/DDR/PHY, mapped/fitted clock controls, reset-phase and hardware gates
remain open. Old mux constraints require explicit new-hierarchy qualification.
The isolated real-PLL handoff harness now maps/fits, exposing input-side
`enaout` feedback in the fitted topology. An explicit falling-edge witness and
selected-clock enable synchronizer replace that assumption; twelve native
clock/tag cases and six exact-policy cases (4,923 words) pass, including a
stop-HIGH-before-closure test. Narrow mux-output clock choices pass twelve
bounded timing rows at one corner; raw/global setup and hold remain open.
Full fitted gate semantics, eight corners, startup/placement and board/DDR/I/O
qualification are still required. No handoff-enabled QSF/RBF exists yet.
The frozen isolated fit now passes all 96 bounded enable/witness/native-gate
rows at eight corners; stage-chain hold minimum is +0.121 ns. Raw/global
timing still fails. The emitted functional-only netlist preserves falling-edge/
low-power-up gate parameters and inverted-clock witness; it is not a routed
timing simulation or physical acknowledgement proof. Full-board default
148.5 MHz HDMI, resource/initialization/CDC/DDR/I/O and hardware gates remain
required; isolated 74.25 MHz probe fitting does not qualify them.
The separate `sharpx1_turbo_z_handoff` full-board qualification revision now
enables the handoff while existing revisions stay disabled. Static feature/
constraint isolation and eighteen new invalid mux-scope controls pass;
native scope acceptance, full flow/timing and physical results remain open.
Its `4800715` source-bound full flow completes zero on `misterubuntu` in
`quartus-linux-O40JuhMa`, but fails setup -46.374 ns (hold minimum +0.210 ns).
The produced RBF predates two subsequent reset/epoch fixes and is unqualified.
Reset can now leave video while CE-qualified readiness is stopped; a later
video retry drains the outstanding epoch instead of accepting stale completion.
All 96 native reset-phase/rate/readiness cases, twelve native clock-handoff
profiles and six connected policy profiles (4,994 exact words) pass. Fresh
corrected-source fitting/timing, full upstream and physical acceptance remain
required. Hardware has not been touched.
The corrected `d8f7024` full-board flow finishes zero; its eight-corner native
inventory and independent audit pass 208 bounded handoff stage/witness/native-
gate rows (setup/hold minima +1.015/+0.285 ns), exact first-stage fanout and
unchanged source/original artifact hashes. Original-constraint global setup/
hold still fail -47.082/-1.806 ns; the RBF remains unqualified. No new timing
exceptions are applied. Raw first-stage inputs, held mode/data, MTBF/I/O and
physical output remain next, alongside the still-running combined-Z matrix.
A first-stage-only candidate passes a completed-fit eight-corner before/after
probe: 416 unchanged positive chain/witness/gate rows, 192 original raw rows,
96 excluded input reports and 232 unchanged held-mode rows. Global setup/hold
still fail -18.252/-0.062 ns after the candidate. The original driver guard
failed safely because default fan-in traversal included clock-select edges;
the native documented synchronous-data query resolves that distinction.
Only the separate handoff revision selects the guarded six-input candidate.
Final comment-adjusted bytes pass the fresh v3 native probe and independent
source/row audit; fresh native map/fit/MTBF,
remaining output-data timing and physical acceptance are still required.
Nine actual pending-transaction snapshots pass ninety byte-identical
continuations; cold-start/clock guards remain tested. Fresh combined-Z
pixels, current-source Quartus bundle/consumer timing and native/hardware
qualification remain open; no broad goal work group is complete.

The experimental X3 [blink crossing](VIDEO_BLINK_CDC_STATUS.md) now samples
the real sub-CPU held level in the video domain. Four delay-aware blink pixel
cases, helper reset/latency controls, snapshot rejection/continuation and
connected combined-Z reset checks pass. All five ordinary commercial titles
finish fresh bounded gameplay checks. Full delay-aware baseline plus blink
helper finishes zero (149 PASS reports); the older combined matrix is
historical for this new RTL. Fresh
FPGA fitting/timing, current combined pixels and native/physical gates remain
required. This does not complete any broad work group.
The blink-source `6e334b4` fit now finishes zero. Independent native blink
inventory/timing checks pass all 12,080 reported synchronous rows at eight
corners, including all 85 final consumer keepers. Raw input remains open;
the full global audit still fails setup −12.162 ns despite positive reported
hold/recovery/removal/pulse-width minima. The current 120-case matrix and
physical/native acceptance are not established by those bounded paths.
Next timing work must address actual CRTC MPU-register SYS-to-VID transfers
(`R_Nadj`/`R_Nr`) and raw reset/control consumers, alongside mode-aware HDMI
output routing and scaler data contracts. Synchronizing each bit independently
or cutting whole clock domains does not establish coherent register updates.

The experimental [SYS VSYNC increment](VSYNC_SYS_CDC_STATUS.md) adds two-stage
sampling before frame-wait/configuration consumers. Nine local clock pairs
pass; raw/one-stage controls fail. Ordinary revisions and other VSYNC domains
remain unchanged. Fresh fitted inventory/timing, pulse/physical and native
acceptance remain open; this is not completion of the Turbo Z work group.
The `e32bd69` full flow now finishes zero, and all 80 reported VSYNC
chain/consumer rows pass eight-corner setup/hold. Raw stage-zero input timing
remains open. PCG/snapshot and reported scaler paths pass local audits;
global setup/hold still fail −46.112/−1.800 ns. The RBF is unqualified and
native/physical/full-feature gates remain open.
The unselected VSYNC input-only probe now preserves all 48 synchronous
report pairs and reports hold +0.017 ns; setup still fails −12.017 ns.
Actual early-map scope validation now passes in a hash-matching unfitted copy;
the misleading ignored `-post_map` attempt is explicitly not counted. Only
experimental Z selects the guarded source-to-stage-zero data input for a fresh
fit. Setup, physical/native and all remaining feature gates remain open.
The selected-scope `caf15d3` full flow finishes zero in its new frozen folder.
All 80 reported VSYNC synchronous rows pass; PCG and scaler-release audits
also pass. Overall eight-corner setup/hold still fail −11.927/−0.985 ns.
Its unqualified RBF predates the blink correction; no physical/native
acceptance is inferred from either fit or simulation.
The [expanded combined diagnostic matrix](TURBO_Z_COMBINED_STATUS.md#expanded-combined-diagnostic-matrix-started-not-yet-qualified)
now schedules 120 cold/warm, identity/custom, bank/priority/text/reverse cases
on the frozen ownership-corrected runner. Enumeration passes; actual execution
has started, not completed. Native Z and hardware gates remain separate.

The shared-SIO increment now requalifies all five commercial titles from fresh v15
native boot: Druaga, Xevious, Mappy and Galaga movement, Galaga firing, and
Shanghai cursor/matching-pair removal. Exact RGB/dump/state/report and private
input-preservation checks pass on the frozen ordinary fast runner
(`f484bede6fde9a1f0bbba6ff30b6f5727c05041762a5b6179520b3b094e987f9`); see
[commercial evidence](COMMERCIAL_COMPATIBILITY.md). This is not native Turbo,
Arcus/Bastard Special, delay-aware or new-RBF hardware acceptance. The earlier
`9748410` checkpoint's Turbo single-clock RBF fits and passes all eight constrained
timing corners; deployment/physical gates remain open. The latest `0009dd1`
Turbo single-clock refit also completes and passes all eight constrained
corners, producing the identical RBF; SIO and Turbo Z remain disabled in it.
Unconstrained I/O remains. See [the refit audit](SIO_MACHINE_STATUS.md#completed-source-bound-refit).
The [SIO asynchronous ×1 increment](SIO_X1_STATUS.md) adds external
bit-synchronization behavior; ×1 fractional-stop and native timing are still
required before full serial acceptance.
The [FM decoder increment](FM_DECODE_STATUS.md) connects conservative exact-port
selection to the real CPU/JT51 fixture and exhausts bus-control isolation;
the [shared FM CPU-bus increment](FM_MACHINE_STATUS.md) now passes generated
IPL busy/status/WAIT, actual PPI DAM, real DMA and retained-reset checks at
three clocks. Native IRQ and full FM hardware remain open.
The standalone [signed PSG/mixer foundation](PSG_FM_MIX_STATUS.md) passes
independent scalar DC/CE/reset/stereo/mono saturation checks. Its sample-aligned
output now passes genuine concurrent JT49/JT51 waveform, pitch/panning and
reset-repeatability tests at three master frequencies. The [shared signed audio
path](FM_MACHINE_AUDIO_STATUS.md) now passes actual CPU-programmed cold/warm
captures and C++ stereo WAV checks; native IRQ/analog/hardware remain open.
Current ordinary snapshots require v17; direct continuation/old-v16 rejection
passes. The [live FM/audio owned-DMA reset fixture](FM_OWNED_RESET_STATUS.md)
also passes at three clocks, including a failing premature-audio-reset control;
owned disk-host/mixed-service and physical reset gates remain open. The
live-FM [pending-SD reset matrix](FM_SD_RESET_STATUS.md) now passes all sixteen
payload cases with generated media, alongside sixteen FM-disabled controls.
Its expanded 48-case metadata/split-header matrix also finishes zero, giving
64 completed live-FM pending-host cases. Partial payload/Ready loss,
mixed-service and native/physical gates remain open.
The [partial CPU disk reset test](CPU_PARTIAL_DISK_RESET_STATUS.md) now passes
24 A/B read/write held/short cases with live FM at 1/64/255 bytes, unchanged
pre-retry images and 256 fresh CPU bytes. Profiles
without the DMA reset guard now also pass twelve held-reset A/B/read/write
cases at those three boundaries. Other byte boundaries, bare-base/sub-cycle reset, Ready loss and
physical/native gates stay open.
The [experimental combined Z FPGA profile](TURBO_Z_BOARD_BUILD_STATUS.md)
now exposes the existing palette/multi-mode/text paths for separate fitting;
wrapper lint passes. Its full Quartus flow completes but reports negative
setup/recovery; this is not timing or native/physical acceptance. Combined
control/reset and all six selected custom/warm pixel cases pass (704,000 exact
pixels); the complete combined cold/identity/front/order matrix remains open. See
[combined-profile evidence](TURBO_Z_COMBINED_STATUS.md).
The subsequent [ownership reset correction](TURBO_Z_OWNER_RESET_STATUS.md)
removes cross-domain reset-release feedback and passes three-clock connected
RAM/stopped-clock tests, including a failing raw-release control. All six fresh
custom/warm combined pixel cases also pass, with exact PPM and frozen-input checks.
The new fit completes but eight-corner timing fails setup/recovery/hold.
The scoped mux probe preserves same-clock HDMI and both SYS/VID CDC failures;
the hold path is a held video-measurement snapshot bundle. Production constraint
review and native/physical acceptance remain open. The fresh full delay-aware
baseline finishes zero (140 PASS reports); fresh ordinary snapshots pass,
and both ordinary runners are byte-identical to their previously qualified v17 builds.
The [bounded dimensions snapshot constraint](TURBO_Z_SNAPSHOT_TIMING_STATUS.md)
now checks the real two-period protocol window and passes 72-bit payload
setup/hold at eight prior-fit corners. It is selected only by the experimental
Z QSF; fresh map/fit and eight-corner payload checks now pass, while global
setup/recovery/hold and remaining CDC/HDMI/native/physical gates remain open.
The [PCG bundle-window audit](PCG_BUNDLE_TIMING_STATUS.md) now measures real
request/response consumption and accepted-field stability in base and Turbo
fixtures, including six high-speed SYS=32 MHz cases. All existing PCG/font/reset checks pass; bounded FPGA payload,
synchronizer and native/physical acceptance remain open.
The completed-fit response-bound experiment passes all eight corners; expanded
request reconnaissance identifies 293 VID and 154 SYS paths per check,
including physical PCG RAM data/write-enable replication. Request constraints,
source-bound refit and full PCG timing/hardware qualification remain open.
Both request and response bounds now pass completed-fit eight-corner probes;
the first integrated refit fails the strict request inventory gate because
early RAM endpoints differ. Request selection is withdrawn pending a verified
early/fitted endpoint contract; response selection remains experimental-Z-only.
A fresh fit/all-corner audit are required; machine RTL remains unchanged.
The follow-up validates explicit mapped/fitted request profiles in native
Quartus and rechecks all 4,688 fitted request paths at eight corners. Forty-eight
invalid inventories refuse all bounds. Experimental Z request selection is
restored for a new full flow; fresh-fit/hardware qualification remains open.
The `3dc3727` refit fits successfully but final STA fails the response inventory
gate on same-bit CPU capture replicas. Fitter reports confirm bits 0/3 cloned;
revised native inventories include all ten captures. New full flow/all-corner
qualification remains required; its generated RBF is unqualified.
The subsequent `67de103` full flow completes zero with the replica-aware
guards. Eight-corner PCG and snapshot payload audits now pass, including both
CPU capture replicas. Global setup/hold/recovery still fail; original artifacts
are preserved, and no
timing-qualified or hardware/native Turbo Z claim is made.
The [reset-input experiment](VIDEO_RESET_TIMING_EXPERIMENT.md) preserves both
stage-transfer paths and all 341 reported downstream release paths per corner.
Only four validated core asynchronous input pins are selected by experimental
Z; fresh-fit/physical qualification remains open. Scaler recovery and HDMI
routing still fail and are not masked by this scope.
Source inspection identifies three separate single-stage scaler reset releases;
the [reporting-only scaler audit](SCALER_RESET_TIMING_AUDIT.md) prepares
eight-corner input/downstream checks without new exceptions. Native execution
and any framework correction remain open.
The selected-input `89f8226` fresh flow now completes zero. PCG (nine captures),
snapshot and reported core release paths pass eight-corner local audits;
global setup/recovery remain −15.158/−4.881 ns, with hold now +0.059 ns.
The native scaler audit exposes 32 empty raw-input reports from inherited
clock groups, not passes. Full CDC/reset/HDMI and native/hardware acceptance
remain open; see the latest [fresh-fit evidence](VIDEO_RESET_TIMING_EXPERIMENT.md#fresh-selected-constraint-fit).
The next experimental scaler increment adds independent two-edge releases
for input-video, HDMI and Avalon, preserving the default legacy branch.
Actual-helper GHDL tests at four clocks and one-edge failing control pass;
the modified scaler analyzes. No added timing cut; fresh FPGA inventory,
timing, raw-crossing review and physical acceptance remain open. See
[scaler increment](SCALER_RESET_TIMING_AUDIT.md#experimental-destination-local-release-increment).
The first local-release flow fits/assembles but final STA rejects the old
mandatory PCG stage replica. Native inventory confirms six scaler stages/
six raw input pins and an unreplicated PCG state profile. Revised strict
35/36-endpoint guard passes native syntax and 84 negative controls; fresh
flow, all-corner timing/report coverage and physical/native gates remain open.
The corrected `ed3c332` flow now completes zero. Native PCG unreplicated
profile and snapshot payload pass all-corner audits; six scaler stage-chain
and reported downstream releases pass. Global setup/hold/recovery still fail
−15.064/−0.033/−4.835 ns; raw reset coverage, real HDMI routing, other CDC/I/O
and native/hardware acceptance remain open. The unselected exact mux candidate
executes successfully but preserves real failures, not a timing-pass claim.
The six-pin scaler reset probe now preserves all 96 stage/downstream report
pairs at eight corners, with constrained global recovery minimum +4.280 ns.
Mapped scope also validates. Only experimental Z selects those exact raw
pins and the independently scoped mux aliases for a fresh fit; no RTL change.
Setup/hold, CDC/I/O, physical reset/mode switching and native/hardware gates
remain open; do not treat the experiment as a qualified RBF.
The selected `6133f27` refit now completes: PCG/snapshot and reported scaler
stage/downstream paths pass; constrained global recovery is +4.375 ns.
Setup/hold remain −47.729/−1.275 ns with newly visible raw VSYNC SYS samplers.
Active master-to-own-mux-alias and internal HDMI paths report positive, but
CDC/input-stage scope, inactive mode branches, I/O and physical/native gates
remain open. Fresh full ordinary local suite finishes zero (143 PASS reports),
not a new Turbo Z/game/hardware claim.
The [Turbo Z in-flight control reset test](TURBO_Z_INFLIGHT_RESET_STATUS.md)
passes at three independent video rates, including a deliberately failing
asynchronous-reset-removal control. Exact reset frames, pending palette/
DMA traffic and native/physical acceptance remain separate gates.
The full v17 fast suite finishes zero with 137 PASS reports.
The delay-aware suite finishes zero with 140 PASS reports, and all five fresh
native game qualifications pass on frozen source/inputs, including Galaga
firing; see [v17 acceptance](BASELINE_V17_STATUS.md).
The separate [FM-enabled FPGA revision](FM_BOARD_BUILD_STATUS.md) fits and
passes all eight constrained corners; unconstrained I/O and physical/native
FM gates stay open. No MiSTer is loaded.
Historical v16 full fast suite, direct snapshots
and fresh five-game native qualification pass. The delay-aware baseline also
passes (140 PASS reports). The `832766f` refit completes with positive reported
Slow 1100 mV 100 C timing; supplemental corners and unconstrained I/O remain
open. See [the current audit](FM_MACHINE_STATUS.md#completed-source-bound-refit).
Earlier v15 passes above remain
source-bound history, not acceptance of those new runners.

The [DMA-build hardware feature matrix](HARDWARE_DMA_FEATURE_MATRIX_STATUS.md)
records six exact 40/80-column graphics/text/PCG cases before and after warm
reset on the separately fitted DMA revision, six native reset/input observations
and both bounded actual OSD reset entries. Full-device, native-gameplay,
writable/owned-SD reset, audio/physical-input and Turbo Z gates remain open.

The [Turbo Z palette storage foundation](TURBO_Z_PALETTE_STORAGE_STATUS.md)
now passes nine independent-clock/accepted-enable profiles, each exhausting
4096 addresses, three components and sixteen nibble values. It is standalone:
native ASIC registers, arbitration, renderer integration and combined-machine/
hardware palette qualification remain open. Its standalone Quartus probe now
fits in six M10Ks and 39 ALMs. New technical-book programming diagrams
corroborate full index packing but introduce an APEN/APRD gating conflict.
The subsequently retrieved screen-display chapter supplies repeated normal
`80h` write / `88h` selector/read setup examples, so that sequence now has
primary programming support. It also requires power-on palette defaults,
retention across IPL reset and fixed-black text entry zero. These are new
integration requirements; external RAM cold identity is now implemented and
passes all-address pre-write CPU/video checks at nine clock/enable profiles,
with retained reset and an intentionally failing wrong-green-image control.
Its fresh Apple Quartus fit retains six M10Ks/39 ALMs; all 12,288 generated
initialization nibbles are audited against the cold-image oracle. Earlier native
17.0.2 evidence binds the prior uninitialized storage, not this extension.
Native registers/internal/text palettes remain unimplemented; inactive modes, precise
index/bank/WAIT policy and some inconsistent listing literals remain open.
See the [updated contract audit](TURBO_Z_PALETTE_CONTRACT.md). Z2 and the
Turbo Z work group are not done.
The separate [external-palette bus adapter](TURBO_Z_PALETTE_ACCESS_STATUS.md)
now connects frozen selector/write/read transactions to the real RAM in
diagnostics. Native control decode, upper input bits, actual CPU/DMA/beam
ownership and rendering still need integration. An opt-in
[CPU-only palette profile](TURBO_Z_PALETTE_CPU_STATUS.md) now passes actual Z80
cold/read/write/dummy-selector and retained warm-reset tests at 19 boundary
indices across all components. The unchanged diagnostic fails as expected
with the feature disabled. Full native decode, DMA/beam arbitration and
rendering remain open; ordinary profiles and RBFs are not enabled.
The [sequential GRAM buffer](TURBO_Z_GRAM_FETCH_STATUS.md) passes all base
addresses/five source layouts/pages/parities using real component RAM at three
clock ratios, including exact latency/reset seams and a wrong-bank negative
control. Connect it to native CRTC addressing, pixel serialization and palette
arbitration; this standalone gate does not complete Z3.
The full delay-aware baseline suite also exits zero after the CPU-palette
integration (`fe734f1`); its frozen ordinary-profile runner remains unchanged.
This is local diagnostic evidence, not optional-device or hardware acceptance.
The [palette ownership follow-up](TURBO_Z_PALETTE_OWNER_STATUS.md) corrects the
CPU experiment's C6 polarity (40 columns is C6=1), adds a connected blank-window
lease/drain, and passes original real-CRTC CPU cold/warm waits. The retained
read-tail fix closes a reproduced late-IN failure without changing its ROM;
the extra-store diagnostic's phase-dependent pass is not substituted for it.
Analog pixels, DMA/native ASIC timing and hardware still remain open.
The [connected 4096-color prototype](TURBO_Z_VIDEO_STATUS.md) now compiles and
passes all-address/eight-pixel/twelve-bit shifter checks at three clock rates.
Actual CPU-written identity-palette pixels now pass all 64,000 pixels and
line/frame periods. Custom-palette and retained warm reset are being qualified;
the initial DAM/width failure and early custom/reset failure are preserved.
No complete multi-mode/native/hardware gate is marked complete from this case.
Custom-palette cold pixels also pass. Both retained-reset captures reproduce
seven pixels corrupted by PPI mode-set at aliased GRAM `1A03h`; the
[transaction-bound DAM correction](DAM_TRANSACTION_STATUS.md) passes standalone
and actual-CPU regressions. Fixed identity/custom retained-reset pixels each
pass all 64,000 pixels, with post-reset I/O proving no refill. The new complete
baseline is in progress. Current snapshots require v13; prior v12 qualifications remain
source-bound history, not acceptance of this pending-state change.
The subsequent [palette pin reconciliation](TURBO_Z_PALETTE_CONTRACT.md#cpudisplay-pin-reconciliation-table-4-22)
corrects the renderer/oracle's shared reversed-significance assumption.
All 4096 connected GRAM/fetch/shifter/palette indices and corrected identity
CPU retained-reset pixels pass, including corrected custom-palette pixels.
Pre-correction images prove internal agreement only, not the physical pin map.
The preceding default v13 baseline suite exits zero. A separate
[multi-mode experiment](TURBO_Z_MULTIMODE_STATUS.md) adds coherent controls,
wide/tall/selected-screen fetch and explicit provisional reduced expansion.
All-address/five-layout and held-request live-control mutation checks pass.
Wide/tall custom-palette and selected-screen 0/1 retained-reset CPU pixels
pass; the complete sixteen-case frozen reduced matrix also exits zero, with
all sixteen identity/custom cold/warm cases passing. Corrected
full-color identity/custom cold/warm matrix and current default-source
timing/GRAM/DAM checks finish successfully.
Native reduced CPU bank policy, composition and native internal-palette acceptance remain open.
The separate [640x400 internal-palette extension](TURBO_Z_INTERNAL8_STATUS.md)
now connects eight-entry storage and actual CPU writes/selector reads. Identity
and custom retained-reset captures each pass all 256,000 pixels, as does a
custom cold cross-store isolation case. Exhaustive alias/nibble/reset units
and captured shifter tags pass. The stronger four individual cold/warm
identity/custom isolation cases subsequently all finish with exit zero.
Native priority, live switches/reset races and hardware remain; Z2/Z3 and
the work groups are not complete.

The separate [text-palette CPU increment](TURBO_Z_TEXT_PALETTE_STATUS.md)
passes all nine unit profiles and five frozen actual-CPU cases (modes 80h/90h,
cold/warm, disabled negative). Seven writable six-bit entries, fixed black
zero, DAM isolation and reset retention are covered. Analog text RGB,
intensity pin order, `1FC0` priority and native/hardware qualification remain
open; this does not complete Z2/Z4 or change board defaults.
The [paired-screen fetch/shifter increment](TURBO_Z_PRIORITY_CONTRACT.md#executed-paired-screen-fetchshifter-increment)
passes nine clock/profile gates, all base addresses and all 64x64 independent
color pairs. It retains two distinct indices; the shared machine still leaves
the second unconnected. CPU priority registers, dual-screen composition,
opacity/text RGB and native/hardware acceptance remain unfinished.
The subsequent [CPU priority/ordering increment](TURBO_Z_PRIORITY_CPU_STATUS.md)
passes `1FC0` all-byte, exact-decode/text/DAM/inactive/reset tests through the
shared Z80, three held-strobe unit profiles and 16,384 ordering cases. The
original oracle rejects substituting text-on-top for between-screen text.
The existing text CPU controls still pass. Priority now crosses in the held
mode/bank/blackclip/width payload; actual-CPU all-byte cold/warm tests and
physically stopped SYS/VID recovery pass at three video clocks. Rendered
composition/opacity, native reset/readback and hardware remain open.
The subsequent [paired graphics connection](TURBO_Z_PAIRED_VIDEO_STATUS.md)
admits both banks and selects a captured-priority index before palette lookup,
behind the combined opt-in profile. Its first 64,000-pixel case passes;
the remaining pixel matrices are in progress, not a completed acceptance gate.
Opaque/analog text, native reduced banks/opacity and hardware remain open.
The [analog text follow-up](TURBO_Z_TEXT_COMPOSITION_STATUS.md) now builds and
connects actual glyph presence to paired ordering; the first 64,000-pixel
between-screen text case passes, with wider cold/warm tests running. Fresh v14 ordinary snapshot/old-version rejection and
focused default timing/GRAM/DAM checks pass. Native intensity, opacity,
attribute/blackclip and hardware gates remain open; v13 results stay historical.
The [single-screen text increment](TURBO_Z_SINGLE_TEXT_STATUS.md) now builds
and passes focused control/order/wrapper gates for captured 320x200 layouts;
initial full/selected-screen probes each pass 64,000 pixels; the wider matrix
and full v14 baseline are running. It does not extend the
low-scan priority rule to 640/400-line formats or close native/hardware gates.
The [reverse-text extension](TURBO_Z_REVERSE_TEXT_STATUS.md) passes a real CPU
64,000-pixel custom/text-between warm case, including source opacity and
retained palettes/VRAM. This is bounded attribute coverage, not full Z4.
The [full default v14 baseline](BASELINE_V14_STATUS.md) now exits zero.
The [opacity coverage audit](TURBO_Z_TEXT_OPACITY_COVERAGE.md) finds missing
selected text in older full/paired graphics-on-top scenes; corrected CPU
windows and all-seven-color full/paired warm gates now pass 64,000 pixels each.
The strengthened twelve-case paired-text matrix now terminates zero,
including seven distinct entries and selected text beneath graphics;
strengthened single-text matrix now terminates zero (16/16, with independent
PPM byte comparisons); the strengthened graphics matrix also terminates zero
(24/24, independent PPM and frozen runner/fixture/program hash checks). Do not promote
those earlier passes to beneath-graphics text acceptance or native Z completion.

The expanded [hosted diagnostic run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37865161650)
now completes successfully on `95c3e4a`. The newer `99eb141` palette-RAM/
hardware-runner targets have their own hosted run still in progress when
last checked, as does run `37879886647` on `86d21eb`; new probe-script checks likewise need their source-bound CI
result. These are asset-free local/hosted gates, not complete native hardware
or Turbo Z acceptance.

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
| 1. SIO | Owned serial read/write reset drain, idle Send Break, active-character Transmit Enable drain/queued resume, functional WR3 CTS/DCD automatic gating, asynchronous RTS drain, table-28 five-or-less TX encoding and 12 actual-CPU stopped-CE ACK/handler/FIFO/RETI chip-reset cases pass separately; add short-frame/modem/IRQ/Ready combinations, channel/short-pulse and concurrent multi-device reset service; trace schematic clocks/modem/Ready/decode before opt-in shared-machine integration; finish remaining modes and native serial diagnostics |
| 2. DMA | Reset/video/restart/comparison, search/stop and actual-CPU fast/delay-aware profiles pass; opt-in completion/restart IRQ has shared-machine IM2/HALT/RETI and snapshot acceptance; broaden concurrent-service/reset/savable gates, integrate Ready/mixed restart IRQ and variable timing, resolve sequential non-Byte stop; broaden payload/Ready/DAM/native Turbo IPL and hardware acceptance |
| 3. Kanji/Turbo video | CPU latch/ROM/glyph paths with synthetic fixtures, then authorized native fonts; complete attribute/PCG/text combinations, ASIC behavior and native Turbo/400-line software |
| 4. Timing/hardware | Narrow audited CDC/reset/mux constraints, current-source Quartus refit and positive setup/hold/recovery; hardware bandwidth/video/audio and Main/OSD reset verification |
| 5. Disk/software | Format/density/HD/media-change contracts; native metadata qualification; Arcus/Bastard playability; delay-aware and hardware game matrix |
| 6. Base completeness/CI | Asset-free diagnostic CI now passes hosted execution; finish keyboard/sub-CPU, cassette and PPI functions; exact PCG/scanline/audio fidelity; BASIC compatibility and provenance |
| 7. Turbo Z | RGB12 output/capture foundation passes exhaustive capture/wrapper and snapshot checks; implement/qualify Z0–Z9 model, palette/multi-mode, text, FM, HD, Kanji/devices, capture and native/hardware gates |

No legacy notices or private assets may be removed/bundled to claim completion.
The [standalone SIO chain bridge](SIO_CHAIN_STATUS.md) now exports actual SIO
IUS and checks nested SIO/DMA/CTC returns, held-vector/channel-reset ownership
and stale-ACK quarantine. Its first downstream service models are synthetic;
subsequent real SIO/DMA/CTC and actual-CPU nested IM2 fixtures pass at CE=1/4/7,
including stopped-CE concurrent service reset and retained-program reboot.
The subsequent [shared-machine increment](SIO_MACHINE_STATUS.md) now passes
generated IPL CPU/RX/WAIT/nested IM2 and retained reset with DMA present/absent.
Broader reset phases, native clocks/pins/software, enabled snapshots and FPGA
integration remain open. Ordinary profiles remain disabled; snapshots now
require v15 and older private states must be regenerated, never converted.
The [October 9 SIO machine-wiring audit](SIO_MACHINE_WIRING_AUDIT.md) now
records actual SIO/0 bus/clock pins, DTRB-controlled A clock selection,
mouse-related B controls, model-specific carrier inputs and the absence of a
traced SIO-to-DMA Ready connection. Finish internal clock/ASIC routes and
native event-adapter integration, then real CPU decode/shared daisy service
and pin-driven mouse/serial acceptance. This research does not connect SIO
or complete group 1/Z7.
The [standalone event adapter](SIO_EDGE_CLOCK_STATUS.md) now passes nine
queue-oracle and 36 real CTC/SIO clock/CE profiles, plus the required lost-event
negative control. Native selector/pin CDC and shared-machine integration remain
open; this does not alter default machine RTL or the current RBF.
The CZ-851 clock-selector polarity and all 16 pin-level combinations now pass,
including real SIO DTRB writes in the 36 CTC/SIO profiles. The enlarged CZ-880
scan shows a different/possibly mislabelled alternate input route; the
[updated wiring audit](SIO_MACHINE_WIRING_AUDIT.md) withdraws the previous
common-internal-source implication. Finish that native model distinction,
pin waveform and CDC before connecting the shared machine. Subsequent
contiguous CZ-851 sheet-1 tracing now establishes CTC1-to-A-alternate and
CTC2-to-B. The original route module passes 128 exhaustive net truth cases
and 36 real distinct-rate CTC/SIO profiles, including stopped-CTC1 A isolation
with B continuing. This resolves earlier-board routing, not native pulse width,
CZ-880 routing, shared CPU/daisy integration or full work group 1/Z7.
The [CTC phase audit](CTC_PIN_TIMING_AUDIT.md) now confirms separate clock
polarities for ZC rise/fall. Implement/qualify explicit two-phase enables,
counter trigger sampling and native duration; a next-rising-CE prototype was
withdrawn despite passing its own tests. No waveform or integration gate is
marked complete from that prototype.
The [SIO decode increment](SIO_DECODE_STATUS.md) now passes 8,388,608 exhaustive
address/control cases, nine real CPU neighboring/DAM/disabled profiles and
three intended-failure controls. Existing nine CPU IRQ/flow and twelve
stopped-CE service/reset profiles pass with the decoder. It remains standalone;
connect and qualify the default-disabled shared-machine profile, response
retention and shared ACK/RETI ownership before claiming native SIO or group 1.
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

## Phase 5 — Turbo Z (partial foundations; native acceptance open)

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
  Original real-CPU EC..EF diagnostics now reproduce the missing clock tick
  after exact command storage/readback; see `RTC_COMMAND_STATUS.md`. A primary
  NEC reference is retained locally. No running/battery-backed RTC is implemented
  by this investigation; delay-aware/probe/default-rejection checks now finish
  and independently confirm the defect without falsely accepting an RTC.
  A new native-calendar arithmetic backend passes exhaustive seconds/date/
  weekday and invalid-alias checks; oscillator, serial command/MCU integration,
  year handling and persistence remain open, so elapsed-time acceptance still fails.
  An independent normal-mode counter backend now passes 1,201,499 SYS-edge
  checks and three negative controls. It still needs a crystal-event producer,
  serial/MCU integration and physical/storage qualification; it is not an RTC
  enabled on any existing machine/board profile.
  The board's exact P1/T1 serial routing is now traced; a standalone frontend
  passes 137,050 scaled SYS edges and three wrong-pin controls. C2/TP are
  grounded on CZ-880. Connect a crystal-event producer and verified controller
  driver (the inherited MR16 ROM has only 22 bytes free), then require unchanged
  real-CPU elapsed-time acceptance. Serial unit tests do not close Z7.
- [ ] Research/implement capture quantization/inversion, mosaic, chroma key,
  extra scroll and superimpose/telopper, with a deterministic test video source.
  Primary encodings and a standalone decoder now pass exhaustive local checks;
  see `TURBO_Z_EFFECT_CONTROL_STATUS.md`. Input sampling, CPU integration,
  line-buffer/GRAM ownership, actual effects and native/physical gates remain open.
  The follow-up primary ADC wiring audit and digital adapter exhaust all
  code/validity combinations; they do not implement analog sampling or capture.

The reset helper now prepares repeated physical OSD menu checks with exact
active-set refusal and distinct image evidence. Asset-free safety tests and
actual read-only mister126 asset preflight pass; execution awaits availability
confirmation. See `RESET_STATUS.md`. This does not check a hardware box or
replace current-source Quartus qualification.
- [ ] Validate native Z software, pending-operation resets, Quartus/CDC and
  physical video/input/audio. EMM/SASI remain separately scoped expansions.
