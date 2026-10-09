# Video reset input timing experiment — not qualified

October 9, 2026. The source-bound Z fit's recovery failures include raw reset
sources into two `x1_reset_release` pipelines. Their downstream outputs release
after two local clock edges. These are different timing contracts: excluding
all paths to/from reset registers would also hide ordinary stage transfer and
synchronous downstream recovery, and is not proposed here.

`scripts/constraints/video_reset_input_candidate.sdc` was analysis-only during
the completed-fit experiment; it is now selected by the experimental Z QSF
only, pending fresh-fit acceptance. It checks precisely four pins: `release_pipe[0/1]|clrn`
on `video_reset_domain.release_reset` and palette ownership's
`local_release.video_release`. Only those asynchronous input pins receive a
false-path candidate. It does not select their D/CLK/Q pins, whole registers,
CPU reset pipelines, downstream release fanout or clock domains.

`make -C verilator test-video-reset-sdc` finishes zero. Mocked valid scope
matches exactly those four pins; nine invalid inventories reject all
exceptions, including data/clock/output pins, CPU pipeline, wrong stage,
wrong instance and missing/duplicate/extra pins. It is now selected in CI
alongside the seven-profile `test-reset-release`. This mocked test does not
prove native Quartus pin matching, exception semantics or timing.

`scripts/quartus_video_reset_probe.tcl` now executes on the completed source-bound
`67de103` fit, after the original artifacts and other acceptance reports are
preserved. It finishes zero, no warnings
(`/tmp/x1-quartus-67de103-video-reset-probe.log`). Retrieved reports are kept
separately in ignored `output_files/quartus-linux-5wJWPc6b/video-reset-probe/`.
It changes no project assignments or RBF. Native post-map pin inventory/
exception syntax also passes (one inherited netlist warning), log
`/tmp/x1-quartus-67de103-mapped-reset-input.log`; this mapped check does not
perform clock timing.

Independent normalized comparisons confirm unchanged before/after pipeline
setup/hold and downstream release recovery tables. Sixteen corner chain
setup/hold files each contain both real stage-transfer paths (32 total),
minimum setup **+21.474 ns**, hold **+0.249 ns**. Sixteen downstream recovery/
removal files each retain 341 paths (5,456 total), minimum recovery
**+17.661 ns**, removal **+0.549 ns**. No report hits its 10,000-path cap.
The source-bound raw-pin validator passes without D/CLK/Q exceptions.

Global recovery still fails at **−5.379 ns**, from `reset_req` to the inherited
scaler's `ascal|i_reset_na`; global removal minimum is +0.409 ns. This experiment
does not excuse that separate framework reset contract, other crossings,
HDMI routing or full core timing. The source-bound RBF is unchanged.
The [scaler reset audit](SCALER_RESET_TIMING_AUDIT.md) identifies its separate
single-stage release contract and prepares reporting-only three-domain checks.

Remaining acceptance: a fresh fit after experimental project selection,
repeat endpoint/chain/downstream/all-corner audits, and placement/reset
pulse-width/MTBF review. The existing digital phase,
reassertion and stopped-clock tests do not simulate metastability. No new
reset RTL, physical reset qualification or work-group completion is claimed.

| Prepared artifact | SHA-256 |
|---|---|
| Input-only candidate executed in native probe (selection-header update is comment-only) | `cdd73e2db8e3a737780a6845090aeb3ed78b95f2fbeac5df38efebfab494db63` |
| Native probe | `23736d53597872686ecff765c1a23854648fad2f2bd9b7e9414ffd058afa8234` |

## Fresh selected-constraint fit

Source `89f8226e7185083323a99ead89d6cea465898994` full flow finishes zero at
2026-10-09 17:30:42 UTC after 10:05, frozen host folder
`output_files/quartus-linux-GUPIFiKT`. Original reports/RBF are preserved
locally in its `completed-flow/`, supplemental reports separately in
`acceptance/`. RBF SHA-256
`31a422f8e5d198840ac677547352fb0d4949e25c865c5e555fec81076aa845aa`
remains **unqualified**. Input manifest SHA-256
`fa45f8534f9353ef7eda8e8ec725428c339c7468f390a326e69fa71c02d467b4`;
383 input files match, only Quartus-rewritten `sharpx1.qpf` differs.

Sequential native all-corner, inventory, path, snapshot, PCG request/response,
core-reset and scaler-reset checks finish zero, log
`/tmp/x1-quartus-89f8226-all-acceptance.log`. Independent PCG auditor passes
48 request/16 response reports at the actual **nine** CPU captures (bit 0
replicated). Snapshot audit passes 16 files/1,152 rows, each with all 72
retained bits: minimum combined setup/hold +0.589 ns, maximum physical data
13.028 ns. This is payload acceptance, not whole-design CDC qualification.

Core chain audit retains two paths in each of 16 corner setup/hold reports
(32 rows), minimum +0.258 ns. Downstream recovery/removal retains 333 paths
per report (5,328 rows), minimum +0.281 ns. Counts are fresh-fit-specific,
not the previous fit's 341. Redundant before/after candidate application
preserves normalized stage setup/hold and downstream recovery tables.
Endpoint completeness, physical release placement/pulse/MTBF and hardware
acceptance remain open.

Global eight-corner minima: setup **−15.158 ns**, hold +0.059 ns,
recovery **−4.881 ns**, removal +0.281 ns, pulse width +0.529 ns.
Hold now reports positive, but setup/recovery still fail. See the
[scaler audit](SCALER_RESET_TIMING_AUDIT.md) for raw-reset coverage gaps.
No MiSTer is loaded and no full Turbo Z timing claim is made.
