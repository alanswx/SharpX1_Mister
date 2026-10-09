# Experimental SYS VSYNC synchronization

The independent-X3 Turbo Z board revision now samples `HDMI_TX_VS` through
`rtl/x1_vsync_sys.sv` before the SYS-domain frame-wait filter and PLL/configuration
gate. Two initialized registers sample on every SYS edge, with no CE/reset.
Only the second stage feeds those consumers. Their existing filter and gate
equations remain unchanged; the input acquires two sampling stages.
Ordinary board revisions retain the inherited raw input branch.

This addresses the raw reread in the old frame filter and first-stage use in
the configuration edge detector. The preceding `6133f27` fit exposes raw VSYNC
SYS paths, including a −47.729 ns path. That historical fit does not qualify
this new implementation. No new timing exception is added: actual fitted
stage inventory, first-stage fanout, downstream timing, physical placement/
MTBF, pulse widths and mode switching still require acceptance.

## Local acceptance

```sh
make -C verilator test-vsync-sys-controls
```

The actual helper and mirrored existing consumer equations pass nine clock
combinations: SYS half-periods 15,625/17,500/10,000 ps crossed with source
half-periods 3,366/11,640/25,000 ps. Checks cover initialized low output,
two-sample latency, output changes only on SYS edges, a transition 1 ps before
an edge, twelve source phases, exact frame-event counts and actual mirrored
frame-wait retention/clear behavior, configuration enable/
disable/not-ready behavior and a stopped SYS clock with a held input level.
Raw-input and one-stage negative controls both fail the fixture. CI selects
the same target. This is not full `sys_top` simulation or metastability modeling.

The helper is a level synchronizer, not a short-pulse queue. It intentionally
does not promise delivery of a pulse entirely between SYS sampling edges.
Hardware VSYNC width must be checked for each supported output mode.

The raw VSYNC HPS interrupt and `hps_io`'s separate 100 MHz measurement path
are unchanged. Feeding them a SYS-qualified level would not qualify their
different clock-domain contracts. They remain separate review items.

Machine RTL, ordinary game runners and private assets are unchanged.
Fresh Quartus fitting, eight-corner timing and physical/native tests remain
open. This change does not make the Turbo Z RBF timing-qualified.

## In-flight source-bound fit and reporting

Checkpoint `e32bd6967577580ea9724e5d0bc3bf4f4129b45a` is pushed to alanswx.
The authorized idle Linux host starts its frozen-source full flow in
`output_files/quartus-linux-1uPykZZ7`; local observation log is
`/tmp/x1-quartus-e32bd69-vsync-build.log`. This records a started build, not
a completed fit or RBF qualification. Ordinary and experimental wrapper lint
finish zero with inherited warnings; those checks do not elaborate `sys_top`
or the VHDL scaler.

`scripts/quartus_vsync_sys_paths.tcl` prepares reporting-only acceptance of
exactly two actual, distinct `sample_pipe[0/1]` registers. Missing, duplicated,
replicated, misnumbered and unresolved stage inventories reject before reports.
Its 64 scopes cover input, stage transfer, all reported stage-zero fanout and
stage-one consumers, setup/hold at eight corners. No exception is issued;
raw input timing may fail, and empty reports are not acceptance. Native
connectivity/physical fanout must still be inspected in addition to these
bounded path reports. Mock coverage and eight rejecting inventories pass via
`make -C verilator test-vsync-sys-paths`; CI selects it. Native execution waits
for the build to become idle and original reports to be preserved.

## Completed full flow; native audit in progress

The `e32bd69` full flow finishes zero at 19:08:07 UTC, elapsed 8:32.
Original local artifacts are preserved in
`output_files/quartus-linux-1uPykZZ7/completed-flow/` before supplemental STA.
RBF SHA-256
`d3a9b0250f196acf1fb8871b065a5b665dc78575fa272a70ec9004af2c424ad6`
is **unqualified**. Input manifest SHA-256
`c5c9cd98729f9e3a168983583d66bf45d1d4acf2234a948060e0dec5fd02f356`;
387 inputs match, only Quartus-rewritten QPF differs.

The initial Slow 100 C report still fails setup −46.112 ns. Its positive hold
minimum +0.200 ns does not represent all-corner acceptance. Sequential native
acceptance starts after preserving originals, log
`/tmp/x1-quartus-e32bd69-native-acceptance.log`.
The VSYNC reporter completes zero/no warnings and validates precisely stages
zero/one. Early Slow −40 C reports show one stage-zero-to-one path, and three
stage-one consumers `vs_d0`, `vs_d1`, `vsd`, all positive. Raw input reports
remain negative and target only stage zero from the actual duplicated VSYNC
source. Final eight-corner independent audit and physical connectivity/MTBF
remain required; those early reports are not a complete CDC/timing pass.

`scripts/audit_vsync_sys_reports.py` checks all 64 report scopes, exact SYS
chain/consumer directions and nonnegative synchronous setup/hold. It requires
both reported input clock aliases but never calls their asynchronous slack a
pass. Physical data delay is parsed separately from skew. The independent
native raw-source name is supplied explicitly. Synthetic valid coverage and
13 rejecting controls pass via `make -C verilator test-vsync-report-audit`;
CI selects the same parser test, not native timing execution.

## Completed eight-corner reports

Sequential acceptance finishes zero at 19:12:45 UTC; local reports are in
`output_files/quartus-linux-1uPykZZ7/acceptance/`, separately from original
full-flow reports. The independent VSYNC audit passes all 64 files:
80 synchronous chain/fanout/consumer rows, minimum **+0.250 ns**. The 32 raw
input rows have minimum **−46.112 ns** and remain explicitly open, not passes
or an applied exception. Actual input source is `hdmi_out_vs~_Duplicate_1`.

Native inventory without SDC reports two registers and eight associated pins:
stage zero uses `|asdata`, not a presumed `|d`; stage one uses `|d`, and each
has its own CLK/Q. A future input-only probe must bind the actual first-stage
data pin and preserve CLK, Q, stage transfer and consumer paths. No such cut
is selected. Log `/tmp/x1-quartus-e32bd69-vsync-pin-inventory.log`.

All eight global minima from the full multicorner command's preserved log:
setup **−46.112 ns**, hold **−1.800 ns**, recovery +3.418 ns, removal +0.256 ns,
pulse width +0.529 ns. Design MTBF is not calculated by Quartus because timing
requirements are not met. These reports do not establish physical CDC safety.

Independent PCG audit passes 48 request/16 response files, 4,672 request and
128 response paths; native inventory has eight CPU captures and zero state
replicas. Snapshot checks pass 1,152 rows, minimum combined setup/hold
+0.584 ns and maximum physical data delay 13.036 ns. Six scaler stage-chain
checks contribute 48 rows, minimum +0.233 ns; properly scoped stage-one
downstream reports contribute 352 rows, minimum +0.256 ns. Per-domain paths
per check are input/HDMI/Avalon **1/14/7**, not an assumed prior-fit count.

The 320-scope clock reporter also finishes zero. Bounded internal HDMI-alias
setup reports have 440 rows, minimum +1.024 ns; HDMI master-to-own-alias
setup has 232 rows, minimum +0.056 ns; VID master-to-own-alias setup has
192 rows, minimum +14.165 ns. Those are setup-only row totals; they do not
qualify all hold paths, inactive mode branches, external I/O or switching.

Native no-SDC `get_fanouts` now confirms exactly stage zero → stage one,
and stage one → the three expected consumers, with no other keeper fanout.
The Fast −40 C sidecar confirms the −1.800 ns hold failure is also the raw
VSYNC source → stage-zero input, not a synchronous stage/consumer failure.
Its next reported path is +0.047 ns. Logs are
`/tmp/x1-quartus-e32bd69-vsync-fanout-fast-hold.log`, sidecar separately in
`output_files/quartus-linux-1uPykZZ7/fast-hold-acceptance/`.
The reporting tool now refuses changed native fanout before any timing
reports; fourteen invalid stage/fanout inventories reject in its mock test.
The strengthened guard's native rerun finishes zero/no warnings at 19:19:32
UTC (`/tmp/x1-quartus-e32bd69-vsync-guard-acceptance.log`), with separate
reports in `output_files/quartus-linux-1uPykZZ7/vsync-fanout-acceptance/`.
An exact input-pin-only before/after probe remains next; no exception is
selected. No hardware is contacted/
loaded. Work groups 1–6,
native/full Turbo Z and physical acceptance remain incomplete.
