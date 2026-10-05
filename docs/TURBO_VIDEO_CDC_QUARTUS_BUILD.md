# X3 coherent-snapshot Quartus audit — October 5, 2026

The isolated **`c0d1042`** build fits and assembles an RBF, but **does not
close timing**: setup/recovery fail at all eight corners and hold at three.
Both coherent snapshot instances survive; four first-stage registers remain,
but only the two timings-instance chains appear in the synchronizer report.
This report does not claim hardware acceptance or validate later source changes.

## Invocation and frozen inputs

```sh
QUARTUS_REVISION=sharpx1_turbo_video bash scripts/build_quartus.sh
```

Used the existing script and local Apple builder without edits, with installed
cached Quartus Prime Lite **17.0.0 Build 595, 04/25/2017 SJ Lite Edition**.
Read `AGENTS.md`, `Readme.md`, `docs/SHARP_X1_TODO.md`, the build script and
local Apple-container README/builder instructions before building.
No tools/images were installed/downloaded, licences accepted, hardware
deployed, private assets changed or source/constraints edited.

Frozen directory:
[output_files/quartus-BV5bJ71k/source](../output_files/quartus-BV5bJ71k/source/).
The checkout was clean at **`c0d104282835ccc06f10cf03fc66741264b3e973`**.
The script hashed all **340 inputs**, compared source-before/source-after
and copied snapshot manifests, and isolated the build before later main-agent
work. Independent recomputation of every input from `git show c0d1042:<path>`
confirms **340 matches, zero differences**, including `AGENTS.md`.
This is not a claim that later HEAD/working-tree inputs match.
Later parent checkpoints `c7cf4d6` and `76d87a2`, and subsequent dirty
PCG/font/reset work, are intentionally outside this RBF's source binding.
Post-build snapshot checks find **338/340 input files byte-identical**; the
two generated exceptions are `sharpx1.qpf` (header/date/revisions) and
`sharpx1_turbo_video.qsf` (serialized sourced assignments/tool metadata).
Those post-flow files are not substituted for the original manifest.

| Identity | SHA-256 / value |
| --- | --- |
| [Input manifest](../output_files/quartus-BV5bJ71k/input.sha256) | `1a0a478870b0efa8bc9e8b1821144e0a347e6952eb6f4399baa564dd9c75184c` |
| Runtime | `docker.io/library/quartus17-runtime:apple-amd64` |
| Runtime identity | `6550dd9261ca3b1397e53a2c063d71d6fe646a238fda876c75773ee05be96b3e` |
| Runtime index digest | `sha256:6edc7bc0edee8c0a3f332ced040776c459287e856ee3ba85992512b7b313a370` |
| Existing build script | `51d922b6a80b84040bada17beaa21e4010a0dc5da51b2cfa459a013f39cbc3c6` |
| Existing local builder | `49a5c3a8c4fa9a6718c96310469b3defc5a4bdeda6908e250383af53e0552fd2` |

Relative to font-only `quartus-nAtarDJb` / `f7875af`, five existing manifest
inputs changed and one was added; all others match:

| Changed/new input | SHA-256 |
| --- | --- |
| `AGENTS.md` | `21b0bf81ca59670859f55ff5417f53c3dd2aa1b69a92944641fe253606fcff0e` |
| `files.qip` | `f52c67071271913718ad5844c7cd244543797d7ed4729fc13e62868a3e037168` |
| `rtl/vendor/wd1793.sv` | `c7fbd63aaedc13347cfc5c3a4d2a9f76e89aecd7db29e994c38eb69775a3b89e` |
| New `rtl/x1_cdc_snapshot.sv` | `ee31d3edbe7446b96e727c6ca0dbe9cc9dfab41bc6954b675628ccab7cbb85e5` |
| `sharpx1.sv` | `109ff6459809c220128549e0ca966136539169211775c067fd3b5cc35b7b9223` |
| `sys/hps_io.sv` | `9c3966e648b69b77021df7e7e29f5dd7760def0a5e19ecf8b57d87904299bdaf` |

Evidence includes the [input list](../output_files/quartus-BV5bJ71k/input-files.txt),
[before](../output_files/quartus-BV5bJ71k/source-before.sha256) /
[after](../output_files/quartus-BV5bJ71k/source-after.sha256) hashes,
[build manifest](../output_files/quartus-BV5bJ71k/build-manifest.txt),
[snapshot-time status](../output_files/quartus-BV5bJ71k/git-status.txt) and
[build log](../output_files/quartus-BV5bJ71k/build.log).

Project `sharpx1`, revision `sharpx1_turbo_video`, top `sys_top`, device
`5CSEBA6U23I7`, seed 1; map one thread, fit eight threads, container
16 CPUs / 16 GiB. Active `sharpx1.sv` → `rtl/sharpx1.v` machine retains
32 MHz sys, separate X3 video PLL, `X1_TURBO_FOUNDATION=1` and
`X1_TURBO_VIDEO_MASTER=1`. No single-clock macro or new timing exceptions.
The pre-flow hook generated `BUILD_DATE=261005`.

## Intended synthesized seam and physical audit limits

Wrapper `hps_io.VIDEO_CDC(TURBO_VIDEO_MASTER)` selects the X3-only
`video_calc.COHERENT_SNAPSHOTS` branch. Other profiles retain the legacy
measurement path. The two requested instances are:

| Instance under `emu:emu|hps_io:hps_io|video_calc:video_calc` | Width | Source → destination |
| --- | ---: | --- |
| `x1_cdc_snapshot:coherent_measurements.dimensions_to_sys` | 74 | video PLL → 32 MHz sys |
| `x1_cdc_snapshot:coherent_measurements.timings_to_sys` | 128 | HPS 100 MHz user clock → 32 MHz sys |

Each protocol holds `held_data` until acknowledged, synchronizes `request`
back into the source through `request_meta/request_sync`, and synchronizes
`acknowledgement` forward through `acknowledgement_meta/acknowledgement_sync`
before destination capture. There is no machine warm-reset input.
An additional `mode_meta/mode_sync` pair carries `new_vmode` to video.
The source comment requires audited synchronizer treatment and a bounded
payload path of at most **two destination periods (62.500 ns)**. Merely
synthesizing this logic, or passing a behavioral protocol test, does not prove
metastability safety, held-bus skew/settling or physical signoff. No blanket
false path was added. HPS register halves can still span separate snapshot
refreshes; the interface is not an atomic whole-command snapshot.

Both instances survive fitting, rather than merely elaborating. Fitted
dimensions hierarchy uses **29.5 ALMs / 151 registers**; timings uses
**24.3 ALMs / 262 registers**. `held_data`/`destination_data` contain
**72/72 retained registers** in dimensions and **128/128** in timings.
Dimensions bits 0/1 (the input interlace field) are constant zero and removed;
this is a requested 74-bit instance with 72 nonconstant fitted bits, not a
fully retained 74-bit bus. The dimensions `acknowledgement` has one original
and one router duplicate; all other handshake registers have one fitted
register each. No payload-register duplication is reported.

The actual first-stage count is **four**: two `request_meta`, two
`acknowledgement_meta`, zero `mode_meta`. Full retained names:

```text
emu:emu|hps_io:hps_io|video_calc:video_calc|x1_cdc_snapshot:coherent_measurements.dimensions_to_sys|request_meta
emu:emu|hps_io:hps_io|video_calc:video_calc|x1_cdc_snapshot:coherent_measurements.dimensions_to_sys|acknowledgement_meta
emu:emu|hps_io:hps_io|video_calc:video_calc|x1_cdc_snapshot:coherent_measurements.timings_to_sys|request_meta
emu:emu|hps_io:hps_io|video_calc:video_calc|x1_cdc_snapshot:coherent_measurements.timings_to_sys|acknowledgement_meta
```

`coherent_measurements.mode_meta/mode_sync` were optimized to ground, as
recorded in map's optimization tables. Do not create an exception expecting
a fifth retained first-stage register. Quartus ignores the `async_reg`
attributes (10335); retained names alone do not prove synchronizer recognition
or metastability signoff. `request_sync` and `acknowledgement_sync` survive
in both instances and must not be included in first-stage-only exceptions.

## Compile outcome, physical RAM and resources

The flow completed with **exit 0**, RBF/SOF generated, but primary STA emits
**Critical Warning 332148: Timing requirements not met**. Primary setup
**-14.976 ns**, hold **+0.180**, recovery **-9.815**, removal **+0.814**,
minimum pulse **+0.529**. This is not timing closure.

Build-script timestamps: **17:27:36–18:57:58 UTC**, **1:30:22** elapsed span.
Quartus stage measurements:

| Stage | Elapsed | Errors | Warnings |
| --- | ---: | ---: | ---: |
| Pre-flow hook | 0:03 | 0 | 0 |
| Map | 8:37 | 0 | 114 |
| Fit | 1:19:24 | 0 | 11 |
| Assembly | 0:50 | 0 | 0 |
| Primary STA | 0:34 | 0 | 1 |
| Supplemental eight-corner STA | 7:46 | 0 | 8 |

Fitter CPU time is **6:07:58**, peak virtual memory 4,263 MB; fitter
preparation 3:31, placement preparation 22:19, placement 8:28, routing 22:42,
post-fit 2:23. Average/peak interconnect use is 25%/37%. The router reports
approximately 3,000 ns aggregate delay added for hold (1.5% of device routing
delay); this is not a delay on any single path. Observed long-running stages
were allowed to finish; no duplicate fit/restart was performed.

| Resource | This fit | Font-only `f7875af` | Change |
| --- | ---: | ---: | ---: |
| ALMs / 41,910 | 20,608 (49%) | 20,327 (49%) | +281 |
| Registers | 32,172 | 31,813 | +359 |
| RAM bits / 5,662,720 | 3,108,712 (55%) | 3,106,664 (55%) | +2,048 |
| RAM blocks / 553 | 389 (70%) | 389 (70%) | 0 |
| DSP blocks / 112 | 32 (29%) | 32 (29%) | 0 |
| PLLs / 6 | 4 (67%) | 4 (67%) | 0 |
| Pins / 314 | 145 (46%) | 145 (46%) | 0 |

Fitted sector index `emu:emu|sharpx1:sharpx1|wd1793:fdc|x1_fdc_index_ram:edsk_ram|…|ALTSYNCRAM`
is **single-clock true dual-port 2048 × 57**, **116,736 logical and implemented
bits**, **12 M10Ks**, zero MLABs, no initialization file. Its width-57 storage
is not synthesized into a large FF array. Physical sites:
`M10K_X14_Y54_N0` through `M10K_X14_Y63_N0`, plus `M10K_X5_Y54_N0` and
`M10K_X5_Y55_N0`. The +2,048 total RAM-bit delta exactly matches the one-bit
index widening across 2,048 entries; RAM-block count is unchanged.

Font `emu:emu|sharpx1:sharpx1|x1_font16:turbo_font.font16|x1_video_ram:storage|…|ALTSYNCRAM`
is **dual-clock simple dual-port 4096 × 8**, **32,768 bits**, **four M10Ks**,
zero MLABs and no initialization file, at `M10K_X26_Y43_N0`,
`M10K_X26_Y42_N0`, `M10K_X38_Y43_N0`, `M10K_X38_Y42_N0`. Font hierarchy
uses 21.5 ALMs / 19 registers / 36 logic cells. Mixed-port read-during-write
mode remains Don't Care for both RAMs; collisions are not hardware-validated.

Fitter PLL report again confirms **VCO 945 MHz, M189/N10/C22**, nominal
output **42.954545454545… MHz** from 50 MHz, versus requested
**42.954540 MHz**: **+5.454545… Hz**, ratio **1.000000126984143…**,
**+0.126984143… ppm**, period **23.280423280423… ns** (STA rounds to 23.280).
System PLL M32/N5/C10 remains exactly **32 MHz / 31.250 ns**. These are
fitted nominal divider rates, not measured oscillator accuracy, phase, jitter
or hardware acceptance. The old PLL video output is not used by this revision.

## Primary failures: real crossings versus clock-mux alternatives

Full-path extraction defaults to Slow 1100mV 100C. sys/video/HDMI below
refer to `emu|pll|…|divclk`, `emu|turbo_video_pll|…|divclk` and
`pll_hdmi|…|divclk` respectively. Actual endpoints:

| Check | Launch → capture | Start → endpoint | Slack ns |
| --- | --- | --- | ---: |
| Global setup | HDMI → video | `d[16] → hdmi_out_d[16]` | -14.976 |
| sys → video setup | sys → video | `emu:emu|hps_io:hps_io|ioctl_download → emu:emu|sharpx1:sharpx1|x1_video_ram:pcg_b|altsyncram:mem_rtl_0|altsyncram_g9n1:auto_generated|ram_block1a0~porta_we_reg` | -10.994 |
| video → sys setup | video → sys | `emu:emu|sharpx1:sharpx1|x1_vid:display|crtc6845s:crtc6845s|crtc_gen:crtc_gen|R_V_SYNC → emu:emu|sharpx1:sharpx1|cpu:Cpu|tv80e:Z80CPU|di_reg[2]` | -10.095 |
| Recovery | sys → video | `emu:emu|hps_io:hps_io|status[0] → emu:emu|sharpx1:sharpx1|turbo_black_meta[4]` | -9.815 |
| Primary hold | HDMI → HDMI | `ascal:ascal|o_poly_phase_b.t3[1] → ascal:ascal|o_poly_phase_b2.t3[1]` | +0.180 |

The global setup pairing is between alternative clocks on the shared
`hdmi_tx_clk` mux: both registers are in the same `always @(posedge hdmi_tx_clk)`
block in inherited `sys/sys_top.v`. Existing clock-group matching omits
`turbo_video_pll|oscillator`, so TimeQuest considers HDMI and new video PLL
alternatives. This warrants a **targeted clock-mux/exclusivity review**, not
a blanket real-CDC false path. It does not explain away the independent
sys/video control, CPU readback and reset-release failures above.

The old direct `video_calc|vid_vcnt* → video_calc|dout*` setup query finds
**no path**: the snapshot pipeline introduces register boundaries. That is
structural evidence of replacing the live-counter return, not proof all
HPS/CPU CDCs are solved. `dimensions_to_sys` still reports:

| Snapshot path | Clock direction | Slack ns |
| --- | --- | ---: |
| `held_data[70] → destination_data[70]` | video → sys | -9.434 |
| `request → request_meta` | sys → video | -7.218 |
| `acknowledgement → acknowledgement_meta` | video → sys | -8.822 |

These are currently conventional setup checks, not implemented two-cycle
payload bounds or targeted first-stage exceptions. The 128-bit timings
instance's HPS-100-MHz↔sys handshake and payload ordinary setup queries
find no timed paths because inherited clock groups already cut them.
`report_timing -false_path` exposes its held-data/capture path (sample
`held_data[39] → destination_data[39]`, hypothetical slack +2.678); that is
**not constrained-path acceptance**. Independent `report_path` measurement
below includes the cut payload paths without adding an exception.

Original diagnostic extraction ran concurrently with primary STA and exited
**2** with `Fatal Error: Segment Violation at 0x10`, in
`HDB_NAME_MGR::open_cap_inst`, reached from `sta_create_timing_netlist`.
Its [log](../output_files/quartus-BV5bJ71k/timing-paths.log) is preserved.
The exact cause is not established; concurrent database access is a possible
factor. After the primary flow completed, the complete fitted source/database
was copied to [timing-audit-source](../output_files/quartus-BV5bJ71k/timing-audit-source/)
and extraction retried there, separate from all-corner STA on the original
fit. No source/SDC/assignment edits, synthesis, fit or assembly were repeated.
Diagnostic files are under that copy's
[output_files](../output_files/quartus-BV5bJ71k/timing-audit-source/output_files/),
with exact commands/counts in
[timing-paths-retry.log](../output_files/quartus-BV5bJ71k/timing-paths-retry.log).
The retry exits 0, prints `AUDIT_COMPLETE` and completes all requested counts,
primary paths and eight-corner payload/same-clock reports (elapsed 7:03,
CPU 18:43). Its interactive footer says `unsuccessful. 0 errors, 0 warnings`;
this report extraction is not a passing STA assertion.

Supplemental worst hold is **`d[4] → hdmi_out_d[4]`**, video→HDMI,
**-0.102 ns at Slow 1100mV -40C**, another clock-mux alternative pairing.
Worst removal is **`emu:emu|sharpx1:sharpx1|x1_vid:display|vid_reset →
…|crtc6845s:crtc6845s|crtc_gen:crtc_gen|R_V_DISPTMG`**, video→video,
**+0.319 ns at Fast 1100mV -40C**.
See [worst hold](../output_files/quartus-BV5bJ71k/timing-audit-source/output_files/cdc_slow_minus40_hold.rpt),
[worst removal](../output_files/quartus-BV5bJ71k/timing-audit-source/output_files/cdc_fast_minus40_removal.rpt),
[primary setup](../output_files/quartus-BV5bJ71k/timing-audit-source/output_files/cdc_setup.rpt),
[recovery](../output_files/quartus-BV5bJ71k/timing-audit-source/output_files/cdc_recovery.rpt),
[sys→video](../output_files/quartus-BV5bJ71k/timing-audit-source/output_files/cdc_sys_to_video.rpt),
[video→sys](../output_files/quartus-BV5bJ71k/timing-audit-source/output_files/cdc_video_to_sys.rpt),
[dimensions payload](../output_files/quartus-BV5bJ71k/timing-audit-source/output_files/cdc_dimensions_to_sys_payload_setup.rpt),
[request first stage](../output_files/quartus-BV5bJ71k/timing-audit-source/output_files/cdc_dimensions_to_sys_request_meta.rpt)
and [acknowledgement first stage](../output_files/quartus-BV5bJ71k/timing-audit-source/output_files/cdc_dimensions_to_sys_acknowledgement_meta.rpt).
The final [hold/metastability extraction log](../output_files/quartus-BV5bJ71k/worst-hold-path.log)
exits 0 with `AUDIT_COMPLETE` (33 seconds) and the same zero-error unsuccessful
interactive footer; no further fit was performed.

## Eight-corner constrained-path audit

Primary reports were preserved in
[single-corner-reports](../output_files/quartus-BV5bJ71k/single-corner-reports/)
before running the established procedure on the original fitted tree:

```sh
quartus_sta sharpx1 -c sharpx1_turbo_video --multicorner=on --all_corners
```

Container 4 CPUs / 8 GiB; Quartus detects five processors. Shell timestamps
**18:59:16–19:07:09 UTC** (7:53); Quartus elapsed **7:46**, CPU **21:02**,
exit **0**, zero errors / eight timing critical warnings. The final
[STA report](../output_files/quartus-BV5bJ71k/source/output_files/sharpx1_turbo_video.sta.rpt)
contains all eight models; `.sta.summary` remains byte-identical to the
preserved primary summary. RBF/SOF hashes are unchanged after supplemental
analysis. No new constraints, latency overrides or exceptions were applied.

All values are ns, at 1100 mV; minima cover reported constrained clocks.

| Model / temperature | Setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow 100°C | -14.976 | +0.180 | -9.815 | +0.814 | +0.529 |
| Slow -40°C | -14.390 | -0.102 | -9.662 | +0.749 | +0.529 |
| Slow 85°C | -14.810 | +0.151 | -9.760 | +0.804 | +0.529 |
| Slow 0°C | -14.415 | -0.090 | -9.640 | +0.741 | +0.529 |
| Fast -40°C | -7.165 | -0.068 | -4.711 | +0.319 | +0.529 |
| Fast 0°C | -7.410 | +0.030 | -4.817 | +0.324 | +0.529 |
| Fast 85°C | -8.119 | +0.128 | -5.081 | +0.365 | +0.529 |
| Fast 100°C | -8.361 | +0.131 | -5.149 | +0.375 | +0.529 |

TNS sums the **per-clock endpoint TNS reported by STA**, not deduplicated
physical endpoints across mux alternatives. Removal/pulse TNS are zero
at all corners. The +0.529 pulse minimum belongs to the video PLL VCO phase,
not its divided video output.

| Model / temperature | Setup TNS sum | Hold TNS sum | Recovery TNS sum |
| --- | ---: | ---: | ---: |
| Slow 100°C | -7961.969 | 0.000 | -567.176 |
| Slow -40°C | -7639.449 | -0.102 | -559.371 |
| Slow 85°C | -7878.264 | 0.000 | -563.519 |
| Slow 0°C | -7660.226 | -0.090 | -557.950 |
| Fast -40°C | -3990.529 | -0.116 | -270.528 |
| Fast 0°C | -4097.471 | 0.000 | -276.023 |
| Fast 85°C | -4427.369 | 0.000 | -289.920 |
| Fast 100°C | -4517.282 | 0.000 | -293.500 |

Core output-clock setup includes real cross-domain paths; the video capture
clock also includes HDMI mux alternatives. These are not same-clock Fmax limits:

| Model / temperature | sys setup | sys setup TNS | video setup | video setup TNS |
| --- | ---: | ---: | ---: | ---: |
| Slow 100°C | -10.095 | -834.921 | -14.976 | -5902.614 |
| Slow -40°C | -9.185 | -749.959 | -14.390 | -5767.557 |
| Slow 85°C | -9.881 | -817.587 | -14.810 | -5858.973 |
| Slow 0°C | -9.271 | -760.089 | -14.415 | -5762.659 |
| Fast -40°C | -5.163 | -428.067 | -7.165 | -2790.982 |
| Fast 0°C | -5.430 | -451.274 | -7.410 | -2850.452 |
| Fast 85°C | -6.433 | -537.692 | -8.119 | -3005.717 |
| Fast 100°C | -6.688 | -561.753 | -8.361 | -3045.063 |

Other primary failing capture-clock setup/TNS: HDMI **-8.662/-1100.376**,
`FPGA_CLK1_50` **-6.409/-6.409**, HPS `h2f_user0_clk`
**-5.738/-117.649**. Full per-clock setup/hold/recovery/removal/pulse/TNS
at every corner are retained in STA; not all failures are in the new snapshot.

## Held-data delays and same-clock setup at every corner

`report_path -from <held registers> -to <destination registers> -npaths 0
-pairs_only -summary` measures **all 72 dimensions and 128 timings data paths**
at every corner, including the inherited-cut timings bus. It applies no
constraint and includes no clock relationship/skew in the reported path delay.
Both measured maxima are below the source comment's 62.500 ns two-sys-period
budget, but that budget is **not enforced by this frozen SDC**. Neither this
observed margin nor conventional setup slack substitutes for a reviewed
bundled-data constraint, handshake stability, bit-skew or metastability proof.

| Model / temperature | Max dimensions data delay | Max timings data delay | Same-clock sys setup | Same-clock video setup |
| --- | ---: | ---: | ---: | ---: |
| Slow 100°C | 11.928 | 2.087 | +6.385 | +11.650 |
| Slow -40°C | 11.388 | 2.053 | +6.688 | +11.614 |
| Slow 85°C | 11.820 | 2.071 | +6.536 | +11.677 |
| Slow 0°C | 11.364 | 2.049 | +6.872 | +11.609 |
| Fast -40°C | 6.201 | 1.003 | +12.657 | +16.996 |
| Fast 0°C | 6.466 | 1.038 | +12.534 | +16.712 |
| Fast 85°C | 7.500 | 1.160 | +12.097 | +15.722 |
| Fast 100°C | 7.758 | 1.200 | +11.961 | +15.431 |

Per-bit tables and same-clock full paths are named
`cdc_<slow|fast>_<temperature>_<dimensions_to_sys|timings_to_sys>_payload_delay.rpt`
and `cdc_<slow|fast>_<temperature>_<sys|video>_sameclock.rpt` under the
[audit output directory](../output_files/quartus-BV5bJ71k/timing-audit-source/output_files/).
The primary payload setup endpoint's data delay and the largest pure-data-delay
endpoint need not be the same; the 11.928 ns figure is the maximum of all
dimensions paths, not a relabeling of the -9.434 ns setup slack.

## Unconstrained paths, recognized chains and remaining review

STA reports **0 illegal clocks, 0 unconstrained clocks**; setup and hold each
retain **3 unconstrained input ports / 7 paths** and **44 unconstrained output
ports / 50 paths**, unchanged from the font-only audit. TimeQuest explicitly
says setup/hold are not fully constrained. Complete external I/O signoff
is not implied by this build.

TimeQuest finds **382 synchronizer chains**, versus 380 in the font-only fit,
and **does not calculate design MTBF because timing requirements are unmet**.
The supplementary
[full metastability report](../output_files/quartus-BV5bJ71k/timing-audit-source/output_files/cdc_metastability.rpt)
(`report_metastability -nchains 1000`) lists the two timings-instance
`request → request_meta → request_sync` and
`acknowledgement → acknowledgement_meta → acknowledgement_sync` chains;
both MTBF entries are Not Calculated / not included in design MTBF. It lists
**no dimensions-instance chain**. Thus four retained first stages are **not**
four demonstrated recognized synchronizers. Ignored attributes, current
first-stage timing failures and recognized-chain treatment require review.

Warning comparison against `f7875af`: **114/11/1** map/fit/primary STA versus
**111/11/1**. After normalizing source locations, the only added top-level
warnings are three **10335 unrecognized `async_reg`** declarations: two in
`x1_cdc_snapshot.sv`, one in `sys/hps_io.sv`; none were removed. Existing
RAM-collision, width/parameter/implicit-net, framework connectivity, PLL
reset/lock/compensation, incomplete I/O and ignored fitter/LogicLock warnings
remain. No warning suppression or licence action was taken.

Bounded follow-up is a separately authorized narrow constraints/CDC/reset
review: clock-mux alternative exclusivity; exactly matched, cardinality-checked
first-stage paths while leaving second-stage timing intact; an actually
enforced held-bus settling bound compatible with installed Quartus 17; and
the real PCG/control/reset/CRTC CPU-return paths. Current inherited clock-group
cuts on the timings instance must be included in that review. This audit made
none of those changes. Positive same-clock setup and observed payload delays
do not close the remaining real crossings or authorize blanket exceptions.

Parent-reported baseline diagnostic/five v04 game passes are separate simulator
evidence; this Quartus-only audit did not rerun them. Their later runner/source
checkpoints are not substituted for `c0d1042`. No hardware is available and
none was deployed/tested. PLL behavior, complete I/O, CDC/reset and functional
hardware acceptance remain unverified. The only new nonignored file written
by this audit is this report; RTL/SDC/firmware/framework/private assets and
existing documents were not edited. No commit/push was performed.

Earlier [register-font report](TURBO_VIDEO_QUARTUS_BUILD.md) /
[font-BRAM report](TURBO_VIDEO_BRAM_QUARTUS_BUILD.md) and their original
`quartus-p0epmzTq` / `quartus-nAtarDJb` outputs remain preserved. Their report
hashes and prior font-BRAM build-log/RBF hashes were checked unchanged.

## Output identity

SHA-256 identifies these timing-failed artifacts, not an approved release:

| Artifact | SHA-256 |
| --- | --- |
| [RBF](../output_files/quartus-BV5bJ71k/source/output_files/sharpx1_turbo_video.rbf) | `b745619386a55e33ccd315252bca10755d8e9b354050fff7dcdd29f096fd2aa3` |
| [SOF](../output_files/quartus-BV5bJ71k/source/output_files/sharpx1_turbo_video.sof) | `2abfccb17644ada7e869234728e8448600a35f566d3f20bdcf5613900dfbbccb` |
| [Build log](../output_files/quartus-BV5bJ71k/build.log) | `d7e9771db93d8d12d39d90cb8a8dbb4716899ccfe030879895a8bfd97573e414` |
| [Fitter report](../output_files/quartus-BV5bJ71k/source/output_files/sharpx1_turbo_video.fit.rpt) | `75d467622d294eeef3d48c171e799bed92ea6a1c448bb9ec97391d878e292b60` |
| [Map report](../output_files/quartus-BV5bJ71k/source/output_files/sharpx1_turbo_video.map.rpt) | `0bb40e43191004551f388d8c59436a86a6ad409f0fcaeb9b12914b37d91b577c` |
| [Preserved primary STA report](../output_files/quartus-BV5bJ71k/single-corner-reports/sharpx1_turbo_video.sta.rpt) | `f4a4b1e4a46af2840d3f4fc22cf211896dd19793d733a5993887ac5ae28020c9` |
| [Preserved primary STA summary](../output_files/quartus-BV5bJ71k/single-corner-reports/sharpx1_turbo_video.sta.summary) | `f66b6c9c8535422b3aafa592429861e2f00a3096b597b530389bdcdb988ca430` |
| [Eight-corner STA report](../output_files/quartus-BV5bJ71k/source/output_files/sharpx1_turbo_video.sta.rpt) | `5cdaebb7cae5e25551846c6ccc42900313ec88b0f689470a8d128e2fddfbd5fc` |
| [Eight-corner log](../output_files/quartus-BV5bJ71k/all-corners.log) | `cde91b044e36f427021cb2747b6ad9cc71125f35ddb369accdc1c1c05fefdd63` |
| [Completed endpoint/count/payload audit log](../output_files/quartus-BV5bJ71k/timing-paths-retry.log) | `e8163744bbcdea2aa80147564d1fbb388d2b0b20096e4bebc8d693bc825034fe` |

## Installed Quartus 17 constraint syntax (read-only help audit)

Queried `quartus_sta -s`, `package require ::quartus::sta`, then
`help set_max_delay`, `help set_false_path`, `help get_registers`,
`help report_timing` and `help report_path`, without opening a project or
applying constraints. Full installed-tool help is retained in
[sta-constraint-help-corrected.log](../output_files/quartus-BV5bJ71k/sta-constraint-help-corrected.log).
The first query incorrectly used `help -long`, which returned help-command
usage; that diagnostic log is preserved separately as
[sta-constraint-help.log](../output_files/quartus-BV5bJ71k/sta-constraint-help.log).
This installation uses `help <command>` (or `help -cmd <command>`), not
`help -long <command>`.

Installed `::quartus::sdc 1.5` usage:

```text
set_max_delay [-fall_from <names>] [-fall_to <names>] [-from <names>]
  [-rise_from <names>] [-rise_to <names>] [-through <names>]
  [-to <names>] <value>

set_false_path [-fall_from <names>] [-fall_to <names>] [-from <names>]
  [-hold] [-rise_from <names>] [-rise_to <names>] [-setup]
  [-through <names>] [-to <names>]
```

Help/usage switches `-h`, `-help`, `-long_help` are also supported.
**There is no documented `-datapath_only` or `-ignore_clock_latency` option
for `set_max_delay` in this installed Quartus 17 command.** Its help explicitly
includes source and destination clock-network delays in the analysis.
Consequently the supported register-to-register expression below is **not
a pure datapath-only bound** and must not be advertised as one:

```tcl
# Syntax illustration only — not executed or added to frozen constraints.
set_max_delay -from $held_registers -to $destination_registers 62.500
set_false_path -from $control_source_register -to $first_stage_register
```

Both collections may be formed with `get_registers` using exact post-fit
hierarchy, but cardinality, source/destination clocks and exceptions must be
checked first. A first-stage-only false path must not include second-stage
registers or `destination_data`, and must not silently expand to an entire
clock domain. `-setup` cuts setup/recovery; `-hold` cuts hold/removal;
omitting both cuts both categories. Omitting `-from` expands to all keepers,
so specifying the actual source is narrower. Existing clock-group exceptions
may already cut a path; a max-delay expression is not proof it overrides them.
Help says pin-form `-from` must be a **clock pin**, so substituting a source
Q pin is not a documented register-datapath-only workaround.

For a **read-only fitted data-delay audit**, installed `report_path` supports:

```tcl
report_path -from $held_registers -to $destination_registers \
  -npaths 0 -pairs_only -show_routing -file output_files/payload_paths.rpt
```

That reports path delays; it does **not** constrain placement/routing or
establish a datapath-only SDC bound. No new exception, latency override,
constraint or duplicate build was applied by this audit.
