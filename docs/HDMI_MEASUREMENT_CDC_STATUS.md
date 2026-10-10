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
