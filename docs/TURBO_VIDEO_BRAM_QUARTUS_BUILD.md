# Font-BRAM X3 Quartus audit — October 5, 2026

Checkpoint **`f7875af2c5647a733cf68717ef86041539907c47`** compiles, fits and
assembles an RBF, but **is not timing-closed**. The font refactor really uses
four M10Ks, reducing utilization from 94% to 49% ALMs. Primary setup and
recovery fail at **all eight corners**; hold, removal and pulse width pass.
This is build evidence, not hardware acceptance or functional requalification.

## Frozen source and execution

Executed the existing, unmodified script:

```sh
QUARTUS_REVISION=sharpx1_turbo_video bash scripts/build_quartus.sh
```

Evidence directory: [quartus-nAtarDJb](../output_files/quartus-nAtarDJb/).
Frozen source: [source](../output_files/quartus-nAtarDJb/source/).
The script copied 339 tracked/dirty/untracked inputs and compared the source
before/after hashes with the snapshot hashes before starting Quartus.
Independent SHA-256 recomputation using `git show f7875af:<path>` for every
manifest entry confirms **339 matches, zero differences**, including clean
committed `AGENTS.md`. Snapshotting had already completed before the parent
started later WD1793/test/snapshot-version changes; no committed archive or
mixed-working-tree substitution was needed. This evidence is **not** bound
to later `2db40b0`, current HEAD, or the current working tree.

Compared with the preceding `quartus-p0epmzTq` X3 snapshot, exactly two
manifest inputs differ: `AGENTS.md` (documentation) and `rtl/x1_font16.sv`
(font implementation). The previous snapshot's AGENTS exception does not
apply to this build. All other inputs, including RTL/QSF/QIP/SDC/firmware,
match the preceding snapshot. Later main-agent documents/tests are not
FPGA inputs; later WD1793 source edits are inputs, but are absent here.

| Binding | Value |
| --- | --- |
| Commit | `f7875af2c5647a733cf68717ef86041539907c47` |
| [Input manifest](../output_files/quartus-nAtarDJb/input.sha256) SHA-256 | `db49eba3e124e5b964160e021b2d59753b4152f0c73d2744e97ff2eace30b864` |
| `rtl/x1_font16.sv` SHA-256 | `d3ee7b0ebe69cc1f565bc176a9bb472f2db53e05cfc02025e97d90fbf45bca97` |
| `AGENTS.md` SHA-256 | `1525b9276c8b4e7063717103dbc7117cf5490e50234aaddbda989ac57a2f824f` |
| Snapshot | `/Users/alans/dev2/SharpX1_Mister/output_files/quartus-nAtarDJb/source` |
| Runtime | `docker.io/library/quartus17-runtime:apple-amd64` |
| Runtime identity SHA-256 | `6550dd9261ca3b1397e53a2c063d71d6fe646a238fda876c75773ee05be96b3e` |
| Runtime index digest | `sha256:6edc7bc0edee8c0a3f332ced040776c459287e856ee3ba85992512b7b313a370` |
| Build-script SHA-256 | `51d922b6a80b84040bada17beaa21e4010a0dc5da51b2cfa459a013f39cbc3c6` |
| Cached builder SHA-256 | `49a5c3a8c4fa9a6718c96310469b3defc5a4bdeda6908e250383af53e0552fd2` |
| Generated `build_id.v` SHA-256 | `ab6f6e17454d678dfff7f5cd8f753698aa3f5842ba310c324a316a2f1dbeff06` |

The [build manifest](../output_files/quartus-nAtarDJb/build-manifest.txt),
[input list](../output_files/quartus-nAtarDJb/input-files.txt),
[source-before hashes](../output_files/quartus-nAtarDJb/source-before.sha256),
[source-after hashes](../output_files/quartus-nAtarDJb/source-after.sha256)
and [snapshot-time status](../output_files/quartus-nAtarDJb/git-status.txt)
are retained. Post-build rechecking leaves **337 input files byte-identical**;
the two exceptions inside the isolated snapshot are Quartus-generated
`sharpx1.qpf` (header/date/revision list) and `sharpx1_turbo_video.qsf`
(serialized sourced assignments and tool metadata). These are distinct from
the frozen input manifest; root project files were not edited by this audit.

Read current `AGENTS.md`, `Readme.md`, `docs/SHARP_X1_TODO.md`, build script
and the local Apple-container README/builder instructions before task work.
Used installed cached Quartus Prime Lite **17.0.0 Build 595, 04/25/2017 SJ
Lite Edition**, Linux amd64 under the existing local Apple container setup.
No tools/images were installed/downloaded and no licences were accepted.

Project `sharpx1`, revision `sharpx1_turbo_video`, top `sys_top`, Cyclone V
`5CSEBA6U23I7`, seed 1; active path `sharpx1.sv` → `rtl/sharpx1.v` via
`rtl/machine.qip`. `X1_TURBO_FOUNDATION=1`, `X1_TURBO_VIDEO_MASTER=1`, no
single-clock macro. System clock stays 32 MHz; the separate candidate video
PLL and enabled CRTC/video divider are used, not the old PLL video output.
The pre-flow hook generated `BUILD_DATE=261005`.

Main container: 16 CPUs / 16 GiB; map one thread, fit eight threads.
Build-script timestamps are **15:30:48–16:31:06 UTC**, a **1:00:18** span;
script exit **0**. These are measured elapsed values, not a speed guarantee.

| Stage | Quartus elapsed | Errors | Warnings |
| --- | ---: | ---: | ---: |
| Pre-flow hook | 0:02 | 0 | 0 |
| Analysis/synthesis | 3:29 | 0 | 111 |
| Fitter | 53:39 | 0 | 11 |
| Assembly | 1:14 | 0 | 0 |
| Primary STA | 0:53 | 0 | 1 |
| Supplemental eight-corner STA | 10:24 | 0 | 8 |

Fitter CPU time is 45:16; placement 13:20, routing 5:54, post-fit 16:43.
Average/peak interconnect use is 25%/38%, versus 39%/59% previously.
Exit 0 and an RBF do not override `Critical Warning (332148): Timing
requirements not met`.

## Actual fitted PLL, not the requested approximation

The [fitter report](../output_files/quartus-nAtarDJb/source/output_files/sharpx1_turbo_video.fit.rpt)
reports video VCO **945.0 MHz**, M **189**, N **10**, output C **22**,
output **42.954545 MHz**. Derived-clock commands independently confirm
multiply-by 189/divide-by 10 followed by divide-by 22.

```text
requested video = 42.954540 MHz = 42,954,540 Hz
fitted video    = 50,000,000 × 189 / 10 / 22
                = 42,954,545.454545... Hz
error           = +5.454545... Hz
fitted/request  = 1.000000126984143...
relative error  = +0.126984143... ppm
period          = 23.280423280423... ns
```

This is the **actual nominal fitted divider rate**, assuming the specified
50 MHz reference, not an oscillator measurement or PLL jitter/board-tolerance
validation. The rounded STA clock period is 23.280 ns. System PLL M32/N5/C10
gives exactly 32 MHz (31.250 ns); its VCO is 320 MHz. The divider does not
make the requested and fitted video frequencies identical.

## True font RAM and resources

The mapped font RAM is **4096 × 8 = 32,768 bits**, simple dual-port,
dual-clock, with registered address inputs and no initialization file.
Final physical RAM instance:

```text
emu:emu|sharpx1:sharpx1|x1_font16:turbo_font.font16|
x1_video_ram:storage|altsyncram:mem_rtl_0|
altsyncram_2dj1:auto_generated|ALTSYNCRAM
```

It occupies **four M10Ks**, with 32,768 logical and implemented bits, zero
MLABs, at `M10K_X38_Y49_N0`, `M10K_X41_Y50_N0`, `M10K_X41_Y49_N0` and
`M10K_X38_Y50_N0`. Font hierarchy totals are **22.0 ALMs, 22 registers,
35 logic cells, 32,768 RAM bits and four RAM blocks**, compared with the
prior register-font hierarchy's approximately 17,947.4 ALMs / 32,796
registers / no RAM. The RAM child itself uses zero ALMs/registers.
TimeQuest finds **zero** registers matching the previous font-array
`*turbo_font.font16*rom~*` names. The previous direct array-FF→display-data
crossing is eliminated; this does not eliminate readiness CDC.

| Resource | New font-BRAM fit | Previous X3 register-font fit | Two-disk baseline | New minus baseline |
| --- | ---: | ---: | ---: | ---: |
| ALMs / 41,910 | 20,327 (49%) | 39,443 (94%) | 20,294 (48%) | +33 |
| Registers | 31,813 | 64,543 | 31,785 | +28 |
| RAM bits / 5,662,720 | 3,106,664 (55%) | 3,073,896 | 3,069,624 (54%) | +37,040 |
| RAM blocks / 553 | 389 (70%) | 385 | 384 (69%) | +5 |
| DSP blocks / 112 | 32 (29%) | 32 | 32 (29%) | 0 |
| PLLs / 6 | 4 (67%) | 4 | 3 (50%) | +1 |
| Pins / 314 | 145 (46%) | 145 | 145 (46%) | 0 |

Relative to the previous X3 fit, this removes **19,116 ALMs and 32,730
registers**, adding exactly **32,768 RAM bits and four RAM blocks**.
Baseline is the successful `quartus-JC4BFj9f` retry in
[DUAL_DISK_QUARTUS_BUILD.md](DUAL_DISK_QUARTUS_BUILD.md), a different
single-clock revision, not an isolated font-only comparison.

Map also emits Info 276007 for a `storage|mem` branch with asynchronous-read
logic. That message must not be interpreted as failure of the retained
font RAM: the final mapped/physical `mem_rtl_0` is explicitly BRAM, as above.
Warning 276027 notes undefined dual-clock read-during-write behavior;
mixed-port collision mode is Don't Care. Single validated writes and
post-read readiness gating do not establish safe arbitrary concurrent
font reload/display collisions on hardware. No private font bytes are embedded.

## Eight-corner constrained timing

Preserved primary `.sta.rpt` and `.sta.summary` before running the established
supplemental procedure against this fit, using the cached runtime with
4 CPUs / 8 GiB (Quartus detected five processors):

```sh
quartus_sta sharpx1 -c sharpx1_turbo_video --multicorner=on --all_corners
```

Supplemental shell timestamps: **16:35:14–16:45:50 UTC** (10:36);
Quartus elapsed **10:24**, CPU time 28:31, exit **0**, zero errors and
eight critical warnings 332148, one per corner. No synthesis/refit/assembly
or assignment/constraint change was made. The final
[STA report](../output_files/quartus-nAtarDJb/source/output_files/sharpx1_turbo_video.sta.rpt)
contains all eight corners; `.sta.summary` remains byte-identical to the
preserved primary summary. RBF/SOF hashes are unchanged before/after STA.

All values below are ns at 1100 mV. Each column is the minimum over reported
constrained clocks, not an unconstrained-path pass claim.

| Model / temperature | Setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow 100°C | -15.059 | +0.245 | -9.804 | +1.086 | +0.529 |
| Slow -40°C | -14.455 | +0.084 | -9.664 | +1.026 | +0.529 |
| Slow 85°C | -14.907 | +0.247 | -9.742 | +1.075 | +0.529 |
| Slow 0°C | -14.493 | +0.096 | -9.653 | +1.012 | +0.529 |
| Fast -40°C | -7.218 | +0.019 | -4.690 | +0.455 | +0.529 |
| Fast 0°C | -7.465 | +0.119 | -4.786 | +0.468 | +0.529 |
| Fast 85°C | -8.145 | +0.131 | -5.048 | +0.516 | +0.529 |
| Fast 100°C | -8.367 | +0.134 | -5.113 | +0.529 | +0.529 |

TNS below sums the report's **per-clock endpoint TNS**, not a deduplicated
count of physical endpoints across clock alternatives. Hold/removal/pulse
TNS are **0.000 at every corner**.

| Model / temperature | Setup TNS sum | Recovery TNS sum |
| --- | ---: | ---: |
| Slow 100°C | -7411.155 | -558.882 |
| Slow -40°C | -7137.206 | -551.417 |
| Slow 85°C | -7343.271 | -555.429 |
| Slow 0°C | -7157.937 | -550.770 |
| Fast -40°C | -3705.511 | -266.391 |
| Fast 0°C | -3794.955 | -271.500 |
| Fast 85°C | -4068.372 | -285.326 |
| Fast 100°C | -4141.389 | -288.828 |

Core output-clock setup results include cross-domain paths and clock-mux
alternatives; they are not same-domain Fmax limits:

| Model / temperature | sys setup | sys setup TNS | video setup | video setup TNS |
| --- | ---: | ---: | ---: | ---: |
| Slow 100°C | -10.176 | -335.694 | -15.059 | -5838.620 |
| Slow -40°C | -9.356 | -303.575 | -14.455 | -5700.050 |
| Slow 85°C | -9.993 | -328.762 | -14.907 | -5800.991 |
| Slow 0°C | -9.430 | -306.515 | -14.493 | -5702.814 |
| Fast -40°C | -5.082 | -168.543 | -7.218 | -2759.733 |
| Fast 0°C | -5.338 | -177.152 | -7.465 | -2815.973 |
| Fast 85°C | -6.337 | -209.925 | -8.145 | -2966.911 |
| Fast 100°C | -6.590 | -218.644 | -8.367 | -3003.858 |

Across all corners, output-clock minima for sys/video respectively are:
hold **+0.019/+0.106**, recovery **+9.914/-9.804**, removal
**+0.747/+0.536**, pulse width **+14.160/+10.183**. Video recovery TNS is
the recovery sum shown above; sys recovery TNS is zero everywhere.
The global +0.529 ns pulse minimum is the video PLL **VCO phase**, not its
divided video output. Full per-clock setup/hold/recovery/removal/pulse and
TNS values for all eight models remain in the linked STA report.

Primary other failing capture clocks are HDMI setup **-8.751**,
`FPGA_CLK1_50` **-6.221**, and `sysmem|fpga_interfaces|clocks_resets|h2f_user0_clk`
**-5.753**; their setup TNS values are -1112.622, -6.221 and -117.998.
Positive same-clock sys/video paths below do not clear these failures.
Compared with the preceding X3 fit's global minima, setup improves from
-16.059 to -15.059, recovery from -10.925 to -9.804, hold from -1.954 to
+0.019, removal from +0.256 to +0.455; pulse remains +0.529. This is a new
placement, so resource improvement is not proof of any particular CDC fix.

## Primary paths and bounded follow-up

All following extracted paths use **Slow 1100mV 100C**. Full reports include
launch/capture clocks, clock skew, data delay and physical endpoints.
Clock labels below abbreviate the exact derived names: sys=`emu|pll|…|divclk`,
video=`emu|turbo_video_pll|…|divclk`, HDMI=`pll_hdmi|…|divclk`.

| Check | Launch → capture | Actual start → endpoint | Slack ns |
| --- | --- | --- | ---: |
| Global setup | HDMI → video | `d[17] → hdmi_out_d[17]` | -15.059 |
| sys → video setup | sys → video | `emu:emu|hps_io:hps_io|status[0]~DUPLICATE → emu:emu|sharpx1:sharpx1|x1_vid:display|crtc6845s:crtc6845s|crtc_gen:crtc_gen|R_LAST_LINE` | -10.696 |
| video → sys setup | video → sys | `emu:emu|hps_io:hps_io|video_calc:video_calc|vid_vcnt[21] → emu:emu|hps_io:hps_io|video_calc:video_calc|dout[5]` | -10.176 |
| Recovery | sys → video | `emu:emu|hps_io:hps_io|ioctl_download → emu:emu|sharpx1:sharpx1|x1_pcg_access:cg_bus|request_meta` | -9.804 |
| Font readiness setup | sys → video | `emu:emu|sharpx1:sharpx1|x1_font16:turbo_font.font16|loaded → …|loaded_meta` | -7.459 |
| Same-clock sys setup | sys → sys | `emu:emu|sharpx1:sharpx1|x1_sub:subCPU|sub_rom:sub_rom|DO[6] → …|dpram:sub_w_ram|q_b[9]` | +7.304 |
| Same-clock video setup | video → video | `csync:csync_vga|csync_hs → dv_hs1` | +11.172 |
| Primary hold | audio → audio | `alsa:alsa|acc[6] → alsa:alsa|acc[6]` | +0.245 |

The global worst setup is a **clock-mux alternative pairing**, not the old
font FF path: `sys/sys_top.v` clocks both `d` and `hdmi_out_d` with
`hdmi_tx_clk`, supplied by `hdmi_clk_sw` from HDMI PLL or core video clock.
TimeQuest reports a 0.564 ns relationship, -5.280 ns skew and 9.973 ns data
delay for the HDMI→video pairing. Existing `sys/sys_top.sdc` clock-group
pattern `*|pll|pll_inst|altera_pll_i|…|divclk` does **not** match the new
`turbo_video_pll|oscillator|…` name. A targeted review of the mux-generated
clocks and genuinely exclusive alternatives is warranted; this report does
not assert that changing exclusivity alone closes the design.

Separately, the timed HPS video return, system control and asynchronous
reset-release paths require their own CDC/reset review. `loaded → loaded_meta`
is the readiness synchronizer's first stage, still timed at -7.459 ns; the
ignored `async_reg` attribute is not a timing exception. Review recognized
synchronizer implementation, stable-data transfer and reset deassertion in
destination domains before applying any narrowly justified constraints.
**No false-path, constraint, RTL or framework changes were made.**

Diagnostic [setup](../output_files/quartus-nAtarDJb/source/output_files/turbo_video_bram_setup.rpt),
[hold](../output_files/quartus-nAtarDJb/source/output_files/turbo_video_bram_hold.rpt),
[recovery](../output_files/quartus-nAtarDJb/source/output_files/turbo_video_bram_recovery.rpt),
[sys→video](../output_files/quartus-nAtarDJb/source/output_files/turbo_video_bram_sys_to_video.rpt),
[video→sys](../output_files/quartus-nAtarDJb/source/output_files/turbo_video_bram_video_to_sys.rpt),
[font readiness](../output_files/quartus-nAtarDJb/source/output_files/turbo_video_bram_font_readiness.rpt),
[same-clock sys](../output_files/quartus-nAtarDJb/source/output_files/turbo_video_bram_system_same_clock.rpt)
and [same-clock video](../output_files/quartus-nAtarDJb/source/output_files/turbo_video_bram_video_same_clock.rpt)
are retained. Interactive extraction exited 0 and printed `AUDIT_COMPLETE`
and `OLD_FONT_ARRAY_REGISTERS=0`; its shell footer nevertheless says
`unsuccessful. 0 errors, 0 warnings`. This is report extraction, not passing
STA. The [diagnostic log](../output_files/quartus-nAtarDJb/timing-paths.log)
retains that footer and the commands.

Supplemental Fast 1100mV -40C endpoint extraction confirms the tight
**+0.019 ns hold** path is
`emu:emu|hps_io:hps_io|video_calc:video_calc|vid_hcnt[29] → …|dout[13]`,
video→sys, and **+0.455 ns removal** is
`ascal:ascal|o_reset_na → ascal:ascal|o_copy.sSHIFT`, HDMI→HDMI.
See [fast-corner hold](../output_files/quartus-nAtarDJb/source/output_files/turbo_video_bram_fast_minus40_hold.rpt),
[removal](../output_files/quartus-nAtarDJb/source/output_files/turbo_video_bram_fast_minus40_removal.rpt)
and [extraction log](../output_files/quartus-nAtarDJb/fast-minus40-paths.log).
This second extraction also exits 0 with `AUDIT_COMPLETE` and the same
zero-error/zero-warning unsuccessful shell footer. Positive margins,
particularly 19 ps on a cross-domain path, are not CDC validation.

## Constraints, warnings and verification limits

Primary STA reports **zero illegal clocks, zero unconstrained clocks**;
setup and hold each retain **3 unconstrained input ports / 7 paths** and
**44 unconstrained output ports / 50 paths**. This matches both previous
reports; it does not establish complete I/O constraints. Unconstrained
inputs include HDMI/IO I²C SDA and partially constrained VGA enable;
outputs include HDMI data/control/clock/I²S/I²C, IO I²C, selected LEDs,
SPDIF, SD SPI CS and USER_IO. Full names/existing exceptions remain in STA.

TimeQuest detects **380 synchronizer chains**, unchanged from the preceding
X3 fit (386 in the two-disk baseline), and explicitly **does not calculate
design MTBF because timing requirements are unmet**. Independent PLL phase,
reset assertion/release, bundled-data stability/max-delay/skew, ignored
`async_reg`, bare PLL reset/lock wiring and mixed-port RAM collision behavior
remain unverified. Zero unconstrained clocks is not CDC signoff.

Warning totals: map **111**, fit **11**, primary STA **1**, versus **110/11/1**
in the preceding X3 fit and **93/9/0** in the two-disk baseline. Normalizing
numeric source locations, the sole added top-level warning relative to the
preceding X3 fit is **276027 for inferred dual-clock font RAM**; none were
removed. Against the single-clock baseline, differences also include font
`async_reg`, the two-bit `x1_video_timing.sv` truncation in place of legacy
three-bit `x1_vid.v` truncation, dual-clock video-memory warnings, 17 rather
than 16 connectivity-warning hierarchies, candidate PLL compensation warning
177007 and timing failure. Counts include nested warning diagnostics, so
top-level set differences are not the same as differences in total counts.
Inherited width/parameter/implicit-net warnings, incomplete I/O, ignored
fitter assignments and subscription-only LogicLock remain; no suppression
or licence action was taken.

The parent reports font16 unit, delay-aware raster-3 ANK warm-reset tests at
both widths and wrapper lint passing, and later reports the five-game
font-checkpoint suite passing. Those tests were **not executed by this
Quartus-only audit**; later v04/D88 tests and source changes are not bound to
this RBF. No hardware was deployed or tested. No source, constraint, test,
build script, existing documentation or sibling repository was edited;
no commit/push was performed. Further functional, CDC/reset, complete-I/O,
PLL/board and hardware validation remain required. No additional refit ran.

The previous timing-failed fit remains at
[quartus-p0epmzTq](../output_files/quartus-p0epmzTq/), with its unchanged
[report](TURBO_VIDEO_QUARTUS_BUILD.md). Its report/build-log/RBF hashes were
rechecked unchanged after this build.

## Artifact hashes

SHA-256 values identify the actual outputs, not a timing-approved release.

| Artifact | SHA-256 |
| --- | --- |
| [RBF](../output_files/quartus-nAtarDJb/source/output_files/sharpx1_turbo_video.rbf) | `1a03fbb3ab40fc0043a478b609fd2f6a0694d3338a09e6904cfd3b00ab3eac64` |
| [SOF](../output_files/quartus-nAtarDJb/source/output_files/sharpx1_turbo_video.sof) | `9adc8f3abe62e39610eaf1b36be1178ba45a52df7830fabe81f75521b973daa2` |
| [Build log](../output_files/quartus-nAtarDJb/build.log) | `0364793fd1b74cf17e7cc0993d73d66e09acb75befc7eeaf0d42d724fe45b688` |
| [Fitter report](../output_files/quartus-nAtarDJb/source/output_files/sharpx1_turbo_video.fit.rpt) | `b8a727d0fc6106957940bbd7eec63f4b3a4b7f8441a523f35b0c302b317c2971` |
| [Map report](../output_files/quartus-nAtarDJb/source/output_files/sharpx1_turbo_video.map.rpt) | `187c02b8e3542fc650f30cf1219324329897cbdeaf11a8402ff6ce39271cfee9` |
| [Preserved primary STA report](../output_files/quartus-nAtarDJb/single-corner-reports/sharpx1_turbo_video.sta.rpt) | `17861e936b42e0dfa7c6564af15b5aaf170a3439884565fa12bcf8c36d65b1db` |
| [Preserved primary STA summary](../output_files/quartus-nAtarDJb/single-corner-reports/sharpx1_turbo_video.sta.summary) | `34771239c7fc06dcdb624696fee4503fbcee9c59727ce6e4e58f9d9b6fff2acc` |
| [Eight-corner STA report](../output_files/quartus-nAtarDJb/source/output_files/sharpx1_turbo_video.sta.rpt) | `9ae419e9a06d76f99c340e0e4af325dae67c664153f56ca3f28ad058c4655a5f` |
| [Eight-corner log](../output_files/quartus-nAtarDJb/all-corners.log) | `6fdaf6539caf0bfaa3b5054f9c4dce62102e2d92702b43aee5149f82094d4ad1` |
