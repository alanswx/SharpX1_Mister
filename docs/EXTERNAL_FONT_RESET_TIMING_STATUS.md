# External-font video reset timing

October 16 local work (UTC evidence continues October 17). MiSTer remains
with the user and is not accessed. This concerns only the separate
`sharpx1_turbo_z_font` qualification revision. No machine RTL changes.

**Final gate: build PASS, selected reset/data/snapshot timing PASS, global
timing FAIL, hardware UNEXECUTED.** All jobs below are terminal. The new RBF
is a source-bound experimental checkpoint, with a new global hold failure;
it is not a hardware-qualified replacement for the previous core.

## Completed same-fit probe

Evidence: `output_files/TIMING_FONT_RESET_20261017T020358Z/`. The original
`quartus-O1IV3KIp` build is hashed in `baseline-build.json`; reporting uses
private copies. Its worst recovery paths are SYS-owned external-font service
state to the asynchronous inputs of the VID reset-release pipeline. The
reported minimum is −8.300 ns. This is distinct from the pipeline's ordinary
stage transfer and released-reset fanout.

The font profile has exactly two `release_pipe` registers and two CLRN pins
in `video_reset_domain.release_reset`. It has no palette reset pipeline.
The existing four-pin Z-video constraint therefore cannot be selected here.
Native connectivity confirms stage zero feeds only stage one, and stage
one's synchronous data fan-in is exactly stage zero. The second stage has
496 native register fanouts in this fit; this count is not a claim that
every fanout has an asynchronous reset timing check.

`sharpx1_turbo_z_font_reset.sdc` validates both full native pin names before
excluding only those two raw asynchronous inputs. It excludes no D/CLK/Q,
stage transfer, released-reset fanout or clock domain. Only the font QSF
selects it. Physical assertion pulse width, placement and MTBF remain open.

The native before/after probe finishes zero with no warnings, log
`/tmp/x1-font-reset-probe-v2.log`, reports `probe-reports-v2/`. Across all
eight Slow/Fast 1100-mV corners at −40/0/85/100 C:

| Retained timing | Paths per corner | Minimum slack |
| --- | --- | --- |
| Stage 0 → 1 setup | 1 | +21.618 ns |
| Stage 0 → 1 hold | 1 | +0.328 ns |
| Released reset recovery | 147 | +17.818 ns |
| Released reset removal | 147 | +0.414 ns |

All 2,368 retained rows are identical before/after. Global setup/hold tables
are also identical. Both raw-pin reports become explicitly excluded, never
called timing passes. Global recovery still fails at −4.864 ns from
`reset_req` to the inherited scaler's `i_reset_na`. Global setup is unchanged
at −15.149 ns. Global reports contain the worst 30 paths, not exhaustive
design acceptance. `probe-audit.json` records the independent checks.

The first reporter attempt fails before applying constraints because Quartus
17 `get_fanouts` does not support `get_fanins`'s `-synch` option. Its inputs,
partial inventory and log remain preserved; it is not a negative timing
qualification. The corrected reporter uses the native fanout traversal.

## Digital and audit controls

Fresh `make -C verilator test-reset-release` passes all seven destination
half-periods: 3,000/7,000/31,000/15,625/17,500/11,640/25,000 ps. It checks
short asynchronous assertion, phase variation, release exactly after two
local edges, reassertion between stages, near-edge deassertion and stopped
clock recovery. Frozen early-release and synchronous-assertion RTL mutants
both compile and reject at their exact runtime assertions. These digital
tests do not model metastability or minimum physical pulse widths.

`python3 verilator/tests/test_z_font_reset_sdc.py` passes fifteen synthetic
scope cases: two valid inventories and thirteen refusing all exceptions,
including missing/duplicate/extra pins, D/CLK/Q, foreign owners, CPU/palette
instances, extra stages and replicas. This does not prove native matching.

Five copied-report controls reject first-stage consumer fanout, a missing
chain row, a wrong output clock, negative chain hold and a raw path that
was not excluded. `audit-controls.json` records these as audit-policy
controls, not DUT or native timing negatives. Frozen inputs and digital
results are in `qualification-inputs.json`, `digital-audit.json` and
`reset-controls.json`.

## Fresh fit

The source-bound local Quartus 17.0.0 build 595 full flow finishes zero in
13m08s, `output_files/quartus-tIvlttNZ/`, log `/tmp/x1-font-reset-quartus.log`.
There are 430 hashed compiler inputs: only the old font QSF changes and the
new reset SDC is added relative to the prior 429-input build. Generated
`build_id.v` now records UTC October 17. No RTL source was edited.

The RBF SHA-256 is
`b570e529302c20dbf06858533c318c37c9b12997270398090c502f416f38384c`.
Resources are 25,442 ALMs, 37,179 registers, 4,319,336 memory bits,
534/553 M10Ks, 32 DSPs and four PLLs. All 159 synthesis and eleven fitter
warnings retain their prior identities (only generated RAM entity/file
suffixes normalized). Assembly has zero warnings; main STA has one warning
for unmet timing. The full flow has 171 stage warnings.

Main Slow 100 C setup/hold/recovery/removal are
**−15.124/−2.988/−4.846/+0.705 ns**. The new hold failure is a regression in
reported global timing, not a qualified improvement. It crosses from the
scaler's input-size/downscale logic into its HDMI output-size registers;
the Slow −40 C reports also expose an HDMI data-output hold failure.
`sys/ascal.vhd` lines 1562–1563 select the input sizes and lines 1901–1902
sample them on an output frame-buffer change, explicitly marked `<ASYNC>`.
That comment alone establishes no stable-payload/ownership timing contract.
These paths remain timed and open; no additional cut is proposed here.
The changed placement and generated build date preclude attributing this
new global failure solely to the reset constraint. The same-fit probe above
does prove its raw-only exception leaves reported data timing unchanged.

The effective-assignment review passes all 2,232 values and machine HDL/QIP
ordering, apart from the same four isolated PLL-library records as before.
The two node-only font SDCs move ahead of the base clock SDCs; the latter's
relative order is retained. The first auditor omitted `sys/sys_top.sdc`'s
QIP ownership tag and rejects its exact row comparison; its source/log are
preserved. The correction retains that exact ownership tag, all ordering
predicates and the native assignment values. Integrated reports must still
prove the selected bounds under the actual assigned order.

The three frozen reporters finish sequentially on `fresh-fit-work/`, a copy
of the completed build. All return zero with no warnings and use only
assigned SDCs; the integrated probes add no analysis exceptions. Logs are
`fit-reset.log`, `fit-snapshot.log`, `fit-data.log`, copied byte-exact to
`/tmp/x1-font-reset-fit-{reset,snapshot,data}.log` for the independent audits.

| Fresh eight-corner gate | Coverage | Minimum slack |
| --- | --- | --- |
| Stage 0 → 1 setup/hold | 1 path per check/corner | +21.722/+0.232 ns |
| Released reset recovery/removal | 144 paths per check/corner | +16.713/+0.259 ns |
| Synchronous release data setup/hold | 8,272 rows / 413 register targets | +13.030/+0.568 ns |
| Dimensions payload setup/hold | 72 bits / 1,152 rows | +20.128/+0.517 ns |

The 144 recovery targets and 413 synchronous data targets together cover
all **487** native second-stage register fanouts, with 70 targets appearing
in both sets and no unclassified register endpoint. The first stage still
feeds only the second stage. This is register-endpoint coverage under the
assigned constraints, not every-pin/physical CDC acceptance. The old fit's
496 fanouts/147 asynchronous targets must not be substituted for this fit.
The snapshot's maximum physical data delay is **13.215 ns**; every selected
setup/hold relationship remains exactly **31.25/0 ns** under the rewritten
SDC order. `reset-fit-audit.json`, `release-data-audit.json` and
`snapshot-fit-audit.json` pass independently.

Eight-corner reported global minima are setup **−15.124 ns**, hold
**−2.988 ns**, recovery **−4.852 ns**, removal **+0.259 ns**.
`global-timing-discovery.json` binds the actual negative scaler-size and
HDMI-output hold rows to native reports and unchanged scaler source.
I/O setup/hold constraints are incomplete. These worst-30 reports do not
establish exhaustive global path coverage; MTBF is not calculated while
timing fails. Physical reset assertion widths and placement remain open.

The final build auditor also checks unchanged original/completed build
trees, all current compiler inputs, selected constraint/reporter identities,
effective assignments and all independent report hashes. The first final
auditor rejects Quartus's automatic QPF rewrite on the isolated original
query copy. Its source/log are preserved. The exact review verifies that
`project_open` adds only its dated header and the explicitly queried font
revision, retaining version 17.0 and the base revision; every other input
in that query copy remains exact. Root inputs and completed builds are
unchanged. `assignment-review/original-query-rewrite.json` records this,
and `final-build-audit.json` passes with the original report/timing gates
unchanged.

Next work: separately qualify the scaler's destination-local reset release
for this font profile. Its existing two-stage helper is enabled by the
different Z-video experiment, while this profile still uses the inherited
one-stage release. Do not select that experiment wholesale: it also enables
other incompatible video behavior. Scaler size CDC, cache publication,
HDMI clock switching, remaining I/O and physical/hardware acceptance stay
open. No additional timing cut or framework RTL change is made here.
