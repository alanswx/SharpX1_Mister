# Final CTC Turbo Quartus build — October 4, 2026 (local)

The final CTC/interrupt RTL in `sharpx1_turbo_single` compiled successfully
with Quartus Prime Lite 17.0.0 Build 595. Supplemental TimeQuest analysis
passes all reported constrained paths at all eight available corners.
External I/O constraints and CDC/reset-release review remain incomplete;
this is development build evidence, not full timing signoff, Turbo software
acceptance or hardware validation. No hardware access or deployment occurred.

## Source binding and configuration

Executed the existing source-freezing script from the repository root:

```sh
QUARTUS_REVISION=sharpx1_turbo_single bash scripts/build_quartus.sh
```

Final build directory: `output_files/quartus-CEhveaur/`. The script froze
333 inputs, including dirty/untracked RTL, and compared the working-tree
hashes before/after copying with the snapshot manifest, byte-for-byte.
All 333 input hashes were subsequently recomputed from parent implementation
commit **`0115a38056936976ccbc311771a9a41dac15e64a`**: **333 match, zero
differences**. All 333 also match the working tree after supplemental STA.
The original pre-commit identity remains recorded rather than overwritten:

```text
source_commit=17b01d3b4e37e5250d8f78ad5a2905d6c0d885eb
input_manifest_sha256=3bd98b97070f85171960d4ab50a40055dd0364bb5bb2adc8e03c098814e84f48
sidecar_sha256=e7edd73862ad1b65f1c662b6be9d7a937f6c9ebba1a3ce1d51649d845f887de6
builder_sha256=49a5c3a8c4fa9a6718c96310469b3defc5a4bdeda6908e250383af53e0552fd2
runtime_identity_sha256=6550dd9261ca3b1397e53a2c063d71d6fe646a238fda876c75773ee05be96b3e
runtime_index_digest=sha256:6edc7bc0edee8c0a3f332ced040776c459287e856ee3ba85992512b7b313a370
rtl/x1_ctc.sv=c88ab0bfe9aabd842678897a3f9f17fa0e1a4fc24558a8a21e288e93732101e1
rtl/x1_irq_bridge.sv=f8372256ac76148cefbee44292ac098ac8b6a5ff4aab020c7575dff260b9a833
```

The final CTC snapshot includes the parent's last trigger-wait patch: a
control write without software reset preserves an existing trigger wait
while loading a new constant; the software-reset branch clears that wait.
The frozen CTC was also compared directly with the patched file.
An earlier snapshot, `quartus-czi36B6d`, was frozen before that patch. Its
container was explicitly stopped during synthesis (exit 137), with no RBF;
it is superseded and is not evidence for the final RTL.

The main project is `sharpx1`, revision `sharpx1_turbo_single`, top `sys_top`,
device `5CSEBA6U23I7`, seed 1. The revision inherits `X1_SINGLE_CLOCK=1`
and adds `X1_TURBO_FOUNDATION=1`. The active path is `sharpx1.sv` →
`rtl/sharpx1.v`, including `rtl/x1_ctc.sv`, `rtl/x1_irq_bridge.sv` and
the sub-CPU interrupt-acknowledgement changes through `rtl/machine.qip`.
The board machine master remains **35.000 ns / 28.571428 MHz**, distinct
from the simulator's 28.636364 MHz setting.

Relative to the prior Turbo foundation snapshot `quartus-t7wQxGHo`, the
input manifest changes only `rtl/machine.qip`, `rtl/sharpx1.v` and
`rtl/sub_cpu.v`, and adds the two CTC/interrupt modules above. Documentation,
Verilator tests and the parent's runner trace helper are outside this FPGA
input set. The generated UTC build date changed to `261005`; artifact
differences are therefore not a controlled RTL-only bitstream comparison.

Quartus expanded inherited assignments and wrote project metadata in the
snapshot revision QSF. The input manifest retains its original bytes.
Root project files and RTL were not edited by this build sidecar. No new
constraints, exceptions or warning suppressions were introduced.

## Tools and execution

Read `AGENTS.md`, `Readme.md`, `docs/SHARP_X1_TODO.md`, the prior
`docs/TURBO_QUARTUS_BUILD.md`, and the existing Apple container instructions
and builder under `/Users/alans/dev2/apple-containers-example`.
Used the already inspected cached
`docker.io/library/quartus17-runtime:apple-amd64` runtime and installed
Quartus payload, mounted read-only, with permitted container escalation.
No tools were downloaded or installed, no image was built, and no license
acceptance was performed. Container startup progress labels are not evidence
of a new download.

The existing builder runs the pre-flow build-ID hook explicitly, then the
stepwise main-project flow: map with one thread, fit with eight threads,
assembly and STA. Build container: 16 CPUs / 16 GiB. Supplemental STA:
4 CPUs / 8 GiB, with Quartus detecting five processors.

| Stage | Elapsed | Errors | Warnings |
| --- | ---: | ---: | ---: |
| Analysis/synthesis | 2:24 | 0 | 93 |
| Fit | 15:01 | 0 | 9 |
| Assembly | 0:31 | 0 | 0 |
| Original single-corner STA | 0:23 | 0 | 0 |
| Supplemental all-corner STA | 3:52 | 0 | 0 |

Build script exit: **0**. Build wall time: **18:42**, October 5,
**02:26:39–02:45:21 UTC** (October 4 locally). Supplemental STA ran
**02:45:57–02:49:49 UTC**, exit **0**. The manifest, full build log,
runtime identity, input list/hashes and original Git status are retained in
the build directory. Longer fitting than the prior 7:11 Turbo fit was
observed; process checks confirmed active CPU work, and fitting succeeded.

## Artifacts

The final local experimental artifact is
[sharpx1_turbo_single.rbf](../output_files/quartus-CEhveaur/source/output_files/sharpx1_turbo_single.rbf).
RBF and SOF hashes were checked before and after supplemental STA and match.

| Artifact | SHA-256 |
| --- | --- |
| RBF | `7244057eeca876a27b01e7160a2b641d12770bb97b5670d0a0c70c469e12e623` |
| SOF | `e2a0d2f9bf4fd803427d5bc0227b738342692eee3f26e485cd5d0f8332c19139` |
| Generated `build_id.v`, `BUILD_DATE=261005` | `ab6f6e17454d678dfff7f5cd8f753698aa3f5842ba310c324a316a2f1dbeff06` |
| Original single-corner STA report | `602e5c2db9e4cce0c8605944d67a1c957eed21c8f92256d8e31dac421196c862` |
| [All-corner STA report](../output_files/quartus-CEhveaur/source/output_files/sharpx1_turbo_single.sta.rpt) | `6def25187d4762ab3443ee74ef9443bb354a9371037f7f7d9fc68394be46ae67` |
| [All-corner log](../output_files/quartus-CEhveaur/all-corners.log) | `d9045a298783b13f37feaf51034b00fd1fe99fd7d318a705662dbb006cb28c7e` |

Artifacts, source snapshots and firmware remain local ignored outputs.
Inherited attribution and licensing limitations remain unresolved.

## Timing and constraints

The inherited QSF keeps `TIMEQUEST_MULTICORNER_ANALYSIS OFF`. Original
`.sta.rpt` and `.sta.summary` were copied with metadata preserved into
`output_files/quartus-CEhveaur/single-corner-reports/` before executing:

```sh
quartus_sta sharpx1 -c sharpx1_turbo_single --multicorner=on --all_corners
```

This command used the **same fitted database**: no map, fit, assembly,
assignment edits or extra timing exceptions. The snapshot's output STA
report and summary now contain the all-corner analysis. All corners are
1100 mV. Global worst slack, in ns:

| Model / temperature | Setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow / 100°C | +0.653 | +0.171 | +4.352 | +0.792 | +1.122 |
| Slow / −40°C | +0.359 | +0.055 | +4.517 | +0.742 | +1.122 |
| Slow / 85°C | +0.664 | +0.145 | +4.394 | +0.786 | +1.122 |
| Slow / 0°C | +0.444 | +0.068 | +4.507 | +0.733 | +1.122 |
| Fast / −40°C | +3.893 | +0.088 | +5.556 | +0.308 | +1.122 |
| Fast / 0°C | +3.780 | +0.106 | +5.515 | +0.316 | +1.122 |
| Fast / 85°C | +3.409 | +0.127 | +5.374 | +0.347 | +1.122 |
| Fast / 100°C | +3.292 | +0.131 | +5.331 | +0.352 | +1.122 |

Machine-domain slack, in ns, for
`emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk`:

| Model / temperature | Setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow / 100°C | +8.572 | +0.241 | +10.476 | +0.973 | +16.063 |
| Slow / −40°C | +8.934 | +0.196 | +10.706 | +0.900 | +16.041 |
| Slow / 85°C | +8.680 | +0.244 | +10.553 | +0.962 | +16.065 |
| Slow / 0°C | +8.984 | +0.211 | +10.724 | +0.891 | +16.045 |
| Fast / −40°C | +13.442 | +0.114 | +13.929 | +0.407 | +16.387 |
| Fast / 0°C | +13.300 | +0.117 | +13.785 | +0.423 | +16.378 |
| Fast / 85°C | +12.795 | +0.127 | +13.322 | +0.470 | +16.376 |
| Fast / 100°C | +12.642 | +0.131 | +13.174 | +0.481 | +16.376 |

All reported endpoint TNS values are zero. Global minimum setup/hold is
**+0.359 / +0.055 ns**, both in HDMI at Slow / −40°C. Compared with the
prior Turbo build's +0.233 / +0.086 ns, setup improves by 0.126 ns and hold
decreases by 0.031 ns. Global minimum removal is +0.308 ns, versus +0.407 ns
previously. Machine setup/hold/recovery minima are
**+8.572 / +0.114 / +10.476 ns**; removal/pulse-width minima are
**+0.407 / +16.041 ns**. Original Slow / 100°C machine same-clock Fmax is
40.23 MHz (previously 40.03 MHz); this excludes cross-clock paths and is not
a supported operating-frequency claim.

There are **zero illegal or unconstrained clocks**. Setup and hold each
retain **3 unconstrained input ports / 7 paths** and **44 unconstrained
output ports / 50 paths**, unchanged from the previous build. Inputs include
`HDMI_I2C_SDA`, `IO_SDA` and partially constrained `VGA_EN`; outputs cover
HDMI I²C/I²S/clock/data/control, IO I²C, selected LEDs, SPDIF, SD SPI CS and
USER_IO. The full lists are in STA. TimeQuest reports the incomplete setup
and hold constraints as informational messages despite zero warnings.

## Resources and warning review

| Resource | Final used / available | Difference from prior Turbo build |
| --- | ---: | ---: |
| ALMs | 20,115 / 41,910 (48%) | +96 |
| Registers | 31,752 | +105 |
| Block-memory bits | 3,069,504 / 5,662,720 (54%) | 0 |
| RAM blocks | 384 / 553 (69%) | 0 |
| DSP blocks | 32 / 112 (29%) | 0 |
| PLLs | 3 / 6 (50%) | 0 |
| Pins | 145 / 314 (46%) | 0 |

Top-level synthesis and fitter warning messages were compared with
`quartus-t7wQxGHo` after normalizing numeric source locations: no message
differences. Totals remain 93 synthesis / 9 fitter warnings. No new CTC or
interrupt-bridge width/truncation warning appeared. Existing warnings cover
ignored `async_reg` attributes, implicit `text_cs`, width/truncation and
parameter declarations, dual-clock RAM read-during-write behavior,
undriven/unused framework signals, PLL reset/lock wiring, incomplete I/O,
ignored fitter assignments and subscription-only LogicLock.

Connectivity information additionally identifies the bridge's unused
`ctc_selected` output, constant-high CTC trigger 0, and unused ZC outputs
1–3. ZC0 remains connected to channel 3's cascade; CTC logic is present in
the fitted hierarchy. These informational entries are not additional
top-level warning messages. Base-X1 FDC INTRQ/DRQ remain intentionally
unconnected. No diagnostic CPU interrupt connection was invented.

TimeQuest detects 386 synchronizer chains but cannot calculate MTBF for
99.2% of them. Its headline MTBF estimate does not validate CDC or reset
release. Bundled-data placement/constraints and physical CTC trigger phase
and pulse widths remain review gates.

## Verification limits and ownership

This sidecar executed Quartus synthesis, fitting, assembly and timing only.
The parent owns functional benches, deferred-reload/trigger-wait regression,
native software probes and any later commit/push. The parent's Arcus
diagnostic showing a drive-B-ready wait is not game acceptance and is not
hardware evidence. This RBF has not been loaded, booted or tested for
physical keyboard/joystick/audio/storage or OSD reset behavior.
SIO/DMA, complete Turbo video/firmware compatibility and hardware signoff
remain open. Positive analyzed timing does not close those gates.

Only this documentation destination was added to the working tree by this
sidecar; no RTL edit, commit or push was performed. Parent commits during
the build are recorded above as source-binding evidence.
