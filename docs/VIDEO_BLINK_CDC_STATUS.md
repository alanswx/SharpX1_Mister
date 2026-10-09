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
`make -C verilator test-z-build-isolation` now reproduces the problem with
actual Verilator/GNU make and a tiny parameterized RTL/C++ build fixture:
the uncorrected nested build links its parent's ordinary-profile object;
the selected Z recipe rebuilds locally and reports the requested profile.
Parent executable/object hashes remain unchanged. This test is selected in
CI, log `/tmp/x1-z-build-isolation-regression.log`; it proves build isolation,
not Sharp X1 behavior. The fixture varies RTL as well as C++ profile so it
does not merely reuse an unchanged parent's entire executable.
The matrix scheduler now performs a short profile check before any long case;
the actual wrongly linked frozen runner is rejected by that check, without
launching a pixel case. Original pixel durations/assertions remain unchanged.
A new disposable frozen run starts under
`verilator/obj_dir_headless/z-blink-combined/qualified-inputs-UKsvP0/all-120/`,
log `/tmp/x1-blink-z-fixed-all-120.log`. Its profile preflight passes before
the first pixel case starts. Scheduler SHA-256:
`638fd9ef33f6e316a5ff7435683362f2c5a92614f1eb13a92793d6e460e5f1df`.
Completion is pending; do not resume or relabel the failed root as corrected
qualification.

`scripts/quartus_video_blink_paths.tcl` prepares a reporting-only eight-corner
inventory/path audit. It requires two unreplicated paired stages and exclusive
stage-zero-to-stage-one keeper fanout, logs native final consumers/pins/fanins,
and reports input, chain, first-stage fanout and final-consumer setup/hold.
Mock checks pass 64 unique scopes and sixteen rejected inventories; CI selects
them. It adds no exceptions. Actual fitted names/coverage, path results and
physical synchronizer placement still need native execution after the fit.

The `6e334b4` full Quartus flow completes zero at 20:18:27 UTC on October 9
in the new frozen folder
`output_files/quartus-linux-4hQayhHF`, log
`/tmp/x1-quartus-6e334b4-blink-build.log`. Original reports/RBF are preserved
under `completed-flow/` before supplemental STA. Build input manifest SHA-256:
`079ab0b7e4be3626e6f17f970aa23c03ccc9abe0da545847a4ea7c142777ebba`.
RBF SHA-256:
`d0eb60c222b359820db298d781af1caf56d4f777b41d211bd65c3ce10796a70d`.
It is **unqualified**: fit success does not establish timing closure or native
hardware behavior. The full sequential eight-corner acceptance run finishes
zero at 20:24:31 UTC. Global reports are separately preserved under
`all-corner-global/`, sidecars under `acceptance/`, log
`/tmp/x1-quartus-6e334b4-native-acceptance.log`. Independent audits pass:

- VSYNC: 80 synchronous rows, minimum +0.242 ns; sixteen raw-input reports
  are explicitly excluded by the previously selected narrow VSYNC scope,
  not physical timing passes. Native source/first `|d` inventory matches.
- PCG: 48 request/16 response corner reports, eight primary CPU captures,
  no capture or stage01 replicas in the independent native inventory.
- Snapshot: 1,152 rows covering exactly held/destination bits 2–73 at all
  eight corners, VID-to-SYS clocks; minimum +0.671 ns, max data 12.957 ns.
- Scaler release: 48 chain rows, minimum +0.224 ns, and 352 reported downstream
  rows, minimum +0.252 ns. This does not qualify the scaler's data crossings.

All eight global corner summaries are present. Setup still fails, minimum
**−12.162 ns**; hold/recovery/removal/pulse-width minima are
+0.017/+4.700/+0.252/+0.529 ns. The improved hold result is this particular
fit's reported timing, not a functional correction or physical qualification
of unsynchronized scaler buses. Setup failures include inactive HDMI output
branches and real raw SYS-to-VID CRTC/reset/control crossings. The bounded
SYS-to-VID top-100 setup report still has minimum −10.525 ns; its cap is not
complete CDC coverage. No blanket clock grouping or new blink exception is
used to hide these paths.

Post-analysis input audit matches 389 inputs; the sole mismatch is the
Quartus-rewritten `sharpx1.qpf`. Comparison with the source commit identifies
added tool comments/date and experimental revision entry, not an RTL/SDC
change. Current and preserved RBF hashes match. Log:
`/tmp/x1-quartus-6e334b4-post-input.log`.

The reporting-only blink audit executes natively and finishes zero at
20:21:02 UTC, log `/tmp/x1-quartus-6e334b4-native-blink.log`. Executed tool SHA-256:
`b1fb46cddbf4a6dbb8706e927e36a1ad87799d98d918012e85e4e348035cb2f6`.
It finds exactly the two unreplicated `crossing.sample_pipe` stages and
exclusive stage-zero fanout to stage one. Stage one's native fanout is 85
register keepers. The actual first data pin is `|d`; native data fanin is the
sub-CPU `mr16_x1:sub_cpu|O_P1[4]`, not a guessed source clock. No new exception
is applied. The independent `audit_video_blink_reports.py` check now passes
all 64 reports: 85 final keeper identities match the independent native
fanout inventory, chain/first-fanout reports agree, and all 12,080 synchronous
rows have VID-to-VID clocks, nonnegative slack and physical data delays within
the video period. Minimum synchronous slack is +1.058 ns. The sixteen raw
SYS-to-first-stage rows remain explicitly **open**, minimum −7.218 ns; no new
exception is applied. The parser has fifteen rejected synthetic scope/domain/
data/native-log controls selected in CI. Positive synchronous paths do not
prove placement/MTBF or authorize a whole-clock/GPIO cut.
Inspect actual synchronizer placement,
first-stage input and active stage/consumer/reset timing, and qualify physical
blink/native firmware. The completed `caf15d3` RBF predates this correction.
No new timing-qualified or hardware-qualified RBF is claimed here. Native
Turbo Z compatibility and the complete TODO groups remain open.
