# Experimental X3 text blink crossing

The sub-CPU's blink output is a held level. `bios/reference/fw_subcpu/x1sub.asm`
names `CLK_1HZ` and toggles HOST_CTRL bit 4 in `isr_500ms`;
`rtl/sub_cpu.v` exposes OP1[4] as `O_clk1`. The legacy renderer uses this level
in `att_rev ^ (att_blink & I_CLK1)`. This increment does not change the firmware
or its timer period, and does not treat blink as a clock or clock enable.

The preceding fitted timing probe identified real SYS-to-VID blink paths into
text and palette selection. `rtl/x1_video_blink.sv` now samples that level
through two destination-clock registers, with the existing destination-local
video reset. Only `TURBO_VIDEO_MASTER` profiles instantiate it. Ordinary RTL
retains the direct connection, with no additional helper state. This is a
functional CDC correction, not permission to cut all sub-CPU GPIO timing.

## Executed local checks

- `make -C verilator test-video-blink` passes four video periods, twelve
  near-edge input phases, two-sample latency, stopped-clock retention,
  asynchronous reset assertion and destination-edge reset release/restart.
  Raw-level and first-stage-output controls fail. The fixture instantiates
  the real helper and reset release, not the full renderer; it does not
  simulate metastability. An inherited reset-helper timescale warning remains.
- The actual CPU-programmed delay-aware X3 renderer passes all four existing
  40/80-column blink-off/on pixel tests, using the real sub-CPU timer.
  SYS is 32 MHz; VID is nominal 42,954,540 Hz. Durations remain 200/700 ms.
  All 384,000 expected pixels pass; log
  `/tmp/x1-blink-x3-actual-pixels.log`. Runner SHA-256:
  `2a78e7b965a9d8ddbab90a517d3dd6a35a882f88231e2c440330fbe39fe2067d`.
- Ordinary snapshots and new X3 snapshot continuation pass. A separately
  rebuilt pre-blink `cd53e0b` X3 runner creates an actual unmodified state;
  the new runner rejects it before deserialization. Application profile bit
  63 records this X3 layout revision. Ordinary v17 is unchanged. No state
  bytes are converted or patched. Logs:
  `/tmp/x1-blink-base-snapshot.log` and
  `/tmp/x1-blink-x3-isolated-snapshot.log`.
- Actual ordinary generated serializer/deserializer files match the archived
  pre-blink build, including root checksum `0x15a674813a657c3eULL`. Rebuilt
  executable hashes differ; binary identity is not claimed. Five fresh
  ordinary commercial-game collectors finish zero; see
  [commercial qualification](COMMERCIAL_COMPATIBILITY.md).
- Connected combined-Z control/reset and palette-owner reset diagnostics pass,
  including their failing controls. Ordinary and experimental wrapper lint pass;
  this is not a full `sys_top`/VHDL fit or physical validation.

Frozen machine SHA-256:
`7f0a8f18524701d00250e31f2fe71bff0520e8b50bd6c4690b2ffd9c46528e80`.
Helper SHA-256:
`59f3c1a87a5eec87a3682b3362e1b89a4a9ed802492fffa8afa8dff706bb58ff`.
X3 savable runner:
`7ead6bf324314c1a906c38dc77d0ce500a266ed5103be0ada13dc54c7bea81d1`.
Ordinary fast runner:
`b1452906a5548333486d16007ba90bdc663382ee97980b545d4d8bdcf47a1915`.
Ordinary delay-aware runner:
`3659a1894cecdb549df25b3dc995a7344c5e9ed9d4e81cd07f6d5aa6fc15385c`.

## Remaining acceptance

The full ordinary delay-aware suite plus blink helper finishes zero (149 PASS
reports), log `/tmp/x1-blink-full-baseline.log`. The existing older 120-case
combined-Z run is frozen to the older machine: its results remain historical,
not current blink qualification. Rerun the combined pixel matrix on the new
machine. A fresh frozen current-source 120-case run has now started under
`verilator/obj_dir_headless/z-blink-combined/qualification-dzBGPN/all-120/`,
log `/tmp/x1-blink-z-combined-all-120.log`. It terminates at the first profile
assertion: inherited Verilator `VPATH += ..` links parent `sim_headless.o`,
whose ordinary C++ flags contradict this generated combined RTL. No pixel case
is qualified and the failed frozen root/log is preserved. This is a build
isolation failure, not evidence that the new blink RTL has incorrect pixels.

The experimental Z recipe now forces local object recompilation (`-B`),
verified by actual compile/link commands and a short actual-runner JSON check.
The new runner has all seven combined/delay-aware feature flags and
32/42,954,540 MHz clocks. SHA-256:
`1480640e5a556854cccb0339637e5dd822abde6782592d7db65a3bdea6f8a3a3`.
The ordinary baseline binary remains hash-identical to its qualified build.
The matrix scheduler now performs a short profile check before any long case;
the actual wrongly linked frozen runner is rejected by that check, without
launching a pixel case. Original pixel durations/assertions remain unchanged.
A new disposable frozen run is required; do not resume or relabel the failed
root as corrected qualification.

`scripts/quartus_video_blink_paths.tcl` prepares a reporting-only eight-corner
inventory/path audit. It requires two unreplicated paired stages and exclusive
stage-zero-to-stage-one keeper fanout, logs native final consumers/pins/fanins,
and reports input, chain, first-stage fanout and final-consumer setup/hold.
Mock checks pass 64 unique scopes and sixteen rejected inventories; CI selects
them. It adds no exceptions. Actual fitted names/coverage, path results and
physical synchronizer placement still need native execution after the fit.

The `6e334b4` full Quartus flow has also started in the new frozen folder
`output_files/quartus-linux-4hQayhHF`, log
`/tmp/x1-quartus-6e334b4-blink-build.log`. Fit completion, inventory and timing
are not yet established. Inspect actual synchronizer fanout/placement,
first-stage input and active stage/consumer/reset timing, and qualify physical
blink/native firmware. The completed `caf15d3` RBF predates this correction.
No new timing-qualified or hardware-qualified RBF is claimed here. Native
Turbo Z compatibility and the complete TODO groups remain open.
