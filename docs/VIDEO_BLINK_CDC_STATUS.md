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

The full ordinary delay-aware suite is still running. The existing 120-case
combined-Z run is frozen to the older machine: its results remain historical,
not current blink qualification. Rerun the combined pixel matrix on the new
machine. Fit the new source, inspect actual synchronizer fanout/placement,
first-stage input and active stage/consumer/reset timing, and qualify physical
blink/native firmware. The completed `caf15d3` RBF predates this correction.
No new timing-qualified or hardware-qualified RBF is claimed here. Native
Turbo Z compatibility and the complete TODO groups remain open.
