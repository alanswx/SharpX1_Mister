# Experimental Turbo video Quartus build — October 5, 2026

`sharpx1_turbo_video` synthesized, fitted and assembled an RBF, but **timing
does not close**. Setup, hold and recovery fail at all eight analyzed corners.
The fitted video PLL is **42.9545454545 MHz**, assuming the nominal 50 MHz
reference, versus the requested **42.954540 MHz**. No hardware was contacted,
deployed or measured. This is experimental build/audit evidence, not physical
video, font, game or Turbo compatibility acceptance.

## Execution and frozen implementation

Executed the existing source-snapshot script without edits:

```sh
QUARTUS_REVISION=sharpx1_turbo_video bash scripts/build_quartus.sh
```

The initial sandboxed invocation could not access the Apple container service
(`Operation not permitted`) and stopped before allocating a snapshot. The
authorized escalated invocation used the installed cached runtime and payload;
no installation, download, image build or license acceptance was performed.
Repository AGENTS/README/TODO, the Apple-container README/builder and the
previous two-disk build report were read before building.

Build directory: [output_files/quartus-p0epmzTq](../output_files/quartus-p0epmzTq/).
Snapshot: [source](../output_files/quartus-p0epmzTq/source/).
Project `sharpx1`, revision `sharpx1_turbo_video`, top `sys_top`, device
`5CSEBA6U23I7`, seed 1. The active machine is `sharpx1.sv` →
`rtl/sharpx1.v`, with dependencies through `rtl/machine.qip`.
`X1_TURBO_FOUNDATION=1` and `X1_TURBO_VIDEO_MASTER=1` select the Turbo
foundation and enable-driven video/CRTC divider. `X1_SINGLE_CLOCK` is absent;
the system clock remains 32 MHz. The old PLL video output is unused.

The script copied **339 inputs**, including dirty/untracked RTL and the new
PLL, checking identical hashes before/after the copy and inside the snapshot.
The [input list](../output_files/quartus-p0epmzTq/input-files.txt),
[SHA-256 manifest](../output_files/quartus-p0epmzTq/input.sha256),
`source-before.sha256`, `source-after.sha256`, original Git status and runtime
identity are retained. Simulator tests and ordinary documentation are outside
this manifest; `AGENTS.md` is included explicitly.

Independent SHA-256 comparison with implementation commit
**`cd2695ec9bf1ef8a3d225332994909faa509a33d`** found **338 matches and one
documentation-only difference**, `AGENTS.md`. The commit adds ten lines of
X3/font/snapshot guidance after the snapshot. All RTL, firmware, QSF/QIP,
constraints and other original inputs match that commit. A post-build
working-tree comparison before the parent's subsequent font refactor had the
same 338/1 result. The parent began changing `rtl/x1_font16.sv` while this
report was finalized; that later working tree is not this build's input and
was not rebuilt here. This is not an all-input match to current HEAD or the
current working tree.

| Binding | Value |
| --- | --- |
| Snapshot-time HEAD | `d4309a0e4cf009c4c824901396c207cc1a6f065d` |
| Implementation commit, with AGENTS exception | `cd2695ec9bf1ef8a3d225332994909faa509a33d` |
| Input-manifest SHA-256 | `70ac65d452efdea504db8b64310c9ab9ec7b9d7e469032046bf459804e5222f6` |
| Frozen `AGENTS.md` SHA-256 | `d56f1d14726015f89b527ea93c7c44897997b0771e83b22032fe644e1e0d266e` |
| Commit/current `AGENTS.md` SHA-256 | `1525b9276c8b4e7063717103dbc7117cf5490e50234aaddbda989ac57a2f824f` |
| Build-script SHA-256 | `51d922b6a80b84040bada17beaa21e4010a0dc5da51b2cfa459a013f39cbc3c6` |
| Cached builder SHA-256 | `49a5c3a8c4fa9a6718c96310469b3defc5a4bdeda6908e250383af53e0552fd2` |
| Runtime identity SHA-256 | `6550dd9261ca3b1397e53a2c063d71d6fe646a238fda876c75773ee05be96b3e` |
| Cached runtime index digest | `sha256:6edc7bc0edee8c0a3f332ced040776c459287e856ee3ba85992512b7b313a370` |

Key frozen inputs:

| Input | SHA-256 |
| --- | --- |
| `rtl/x1_turbo_video_pll.sv` | `b9f002085e7e6e38e83c2f7774480b0b0e5fc24db72e2ef35041f1ba94bce188` |
| `sharpx1_turbo_video.qsf` | `9155538cf46332437f3e23cff01ee3ea95ebf1026c9df08058b64f034fc0df28` |
| `sharpx1.sv` | `77cce975bfdbc4c6eedebe2afeb94631ef3857493f1729a7c2e2ea5225ea058a` |
| `rtl/sharpx1.v` | `7150d6a341a70062a3c8d0a04dc262ea258d0f3a28d6af7fab287e22ba2da12c` |
| `rtl/machine.qip` | `643343aaf1ac3b19153a0843fbffec6309d9ab3fde9ed87c3024a889bc6c046c` |
| `rtl/x1_font16.sv` | `73df8cd0c3447fe6d57f23b8873a04663104636c1ce52dffec60b55a77479754` |
| `rtl/x1_video_timing.sv` | `17a0cc7cc3c88dc63e15047bcffa4fb7ed5bb858eaa96e2933ff43d96ba5f2f2` |

Quartus generated `build_id.v` (`BUILD_DATE=261005`) and materialized project
metadata/expanded inherited assignments in the snapshot's `sharpx1.qpf` and
`sharpx1_turbo_video.qsf`. Those two generated project files consequently no
longer byte-match their original input entries; the other **337 snapshot
inputs** still match. The original input identity remains in the before/after
manifests and is reconstructible from the named commit plus frozen AGENTS.
The repository's project files were not edited by this audit.

## Compiler, flow and elapsed time

Quartus Prime Lite **17.0.0 Build 595, 04/25/2017**, amd64 under Rosetta,
with the installed payload mounted read-only. Build container: 16 CPUs /
16 GiB. Map used one thread and fit eight, following the established local
stepwise procedure. The pre-flow build-ID hook succeeded.

Build wall time was **29:44**, **14:34:50–15:04:34 UTC**, exit **0**.
Exit 0 establishes completion of the tool flow, not meeting timing.

| Stage | Quartus elapsed | Errors | Warnings |
| --- | ---: | ---: | ---: |
| Analysis/synthesis | 3:11 | 0 | 110 |
| Fitter | 24:58 | 0 | 11 |
| Assembly | 0:34 | 0 | 0 |
| Primary STA, Slow 1100 mV / 100°C | 0:30 | 0 | 1 |
| Supplemental eight-corner STA | 5:47 | 0 | 8 |

The STA warning is **`Critical Warning (332148): Timing requirements not met`**,
repeated once per corner in supplemental analysis. Fitter placement and routing
succeeded; routing took 9:59, with estimated average/peak interconnect use
39%/59%. A concurrent unrelated SharpMZ build was observed; elapsed times are
this run's measurements, not an isolated performance benchmark.

Original STA report/summary were copied with metadata preserved into
[single-corner-reports](../output_files/quartus-p0epmzTq/single-corner-reports/)
before supplemental analysis on the same fit:

```sh
quartus_sta sharpx1 -c sharpx1_turbo_video --multicorner=on --all_corners
```

Supplemental container: 4 CPUs / 8 GiB (Quartus detected five processors).
Command timestamps were **15:05:23–15:11:14 UTC**, exit **0**; Quartus ran
15:05:26–15:11:13. No refit or assembly rerun was performed. The main
`.sta.rpt` now contains all eight corners; `.sta.summary` retains the primary
Slow/100°C summary. RBF/SOF hashes are identical before and after all analyses.
The failing-timing snapshot and original reports are preserved.

## Fitted oscillator frequency

The [fitter PLL usage report](../output_files/quartus-p0epmzTq/source/output_files/sharpx1_turbo_video.fit.rpt)
reports the candidate at `FRACTIONALPLL_X89_Y1_N0`, VCO **945.0 MHz**,
M counter **189**, N counter **10**, output C counter **22**, and output
frequency **42.954545 MHz**. Generated-clock commands independently confirm
`multiply_by 189 / divide_by 10`, then `divide_by 22`.

```text
fitted_video_hz = 50,000,000 × 189 / 10 / 22
                = 42,954,545.45454545 Hz
requested_hz    = 42,954,540 Hz
fitted/requested = 1.000000126984143
difference      = +5.45454545 Hz = +0.126984143 ppm
video_period    = 23.28042328042328 ns
```

This is the actual fitted ratio, not a measurement of the physical oscillator
or its tolerance. The rounded STA clock table (23.280 ns / 42.95 MHz) alone
is insufficient to establish this error. System PLL M=32/N=5/C=10 produces
**32.0 MHz / 31.250 ns**. No 28.571428 MHz legacy video clock appears in the
final derived-clock table; its unused output is pruned. There are 14 derived
and base clocks including internal VCO clocks.

Mathematically, this video master gives low-scan half-dot average
28.6363636364 MHz and low/high-scan dot rates 14.3181818182/21.4772727273 MHz
for the divider described in `x1_video_timing.sv`. Physical raster timing and
live mode-switch behavior were not measured here.

## Resources and warnings versus the last two-disk build

Comparison is with the successful `quartus-JC4BFj9f` retry in
[DUAL_DISK_QUARTUS_BUILD.md](DUAL_DISK_QUARTUS_BUILD.md), which used the old
single-clock Turbo revision. Configuration changes limit direct attribution
of resource and timing differences to any one source edit.

| Resource | Current used / available | Previous used | Difference |
| --- | ---: | ---: | ---: |
| ALMs | 39,443 / 41,910 (94%) | 20,294 | +19,149 |
| Registers | 64,543 | 31,785 | +32,758 |
| Block-memory bits | 3,073,896 / 5,662,720 (54%) | 3,069,624 | +4,272 |
| RAM blocks | 385 / 553 (70%) | 384 | +1 |
| DSP blocks | 32 / 112 (29%) | 32 | 0 |
| PLLs | 4 / 6 (67%) | 3 | +1 |
| Pins | 145 / 314 (46%) | 145 | 0 |

The new font dominates growth: map reports its 4096×8 array as uninferred
RAM **due to asynchronous read logic**, implementing it in registers and
logic. Its fitted hierarchy reports **17,947.4 ALMs, 32,796 registers and
zero RAM bits**. Thus compiling the font module did not establish a block-RAM
implementation. Only 2,467 nominal ALMs remain unused.

Map/fit warnings rose from **93/9 to 110/11**; primary STA from **0 to 1**.
Top-level warning comparison, normalizing source line numbers, adds:

- Ignored `async_reg` on `rtl/x1_font16.sv:15` (10335).
- 32-to-2-bit divider truncation at `x1_video_timing.sv:26` (10230).
- Six dual-clock RAM read-during-write warnings (276027), for GRAM B/R/G,
  text, attribute and Kanji RAM. Simultaneous read/write collision behavior
  is undefined, unlike an assumption of deterministic old/new data.
- Connectivity-warning hierarchy count 17 versus 16.
- New candidate PLL reset-port warning and compensation-selection warning
  (177007) at its fitted location.

The inherited `x1_vid` 32-to-3-bit truncation is now 32-to-4-bit after widening
`cg_line`; other text-address truncation, unused sync registers, CRTC widths,
implicit `text_cs`, parameter declarations, ignored attributes, framework
connectivity, ignored fitter assignments and incomplete I/O warnings remain.
The old `general[1]` reset warning and unused `general[0]` OUTCLK warning are
absent: the active base PLL output is now system clock, and the candidate has
its own instance. No warning suppression was added. FDC INTRQ/DRQ remain
unconnected as required by the base-X1 integration.

## Timing at all eight corners

All values are ns, all corners 1100 mV. These are constrained-path results;
incomplete I/O constraints and CDC limits are described below.

| Model / temperature | Global setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow / 100°C | −16.059 | −1.660 | −10.925 | +0.643 | +0.529 |
| Slow / −40°C | −16.027 | −1.942 | −10.717 | +0.585 | +0.529 |
| Slow / 85°C | −16.032 | −1.676 | −10.862 | +0.641 | +0.529 |
| Slow / 0°C | −15.953 | −1.954 | −10.718 | +0.575 | +0.529 |
| Fast / −40°C | −7.577 | −1.074 | −5.235 | +0.256 | +0.529 |
| Fast / 0°C | −7.756 | −1.018 | −5.361 | +0.266 | +0.529 |
| Fast / 85°C | −8.384 | −0.750 | −5.675 | +0.294 | +0.529 |
| Fast / 100°C | −8.482 | −0.673 | −5.758 | +0.300 | +0.529 |

TNS below is the **sum of the reported per-clock endpoint TNS** for each
check, using displayed precision; it is not a separately deduplicated endpoint
count. Removal and pulse-width TNS are zero throughout.

| Model / temperature | Setup TNS sum | Hold TNS | Recovery TNS |
| --- | ---: | ---: | ---: |
| Slow / 100°C | −8296.491 | −1.660 | −631.627 |
| Slow / −40°C | −7956.078 | −1.942 | −619.023 |
| Slow / 85°C | −8214.031 | −1.676 | −627.709 |
| Slow / 0°C | −7982.533 | −1.954 | −619.367 |
| Fast / −40°C | −4084.212 | −1.074 | −299.728 |
| Fast / 0°C | −4191.894 | −1.018 | −306.424 |
| Fast / 85°C | −4502.732 | −0.750 | −323.185 |
| Fast / 100°C | −4586.120 | −0.673 | −327.379 |

System-domain destination summary, clock
`emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk`:

| Model / temperature | Setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow / 100°C | −11.551 | −1.660 | +10.325 | +2.110 | +14.185 |
| Slow / −40°C | −10.552 | −1.942 | +10.434 | +1.935 | +14.156 |
| Slow / 85°C | −11.291 | −1.676 | +10.344 | +2.093 | +14.180 |
| Slow / 0°C | −10.649 | −1.954 | +10.475 | +1.914 | +14.160 |
| Fast / −40°C | −6.037 | −1.074 | +13.145 | +0.848 | +14.506 |
| Fast / 0°C | −6.340 | −1.018 | +13.075 | +0.880 | +14.500 |
| Fast / 85°C | −7.551 | −0.750 | +12.758 | +0.988 | +14.498 |
| Fast / 100°C | −7.930 | −0.673 | +12.756 | +1.015 | +14.500 |

Video-domain destination summary, clock
`emu|turbo_video_pll|oscillator|general[0].gpll~PLL_OUTPUT_COUNTER|divclk`:

| Model / temperature | Setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow / 100°C | −16.059 | +0.246 | −10.925 | +0.643 | +10.199 |
| Slow / −40°C | −16.027 | +0.237 | −10.717 | +0.585 | +10.185 |
| Slow / 85°C | −16.032 | +0.249 | −10.862 | +0.641 | +10.202 |
| Slow / 0°C | −15.953 | +0.238 | −10.718 | +0.575 | +10.182 |
| Fast / −40°C | −7.577 | +0.112 | −5.235 | +0.256 | +10.526 |
| Fast / 0°C | −7.756 | +0.119 | −5.361 | +0.266 | +10.520 |
| Fast / 85°C | −8.384 | +0.130 | −5.675 | +0.294 | +10.517 |
| Fast / 100°C | −8.482 | +0.132 | −5.758 | +0.300 | +10.520 |

At Slow/100°C, setup endpoint TNS is −6668.417 ns for video and −346.303 ns
for system; video recovery TNS is −631.627 ns. Other setup destinations also
fail: HDMI −8.869 ns, FPGA_CLK1_50 −7.250 ns and HPS user clock −6.010 ns.
Full per-clock TNS at every corner is retained in the all-corner report.
The previous two-disk build had zero endpoint TNS and global minima
+0.394/+0.080/+4.373/+0.414/+1.122 ns for setup/hold/recovery/removal/pulse.

## Actual failing paths and bounded follow-up

Detailed reports were extracted from the same fit through `quartus_sta -s`,
using `create_timing_netlist`, the existing `read_sdc`,
`update_timing_netlist` and `report_timing -detail full_path`. No constraints,
false paths, RTL or framework fixes were made. Paths below abbreviate the
common hierarchy prefixes; the linked reports contain complete names.

| Check / corner | Launch → capture clocks | Actual start → endpoint | Slack |
| --- | --- | --- | ---: |
| Setup, Slow/100°C | System → video | `sharpx1|turbo_font.font16|rom~27982` → `display_data[6]` | −16.059 ns |
| Setup, Slow/100°C | Video → system | `hps_io|video_calc|vid_hcnt[20]` → `dout[4]` | −11.551 ns |
| Hold, Slow/100°C | Video → system | `hps_io|video_calc|vid_hcnt[16]` → `dout[0]` | −1.660 ns |
| Hold, Slow/0°C, overall worst | Video → system | `hps_io|video_calc|vid_nres[0]` → `dout[0]` | −1.954 ns |
| Recovery, Slow/100°C | System → video reset | `hps_io|status[0]~DUPLICATE` → `sharpx1|turbo_black_meta[3]` | −10.925 ns |

The worst setup report shows an 8.815 ns data delay, −6.874 ns clock skew and
−0.030 ns setup relationship. Recovery has a −0.030 ns relationship too.
Other top recovery endpoints include `turbo_black_video[0]`, PCG response
registers/request synchronizer and `display|vid_reset`, driven from the same
HPS status reset source.

Focused Slow/100°C **same-clock** setup reports are positive: system
**+5.187 ns**, video **+4.723 ns**. Their worst paths are sub-CPU work RAM
`q_b[5]` → `q_b[9]` and scaler `i_h_frac[8]~_Duplicate_3` →
`i_h_bil_t.r[8]`. This does not cancel the cross-clock/reset violations.
Same-clock Fmax reports are 38.37 MHz system and 53.89 MHz video, excluding
cross-clock paths; neither is a supported-frequency/signoff claim.

Bounded suggested work for the implementation owner, not performed here:

1. Make the font storage infer a true dual-clock block RAM, with an
   unconditional synchronous video read and readiness gating after the read,
   preserving the documented read latency and blank/incomplete-load behavior.
   Refit to verify inference, utilization and that the register-array crossing
   is eliminated; the present source does not establish those properties.
2. Audit HPS video-measurement transfer `vid_hcnt`/`vid_nres` → `dout` for a
   stable multi-bit snapshot/handshake across the separate clocks. The named
   setup and hold failures are concrete targets; single-bit synchronizers
   alone cannot establish coherent counter values.
3. Review asynchronous assertion and synchronized reset release separately in
   system/video domains, including HPS reset commands, ioctl and PLL lock.
   The `status[0]` recovery paths need an explicit reset-domain contract and
   subsequent timing verification.
4. Audit the new clock's framework interactions and PCG bundled-data paths.
   The inherited exclusive clock-group pattern names `*|pll|pll_inst|...`;
   the new `turbo_video_pll|oscillator|...` clock is not matched. Actual STA
   transfer tables include system↔video and video↔HDMI/HPS crossings. Any
   future exception needs a proven CDC/held-data contract and physical
   delay/skew bounds, rather than merely hiding the current violations.

Useful reports:
[setup](../output_files/quartus-p0epmzTq/source/output_files/turbo_video_diagnostic_setup.rpt),
[hold](../output_files/quartus-p0epmzTq/source/output_files/turbo_video_diagnostic_hold.rpt),
[worst hold at 0°C](../output_files/quartus-p0epmzTq/source/output_files/turbo_video_diagnostic_worst_hold_0c.rpt),
[recovery](../output_files/quartus-p0epmzTq/source/output_files/turbo_video_diagnostic_recovery.rpt),
[system→video](../output_files/quartus-p0epmzTq/source/output_files/turbo_video_diagnostic_system_to_video.rpt),
[video→system](../output_files/quartus-p0epmzTq/source/output_files/turbo_video_diagnostic_video_to_system.rpt),
[same-clock system](../output_files/quartus-p0epmzTq/source/output_files/turbo_video_diagnostic_system_same_clock.rpt)
and [same-clock video](../output_files/quartus-p0epmzTq/source/output_files/turbo_video_diagnostic_video_same_clock.rpt).

The first 0°C diagnostic extraction stopped with exit 3 because
`set_operating_conditions` required both temperature and voltage; its
[failed log](../output_files/quartus-p0epmzTq/worst-hold-path.log) is preserved.
The retry supplied `-model slow -temperature 0 -voltage 1100` and completed.
Both successful diagnostic runs exit 0 and print `AUDIT_COMPLETE`, generating
all requested reports, although the interactive shell footer says
`unsuccessful. 0 errors, 0 warnings`. They are report extractions, not claims
of passing timing. Logs are retained as
[timing-paths.log](../output_files/quartus-p0epmzTq/timing-paths.log) and
[worst-hold-path-retry.log](../output_files/quartus-p0epmzTq/worst-hold-path-retry.log).

## Unconstrained paths, CDC and verification limits

STA reports **zero illegal clocks and zero unconstrained clocks**. Setup and
hold each retain **3 unconstrained input ports / 7 paths** and
**44 unconstrained output ports / 50 paths**, unchanged from the previous
two-disk result. Inputs are HDMI I²C SDA, IO SDA and partially constrained
VGA enable. Outputs include HDMI I²C/I²S/clock/data/control, IO I²C, selected
LEDs, SPDIF, SD SPI CS and USER_IO. The full lists and false-path entries
remain in the STA report. TimeQuest explicitly says the design is not fully
constrained for setup/hold.

There are **380 detected synchronizer chains**, versus 386 previously.
TimeQuest **does not calculate design MTBF because timing requirements are
unmet**. Ignored `async_reg` attributes, the bare PLL reset connection,
read-during-write behavior, first-stage synchronizer treatment, bundled-data
placement/max-delay/skew, reset release and independent-PLL phase behavior
remain audit/implementation gates. Zero unconstrained clocks does not
establish CDC safety or complete constraints.

This task did not execute simulator/font/native tests. Main-agent-reported
tests and any subsequent implementation work are separate evidence. No
physical 15/24 kHz raster, HDMI/VGA acceptance, PLL tolerance/lock recovery,
font upload, game boot, OSD reset, disk mount/write or hardware transport
behavior is established by this RBF. The failing snapshot is not silently
replaced by later sources. No source, wrapper, constraint, test, build script,
existing documentation, commit or push was changed by this audit; its only
non-ignored write is this report.

## Artifacts and hashes

Experimental RBF:
[sharpx1_turbo_video.rbf](../output_files/quartus-p0epmzTq/source/output_files/sharpx1_turbo_video.rbf).
Preserve it as a failing-timing development artifact, not a timing-closed
hardware candidate.

| Evidence | SHA-256 |
| --- | --- |
| RBF | `fffb0c00899668fc71a87a28b02b89cbd4e856b7da5510291b11c08234652e3a` |
| SOF | `45abc1637579bf7f1578ad06f17d3eec72782f4bb40ff7dbd8f7d448d3890baf` |
| Generated `build_id.v` | `ab6f6e17454d678dfff7f5cd8f753698aa3f5842ba310c324a316a2f1dbeff06` |
| [Build manifest](../output_files/quartus-p0epmzTq/build-manifest.txt) | `ba3f1ec105ec772d9cdbdce7da1bfa3e43997f586a774c9127c3099262e8c4f3` |
| [Build log](../output_files/quartus-p0epmzTq/build.log) | `ecd191cfda33bab957858fe29c8117ebda0e19cd708914728a6a539ea7a58d4c` |
| [Fitter report](../output_files/quartus-p0epmzTq/source/output_files/sharpx1_turbo_video.fit.rpt) | `8ad98c43413849e10edf2be701042e4ef793b079ac2df36d56482bddaff6f671` |
| Preserved primary STA report | `5ea947d3a7efdffdfe62adeedf59c2d1959a497756ff5bbd4c1534d6e0df1582` |
| [Eight-corner STA report](../output_files/quartus-p0epmzTq/source/output_files/sharpx1_turbo_video.sta.rpt) | `8ce001f735b04eb52667008b55044e3b5336bd29cc116b093ef6ae7e88433f5c` |
| [Eight-corner log](../output_files/quartus-p0epmzTq/all-corners.log) | `da8985ff0273e2e8a35df8f69cc6698fe12bd6299f4f2489d296b821c50a17ad` |
| Detailed worst setup report | `8d95152faf524ac1e744cff1b072daf566f639fd061d4a9a72e3ac43877ad9a1` |
| Detailed recovery report | `bfc62ad9199517cd0e1c8b66ea850081ab8178e12dce5b7450c30c9db975fba3` |
| Detailed worst hold / 0°C report | `da707b61dd4a2a1fa594a06d657d576c2c80d4987e322f4c0b5c38500ed67dbc` |
