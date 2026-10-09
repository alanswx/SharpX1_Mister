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

## Executed unselected first-data-input probe

`scripts/constraints/vsync_sys_input_candidate.sdc` validates two primary
stages, exact keeper fanout, one stage-zero data pin and its unique VSYNC
data-source register before a single source-to-data-pin false path. CLK, Q,
stage one, the frame/configuration consumers and the separate measurement/
HPS paths are not excluded. The source may be the primary output or its actual
router duplicate; it is resolved from the data pin, never guessed from a
register fanin list (which also includes the clock port).
Mapped/fitted data-pin representations `d`/`asdata` are accepted only if exactly
one exists. No QSF selected the candidate during the probe below.

Mock tests pass 19 rejecting scope inventories. The optional reporter completes
all 80 baseline scopes before applying the candidate, then emits 80 matching
after scopes. No-argument reporting remains the original 64-file contract.
Coverage/order, thirteen parser negatives, five preservation/exclusion negatives
and the mapped-view refusal tests pass; all are selected by CI.

The native completed-fit probe finishes zero/no warnings at 19:24:59 UTC,
elapsed 36 seconds, log `/tmp/x1-quartus-e32bd69-vsync-input-probe.log`.
Actual reports are preserved locally in
`output_files/quartus-linux-1uPykZZ7/vsync-input-probe/`.
Executed candidate SHA-256
`b159991586efc04d19f31e817d38f8b8bcf0f88dc0877fe8c33b7bb28ae3b5ab`;
reporter SHA-256
`856b489c5fb5d8545c7c1c950e68eb407c1cc7f8be0570ecbf17208dbcd3f07a`.
Scope is exactly `hdmi_out_vs~_Duplicate_1` →
`hdmi_vsync_to_sys|sample_pipe[0]|asdata`.

`scripts/audit_vsync_sys_probe.py` independently confirms 48 unchanged
synchronous before/after report pairs (80 rows) at eight corners. All sixteen
raw input after-reports are valid `Nothing to report` exclusions, **not timing
passes**. Bounded global reports have 800 rows/check/phase: setup changes
−46.112 → **−12.017 ns**, hold −1.800 → **+0.017 ns**. Other CDC, inactive
mode data branches, external I/O and physical pulse/MTBF acceptance stay open.

### Mapped-view trap and actual early validation

The first `-post_map` invocation on the completed fit exits zero but issues
Critical Warning 332199: Quartus ignores that option after fitting. Those
reported "mapped" names are fitted names and are **not mapped validation**.
Log `/tmp/x1-quartus-e32bd69-vsync-input-mapped-fitted.log` preserves this
attempt. `quartus_vsync_sys_inventory.tcl` now refuses known fitter outputs
before opening a mapped view; its mock tests cover fit.rpt, fit.summary and
SOF markers and invalid configurations.

A new, unfitted input-only copy is created under
`output_files/vsync-map-OtdEHdiq/source`. The original QPF is restored from
the original source commit, not the Quartus-rewritten copy; its pre-map audit
matches the original input manifest. Bare `quartus_map` first fails because it
does not execute the inherited build-ID pre-flow hook. That failed log is
preserved in `/tmp/x1-quartus-e32bd69-vsync-isolated-map.log`.
The corrected map-only invocation runs `sys/build_id.tcl` first, then mapping
and early scope validation; log
`/tmp/x1-quartus-e32bd69-vsync-isolated-map-retry.log`. Mapping finishes zero
at 19:32:53 UTC, followed by actual mapped inventory/scope validation zero at
19:32:57 UTC. Its five warnings are inherited PLL RST/LOCKED connectivity,
not ignored `-post_map`; no timing clocks are loaded in this structural view.
All **388 inputs** match the original manifest before mapping. Generated
build-ID SHA-256 matches the completed fit's `1129592d58d7243fb463315e148909ab7b4035ce090d35bdd499dee7f26e2824`.
This true mapped view has six pins, a primary `hdmi_out_vs` source and the
stage-zero `|d` input; the fitted view has eight pins, duplicated source and
`|asdata`. Both have exactly two stages and the same one/three keeper fanout.

After both native views and preservation checks, only the experimental Z QSF
selects the single guarded source-to-input-data-pin scope for a fresh flow.
Ordinary revisions, machine RTL and the stage/consumer timing remain unchanged.
The selected file changes the probe's header comment only; the executed probe
hash above binds the actual experiment, not the newly selected file hash.
Fresh selected-QSF fitting, all-corner audits and physical/native gates remain
required; no new qualified RBF follows from the reporting probe.

## Selected-scope fresh flow (in flight)

Source `caf15d36be941aa2a75710d27f3321a24d9ce64a` is pushed to alanswx and
starts a frozen full flow on the idle authorized host, folder
`output_files/quartus-linux-NvYV9Nk3`, local observation log
`/tmp/x1-quartus-caf15d3-vsync-selected-build.log`. Build completion, fresh
native inventories and all-corner paths are not yet claimed.

For the selected fit, `audit_vsync_sys_reports.py --input-excluded` explicitly
requires sixteen valid excluded-input reports while retaining all 80 positive
synchronous rows and exact consumer scope. Unflagged empty input reports or
flagged still-active input reports fail; its two mode-mismatch controls pass.
This flag reports an exclusion, not physical input acceptance or proof of
the source/pin inventory. The actual native inventory and source-bound SDC
must be audited independently. Do not rerun the optional before/after probe
on an already-selected fit and call its baseline unexcluded.
