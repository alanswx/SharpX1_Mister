# HDMI output mode qualification — timing/hardware open

## October 10 current-source full flow: fitted guard rejection

The guarded source-bound `3c6242e771446dc11843cc8f4b7d4c58430b8f17` flow
starts at 08:02:29 UTC and terminates exit 3 at 08:15:43 UTC, after fitting.
Final STA refuses an unreviewed whole-prefetch D/ASDATA profile. The four
previously qualified patterns are not broadened or silently reapplied.
Native discovery and original-artifact preservation auditing are pending;
the partial STA transcript cannot establish final constrained timing.
Remote frozen root is `output_files/quartus-linux-VlAoOluh/source` on
`misterubuntu`; log `/tmp/x1-quartus-3c6242e-handoff-local.XhSvnjgI`.
See [build identity and gates](DMA_BOARD_BUILD_STATUS.md#october-10-current-source-build-gate).
No new timing-qualified RBF or MiSTer acceptance is inferred.

Terminal auditing reports synthesis/fitting/assembly completion and verifies
all 408 checkout inputs against the frozen manifest. Quartus changes only
the snapshot's QPF metadata/revision; its retained diff is in remote
`terminal-audit-jdL8ZB45`. Direct readback of the fitted summary confirms
20,605 ALMs, 393/553 RAM blocks and four PLLs. Direct artifact hashing confirms
the **unaccepted** RBF SHA-256
`7f6a2009cbebe2caa34fec785bd39a19da0ba58e4f970f2ca80b9f0384d5a993`.
The partial STA summary reports setup/hold -10.317/-2.636 ns, but final
constraint loading failed: these numbers are not a completed constrained
timing audit. The reporting-only fitted inventory was deferred after actual
MacPPC7300/DSPPC604 fitters were observed; no job was killed or guard broadened.

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

## Complete held-mode timing discovery (not acceptance)

The read-only `scripts/quartus_hdmi_handoff_mode_inventory.tcl` inventories all
three fitted `active_mode` bits, combined clock/data fanout and all reported
timing endpoints in the preserved corrected-source `d8f7024` full board fit.
Quartus 17's installed help confirms `get_fanouts` lacks `-synch`/`-clock`;
the first attempt exits with error and is not counted. The corrected native
run and hash-qualified repeat finish with zero errors/warnings.
`scripts/audit_hdmi_handoff_mode_inventory.py` independently validates **1,584
rows**, 99 per report, across eight corners for setup/hold. There are 84
distinct source/endpoint/launch/latch combinations; repeated edge relationships
are retained. The 1,000-path ceiling is not reached. Controller, framework,
reporter and original STA/summary/RBF hashes match before/after.

At slow 100 C, the timing consumers are:

| Domain | Paths | Consumers | Minimum setup |
| --- | ---: | --- | ---: |
| Selected HDMI output | 29 | RGB `d[23:0]`, HS, VS, DE | -18.252 ns |
| Selected video output | 29 | The same output registers | -8.429 ns |
| Native video | 1 | `dv_hs1`, from held csync bit 2 | -7.247 ns |
| SYS | 40 | Pending mode, FSM and blank request | +24.531 ns |

Across all corners held-mode setup/hold minima are **-18.252/+0.817 ns**.
The native `dv_hs1` path separately has **-7.247/+1.485 ns**; maximum reported
data delay is 0.667 ns. First gated-output-edge settling cannot qualify this
ungated VID consumer. Actual CE capture/epoch completion needs a separate
coherent-data contract. Do not blanket-except it or selector clock fanout.
No constraints are added; physical switching, MTBF and RBF acceptance remain
open. Eight invalid provenance/completion/corner/row/domain/source controls
are rejected by the independent audit.

Ignored reports: `output_files/hdmi-handoff-mode-d8f7024/handoff-mode-inventory-v3/`.
Reproduce the audit:

```sh
python3 scripts/audit_hdmi_handoff_mode_inventory.py \
  output_files/hdmi-handoff-mode-d8f7024/handoff-mode-inventory-v3 \
  --native-log /tmp/x1-handoff-mode-inventory-d8f7024-v3.log --source-root .
```

The newer `3a61604` selected-input full flow terminates **unsuccessfully** at
STA on October 9, 16:46:36 host time (8m56s). Fitting introduced
`gate_request~DUPLICATE`; the exact-input candidate rejects that unreviewed
source replica. Do not count this flow as acceptance or broaden its guard
from naming alone. These reports are not from that new fit. The later
OSD ordering guard adds no J/j metadata or machine behavior and does not
retroactively change either build's source identity.

The no-SDC `scripts/quartus_hdmi_handoff_replica_inventory.tcl` subsequently
finishes zero errors/warnings in the failed flow's preserved fit. Its log is
`/tmp/x1-handoff-replica-inventory-3a61604-v1.log`. Connectivity shows
`gate_request_meta` is driven by the new replica, not the canonical source;
the replica fans out only to that first stage, which still feeds only
`gate_request_sample`. Canonical and replica fanins include the same FSM/
settle/ACK controls, but connectivity is **not sequential equivalence proof**.
Choose and qualify either supported replication prevention or exact physical
source/equivalence handling, then repeat fitting and all timing audits. No
SDC is loaded, exceptions changed or timing acceptance claimed by this probe.

### Single-source replication prevention candidate

The controller now applies `(* dont_replicate *)` only to `gate_request`.
This is synthesis-side replication control, not broader CDC exception scope.
Intel's [Standard Edition compilation guide](https://www.intel.com/programmable/technical-pdfs/683283.pdf)
documents the attribute; this is guidance, not proof that Quartus 17's fit
honors it. Strict six-input physical-source/replica/fanout guards are unchanged.
Existing board revisions still do not instantiate this helper. Local profile
isolation, nine invalid SDC inventories, twenty invalid before/after scope/
timing controls, four invalid provenance controls and reset auditor controls
pass. These static/synthetic checks are not a new native 96-case run or fit.
The new controller hash is
`47ca9d7da65df077b8a3b20012a2ede6a98d638756fbc6a746c9b20c71f7f58a`;
prior native/fitted results stay historical. Fresh native reset qualification
and a source-bound full build are next.

The fresh native runner subsequently completes **all 96** ordered reset
phase/rate/readiness profiles, explicit completion gates and independent
current-source/before-after hash checks. Host evidence is
`output_files/hdmi-native-reset-BgTnTzWF`; log
`/tmp/x1-hdmi-handoff-noreplicate-reset-8685be0-native.log`.
The initial legacy `bin` wrapper cannot locate its old `linux_rh60/vlib` and
is not counted; the actual run uses installed `linuxaloem` binaries and
existing verified ABI5 dependencies, with no installation or library changes.

Six fresh extracted actual-policy profiles also complete zero in
`output_files/hdmi-policy-noreplicate-d8xnd0m0`; log
`/tmp/x1-hdmi-policy-noreplicate-8685be0.log`. Independent
`scripts/audit_hdmi_handoff_policy_runs.py` checks all ordered profiles,
completion/warning summaries, frozen before/after controller/fixture/bench/
macro hashes and the actual framework hash embedded in the fixture. It
confirms **4,994 exact words**, **198 first-edge hold checks**, minimum
**169,791 ps**. The current local emitter reproduces the exact frozen fixture
hash. Eleven invalid profile/settle/warning/completion/source controls pass
through `test-hdmi-handoff-reset-audit` (also in CI). This remains an extracted
policy check, not native VID csync timing, whole upstream/DDR/PHY or physical
acceptance; no old fit is relabelled.

The clean build checkout now launches a fresh **`8685be0`** full flow in
`output_files/quartus-linux-1T5MGfci/source`, complete source commit
`8685be09c0663d63e84eefda87c20fca643187c5`, log
`/tmp/x1-quartus-8685be0-z-handoff-noreplicate.log`. Mapping completes and
the fitter is confirmed live (PID 1312593). Final replica guards, fit/STA/RBF
and hardware are still unproven. Earlier frozen outputs remain untouched.

That `8685be0` flow subsequently finishes **zero** on October 9 at
23:58:56 UTC, elapsed 8m26s, with 162 warnings. Unlike the preceding attempt,
its selected six-input scope does not reject a fitted gate-request replica.
The flow summary minima are setup **-18.201 ns**, hold **+0.251 ns**,
recovery **+4.019 ns**, removal **+0.825 ns**, pulse width **+0.529 ns**.
These are the flow summary, not a new independent eight-corner audit.
STA warns that timing is unmet and design MTBF cannot be calculated.
The unqualified RBF SHA256 is
`321b84f044d43756593b74d106e8a8934ce3847d6e1334d537ba421d0739f1ec`.
Manifest/summary copies live under ignored
`output_files/hdmi-handoff-noreplicate-8685be0/`. It predates the following
framework change and has not been loaded on a MiSTer.

## CE-consumed native csync acknowledgement

Only `X1_HDMI_HANDOFF_EXPERIMENT` now synchronizes the epoch and held csync
bit through two native-VID stages. Native `dv_hs1` consumes the sampled bit,
not the raw SYS bit. At the same real `ce_pix` capture, an echo records that
consumed policy and follows the same three VID registers as native HS.
Two CTRL samples return it alongside the epoch; readiness requires both to
match the held request. A stopped CE cannot fabricate that consumed-policy
acknowledgement. Ordinary board revisions retain their original csync path.
No new SDC exceptions are added; new stage/echo/raw-input and whole-board
timing, placement/MTBF and physical gates remain required.

The source-bound emitter now extracts the actual CE-qualified native HS
assignments, with guards on their original placement, in addition to the
output registers/token handshake. The bench checks the HS pipeline, retained
HS during stopped CE, correct policy before video unblank, and a new csync
request while CE is stopped. The frozen emitter/framework/fixture/controller/
bench/macro hashes are verified before/after and against current local inputs
by `scripts/audit_hdmi_handoff_policy_runs.py`. The reusable runner is:

```sh
bash scripts/run_hdmi_handoff_policy_native.sh MODEL_BIN ABI5_DEPENDENCIES normal
bash scripts/run_hdmi_handoff_policy_native.sh MODEL_BIN ABI5_DEPENDENCIES skew
```

Normal native six-profile qualification completes zero:
`/tmp/x1-hdmi-csync-echo-native-v5.log`, scratch evidence
`/tmp/x1-hdmi-csync-qual-wyZBRcaG/output_files/hdmi-native-policy-cUSwVecS`.
It passes **5,030 exact output words**, **204 first-edge hold checks** (minimum
169,799 ps), and **10,273 extracted native HS checks**. The explicitly
diagnostic 3-us csync transport-delay profile also completes all six:
`/tmp/x1-hdmi-csync-skew-native-v3.log`, `hdmi-native-policy-vYpcQ7TY`, with
**5,032 words**, **192 holds** (minimum 170,013 ps), **13,143 HS checks**.
The same skew with consumed-policy echo removed exits **1** at the intended
"video unblanked before consumed csync policy matches" assertion, with
`POLICY_COMPLETION=0`; log
`/tmp/x1-hdmi-csync-skew-noecho-negative-v3.log`. Earlier declaration-order
compile failures and a two-state-oracle startup-X failure are not counted.
Both final positive/negative fixtures use the same four-state oracle.
Synthetic source/extraction/audit controls and the ordinary 72-case static
policy/wrong-clock negative pass; no assertions are weakened to accept an
incorrect consumed policy. The diagnostic delay is **not routed delay**, and
these extracted lanes do not qualify full upstream OSD/DDR/PHY or native ASIC
behavior. Fresh fitting is still required for the changed framework hash
`c95e80d3d59e5eba621bb09c5785b95c9c47cadd506712c386ccbddd5004c19e`.

The verified checkpoint is pushed as `00cabd4`. The clean host checkout starts
a new full flow in `output_files/quartus-linux-Cx5S48qo/source`, exact commit
`00cabd4ff750038555944c15d2edfd8eeccf8f9c`; log
`/tmp/x1-quartus-00cabd4-z-csync-echo.log`. Live mapping is confirmed (PID
1328818). Final new synchronizer/echo scope, fitted consumer timing, all-corner
global checks, MTBF/I/O and hardware acceptance are still unproven. No MiSTer
has been loaded and no previous RBF is relabelled as this framework revision.

### New csync fitted-scope reporter (prepared, not native-qualified)

`scripts/quartus_hdmi_csync_inventory.tcl` inventories thirteen synchronous
stage/capture/native-HS pairs, four raw crossings and both ready-return
consumer cones across eight corners. Four exact first-stage fanout checks and
four registered-data-driver checks run before creating any report directory.
Missing/ambiguous/substituted scalars and unreviewed replicas abort; existing
evidence destinations cannot be reused. It adds no constraints and does not
silently drop failed or raw paths.

`scripts/audit_hdmi_csync_reports.py` independently requires the entire
320-report enumeration, exact source/target/domain coverage, nonnegative
synchronous stage/consumer results, complete unsaturated consumer fanout,
separate raw/global diagnostics, and matching before/after controller/
framework/reporter/original STA/summary/RBF hashes. Mock testing passes 320
ordered reports, six invalid native-inventory controls, 22 invalid scope/
timing controls and four invalid provenance controls; these are **synthetic**
checks, not native stage timing or a new RBF acceptance claim. They now run
under CI's `test-hdmi-handoff-board-inventory` target. The current source-bound
fit remains live; native execution must wait until its database is terminal.

### Terminal fit and replicated second-stage finding

The `00cabd4` flow finishes zero at **2026-10-10 00:15:02 UTC** (7m56s,
162 warnings). Flow-summary minima are setup **-18.551 ns**, hold **+0.234
ns**, recovery **+3.898 ns**, removal **+0.764 ns**, pulse **+0.529 ns**.
This is not independent all-corner acceptance; global timing/MTBF/I/O remain
open. Unqualified RBF SHA256:
`f181ad9267bd0a92fd78f3ca6ed4302a2654c586212fab0f0f5d0b1308f13f6f`.
Manifest/summary copies: ignored `output_files/hdmi-csync-board-00cabd4/`.

The installed native reporter first rejects the preserved older `8685be0`
fit with missing `dv_epoch_meta` (exit 3), before creating a report directory;
log `/tmp/x1-csync-native-old-framework-negative-v1.log`. On the new completed
fit it rejects `dv_csync_sample~DUPLICATE` (exit 3, no reports), log
`/tmp/x1-csync-board-inventory-00cabd4-v1.log`. Independent before/after hash
checks preserve the original source/STA/summary/RBF in both attempts. This
is a **failed native scope gate**, not 320 passing timing reports.

The no-SDC `scripts/quartus_hdmi_csync_replica_inventory.tcl` then completes
with zero errors/warnings on that preserved fit; log
`/tmp/x1-csync-replica-inventory-00cabd4-v1.log`. It confirms:

- `dv_csync_meta` fans out to both physical second-stage copies.
- Canonical `dv_csync_sample` drives `dv_csync_first` (the consumed-policy echo).
- `dv_csync_sample~DUPLICATE` drives actual `dv_hs1`.

Connectivity alone is not sequential equivalence or physical CDC acceptance.
Splitting the policy defeats the intended single physical sample shared by
the HS consumer and echo. The new framework therefore applies documented
`dont_replicate` only to `dv_csync_sample`; all scalar/replica/first-fanout/
data-driver guards stay strict. No new SDC is added. Existing board defaults
remain unchanged. Its new framework hash is
`583dd6f99967b8fc10df7f83ae92e6206f7c0874c51985669609831fcb800630`.

Fresh frozen-source native runs repeat all six normal and six skew profiles
with the same results: 5,030 words/204 holds/10,273 native-HS checks and
5,032 words/192 holds/13,143 HS checks, respectively. Independent audits pass
against the new framework/emitter/fixture/bench/controller hashes. Logs:
`/tmp/x1-csync-single-sample-normal-v1.log`,
`/tmp/x1-csync-single-sample-skew-v1.log`. The matching no-echo negative
still exits 1 at the intended early-unblank assertion with completion zero;
`/tmp/x1-csync-single-sample-noecho-negative-v1.log`. Static extraction/auditor
checks also pass. A **new fit and native scope/timing inventory** must prove
that the protected second-stage really remains single and shared. Neither
native simulation nor an attribute declaration establishes that topology.

The verified single-sample checkpoint is pushed as `ce2eba8`. A clean exact-
commit host checkout starts a fresh full flow in
`output_files/quartus-linux-b8qkpvN8/source`, complete source commit
`ce2eba80d6fd6d2fd0cdbfbb4814c19576f87d3e`; log
`/tmp/x1-quartus-ce2eba8-z-single-csync-sample.log`. Live mapping is confirmed
(PID 1340148). Final topology, native inventory/timing, MTBF/I/O and hardware
remain open. All prior fits and failed scope evidence remain preserved.

## Single-sample fit and native all-corner inventory

The `ce2eba8` full flow completes zero in eight minutes (162 warnings),
ending October 9 at 17:29:19 on the build host. Its source snapshot remains
`output_files/quartus-linux-b8qkpvN8/source`. Flow-summary minima are setup
**-18.327 ns**, hold **+0.253 ns**, recovery **+4.220 ns**, removal
**+0.820 ns**, and pulse width **+0.529 ns**. Design MTBF is not calculated
because timing requirements are unmet. RBF SHA-256 is
`6388008ee87bb1b5cff9b6ff108fc0d9cf1d84e45299e8336db2298ad212cb8d`;
this is an **unqualified experimental RBF**, not a recommended tester build.

The guarded native csync inventory now completes zero with zero warnings.
The exact scalar/replica, four first-stage fanout and four registered-driver
checks pass on this fit, unlike the preceding split-sample fit. Independent
local auditing checks all **320 reports**, including **912 synchronous
stage/consumer rows** at eight corners: minimum setup/hold **+19.594/+0.230
ns**. These include the shared csync sample's echo and native-HS capture paths.
The sample replication repair is therefore supported by fitted evidence,
not merely the source attribute or native simulation.

The same audit records, without accepting them, 64 raw crossing rows with
minimum setup/hold **-9.318/+0.178 ns**, and global setup/hold
**-18.327/+0.009 ns**. The latter eight-corner hold minimum is distinct from
the original flow summary. Raw inputs are not newly excluded by this probe.
Original controller/framework/reporter/STA/summary/RBF hashes match before
and after. Native log: `/tmp/x1-csync-board-inventory-ce2eba8-v1.log`;
local report copy: ignored
`output_files/hdmi-csync-board-ce2eba8/csync-board-inventory-v1/`.
MTBF/placement, held output-data/mode paths, I/O and physical acceptance remain
open. No MiSTer was loaded, and ordinary board defaults remain unchanged.

## Native blank/closed-clock mode-change checks

The extracted native-policy bench now checks each held-mode change while
`output_blank` and `busy` are asserted and the output clock is low. It also
requires at least three complete 32 MHz control periods (93,750 ps) since
the last output-clock transition, before the existing five-period first-edge
settle check. These are functional controller checks, not routed timing or
physical clock-gate readback.

Fresh six-profile runs on framework `583dd6f99967b8fc10df7f83ae92e6206f7c0874c51985669609831fcb800630`
and bench `f6a53879693b3c9bb60d00967f0f83d67c7cea9fc9de533651e8e573c4b37358`
complete zero. Normal: 5,030 output words, 204 first-edge and closed-mode
checks, 10,273 native HS checks. Synthetic 3 us policy delay: 5,032 words,
192 first-edge and closed-mode checks, 13,143 HS checks. Both have minimum
closed-mode quiet time 96,873 ps. Logs are
`/tmp/x1-hdmi-mode-closure-normal-v1.log` and
`/tmp/x1-hdmi-mode-closure-skew-v1.log`; frozen fixtures are copied into ignored
`output_files/hdmi-mode-closure/{normal,skew}/` and independently audited
locally against current sources. The result auditor requires all six closed-
mode counts to match the first-edge counts, and rejects short quiet times.
Its synthetic positive and fifteen invalid controls pass locally.

The repeated raw-policy negative exits 1 with completion zero at the existing
output-pipeline assertion (`/tmp/x1-hdmi-mode-closure-raw-negative-v1.log`).
It does **not** reach or independently validate the newer closure assertion.
Full upstream/DDR/PHY, fitted timing and physical mode switches remain open.

## Held-output-mux delay-budget proposal (unselected)

Fresh full held-mode discovery on the `ce2eba8` fit completes zero, with
original artifact hashes unchanged. Independent auditing covers **1,936 rows**
and 95 source/endpoint/clock combinations at eight corners; minimum setup/hold
is **-18.327/+0.813 ns**. Each corner/check has 121 rows: 29 for each selected
output clock alias, 62 SYS-control paths and one raw csync input. The latter
now ends at `dv_csync_meta`, not the native HS consumer. Log:
`/tmp/x1-handoff-mode-inventory-ce2eba8-v1.log`; local ignored report copy:
`output_files/hdmi-csync-board-ce2eba8/handoff-mode-inventory-v1/`.

`scripts/constraints/hdmi_held_mode_candidate.sdc` is an **unselected**
29-pair proposal for held-mode D routes: bit 0 to the 24 first-stage RGB bits
and HS/VS/DE; bits 1 and 2 to HS only. It guards exact scalar/replica identities,
three clock identities/periods, and the actual synchronous D-input drivers
before applying any constraint. It does not constrain mux clock-selection
pins, raw synchronizers, output DDR/I/O or ordinary pixel-data transfers.

The first 8 ns/0 ns proposal fails the independent positive-slack audit: setup
reaches -0.474 ns and hold -1.394 ns. Installed Quartus 17 help confirms max/
min delay includes clock latency and provides no `-datapath_only` option;
`/tmp/x1-hdmi-delay-help-v1.log` records the exact tool help. The failed probe
is preserved at `held-mode-probe-v1`, with candidate SHA-256
`3f8a7b3e2e7ec27191348f7a78fa521381f4c8b3297f36a1d850f4cdbb7fdda2`.
It is not counted as a passing test or silently overwritten.

The revised proposal derives its budget from the controller's stopped-clock
windows, not ordinary SYS/output phase relationships. Publication is at
least three CTRL periods after the last output transition and at least five
periods before the first reopening edge in the native bench. Use one CTRL
period (**31.25 ns**) for the setup relationship and **-31.25 ns** for hold,
inside those verified pre/post quiet windows. A negative minimum relationship
is not a negative physical data delay: the destination clock is closed while
the bundle changes. This is a functional contract awaiting physical clock-
selection/closure qualification, not a blanket CDC exception.

The revised read-only native probe completes zero and independent auditing
passes **192 reports**, **928 budgeted rows** with minimum setup/hold
**+22.776/+29.856 ns**, and exact bound relationships. All physical route/data
delays match; **1,008 other mode rows and 64 raw-input rows are unchanged**.
Global after-probe setup/hold remains **-12.149/+0.009 ns**. The setup leader
is HDMI-domain csync/OSD data reaching the video-selected output alias; these
inactive-branch/data-sensitization paths need separate analysis, not held-mode
exceptions. No original STA/RBF is changed and no new RBF is built by the probe.

Candidate SHA-256:
`71889e04b0f6dc073f8139988418662edf755b0f45a10bb5fa61235a5b5b1763`.
Native log: `/tmp/x1-held-mode-probe-ce2eba8-v2.log`; local copies:
`output_files/hdmi-csync-board-ce2eba8/held-mode-probe-v2/`.
`make -C verilator test-hdmi-handoff-input-sdc` now also runs eleven invalid
candidate-scope/clock/route controls, nineteen invalid report controls and
four invalid source/artifact controls. Those synthetic checks are not native
timing evidence. The candidate remains absent from every QSF/SDC include;
fresh fitting, controller/clock-pin and physical qualification remain open.

## Fresh fitted profile and native helper-context diagnostic

Completed-fit discovery on the `4cd18ed` snapshot identifies a third exact
prefetch profile: ASDATA on `hdmi_dv_hs`, `hdmi_dv_de`, and data bits 0, 6, 17;
the other nineteen prefetch inputs use D. The output-bank inventory is unchanged.
The inactive candidate accepts only three complete observed signatures, never
independent per-bit alternatives. Local checks pass all three exact 77-cut lists,
twenty original negative controls per profile and 2,045 invalid mixed signatures.

The first native context probe rejects the previously unknown profile before
applying cuts. A second probe fails on a reporter Tcl `else` syntax error;
both failed diagnostics are retained and are not acceptance evidence.
The corrected v3 diagnostic completes with zero errors/warnings and an
independent 384-report audit. BEFORE loads the original held helper globally
for diagnostic comparison and explicitly omits inactive cuts; AFTER uses
native `read_sdc` with the repaired inventory argument and third-profile cuts.
This does not retroactively make the original failed full STA successful.

Across eight corners/setup/hold, 928 held-budget rows and 6,560 active/raw/mode
rows are unchanged; 848 inactive rows are explicitly EXCLUDED, not timing passes.
Global setup/hold remains **-9.918/+0.031 ns**. All eleven source/original-artifact
hashes match before/after; the original unqualified RBF remains
`38a779e9e6e72ea80d8d19087b32978e705b192b14573f180248496b027fb8ee`.

Evidence: `/tmp/x1-held-sdc-native-context-d02ee67-v3.log` and ignored
`output_files/held-sdc-context-d02ee67-v3/reports/`.
Reporter: `scripts/quartus_held_sdc_context_probe.tcl`; independent auditor:
`scripts/audit_held_sdc_context_probe.py`. Fresh source-bound full flow,
PCG-WE timing, CDC/MTBF/I/O and physical switching remain required. No new
MiSTer deployment or timing-qualified RBF is claimed.

## Current-fit gate/witness and inactive-bank discovery

The existing read-only controller inventory repeats on the preserved
`ce2eba8` full fit. Native execution completes zero with zero warnings;
current-source/hash and independent eight-corner audits pass **208 stage/
witness/native-gate rows**, minimum setup/hold **+2.148/+0.174 ns**. Exact
first-stage and gate-enable fanout checks pass. Global timing remains
**-18.327/+0.009 ns**; this is not physical gate readback or board acceptance.
Log: `/tmp/x1-handoff-board-inventory-ce2eba8-v1.log`; local ignored copy:
`output_files/hdmi-csync-board-ce2eba8/handoff-board-inventory-v1/`.

The extracted native-policy bench additionally supports `POISON_INACTIVE=1`:
the video input bank is X when HDMI is selected, and the HDMI bank is X when
video is selected. Every unblanked visible output must remain known and match
the selected-bank/pipeline oracle. Six native clock profiles pass **5,030
visible-output checks**, 204 first-edge/closed-mode checks and 10,273 native
HS checks. This includes all existing mode/reset/stopped-CE transitions and
the real ten-edge output flush; it is four-state masking/flush evidence, not
an analog metastability or routed-timing model.

Fresh normal/skew repeats also pass on this new bench hash
`f9ed1f639ce8c9113754124965faa016c27e9de093f91520abd48e8c55838816`:
normal retains 5,030 words/204 holds/10,273 HS checks, skew 5,032 words/192
holds/13,143 HS checks. Local independent audits require frozen input hashes
and explicit poison enable/check counts matching every visible-output count.
Logs: `/tmp/x1-inactive-{poison,normal,skew}-native-v1.log`; fixtures copied
to ignored `output_files/hdmi-inactive-poison/{poison,normal,skew}/`.
The matched `poison-raw` diagnostic bypasses held selectors and exits 1 at
the pipeline assertion with completion zero, rather than a successful matrix;
`/tmp/x1-inactive-poison-raw-negative-v1.log`. It does not specifically reach
the unknown-output assertion. Synthetic auditor normal/poison positives and
nineteen invalid evidence controls pass in CI's reset-audit target.

`scripts/quartus_hdmi_inactive_data_inventory.tcl` discovers fitted drivers,
pins and both wrong-parent/output-alias directions without new constraints.
Its first attempt fails a Tcl scalar/array collision; the second fails its
assumption that every logical prefetch RGB bit has a separate keeper. Both
failed scripts/logs remain preserved; neither is counted as timing evidence.
The revised discovery enumerates every physical prefetch keeper (including
potential replicas), plus every canonical first-stage output keeper.

Native v3 completes zero with zero warnings. Independent auditing checks
**32 reports, 51 physical targets and 848 rows** at all eight corners, exact
clock identities, target coverage, physical D pins, registered drivers and
unchanged original artifacts. There are 27 output targets and 24 prefetch
targets (21 RGB and three sync/DE); logical bits 4/8/20 have no separate
prefetch keeper on this fit. Driver discovery retains their actual shared
routes; do not infer a general RGB width or treat those missing keepers as
missing logical functionality.

| Inactive direction | Setup minimum | Hold minimum |
| --- | ---: | ---: |
| HDMI master to video-selected output alias | -12.149 ns | +0.009 ns |
| Video master to HDMI-selected output alias | -7.999 ns | +0.454 ns |

These are **discovery**, not accepted or excluded timing paths. Source-bound
native log: `/tmp/x1-inactive-data-inventory-ce2eba8-v3.log`; local reports:
`output_files/hdmi-csync-board-ce2eba8/inactive-data-inventory-v3/`.
Reporter SHA-256:
`4c9475d07f0bfa08f7519daf5920893ac08c969de75e23bc4f8dde9cfdfc106a`.
The inventory auditor's synthetic 32-report positive, nineteen invalid
scope/pin/driver/corner/report controls and four provenance controls pass in
CI's board-inventory target. No inactive-data exceptions or source RTL changes
are made; exact clock-qualified pin scoping, active-path preservation, fresh
fitting and physical output remain next gates.

## Clock-qualified inactive DATA-pin proposal (unselected)

Installed Quartus 17 `set_false_path` help confirms clock-qualified `-from`
and `-to` with a single through-pin collection; recorded without opening a
project in `/tmp/x1-hdmi-delay-help-v2.log`. The new unselected
`scripts/constraints/hdmi_inactive_data_candidate.sdc` scopes only the
opposite-parent path through exact first-stage D/ASDATA pins to the inactive
output clock alias. It does not group master clocks or cut CLK, SLOAD, Q,
SYS-held mode data, synchronizer inputs, downstream DDR or active data paths.
The prior four-state native masking/flush qualification supplies its functional
contract; physical behavior and MTBF remain separate.

Its guards require the discovered 27 output and 24 prefetch keepers, exact
registered driver families and held selector inputs, absence of unreviewed
replicas, and four clock identities/periods. Every guard completes before
any exception. The current fit has 53 output D/ASDATA pins and 24 prefetch
data pins. Prefetch bits **0/1/10/12/15/16/21** pack onto ASDATA rather than D;
the other prefetch data inputs use D. A changed physical bank or pin packing
must stop the candidate for new discovery, not silently broaden the scope.

The first native run completes but a mock negative finds its pin-layout guard
too permissive. The strengthened second run rejects its incorrect assumption
that every prefetch input uses D. The third corrects that layout and completes,
but logs opaque Quartus collection handles instead of independently verifiable
pin names. These intermediate scripts/logs are preserved and are **not**
counted as qualification. The fourth logs each verified physical pin name;
its constraints have the same intended scope, with strict topology guards.

Native v4 completes zero with zero warnings. Independent auditing checks
**384 before/after reports**, **77 exact pin cuts**, and explicitly identifies
**848 original inactive timing rows as EXCLUDED, not passing timing**. It
preserves **6,400 active/raw-input/held-mode rows**, including physical delays,
slacks and clock relationships. Original controller/framework/STA/summary/RBF
hashes match before and after; this diagnostic neither rebuilds nor deploys
an RBF.

| Preserved active group | Setup minimum | Hold minimum |
| --- | ---: | ---: |
| HDMI master to HDMI-selected input bank | -0.106 ns | +1.234 ns |
| Video master to video-selected prefetch | +14.082 ns | +1.679 ns |
| HDMI-selected output pipeline | +1.890 ns | +0.182 ns |
| Video-selected output pipeline | +10.201 ns | +0.182 ns |

The active HDMI csync-to-HS setup violation remains visible. Global after-probe
setup/hold is **-18.327/+0.057 ns**; the independently tested held-mode proposal
is not applied in this probe. Neither this global result nor the excluded
inactive rows establishes closure. Next qualify both proposals together,
preserve all unrelated routes, then fit a source-bound experimental revision
and resolve the remaining active paths. Ordinary boards remain unchanged.

Candidate SHA-256:
`5e4195b520ca0b56f8a83d45be1f7842bd08cbbe75d9a35d1224fa32b7f6deaa`.
Native log: `/tmp/x1-inactive-data-probe-ce2eba8-v4.log`; local ignored reports:
`output_files/hdmi-csync-board-ce2eba8/inactive-data-probe-v4/`.
CI's input-SDC target adds a 77-cut exact-scope mock with twenty invalid
clock/keeper/driver/pin controls, plus a synthetic 384-report auditor positive,
twenty-one invalid preservation/report controls and four invalid provenance
controls. The profile test requires this candidate to remain absent from all
QSF includes. These synthetic tests do not replace the native evidence above.

## Joint output proposal and experimental selection

The unselected joint diagnostic sources the frozen held-mode and inactive-
data proposals without changing either standalone reporter or the preserved
fit. `--joint` auditing requires a separate nine-file before/after manifest,
the exact held-budget marker, all 77 pin cuts, and full held-mode scope; joint
evidence cannot qualify the standalone protocol.

Native execution completes zero with zero warnings. Independent auditing
passes **384 reports**, **928 exact held-mode budget rows** (minimum setup/
hold **+22.776/+29.856 ns**), **848 inactive rows explicitly EXCLUDED**, and
**5,472 active/raw/unbudgeted-mode rows unchanged**. All physical held-data
routes match before/after. Original controller/framework/STA/summary/RBF
hashes are unchanged. Active HDMI still reports **-0.106 ns** setup; this
joint proposal does not mask or fix that real active-path violation.

Global after-probe setup/hold is **-10.797/+0.057 ns**. The setup leader is
`ioctl_download` reaching PCG RAM write-enable keepers. Wrapper/source
inspection connects download to machine reset, while `x1_pcg_access` gates
video RAM writes with both CPU reset and local video reset. This identifies
the next reset/data-domain investigation, not measured corruption or a
qualified fix. The four raw csync/epoch inputs also remain timed; no new
reset, PCG, whole-clock or raw-synchronizer exclusions are added here.

Native log: `/tmp/x1-joint-output-probe-ce2eba8-v1.log`; local ignored reports:
`output_files/hdmi-csync-board-ce2eba8/joint-output-probe-v1/`.
Joint diagnostic SHA-256:
`6b4d7092539d95d50a73ef159f9a388a95ea9f95674be0cd8163e2886992241b`.
The auditor's separate joint synthetic positive, ten invalid scope/budget/
preservation/protocol controls and four invalid provenance controls pass;
the original standalone controls still pass unchanged.

Following that joint scope qualification, **only**
`sharpx1_turbo_z_handoff.qsf` now selects the two individual proposals after
its six-input candidate. The diagnostic joint wrapper remains unselected;
all other revisions retain their prior constraints/features. This is an
experimental build selection, not fitted timing or physical acceptance.
A fresh exact-source full flow must reprove keeper/pin packing and stage/
active timing; previous fitted topology is not automatically inherited.

## Source-bound fit failure and stage-safe discovery (October 9)

The fresh `db2dc8c` handoff attempt in
`quartus-linux-H1XpgcbN/source` completes synthesis but terminates three at
the inactive-data candidate's strict pin guard. Prefetch bit 0 exposes `|d`
instead of the earlier fit's `|asdata`; constraints are not loaded successfully.
No new RBF/timing/PCG qualification is established. Log:
`/tmp/x1-quartus-db2dc8c-handoff-retry.log`.

New reporting-only `scripts/quartus_hdmi_mapped_data_inventory.tcl` enumerates
targets, synchronous drivers and physical pins **without SDC or exceptions**.
The preserved failed build's genuine mapped discovery completes zero with
51 keepers and 77 D/ASDATA pins. Its seven previously ASDATA-only prefetch
keepers now use D: bits 0/1/10/12/15/16/21. Historical `ce2eba8` fitted
discovery also completes zero with 51 keepers/77 data pins and the original
seven-ASDATA layout. These counts are inventory, not timing acceptance or
permission to accept arbitrary pin packing.

An attempted `-post_map` query of that completed historical database emits
Critical Warning 332199: the option is ignored after fitting. That transcript
is **not mapped evidence** and cannot establish a same-stage comparison.
The tightened script now rejects a mapped request when the fitter summary
is Successful, and rejects fitted requests without a successful summary.
Both wrong-stage controls terminate three at their precise guards; correct
mapped/fitted modes complete zero. Any ignored-option warning must still
invalidate a reported mapped stage. Five ordinary PLL warnings in the failed
build's discovery are retained, not suppressed or confused with timing passes.

Current script SHA-256:
`d431a2f6ad4ed0b51341e53da50156c4c60fc79509226a6332d3070c67bae180`.
Logs: `/tmp/x1-hdmi-mapped-db2dc8c-discovery-v3.log`,
`/tmp/x1-hdmi-fitted-ce2eba8-discovery-v3.log`, and
`/tmp/x1-hdmi-{ce2eba8,db2dc8c}-wrong-stage-negative-v3.log`.
The controller/machine/QSF source hashes in both snapshots remain consistent
with their input manifests, and the historical RBF remains
`6388008ee87bb1b5cff9b6ff108fc0d9cf1d84e45299e8336db2298ad212cb8d`.
No candidate SDC or board setting has been relaxed or changed.

A matched synthesis-only copy of the old source is now running in a new
ignored snapshot, `hdmi-synthesis-stage-u9a2sxvJ/source`, with no original DB
copied. Its first direct `quartus_map` attempt failed before synthesis because
it skips the normal flow's generated `build_id.v` hook. The exact historical
generated header was then copied (SHA-256
`1129592d58d7243fb463315e148909ab7b4035ce090d35bdd499dee7f26e2824`),
and the retry started after another idle-host check. It now terminates zero
(150 synthesis warnings). Correct mapped discovery on this new, never-fitted
database also terminates zero, without ignored-option warnings. Its complete
sorted target/driver/pin inventory is **byte-identical** to the genuinely mapped
`db2dc8c` failed build: both topology texts hash to
`9a706d7b74d40d6c21acea9cee75086bbae29302e5296c4a7ac89f08f96b4871`.
Thus these seven D-versus-ASDATA differences are demonstrated between actual
early and packed netlists, not an inferred source change or a relabeled fitted
database. The guard is applying a fitted pin contract too early in the flow.
Logs: `/tmp/x1-hdmi-ce2eba8-fresh-synthesis-stage.log` and
`/tmp/x1-hdmi-ce2eba8-fresh-synthesis-stage-with-id.log`; honest discovery:
`/tmp/x1-hdmi-ce2eba8-genuine-mapped-discovery-v3.log`.
At this checkpoint, an exact early/packed pin contract and its negative
controls, plus native before/after active/raw scope auditing, remained required
before another selected full build. No timing exception or guard was changed
by the discovery investigation; the subsequent repair is recorded below.

### Exact whole-bank early/packed contract qualification

The handoff-only inactive-data candidate now recognizes two **complete**
observed prefetch pin profiles: all 24 DATA inputs on D, or exactly the seven
listed inputs on ASDATA and the other 17 on D. It does not allow independent
per-bit alternatives. All clock identities, exact register/driver inventory,
output pins, replicas and opposite-parent alias checks remain enforced before
any of the 77 cuts. No ordinary revision or machine RTL changes.

`make -C verilator test-hdmi-handoff-input-sdc test-hdmi-handoff-board-profile`
completes zero. Both exact positive profiles pass with independently compared
complete cut lists; all original twenty invalid controls fail before cuts at
both profiles, and all 126 intermediate seven-bit packing patterns fail
before cuts. Log: `/tmp/x1-hdmi-two-pin-profiles.log`.

The reporting-only `scripts/quartus_hdmi_pin_profile_check.tcl` loads assigned
SDCs in their original order, replacing only this candidate in memory. It
refuses a successful fitted database to avoid ignored `-post_map` queries.
On the preserved failed `quartus-linux-H1XpgcbN/source` mapped database it
terminates zero with the **direct** profile and all 77 cuts; five inherited
PLL warnings remain. This proves native guard loading, not fitted route
preservation or timing acceptance. Log:
`/tmp/x1-hdmi-direct-native-guard-v3.log`.

A separate native eight-corner before/after probe on the historical
`quartus-linux-b8qkpvN8/source` completed fit terminates zero with no warnings
and the **packed** profile. Its independent full source/artifact audit passes:
384 reports, 848 original inactive rows explicitly excluded (not passed),
6,400 active/raw/held-mode rows unchanged. The active HDMI setup violation
remains -0.106 ns; global setup/hold remains -18.327/+0.057 ns in this probe.
Before/after hashes of the controller, framework, candidate, reporter and
original STA/report/RBF match. Candidate SHA-256:
`8d668f295c026b5fa91e231d924c68e2990b337f2a06f6afab437cfcd475e28d`.
Log: `/tmp/x1-hdmi-packed-native-preservation-v2.log`; ignored local reports:
`output_files/hdmi-pin-contract-e111325/packed-profile-probe-v2/`.
The first packed probe also completed but lacked pre-run provenance hashes;
it is not substituted for the fully audited second probe.

A fresh full source-bound fit must still prove its actual pin profile, PCG
write-enable repair, active timing, CDC/MTBF and physical behavior. A third
packing profile must fail and be rediscovered, not silently admitted. The
build-host availability check found another project's active Quartus flow;
no new full build was launched or competing process interrupted.

The competing flows later ended. After an actual idle-process check and
clean-checkout fast-forward, the guarded helper launched a new full flow at
`2026-10-10T04:36:33Z`, source
`4cd18ed4ac170240e3af0394bf57f41dcc18df35`, revision
`sharpx1_turbo_z_handoff`, Quartus 17.0.2 Build 602. Immutable snapshot:
`/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-9YrpMbWH/source`.
Input-manifest SHA-256:
`5d7fa6f158af6c4f75e943ca50b2201ff4daa19c70bd37e6fbb2ee743dfeaf25`.
The source-before/source-after/snapshot comparisons pass before launch;
actual `quartus_sh`/`quartus_map` processes confirm synthesis is live.
Log: `/tmp/x1-quartus-4cd18ed-handoff.log`. This is a started flow, not
synthesis/fitting/timing acceptance or a new tester RBF. No MiSTer is loaded.

The flow subsequently terminates **3**, after 9m23s. Synthesis completes
zero (150 warnings), fitting completes zero (11 warnings; 20,525/41,910 ALMs,
49%), and assembly completes zero. Final TimeQuest fails because
`x1_mode_scalar` reads `::x1_mode_inventory` although `read_sdc` evaluates
the held-mode file in a non-global context. This is a same-file helper scope
dependency, not missing HDL or another file's inventory. The inactive-data
candidate is not reached in final STA, so its new fitted pin profile remains
unqualified. Partial failed STA reports cannot establish timing closure.

The failed flow produces source-bound RBF SHA-256
`38a779e9e6e72ea80d8d19087b32978e705b192b14573f180248496b027fb8ee`.
It is **unqualified**, not a successful full flow or a new accepted tester
artifact. The source snapshot, input manifest and failed reports stay
unchanged. Final manifest records exit 3 at `2026-10-10T04:45:56Z`.

The local repair passes the exact inventory as a helper argument rather than
reaching into the global namespace. No keeper/replica/driver/clock check,
29-pair scope or max/min bound changes. The mock now checks all three load
contexts independently (global/procedure/namespace): three identical complete
58-command positive lists and eleven rejecting controls at each context,
before any partial constraint application. The related full scope/provenance/
board-isolation targets complete zero in
`/tmp/x1-hdmi-held-sdc-context-tests-final.log`.
Candidate SHA-256:
`e4266eaa455e0603b0df5e2a8439bfb69b36e98956d431808c7e73acf1f3d5e1`.
An initial expanded mock failed due to collision of its oracle's global
`expected` variable with an SDC scratch variable; a distinct mock-oracle name
fixes that harness bug without altering the proposal. The failure is retained.
Native completed-fit scope/preservation and a fresh source-bound final STA
remain required. Other build-host projects are currently active, so no
competing analyzer or another full build is started.

## Fresh 048d996 handoff flow: fitted guard rejection

Revision `sharpx1_turbo_z_handoff`, source
`048d9968d5aeaa0013d2ab0a1816991f20fed1ad`, runs on misterubuntu at
2026-10-10 05:58:29–06:07:08 UTC. Its preserved snapshot is
`/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-MYNcRVzw/source`;
input-manifest SHA-256:
`2d30392c315100f3dce5d5d7226f4165a370836e2992c96fa4cbe630a07b5d17`.

Synthesis, fitting and assembly pass, but final STA terminates 3 with
`unreviewed whole-prefetch D/ASDATA profile; repeat discovery`. The three
previously qualified exact profiles do not authorize this newly fitted bank.
No guard is loosened, no retry is launched and no core is deployed. Partial
STA diagnostics report setup/hold **-9.962/-2.615 ns**, with MTBF not calculated;
these are not a successful full-flow/eight-corner qualification.

The generated, unqualified RBF SHA-256 is
`16fd053ce22f7ab13f2a2d4982bda07092ede03a7011a5d98a3c3aa16e934a88`.
Local log: `/tmp/x1-quartus-048d996-handoff-local.due3qQKo`;
remote log: `/tmp/x1-quartus-048d996-handoff-remote.Gb9fULCx`.
This board still leaves the experimental RTC disabled.

A subsequent reporting-only fitted-inventory task checks availability once
at 06:09:58 UTC, finds another project's active Quartus fit, and stops without
creating a probe or touching preserved artifacts. Next: discover the exact
24-prefetch pin/keeper/driver contract without SDC changes, qualify any new
whole-bank scope independently, preserve active paths, then run a fresh flow.
The initial launch's idle check is best-effort, not a host-wide reservation;
another project started afterward. Never stop its job to obtain evidence.

The next idle-host check succeeds: reporting-only fitted discovery completes
zero with zero warnings/errors at 06:14:56–06:15:00 UTC. Independent review of
the raw log proves 51 exact keepers, 205 unique pins, 77 D/ASDATA pins and
one matching `dv_*` driver per prefetch keeper. The seven ASDATA prefetch
keepers are `hdmi_dv_hs`, `hdmi_dv_de` and data bits **3,12,13,16,17**;
all other 17 prefetch keepers use D. Output pin scope remains unchanged.
Prefetch bits 4/8/20 remain absent; no target replicas appear. OSD/csync source
replicas are reported separately, not treated as target keepers.

Evidence: `/tmp/x1-hdmi-fitted-048d996.Txc7ofMH/`; raw log SHA-256
`6ea35ae397a3394083ba8f1973caf43c1e95b02224a3a3f79b8f736e77e650df`.
All **20** original source/artifact hashes agree before/after (the manifest
also records three additional reporter/build/input hashes). No SDC was loaded.
The local candidate now accepts this fourth **complete observed profile**,
not independent D-or-ASDATA choices. Four mocked positives require exactly
77 scoped DATA cuts; twenty invalid scopes per profile and all **8,188**
unreviewed combinations over thirteen changing keepers refuse every cut.
Log `/tmp/x1-hdmi-four-profile-scope.log` terminates zero. Native same-fit
active/raw/mode preservation is the next gate; this is not timing closure,
fresh full-flow acceptance or permission to deploy the failed-flow RBF.
The connected `test-hdmi-handoff-input-sdc` target also completes zero
(`/tmp/x1-hdmi-four-profile-connected.log`). A separate strict `--fit-048d996`
auditor binding now requires this preserved fit's five exact artifact hashes,
the corrected original held-SDC hash and exact ordered before/after provenance.
It leaves the historical default binding unchanged and requires `fitted048`
with exactly 77 DATA cuts; synthetic provenance positive and 26 rejecting
controls pass. This prepares independent review, not native preservation.
The same-fit task stops at 06:19:03 UTC because another project's Quartus map
is active; no probe directory or competing flow is created.

### Native fourth-profile same-fit qualification

The later idle-host probe runs at 06:41:46–06:43:16 UTC and completes zero with
zero warnings/errors. Independent `--fit-048d996` auditing of all **384** reports
requires the exact preserved fit/report/RBF and candidate hashes, `fitted048`
and exactly 77 scoped DATA cuts. It proves **928 held-budget rows** and
**6,688 active/raw/mode rows** unchanged; **848 inactive rows are EXCLUDED**,
not timing passes. No pre-existing raw reports are excluded in this inventory.
Global diagnostics remain setup/hold **-9.962/+0.054 ns** after the proposal;
setup still fails. This is same-fit scope preservation, not a fresh full flow,
new PCG-WE/CDC/MTBF/I/O result, timing-qualified RBF or physical acceptance.

Ignored evidence: `output_files/held-sdc-context-048d996-v1/`; native log SHA-256
`9a02fa6fab56de33d56306b5383b1a5ec3cd4aa5a25a693f4aa4ee16674e0c5e`;
all-report hash-list SHA-256
`42724be2201ef90945bfb6ba8570e6ae054a661cd7958260ae7340e8066a99b7`.
Independent copy auditing proves all 384 report hashes and eleven exact
before/after source/artifact pairs; audit log
`/tmp/x1-held-sdc-native-context-048d996-audit.log`. Remote preserved sibling:
`output_files/quartus-linux-MYNcRVzw/held-context-048d996-v1`.
No checkout, original snapshot/report/RBF, other project or MiSTer was changed.
The next full build must bind current source separately, not reuse this older
fit's scope/timing as current machine acceptance.

## Next gates

### Unselected csync first-stage proposal

`scripts/constraints/hdmi_csync_input_candidate.sdc` now prepares four narrow
registered-source/first-stage exclusions for the coherent policy bridge:
epoch to VID, held csync to VID, completed epoch to SYS, and consumed csync
echo to SYS. Exact scalar identities, unreviewed replicas, registered data
drivers and first-stage-only fanouts are guarded for every triple before any
proposed exclusion is issued. Stage transfers, native HS, CE captures,
return-policy consumers and other crossings remain timed. No QSF selects it.

The earlier `ce2eba8` native csync inventory already proves the corresponding
four drivers/fanouts and 912 bounded stage/consumer rows for that fit, but
does not qualify these new exception semantics. The new CI-integrated scope
test passes four exact proposed cuts and 44 invalid identity/replica/driver/
fanout controls, including faults in later triples refusing every cut.
Log `/tmp/x1-csync-input-scope.log`; candidate SHA-256
`7ee95fffde5d3599758f605d76a0d5fc369700f59195fa81e8f8a583029ba022`.
Native before/after source/artifact auditing, unchanged synchronous/active
paths, placement/MTBF and fresh fitting remain required before selection.
This is preparation, not raw-input timing or physical acceptance.

The reporting-only `scripts/quartus_hdmi_csync_input_probe.tcl` now prepares
640 completed-fit reports: the seventeen explicit pairs, both return-policy
consumer groups and global diagnostics, at eight corners/setup/hold before
and after the explicitly supplied proposal. Original SDC is read once and
all 320 before reports precede proposal application. It refuses an existing
output directory and does not rewrite QSF, RTL, original reports or RBF.
`test-hdmi-handoff-input-sdc` also passes mocked orchestration with exactly
640 unique report destinations and no early/partial proposal application
(`/tmp/x1-csync-input-probe-scope.log`). This is not a native timing result;
run the independent native csync inventory alongside it, audit unchanged
stage/consumer rows and original source/artifact hashes, and qualify actual
first-stage exclusions before selecting the candidate.

`scripts/audit_hdmi_csync_input_probe.py` now independently audits the
prepared protocol: every bounded pair and both complete consumer groups must
retain identical positive timing; exactly the four raw source/first-stage
pairs may become empty, explicitly excluded rather than passed. Every
previously reported unrelated global path must remain unchanged. Exact
phase/corner enumeration, report inventory, native scope markers, consumer
counts below cap and seven source/proposal/reporter/original-artifact hashes
before/after are checked. Global timing remains separately reported, not
promoted to closure. The CI-integrated synthetic 640-report positive passes
with eighteen invalid timing/scope and four invalid provenance controls
(`/tmp/x1-csync-input-probe-audit.log`). Native execution remains pending;
these controls are not native constraint or hardware acceptance.

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
