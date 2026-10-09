# HDMI output mode qualification — timing/hardware open

## Actual inherited policy

`sys/sys_top.v` uses the same `~vga_fb & direct_video` expression for the
clock selector and the four output data/sync selections. `direct_video` is
`cfg[10]`; `vga_fb` is `cfg[12] | vga_force_scaler`. This core's wrapper
assigns `VGA_SCALER=0`, so only `cfg[10]/cfg[12]` determine this clock choice.
No inherited framework RTL is changed by this investigation.

| Stable mode | Output clock | Data/DE/VS source | HS source | Output latency |
|---|---|---|---|---|
| Direct=1, framebuffer=0 | Core video | Direct pipeline | Direct pipeline, regardless of csync | Three selected edges |
| Direct=1, framebuffer=1, csync=1 | HDMI PLL | HDMI OSD | HDMI composite sync | Two selected edges |
| Other combinations | HDMI PLL | HDMI OSD | HDMI OSD | Two selected edges |

In steady direct mode, HDMI-OSD-to-selected-output paths are inactive. The
converse direct-data branch is unused in scaled/framebuffer mode. However,
the inherited intermediate `hdmi_dv_*` registers still sample direct data
on the selected clock even while unused. Neither this logic observation nor
an inactive output branch establishes safe asynchronous mode transitions.

## Executed source-extracted functional checks

`make -C verilator test-hdmi-policy` extracts the actual unchanged output
register block from `sys/sys_top.v`, preserving its copyright/license header.
It checks the native selector expression and input ordering before emitting
an **ideal Boolean clock-mux model**, not an Intel primitive simulation.
An independent truth-table/FIFO oracle checks all eight direct/framebuffer/
csync combinations at VID half-period 11,640 ps and HDMI half-periods
3,366/6,250/10,000 ps, across normal, rapidly mutated inactive-source, and
stopped inactive-clock profiles. All 72 cases pass 296 output checks each:
21,312 exact data/HS/VS/DE checks. The intentionally swapped clock-source
negative control fails the expected clock/data-association assertion.

Source SHA-256:
`075b32ea7eff2314453449dccd1cab90a14e6fa1377b809500b9496c4e5b06c1`.
The preserved native fit's framework source has the same hash. Final fixture
build/run has no warnings, all 72 PASS markers and a terminal zero exit.
Output/log: ignored `verilator/obj_dir_headless/hdmi-policy/` and
`/tmp/x1-hdmi-extracted-policy.log`. CI includes the target. These tests do
not elaborate full `sys_top`, simulate Cyclone V switching, validate scaler
pixels/throughput, or establish asynchronous mode-switch/physical acceptance.

## Native fitted inventory and rejected case-analysis attempt

`scripts/quartus_hdmi_mode_inventory.tcl` runs without project SDC or any
exceptions on the completed frozen `fcd1086` Z fit. It finishes zero errors/
warnings at 21:51:17 UTC. Actual `hdmi_clk_sw|clkselect[0]` fanins are exactly
the `cfg[10]` and `cfg[12]` registers, matching source routing. Log
`/tmp/x1-hdmi-native-mode-inventory.log`. This is a fitted inventory, not a
native timing pass.

Although `info commands` lists `set_case_analysis`, the proposed conventional
`set_case_analysis 0 <cfg10 collection>` is rejected by this installed
Quartus 17.0.2 with `Unexpected positional argument: 0`. The reproducer
`scripts/quartus_hdmi_case_probe.tcl` exits 3 at 21:53:04 UTC; only four
mode-0 **before** reports exist, and the queued mode-1 invocation was not
executed. Log `/tmp/x1-hdmi-native-case-probe.log`. No after/mode timing pass
is claimed, and no case-analysis constraint is saved into the project.
Command-name availability and successful help-only invocations are not
evidence of supported or effective static-mode analysis. Older primary
[Altera handbook documentation](https://cdrdv2-public.intel.com/653789/quartusii_handbook_10_0_1.pdf)
lists case analysis as unsupported; it is historical context, not proof of
every Quartus 17 command variant.

### Native command-support follow-up

The no-argument native command invocation now emits **Error 332139: SDC
Command entered is not currently supported by the TimeQuest timing analyzer**.
Log `/tmp/x1-hdmi-case-command-support.log`, terminal exit 3. This identifies
the installed compatibility command as unsupported, rather than merely
assuming an alternative positional syntax would work. Do not use its presence
in `info commands` or help-only success as a static-mode qualification.

## Runtime mode changes are in scope

Read-only inspection of sibling `../MainMess`, commit `da46d07`, finds
`set_vga_fb()` immediately calls `user_io_send_buttons(1)`, which sends
`UIO_BUT_SW=0x01`; `CONF_VGA_FB` and `CONF_DIRECT_VIDEO` map to bits 12 and 10.
`video_fb_enable()` calls `set_vga_fb(enable)` during direct video, and menu
code can toggle that framebuffer while running. This matches this framework's
command-1 `cfg <= io_din` path. Therefore a fixed-until-reload selector
assumption would omit a real reference workflow. The sibling is unchanged;
its Main source is a reference, not proof of the binary deployed on any MiSTer.

## Installed Intel primitive simulation

The installed Quartus `cyclonev_clkselect` wrapper delegates to an encrypted
vendor model. That model was not copied, decrypted or substituted. Its normal
precompiled `cyclonev_ver` library was exercised through installed ModelSim
Altera Starter 10.5b on the authorized build host.

Ubuntu 24.04 lacks the required legacy ABI5 library. The project's
`scripts/setup_modelsim_runtime.sh` downloads actual i386 ABI5 packages from
Ubuntu's official security archive, checks published SHA-256, and extracts
them under this build's ignored `modelsim-abi5-runtime/`. Metadata:
[libncurses5](https://packages.ubuntu.com/jammy/i386/libncurses5/download),
[libtinfo5](https://packages.ubuntu.com/jammy/i386/libtinfo5/download).
No sudo/system installation, fake ABI symlinks, vendor edits or license bypass
were used. Version output alone is not simulation qualification.

The original `hdmi_vendor_clock_tb.sv` diagnostic and `.do` macro finish zero
at 22:07:24 UTC, log `/tmp/x1-hdmi-vendor-clock-qualified.log`. Actual native
elaboration/steady selection passes 48 high/low checks. The seven reported
warnings concern debugger symbols on the modern host; compilation has zero
warnings and simulation has zero errors. Earlier runs used a same-delta edge
observer race and an incorrect normal-finish macro; those are not relabelled
as the final qualification. The corrected observer waits for same-time native
edge callbacks, and the final macro exits normally on `$finish`.

With deliberately asynchronous changes while the incoming clock is high and
outgoing clock low, the vendor model records two off-source rising edges and
three shortened transition intervals. Independent review of the actual
clock-only VCD confirms:

| Output edge time (ps) | Interval since previous output edge (ps) |
|---|---|
| 154842 | 4 |
| 442324 | 4 |
| 444314 | 1990 |

The first two are rising edges away from either corresponding selected-source
rising edge. These are **model observations**, not measurements of physical
FPGA glitches or proof of any exact hardware delay. They show why a simple
Boolean selector/static matrix cannot qualify a safe switch protocol.
The diagnostic does not simulate full HDMI registers, DDR output or the PHY.
Waveform remains ignored at
`output_files/quartus-linux-6FBt6YWN/hdmi-vendor-clock/vendor-clock.vcd`.
No vendor simulation bytes or private machine assets are bundled.

Final bench SHA-256:
`9b4c293ea510f3f35cc16fa77d523c99a8005702efb0d54f8729678ec6ae5f15`.
Final macro SHA-256:
`233bc41fac87378026d863a57acfc8735d542ffef653acda2abf39f34d47ad19`.
Next implementation research: a device-supported glitch-free clock-control
primitive/handoff plus matching data selection and startup/transition blanking,
with both clocks running/stopped and repeated framebuffer changes. Keep this
separate from steady-mode STA and leave ordinary revisions unchanged.

## Simulation-only glitch-free clock-control candidate

Quartus 17's installed `clearbox altclkctrl` generator accepts the checked-in
`verilator/tests/hdmi_altclkctrl_params.txt`: Cyclone V, two global-clock inputs,
glitch-free switch-over enabled and falling-edge enable registration. Generated
vendor HDL stays in ignored build outputs; it is not bundled in the repository
or instantiated by any board. An earlier always-enabled configuration was
generated but is not the qualified configuration.

The falling-edge candidate's 18 native ModelSim runs finish zero, log
`/tmp/x1-hdmi-altclkctrl-clock-stop-matrix.log`. The Cartesian matrix covers
video half-periods 11640/17500 ps, HDMI half-periods 3366/6250/10000 ps, and
three profiles: both sources running, incoming source stopped low, or outgoing
selected source stopped low. Each profile requests HDMI → video → HDMI;
stopped sources resume after the explicit 200000 ps hold. All 18 report 48
steady checks and no shortened intervals. The twelve stopped profiles also
check quiescence before recovery. Simulation errors are zero; each process
reports the same seven host debugger-symbol warnings described above.

An independent top-level-only VCD auditor, `scripts/audit_hdmi_clock_waveforms.py`,
passes all 18 retrieved waveforms, checking every output interval, rising-edge
coincidence with either real source, steady selected-source edges, complete
requests/steady coverage and stopped-clock quiescence/recovery. Minimum output
intervals equal the smaller configured source half-period in every case.
`make -C verilator test-hdmi-clock-waveform-audit` passes a synthetic positive
and twelve invalid-event controls; it is auditor coverage, not native IP execution.
Waveforms remain ignored under
`output_files/quartus-linux-6FBt6YWN/hdmi-altclkctrl-matrix/`.

The native run used bench SHA-256
`a96e9c660948c0fab18945952eecd7644b292300baa2759fc8c85f63cb4ac7b9`
and generator configuration SHA-256
`982088d5aa56abe62ff87f64055b53bcd89efadc42a0ecf5491a7ff1c910eae6`.
The subsequent bench change only corrects the final PASS message to describe
stopped-source profiles accurately; the older wording does not mean both
sources ran throughout those profiles.

**Clock request is not clock-selection acknowledgement.** Observed old-source
rising edges during the handoff are compatible with delayed switching; they
are not claimed as off-active-source glitches. Changing the HDMI data selector
immediately from the raw request could still pair old-clock edges with new
data. This candidate therefore does not yet qualify clock/data alignment,
blanking, rapid repeated requests, startup/reset, fitted placement, timing or
physical output. A stopped selected source also cannot complete handoff until
it resumes in these tests. No board source, default or RBF changed.

## Acknowledged clock/data handoff controller diagnostic

The original, unselected `verilator/tests/hdmi_handoff_candidate.sv` now uses
the installed public `cyclonev_clkselect`/`cyclonev_clkena` interfaces with a
control-clock sequencer. This is project diagnostic code, not redistributed
vendor-generated IP. The sequencer requests three blank output edges,
synchronizes that acknowledgement, requests gate closure, observes native
`enaout` closure, and only then changes its held three-bit mode. A four-control-
cycle settling stage precedes reopening. The old blank acknowledgement must
drain before another request is accepted, preventing rapid reversals from
reusing it. Runtime reset requests the same blank/close transaction rather
than asynchronously changing the clock selector. Requests are coalesced
after the current transaction; there is no invented active-clock ACK.

`hdmi_handoff_vendor_tb.sv` exercises a three-edge diagnostic data pipeline
fed by independent source-clocked tokens and held mode qualifiers. All twelve
native cases (the previous six frequency pairs × stopped-low/stopped-high)
finish zero at 22:28:03 UTC, log `/tmp/x1-hdmi-handoff-v4.log`. Each includes
ten held-mode changes, same-source policy changes, a queued reversal,
incoming/outgoing stopped-clock recovery and retained-clock runtime reset.
Assertions check every output interval and acknowledged-source rising edge,
blanked native gate closure at mode changes, and visible data's held-mode tag.
No forced vendor state or Boolean primitive substitute is used.

The raw-data-mode negative control fails the intended visible-data assertion
at 366896 ps with **exit 1**, log
`/tmp/x1-hdmi-handoff-raw-negative-v4.log`. The first negative did trigger the
assertion but returned zero because this simulator's `$fatal` reached normal
finish; it is not counted as reliable exit-status qualification. The final
`.do` macro checks an unsigned completion counter after simulation stops,
giving twelve positive completion values of 1 and negative value 0. An earlier
one-bit decimal completion value printed -1; that false failure is retained
in `/tmp/x1-hdmi-handoff-completion-format.log`, not hidden as a passed run.
Final positive compilation has zero warnings; native runs retain the seven
host debugger-symbol warnings and have zero simulation errors.

Frozen source SHA-256:

- Controller: `cb9ac8a36977cd0121f37c96eaea375cade9601dcebfd5a36653490f16a2947e`
- Bench: `5264f07453b6f297583eaa1bcc0b688b1580bb53254fd7d33455d4b5ed14d194`
- Macro: `b9705912c601f222f0db427c0db0d4b67c09cd75c8d7a80cf89de199cfd9b9d2`

**Remaining integration gates:** the tagged pipeline is not the actual OSD,
scaler, output DDR or PHY. Three-bit mode packing is a diagnostic contract,
not a framework replacement. Real output blanking, atomic cfg/policy capture,
source-bound CDC constraints/placement, stale/reset requests at every phase,
PLL startup/loss, full extracted-path tests and synthesis/timing still need
qualification. The controller is not in any board QIP/QSF or machine manifest;
no RBF or ordinary behavior changed. Stopping a selected source blocks progress
until its clock resumes; no physical stopped-clock/monitor behavior is claimed.

## Default-off framework connection and actual-register tests

`X1_HDMI_HANDOFF_EXPERIMENT` now connects `rtl/x1_hdmi_clock_handoff.sv` to
the real `sys/sys_top.v` clock/output path. No QSF enables this macro yet.
The controller is a board-only `files.qip` dependency, not shared machine RTL.
The former test-only controller path is historical at commit `d91d5bb`.

The held mode packs `{csync,direct_video,video_selected}`; clock selection,
data selection and composite-sync policy use that same held packet. DE and
RGB are masked during transition blanking. The native DV HS capture uses
held csync rather than an immediately changing raw cfg bit. Default builds
retain their original clock primitive and equivalent raw output policy;
the fresh 72-case default matrix passes all 21,312 exact-word checks and the
wrong-clock negative (`/tmp/x1-hdmi-policy-handoff-default-v2.log`, exit zero).
This narrow framework change is needed because HDMI clock selection and final
output registers live here, not in the machine wrapper.

The post-switch blank handshake now has a fresh generation token and ten
output-edge flush window. That count alone is **not** upstream readiness:
native DV HS is sampled only on `ce_pix`. An additional video-policy epoch
travels through the same CE capture and three VID register stages, then two
control-domain samples. It changes only for video-target transactions, avoiding
false readiness from two intervening HDMI-mode epochs. Unblanking a video
target requires that actual returned epoch. CTRL is framework `clk_sys`, the
cfg writer's domain; the machine's 32 MHz clock must not be assumed here.
The Sharp X1 wrapper keeps forced-scaler selection zero; other cores' asynchronous
forced-scaler contracts are outside this experimental integration.

All twelve current-controller native clock-stop/tag/reset cases finish zero,
log `/tmp/x1-hdmi-handoff-v6.log`. That helper bench explicitly ties video-policy
readiness high and does not qualify the upstream handshake. The separate
source-extracted actual-register fixture does qualify its connected epoch
capture and stopped-`ce_pix` recovery: six frequency pairs finish zero, log
`/tmp/x1-hdmi-handoff-policy-v2.log`, with **4,826 exact RGB/HS/VS/DE checks**.
Each repeats all eight direct/framebuffer/csync combinations three times and
performs three reset/recovery sequences. Blank frames require DE/RGB zero;
visible frames use an independent two/three-edge source-history oracle.
The extracted raw-policy negative fails that oracle at 414021 ps with exit 1,
log `/tmp/x1-hdmi-handoff-policy-raw-negative.log`. Positive native compilations
have zero warnings; simulation retains seven host debugger warnings per run.
`test-hdmi-fixture-extraction` passes four source-bound profiles and two invalid
option controls; extraction tests are not native execution.

Current source hashes:

- `sys_top.v`: `d1fb9155cc8de9604cc9ecfafbab2ac9be102e7cb653991235cc7130d7cccad3`
- Controller: `49139bc1a7b3378521d61392c43cf07d4c2cf9f7ce11dc474b431ec6113ee9a6`
- Exact-policy bench: `39a4f3a5b508a82c1311aa415de5a702ae58613d9e32f70c5586f3e39aa72a92`
- Clock/tag bench: `aef6bdf1fb930098ac979ecaa0b0fa0e55e169dabe1c7ab3ed7bd61011521332`

**Not yet qualified:** complete upstream OSD/scaler/DDR/PHY execution, actual
DV CE/glyph/video timing, reset at every transaction phase, PLL lock/loss,
debug-no-HDMI combinations, and mapped/fitted clock-resource/CDC inventories.
The extracted fixture drives DV data/sync as source-clocked inputs; its epoch
block is real extracted code, but this is not a full DV raster test. Existing
mux constraints name the old primitive and cannot be reused silently with the
new hierarchy. No selected-profile Quartus flow or new RBF exists. Fresh narrow
constraints, source-bound fitting/all-corner timing and physical output remain
required. Ordinary board revisions remain unchanged.

## Isolated fitted clock-control qualification and closure witness

The first native mapping harness connected controller clock ports directly to
external pins. Quartus rejects those sources at mux `inclk[2:3]` (Error 15836),
log `/tmp/x1-hdmi-handoff-native-map-v1.log`, exit 3. This is a harness mismatch,
not justification to rewire the board's PLL inputs. The corrected
`hdmi_handoff_map_top.sv` supplies two real `altera_pll` outputs. Mapping and
isolated fitting finish zero; no assembler or MiSTer build is run.

The follow-up preserves two selected-clock enable samples before the gate.
Native fitted fanout then reveals that public `enaout` cannot be assumed to
be registered physical readback: the status sample is fed by the input-side
enable, alongside native `gate~FF_0`. The controller now uses an explicit
selected-falling-edge witness, synchronized back to CTRL, instead. The witness
is not an analog readback or placement proof. The
[Cyclone V clock-enable handbook](https://docs.altera.com/r/docs/683375/current/cyclone-v-device-handbook-volume-1-device-interfaces-and-integration/clock-enable-signals)
describes falling-edge synchronized enable and optional metastability
registration; this does not establish the exact fitted status-pin contract.

The current twelve native clock/tag cases finish zero, log
`/tmp/x1-hdmi-handoff-v8.log`, including a new adversarial stop HIGH after
gate-disable is sampled but before the necessary falling edge. Selection must
not change during that hold. The six current actual-register cases finish
zero, log `/tmp/x1-hdmi-handoff-policy-v4.log`, with **4,923 exact visible-word
checks**. The raw-policy negative again fails at 414021 ps with exit 1,
log `/tmp/x1-hdmi-handoff-policy-raw-negative-v4.log`.

Current controller SHA-256:
`978537bd98a29eb9ccb7187fcb0b495253c5210688417650f1012817f2553223`.
Current clock/tag bench SHA-256:
`59353c3b96b11a6765f0728bcd430dd55d962697511985a989a123f0c8998a30`.
The actual-register bench and `sys_top.v` remain at the preceding section's
hashes. The frozen isolated v4 map/fit finishes zero at 22:43:51 UTC, log
`/tmp/x1-hdmi-handoff-native-map-fit-pll-v4.log`. Mapping reports three warnings
(PLL connectivity/reset); fitting reports eight warnings, including unpinned
I/O and missing SDC. Its 50 MHz control reference is an isolated probe, not a
board-frequency claim. `ALLOW_POWER_UP_DONT_CARE=OFF` is probe-local; the real
board initialization and placement contract still needs review.

Reporting-only `quartus_hdmi_handoff_inventory.tcl` confirms the enable first
stage only feeds the second stage. The second stage feeds the native gate
register and falling witness. CTRL status now receives the witness, not the
input-side enable. The mux retains four pins; the native gate retains three.
The narrow `mux-clocks` probe creates two choices only at `handoff|mux|outclk`,
leaving concurrent PLL masters and raw crossings uncut. Native probe terminates
zero without warnings, `/tmp/x1-hdmi-handoff-native-gate-v4.log`.

Independent `audit_hdmi_handoff_probe.py` passes all twelve bounded rows at
**Slow/1100 mV/100 C only**, preserving actual endpoints and both clock choices:

| Isolated fitted path | Minimum setup | Minimum hold |
|---|---:|---:|
| Enable stage 0 → stage 1 | +12.130 ns | +0.371 ns |
| Enable stage 1 → falling witness | +4.954 ns | +6.803 ns |
| Enable stage 1 → native gate register | +10.593 ns | +1.572 ns |

The native gate report models a full-period setup relationship, whereas the
explicit witness has a half-period relationship. Do not turn those abstractions
into a measured closure-latency contract; device-specific enable semantics and
post-fit/physical switching still need qualification. Raw enable input setup
remains **-5.566 ns**, and global probe setup/hold remain **-5.785/-3.606 ns**.
No raw input exception is applied or global/board closure claimed.
The independent auditor also rejects fourteen invalid scope/report controls;
`make -C verilator test-hdmi-handoff-probe-audit` checks those controls only.
Retrieved map/fit/STA reports remain ignored under
`output_files/hdmi-handoff-map-pll-v4/`.

Next: resolve the fitted primitive's enable/closure semantics, audit all eight
corners and initialization, then qualify a separate full-board profile with
new-hierarchy constraints and all data/DDR paths. No existing QSF enables the
handoff and no new RBF is produced. Unit fitting is not MiSTer acceptance.

## Eight-corner probe and emitted gate-parameter follow-up

The frozen isolated v4 fit now has all eight slow/fast, -40/0/85/100 C,
1100 mV probe corners. Reporting finishes zero without warnings at 22:50:29
UTC, `/tmp/x1-hdmi-handoff-native-eight-corners-v4.log`. New files include the
corner in their names; the preceding one-corner reports remain intact. The
same two generated mux choices are exclusive; no PLL-master groups or raw
input exceptions are added.

Independent `audit_hdmi_handoff_probe.py --all-corners` passes **96 bounded
rows** and requires the ordered eight-corner markers, both active choices,
exact physical source/destination pairs, first/second-stage fanout and the
falling-witness status input. Log:
`/tmp/x1-hdmi-handoff-eight-corners-independent.log`.

| Isolated fitted path | Eight-corner minimum setup | Eight-corner minimum hold |
|---|---:|---:|
| Enable stage 0 → stage 1 | +12.129 ns | +0.121 ns |
| Enable stage 1 → falling witness | +4.954 ns | +6.527 ns |
| Enable stage 1 → native gate register | +10.593 ns | +0.564 ns |

Raw enable setup remains **-5.860 ns**; global probe setup/hold remain
**-5.860/-3.742 ns**. These raw/control/bundle failures are not renamed passes.
The current auditor tests include fifteen invalid scope/report controls and
six invalid corner-enumeration/final-report controls, alongside one/eight-
corner synthetic positives. Test success is auditor coverage, not fitting.

Installed `quartus_eda` also emits an ignored netlist, terminal zero at
22:51:07 UTC, `/tmp/x1-hdmi-handoff-native-netlist-v4.log`. **Warning 10905 says
this device supports only a functional simulation netlist.** This is not
a routed-delay simulation, and no fitted simulation run is claimed.
Read-only inspection confirms the emitted `handoff|gate` public primitive
parameters remain falling-edge enable registration, low power-up and low
disable, with unused `enaout`. The emitted witness is a separate low-power-up
register clocked by inverted selected clock; status data comes from that
witness. These configuration checks corroborate the intended mapping but
do not reinterpret TimeQuest's full-period gate setup abstraction as a
measured hardware edge or latency. Actual switching, startup/PLL loss and
physical acknowledgement still need qualification.

Generated netlist SHA-256:
`1f336980632c40481542261c677ee66ee230bf074163f9011dbb8f3f23d4f7ea`.
It remains only on the build host under the isolated fit's
`gate-netlist-probe/`; no generated/vendor netlist bytes are committed.
The isolated probe uses a 50 MHz reference/control and requested 74.25 MHz
HDMI PLL, not the full board's controller wiring or default requested
148.5 MHz HDMI PLL. All-corner probe success therefore does not qualify the
board's faster HDMI choice, resource occupancy, I/O or native video paths.
A separate full-board handoff revision with guarded new-hierarchy clocks,
full source-bound fit and all-corner data/clock checks remains next.

## Separate full-board qualification revision prepared

`sharpx1_turbo_z_handoff.qsf` now opts into the connected controller without
changing existing QSFs. Static profile checks preserve the Z/X3 feature set
and all prior constraints except the old raw-mux clock candidate. The new
guarded `hdmi_handoff_mux_candidate.sdc` targets only the new mux's exact
source/output pins and two generated choices. It does not waive raw inputs,
held mode, data-bank, output-DDR or unrelated master-clock crossings.
The revision disables power-up don't-care optimization for qualification.

`make -C verilator test-hdmi-handoff-board-profile` passes profile isolation and
both old/new mocked scope matrices (eighteen invalid inventories each reject
before creating constraints). These are not native board scope acceptance.
Linux/Apple build helpers accept the separate revision; existing defaults and
the project baseline remain unchanged. A source-bound full Quartus flow,
actual fitted inventory, all-corner setup/hold/recovery/removal/pulse-width/I/O
and physical/native video acceptance are still required. No qualified RBF is
claimed from the profile's existence.

### Source-bound full flow started, not yet qualified

The clean authorized `misterubuntu` checkout fast-forwards from the alanswx
fork to `48007152a28f4a61ff73c4831f811528582a5f0d`; preflight finishes zero.
`build_quartus_linux.sh --build` starts the separate revision's full project
flow at **2026-10-09 22:58:02 UTC**, snapshot
`output_files/quartus-linux-O40JuhMa/source`, log
`/tmp/x1-quartus-4800715-z-handoff.log`. Input manifest SHA-256:
`daa2012b5e57c24c33e21af7a980d29e5fcc60d246fe2971f3b54a1a73cbd3a3`.
The full flow finishes **zero** at 23:07:13 UTC, with 162 warnings. This is
compilation, not acceptance: setup fails **-46.374 ns**, with selected HDMI/
video mux setup **-18.205/-12.228 ns**. Reported hold/recovery/removal/pulse-width
minima are +0.210/+4.879/+0.982/+0.529 ns. The design is not fully constrained;
MTBF is not calculated because timing fails. Original reports stay intact.
Generated RBF SHA-256:
`257c94efae3a26768655c19c75ea058ed99390aee426b798ea4b3b951c5608b1`.
It lives in that snapshot's `output_files/` and is **unqualified**, including
because it predates both following reset fixes. Nothing is loaded on a MiSTer.

### Reset with stopped CE and aborted-epoch retry

Native phase-three reset with readiness held low fails on the original
controller; the same phase with readiness high passes. Reset now may leave
video while remaining blank, without waiting for capture needed for unblanking.
The connected actual DV-epoch fixture then exposed a second bug: aborting a
video epoch and retrying while `ce_pix` remains stopped toggled the one-bit
token twice, matching stale completion. That negative fails with exit 1.
The controller now drains an outstanding video token before issuing another;
reset may bypass that wait only to choose blanked HDMI. Ordinary video
unblanking still requires readiness. No shared-machine reset RTL changes.

Current controller SHA-256:
`71c4f0d4a9aa96b188f7eee1f799eb89f55376a21db4e4aeea0cf75c3cb1f663`.
The frozen native reset matrix finishes zero: two video rates, three HDMI
rates, eight actual controller phases and readiness high/low give **96 cases**.
`audit_hdmi_handoff_reset_runs.py` independently requires the exact ordered
matrix, explicit completion, reviewed warnings and unchanged source hashes.
Its positive and fifteen invalid-result controls pass. Log:
`/tmp/x1-hdmi-handoff-reset-drained-96.log`.

Six actual extracted-register/epoch cases finish zero with **4,994 exact
output checks**, including reset-abort/retry while CE stays stopped, then
recovery on CE resumption. Log:
`/tmp/x1-hdmi-handoff-policy-reset-retry-corrected.log`.
Twelve tagged clock-handoff profiles also finish zero:
`/tmp/x1-hdmi-handoff-v9.log`. Their readiness input is tied high; they do
not replace the connected epoch test. Neither set qualifies full upstream
OSD/DDR/raster behavior, original Main reset dispatch, routed timing, PLL loss
or physical output. The smaller prior isolated fitted timing inventory and
the completed board build both use the older controller; a fresh corrected-
source fit is required, not retrospective qualification of their RBF/netlist.

`quartus_hdmi_handoff_board_paths.tcl` supplies an additive full-board worst-
path diagnostic with original SDC only, refuses an existing report directory,
and never writes over flow reports. Native execution finishes zero without
warnings at 23:11:11 UTC, log `/tmp/x1-hdmi-board-paths-4800715-v1.log`.
Before/after hashes of the original STA report, summary and RBF are identical.
New `handoff-board-paths-v1/global_setup.rpt` identifies the worst path as
`blank_ack` to `ack_meta`, from selected HDMI back to SYS: 44.968 ns data
delay (44.633 ns routing) and -46.374 ns slack. Completed-generation feedback
also fails. Held `active_mode[0]` to selected output registers reports
-18.205 ns. These are raw first-stage/control-bundle diagnostics, not
synchronous second-stage acceptance or grounds for whole-domain exceptions.
Placement/CDC and justified scoped timing constraints need separate review.

The corrected-source actual raw-policy negative is retaken in a fresh frozen
directory and fails the intended pipeline assertion with verified exit 1:
`/tmp/x1-hdmi-handoff-raw-negative-reset-v5.log`. The default 72-case static
policy and wrong-clock negative also pass their existing regression.

To reproduce the native reset matrix with an installed Intel ModelSim and
already provisioned ABI5 dependencies (no installation/download performed):

```sh
bash scripts/run_hdmi_handoff_reset_native.sh /path/to/modelsim_ase/linuxaloem /path/to/abi5/dependencies
```

The runner freezes its three inputs in a unique ignored output directory,
requires every native process to succeed, and applies the independent matrix/
source/warning auditor. This remains helper qualification, not board acceptance.
The committed runner is actually executed on `misterubuntu`: terminal zero,
all 96 native cases and its final source/warning audit pass. Frozen evidence:
`output_files/hdmi-native-reset-K4EdoOQt`, log
`/tmp/x1-hdmi-handoff-reproducible-reset-050364f.log`.

The new `quartus_hdmi_handoff_board_inventory.tcl` adds exact full-board
enable, ACK, generation-completion, gate-status, blank and generation stage
pairs, plus falling witness/native gate, across eight corners. It adds no
exceptions and refuses missing/ambiguous scalar registers or existing outputs.
Its local mock passes 144 ordered bounded/global reports and four invalid
inventory/overwrite controls. The independent `audit_hdmi_handoff_board_reports.py`
requires exact physical pairs, active clock choices, ordered corners, nonnegative
bounded rows and retained 50-path global diagnostics. Its synthetic 208-row
positive and sixteen invalid-evidence controls pass; this is not a native
board timing pass. Native execution awaits the running corrected-source fit.

The actual extracted-policy test now also checks held-mode stability before
the **first** selected output edge, not merely after the blank flush. Six
native profiles finish zero at 23:18:38 UTC with unchanged frozen inputs:
`/tmp/x1-hdmi-handoff-policy-settle-v6.log`. They retain all 4,994 exact words
and stopped-CE reset-abort/retry checks, and add **198 first-edge hold checks**
(33 per profile). Minimum observed hold is **169,791 ps**, above the asserted
five 32 MHz CTRL periods (156,250 ps). This is a functional held-bundle
contract, not a routed physical bound or a waiver for continuously changing
OSD/DV sources. Strengthened testbench SHA-256:
`50ef52215eb375076f09ce6b78cbb09518636f2d17fafd1f38bb60579eadbb2f`.
The matching unsafe raw-policy negative again fails the intended pipeline
assertion with verified exit 1, log
`/tmp/x1-hdmi-handoff-policy-settle-raw-negative-v6.log`.

The corrected `d8f7024` revision is pushed to alanswx. Its fresh full-board flow
starts in `output_files/quartus-linux-t5zgQgO6/source`, log
`/tmp/x1-quartus-d8f7024-z-handoff.log`, at 23:12:27 UTC. The full flow finishes
**zero at 23:21:21 UTC**, with 162 warnings. Its flow summary still fails setup
**-47.082 ns**; hold/recovery/removal/pulse-width minima are
+0.250/+4.022/+0.853/+0.529 ns. The broader following eight-corner diagnostic
also finds negative hold; the positive flow-summary hold is not an all-corner
closure claim. RBF SHA-256:
`1abec87fc986a7739646cb2667d5a5f59c84912b782213a12dc2f790cd474617`.
It remains **unqualified** in that snapshot's `output_files/`; no hardware
deployment. The preceding completed flow and additive reports are preserved.

### Corrected-source full-board native stage inventory

The queued supplemental inventory finishes zero without warnings at
23:22:35 UTC, elapsed 1:11.
Native log: `/tmp/x1-hdmi-handoff-board-inventory-d8f7024-v1.log`.
Ignored local reports:
`output_files/hdmi-handoff-board-d8f7024/handoff-board-inventory-v1/`.
Independent audit log: `/tmp/x1-hdmi-handoff-board-d8f7024-independent.log`.
All **128 bounded reports / 208 rows** pass across eight corners, including
the actual board's default requested 148.5 MHz HDMI selection. Bounded setup/
hold minima are **+1.015/+0.285 ns**. Every first-stage fanout is exactly its
second stage; the enable's second stage feeds only the native gate and falling
witness. Native controller/framework/reporter hashes match current source,
and the original flow report/summary/RBF hashes are unchanged before/after.
The updated auditor controls include nineteen invalid timing/scope/fanout
cases and five invalid source/artifact-preservation cases.

This is **not whole-board timing closure**. Original-constraint global setup/
hold diagnostics remain **-47.082/-1.806 ns**. Worst setup is `blank_ack` to
`ack_meta`, selected HDMI → SYS, with 45.755 ns data delay. Worst hold at
fast/-40 C is `completed_generation` to `completed_meta`, selected HDMI → SYS.
Held mode to output registers also fails (for example -18.252 ns to `hs`).
No new input or data exceptions are applied. Physical metastability/MTBF,
source-side synchronization scope, held mode/data, DDR/I/O and physical
switching remain required.

Next constraint work should isolate only verified asynchronous first-stage
inputs, retain synchronous chain/consumer timing, and prove any held-bundle
delay bound separately. Modern [Altera synchronizer timing guidance](https://docs.altera.com/r/docs/683082/25.1/quartus-prime-pro-edition-user-guide/how-timing-constraints-affect-synchronizer-identification-and-metastability-analysis?contentId=Sh6sCC5YZJtwXMs92gyCdw)
explains why raw first-stage timing and interstage settling are distinct.
It is a design rationale reference, not proof that a particular Quartus 17
constraint/MTBF command binds this fitted design. Each candidate still needs
native before/after reports, exact scope guards and fresh fitting.

## First-stage-only input candidate (completed-fit probe)

`hdmi_handoff_input_candidate.sdc` targets only six registered single-bit
drivers to their exact first synchronizer stage: gate request, blank request,
generation, blank ACK, completed generation and falling-edge gate witness.
All sources/stages, data drivers, exclusive first-stage fanout and absence
of unreviewed replicas must validate **before any exception is applied**.
No master-clock groups, second stages, held modes, pixel data or DDR/I/O are cut.

The first native attempt stops with exit 3 at the gate-request driver guard,
log `/tmp/x1-hdmi-handoff-input-probe-d8f7024-v1.log`; it applies no exceptions.
Native `get_fanins -long_help` and a read-only fitted discovery explain the
cause: the default query also traverses clock edges, including the clock mux's
`active_mode[0]` selector. Log:
`/tmp/x1-hdmi-handoff-input-fanins-d8f7024-v1.log` (terminal zero). The driver
guard now uses installed Quartus 17's `-synch` option to check data edges;
it does not simply ignore unknown registered drivers.

The corrected frozen v2 candidate actually finishes zero without warnings at
23:32:02 UTC. Independent before/after auditing passes **416 unchanged positive
stage/witness/native-gate rows**, **192 original raw-input rows**, all **96
excluded input reports**, and **232 unchanged previously reported held-mode
rows** across eight corners. Bounded setup/hold minima remain +1.015/+0.285 ns.
Global diagnostics improve from **-47.082/-1.806 ns** to **-18.252/-0.062 ns**;
they still fail. Controller/framework/probe/candidate and original flow
report/summary/RBF hashes are unchanged. Log:
`/tmp/x1-hdmi-handoff-input-probe-d8f7024-v2.log`; reports remain ignored under
`output_files/hdmi-handoff-input-d8f7024/handoff-input-probe-v2/`.

The final candidate comment identifies the separate experimental revision.
Its fresh v3 probe finishes zero without warnings at 23:36:00 UTC and passes
the same independent matrix/preservation checks; preceding evidence stays
intact. Log `/tmp/x1-hdmi-handoff-input-probe-d8f7024-v3.log`, independent log
`/tmp/x1-hdmi-handoff-input-v3-independent.log`, reports in the adjacent
ignored `handoff-input-probe-v3/`. Final candidate SHA-256:
`70cee679b7db1e530857e4cb3123f1e806cf913828b7790140a6e25ab03ab26c`.
Only `sharpx1_turbo_z_handoff.qsf` selects this input
candidate; all other QSFs remain unchanged/disabled. Static profile isolation,
nine invalid exact-input inventories, twenty invalid before/after report
controls and four invalid source/artifact controls pass. Fresh map/fit,
all-corner native scope/MTBF/consumer timing and physical acceptance remain
required. A completed-fit exception probe cannot retroactively qualify the
original RBF or replace the remaining held-mode/data work.

The verified checkpoint is pushed to alanswx as `3a61604`. A clean host
checkout starts a **fresh full flow**, not reuse of the completed-fit probe,
in `output_files/quartus-linux-wBmGGSvP/source`, source commit
`3a61604fa9f7d5e47d07f9a4088a227dfd9d0610`, log
`/tmp/x1-quartus-3a61604-z-handoff-input.log`. Live mapping is confirmed.
Terminal flow, mapped/fitted input guards, new timing, MTBF and hardware remain
unproven. All preceding fits/probe reports are preserved; no MiSTer is loaded.

## Next gates

1. Establish an actually supported mode-sensitive STA method or a narrow
   output-routing proposal; validate all active data/sync paths in both clock
   selections and preserve unrelated master-clock crossings. Do not substitute
   blanket PLL exclusions or count missing/unsupported reports as passes.
2. Verify selector coherence, source stability, transition blanking/draining,
   stopped-clock behavior and startup/reset when switching modes. The current
   fixture's static-mode success does not answer those questions.
3. Qualify source-bound native inventories, fresh mapping/fitting, and all
   eight-corner setup/hold/recovery/removal/pulse-width and I/O checks.
4. Exercise scaled/direct/framebuffer/csync output and transitions physically
   on an available MiSTer with actual screen captures and source-bound RBF.

The latest before/after packet probe still reports global setup/hold
**-12.003/-0.003 ns**, dominated by HDMI OSD to `x1_video_mux` output paths.
The existing RBF is unqualified; full Turbo/Z native and physical gates remain
open independently of this output-policy increment.
