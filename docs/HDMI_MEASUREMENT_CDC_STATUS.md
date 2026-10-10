# HDMI measurement and palette reset CDC follow-up

October 10, 2026. These are RTL repairs with local tests, not accepted FPGA
timing or a new hardware build. The preserved fifth-fit audit still reports
global setup -9.659 ns; see `HDMI_MODE_STATUS.md` for that exact source/fit.

## Actual fitted causes

The worst fifth-fit setup path ends at `video_calc.old_vs~reg1|d`, from
`hdmi_out_vs~_Duplicate_1` on the selected HDMI clock into the HPS 100-MHz
measurement clock. Its first raw sample also feeds edge detection directly.
The separate `hdmi_vsync_to_sys` exception does not cover this consumer.

The next two setup paths (-9.533/-9.526 ns) end at external/internal palette
`display_selected|d`. The raw reset button `cfg[1]` passes through machine
reset and `display_allowed` into these video-domain selection D inputs.
These are setup/data paths, not recovery/removal checks. Reset-release CLRN
exceptions correctly do not hide them.

## Implemented repairs

`video_calc` now adds dedicated preserved `hdmi_vs_meta/hdmi_vs_sync` stages
on `clk_100` only when its existing `COHERENT_SNAPSHOTS` option is enabled.
Only the second stage feeds the inherited HDMI-period edge detector. Legacy
framework/default behavior is unchanged; no measurement-input timing cut is
added. This narrow framework edit is necessary because that measurement
consumer is inside `sys/hps_io.sv`, not the machine wrapper.

The palette owner's video permission now uses `!video_reset && !video_grant`,
without the redundant raw `!reset` bypass. Local reset already asserts
asynchronously from the same raw request and releases after two video edges.
With local release disabled, `video_reset` equals raw reset, preserving the
compatible equation. CPU permission, storage contents, ownership handshake
and WAIT rules are unchanged. No RAM reset or new clock is introduced.

## Executed local gates

- `test-hps-hdmi-measure`: three live unrelated source/measurement clock
  ratios, exact independent period counts, second-stage-only observations,
  stopped-clock retention/recovery and unchanged legacy behavior pass.
  An actual legacy-bypass instance fails the unchanged two-stage oracle at
  the expected assertion, not a timeout. No measurement registers are forced.
- `test-hps-video-cdc`: existing register mapping, four snapshot clock ratios,
  stopped-source recovery and legacy mapping pass unchanged.
- `test-z-palette-owner` and `test-z-palette-owner-local-reset`: connected
  physical storage/WAIT/retained-read checks and three independent-domain
  reset cases pass, including stopped clocks and fresh lease acquisition.
  The inherited raw-release negative still rejects its expected assertion.
- `test-machine-z-combined-control-reset`: real CPU cold/warm controls and
  stopped-video pending reset pass at three video rates, with its rejecting
  disabled-priority control. Wrapper PLL-stand-in lint passes separately.

Logs: `/tmp/x1-hps-hdmi-measure-connected.log` and
`/tmp/x1-z-palette-reset-bypass-regression.log`, both terminal zero.
The first live measurement fixture stopped immediately after dropping raw
VS and incorrectly expected the previous high sample to disappear without
clock edges. That attempt fails as recorded in
`/tmp/x1-hps-hdmi-measure-first.log`. The corrected fixture drains the low
before stopping, preserving the same period/synchronizer assertions.

| Source | SHA-256 |
| --- | --- |
| Palette owner | `20bac5d0bb3e2d187601c613c961c16da5b11e1216368f26832583d8d5aef09d` |
| HPS integration/measurement | `5881470b83532a7534b022542ed5f0faf19db36298057083aa4f9f13ad2c5d6a` |
| Live measurement fixture | `bb4f363d15a17f30f2bb289e0b040f48183800e86fb6902485eda47da94df03f` |

### Review-driven verification strengthening

A separate read-only review identifies two gaps in that first fixture:
correct period values can hide a consumer updating at the wrong edge, and
forced register-mapping tests do not establish live HPS readout. The strengthened
fixture varies source intervals and checks the actual period register on
**every** 100-MHz edge against independently held expected data. It then
generates an actual interval longer than 65,535 cycles and reads both HPS
halves through the live snapshot/selector path, without forced registers.
All three opt-in ratios and the unchanged legacy route pass.

`test_hps_hdmi_consumer_negative.py` changes only the edge-detector input in
a disposable source copy, leaving the dedicated sync signal intact. The
same unchanged live oracle rejects this consumer-only bypass at its exact
update-edge assertion. Production source and fixture hashes remain unchanged.
This closes the observed test gap, not native fitted fanout or MTBF acceptance.
Connected log `/tmp/x1-hps-hdmi-measure-consumer-final.log`, terminal zero;
current strengthened fixture SHA-256:
`232850a77e99ebe08144f64072ca90869dd5423a459f8ed70189f963e3966890`.
The earlier table records the original fixture used by the earlier logs.

The fresh combined Z pixel matrix has started from frozen runner
`f6eb69653a34db659ce253ad1fde8f09e5cfcb23aea2d86bde9a68197c0124a6`
under ignored `verilator/obj_dir_v17_z_reset_bypass/qualification-cfbnUw/`.
All seven requested profile flags and SYS32/VID42.954540 pass actual preflight.
Runner/oracle/emitter/ANK are frozen before execution, alongside a source
archive; `all-120/completed.json` is the incremental authority. Log
`/tmp/x1-z-reset-bypass-all-120.log`. Launch/preflight is not pixel acceptance.

## Remaining physical gates

Fresh fitting must prove the raw reset no longer reaches palette selection
D pins and that HDMI stage one has only stage two as a consumer. Review actual
stage placement, downstream setup/hold and source pulse widths/MTBF. Any future
input exception must be narrowly guarded against that fitted topology; no
blanket measurement, reset-register or inter-clock cut is justified here.
Global timing, PCG-WE, I/O, native measurement behavior and hardware remain open.

The requested fresh `aa05dd2` full flow is not launched at the first host
check, 10:30:32 UTC: DSPPC604 Quartus shell/fitter PIDs 2001830/2002631 are
active. No source snapshot or probe is created and no competitor disturbed.
This is a busy-host observation, not a compilation failure or timing pass.

The next idle-host check permits launch at 10:35:07 UTC. The source-bound
`aa05dd2` flow finishes synthesis, fitting and assembly, then exits 3 at
10:43:50 UTC: the existing handoff input guard rejects the fitted
`completed_generation~DUPLICATE` source replica. This is not acceptance of
the new measurement synchronizer or reset repair, nor completed constrained
timing. Reporting-only inspection must establish the actual replica's
fan-in/fan-out before any constraint change. See
[the build record](DMA_BOARD_BUILD_STATUS.md#october-10-current-source-build-gate)
for frozen inputs and the unaccepted artifact hash.

Reporting-only inspection subsequently completes on the same fitted database
after the host becomes idle at 11:00:25 UTC. No SDC is loaded or timing cut
changed. Exact-edge and driver logs show `hdmi_vs_meta` feeding only
`hdmi_vs_sync`, which feeds `old_vs~reg1`; both stages use the HPS user clock.
The external/internal palette selection D endpoints each have 78 upstream
register fanins, without raw `cfg[1]`, `status[0]` or `ioctl_download`.
Their CLRN pins are driven by the video-local release pipe. This confirms
those narrow fitted connections, not timing closure or MTBF.

The handoff primary and `completed_generation~DUPLICATE` each expose exact
CLK/ASDATA/Q pins. CLK has a common `gate|outclk` driver and ASDATA a common
`completed_generation~3|combout` driver. `completed_meta` takes primary Q,
not duplicate Q. The duplicate feeds the primary/duplicate feedback cone,
not a first-stage synchronizer directly. Identical D/clock routes alone do
not establish reset/startup/control equivalence; that review remains before
any guarded replica allowance. The original refusal remains intact.

Preserved local reporting evidence:
`/tmp/x1-aa05dd2-topology.Eu3NqBQI/topology-aa05dd2-QaH3AJQC`.
The agent records three terminal-zero probes, unchanged fourteen original
source/artifact hash pairs and 409 snapshot inputs. Main reads the exact
pin/driver logs independently. Driver-log SHA-256:
`99343dce92bc33cf77898a3e2a41a318ffcf4319f571407b3ee423f4bca1d191`.
