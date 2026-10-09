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
