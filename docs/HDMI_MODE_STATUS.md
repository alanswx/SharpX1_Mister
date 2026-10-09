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
