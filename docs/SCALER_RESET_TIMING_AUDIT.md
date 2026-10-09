# Inherited scaler reset timing — acceptance open

October 9, 2026. Source inspection following the completed `67de103` reset
probe distinguishes the scaler from the core's two-stage release pipelines.
The measured remaining global recovery minimum is **−5.379 ns** at Slow
−40 C, `reset_req` → `ascal:ascal|i_reset_na`. This is not covered by the
experimental core's four-pin input exception.

`sys/sys_top.v` produces `reset_req` on `FPGA_CLK2_50` and supplies its inverse
to `ascal.reset_na`. `sys/ascal.vhd` lines 1112–1114 asynchronously assert,
then release each of `i_reset_na`, `o_reset_na`, and `avl_reset_na` on the
**first** rising edge of its respective clock. These are single registers,
not a two-stage synchronizer. Their outputs drive asynchronous resets in
input-video, HDMI-output and Avalon processes. The input video clock is
selectable; it must not be assumed to be the 50 MHz reset source clock.

The existing core protocol proof therefore cannot justify cutting these
three scaler input paths. No scaler RTL or timing exception is changed by
this audit, and no metastability or physical reset qualification is claimed.

Prepared reporting-only tool: `scripts/quartus_scaler_reset_paths.tcl`.
It requires exactly the three named scaler release registers and one raw
reset register, reads the project's actual SDC, and reports raw-input and
downstream-output recovery/removal separately at all eight corners. It adds
no exceptions. Native execution and endpoint/path coverage remain pending;
empty reports must not be treated as positive timing evidence. Preserve
original full-flow artifacts before supplemental STA, and do not run it
alongside an active fitter.

`make -C verilator test-scaler-reset-paths` passes the mocked orchestration:
96 unique input/output recovery/removal reports across three domains and all
eight operating conditions, plus seven rejected inventories/profiles.
Mocked exception commands fail the test if the reporting tool adds a cut or
delay bound. The target is selected in CI. These checks do not execute native
Quartus or establish physical timing.

Next acceptance: execute the reporting tool on an idle fitted database;
inventory every input and downstream reset path, including clock selection;
then qualify a destination-local multi-stage release proposal separately
with assertion, near-edge deassertion, reassertion and stopped-clock tests.
Any necessary inherited-framework change must preserve ordinary revisions
and address all three scaler domains, not simply hide the reported failure.
Fresh fit, all-corner checks, reset pulse/placement/MTBF review and physical
video/memory/reset acceptance remain required.

## Native fresh-fit observation

The reporting tool finishes zero on the preserved `89f8226` fit under native
Quartus 17.0.2 at 17:34:41 UTC, no new exceptions. All three expected register
identities match. Local reports are in
`output_files/quartus-linux-GUPIFiKT/acceptance/`; execution log
`/tmp/x1-quartus-89f8226-all-acceptance.log`.

All 96 files exist, but only **64 contain timing paths** (384 total rows).
Input-video raw recovery/removal has one path each per corner; downstream
input/output/Avalon recovery/removal has 2/14/7 paths respectively per
corner. Input-video raw recovery minimum is **−4.881 ns** at Slow −40 C.
The other 32 reports, HDMI/Avalon raw-input recovery/removal, say
`Nothing to report.` These are not positive timing evidence.

`sys/sys_top.sdc` puts `FPGA_CLK2_50`, HDMI PLL and HPS user clock in separate
exclusive groups, explaining why those raw crossings are not reported;
the experimental video PLL is absent from that inherited group pattern.
Changing the reset RTL alone will not validate the already-excluded raw
crossings. Next: inventory physical asynchronous reset pins and review those
specific clock-group effects without pretending that the three single-stage
releases have the core's two-stage contract. Physical reset qualification and
any framework correction remain open.

## Experimental destination-local release increment

`rtl/x1_scaler_reset_release.vhd` adds asynchronous active-low assertion and
two rising edges to release, with preserved stage registers. The scaler's
new `LOCAL_RESET_RELEASE` generic defaults false; its false branch retains
the original three one-edge assignments. Only `X1_TURBO_Z_VIDEO_EXPERIMENT`
in `sys/sys_top.v` selects true. The input-video, HDMI-output and Avalon
domains each instantiate their own pipeline directly from raw reset, never
from another domain's released output. The helper is a board-only VHDL
dependency in `files.qip`, not part of the shared Verilator machine list.

This narrow inherited-framework edit is needed because raw reset enters the
scaler internally; synchronizing only the wrapper's single input would still
release the other two domains from the wrong clock. No new timing exception
is added and existing clock-group coverage gaps remain unresolved.

`make -C verilator test-scaler-reset-release` analyzes the actual modified
scaler with GHDL 5.1.1 (inherited name-hiding warnings), then tests the actual
release entity at half-periods 11,640/3,366/10,000/15,625 ps. Near-edge
deassertion, short assertion, repeated between-stage reassertion and stopped
clock checks pass. Each run must emit its PASS marker; a simulator time limit
alone cannot pass. The inherited one-edge negative control fails with the
expected early-release assertion. Outputs stay in ignored build directories.
CI selects the target and installs GHDL. Wrapper ordinary/Z lint passes,
but it does not elaborate the VHDL scaler or `sys_top`.

Fresh native compilation, six-stage/pin inventory, all-corner chain/downstream
timing, excluded raw-input review and physical video/Avalon/reset acceptance
remain required. The old reporting tool intentionally requires the inherited
three-register profile and must not be used to claim coverage of these new
pipelines. No corrected timing or hardware behavior is claimed yet.

The subsequent `test-scaler-reset-domains` passes three concurrent clocks,
rotating the stopped domain through input/HDMI/Avalon while the others keep
running. It checks local edge counts and independent restarts using the actual
helper. A deliberately coupled release negative control fails. This tests the
three-helper topology, not the complete scaler datapath or physical CDC.
Native Quartus source elaboration in the `8d94709` fresh flow also recognizes
the VHDL helper inside `ascal`; fitting and timing remain pending.

`scripts/quartus_scaler_release_paths.tcl` prepares reporting-only all-corner
stage setup/hold, raw-input recovery/removal and downstream recovery/removal
for the new topology. It requires two distinct stages per domain and refuses
unknown replicas. Native named-stage collection lookup and actual endpoint
coverage remain pending. No added exceptions; inherited raw-input clock-group
cuts must be reviewed separately, not called passes from empty reports.
`test-scaler-release-paths` passes mocked six-stage endpoint selection and all
144 expected report scopes, with eight rejected inventories/profiles. It is
selected in CI. These mocks do not prove native register matching or timing.

## First destination-local fit: fitted, final STA rejected

The `8d947090ffcec0a6397bc85b6fe83f274f613cc8` flow fits and assembles,
then finishes **exit 3** at 17:51:02 UTC (8:29 elapsed): final STA rejects the
PCG request control inventory, not the scaler's VHDL compilation. Frozen host
folder `output_files/quartus-linux-eoHwZeyI`; original reports, manifest and
generated RBF are preserved locally under `completed-fitter/` before probes.
RBF SHA-256 `1014088699325fdf0037e0357c1a22209739094100398f63174fddd549ec6f50`
is **unqualified**. Input audit finds 384 matching files, only rewritten QPF
differs. Log `/tmp/x1-quartus-8d94709-scaler-reset-build.log`.

Idle-fit reconnaissance without SDC loading confirms exactly **six scaler
release registers and six asynchronous CLRN input pins**, two stages for
input/output/Avalon. Native hierarchy uses escaped generated instance names,
for example `x1_scaler_reset_release:\x1_domain_reset:input_release`.
The reporting-only `quartus_scaler_release_inventory.tcl` finishes zero,
no warnings; no clocks, timing or exceptions are evaluated.

PCG retains the three primary `stage.00/.01/.10` registers without the optional
`.01~DUPLICATE` present in prior fits. The revised request guard accepts either
exact fitted inventory (35/36 control destinations), preserving all existing
RAM plane/bit/source validations and rejecting unknown or repeated aliases.
Mapped inventory still refuses replicas. Three-profile mocks pass 84 negative
controls. Native syntax/inventory check on this fit passes the revised
35-destination candidate, log
`/tmp/x1-quartus-8d94709-stage-syntax-inventory.log`; it does not load clocks
or establish physical timing. Original fitted inputs/RBF remain untouched.

Next: fresh full flow with the corrected guard, all-corner PCG/scaler stage
and downstream audits, plus explicit raw-input coverage review. The PCG
report auditor's old replica-specific profile needs matching native reports
before qualification of this new unreplicated representation. No work-group,
native-software or hardware acceptance is claimed from the failed final STA.

## Corrected full flow and native stage timing

Source `ed3c332` completes zero at 18:05:04 UTC after 8:27, frozen folder
`output_files/quartus-linux-HMU7HdXp`. Original reports/RBF are local under
`completed-flow/`, supplemental reports under `acceptance/`. RBF SHA-256
`1014088699325fdf0037e0357c1a22209739094100398f63174fddd549ec6f50`
is unchanged from the earlier fitted-only run and remains **unqualified**.
Input manifest SHA-256
`92d91f7af57e95f838fcd6584f4965a82347e216d71ce5f409c6caf15a0fca38`;
384 inputs match, only Quartus-written QPF differs.

Sequential native all-corner, inventories, path, snapshot, PCG, new scaler
release and analysis-only mux probes finish zero, last at 18:09:28 UTC, log
`/tmp/x1-quartus-ed3c332-native-acceptance.log`. Native scaler stage lookup
resolves all six named collections uniquely. Independent all-corner chain
audit passes 48 files/48 paths: stage 0 → 1, same clock, minimum combined
setup/hold **+0.249 ns**. Downstream audit passes 48 files/384 paths, all from
stage 1, minimum combined recovery/removal **+0.261 ns**. Input/HDMI/Avalon
downstream counts are 2/14/8 per report; no report reaches its 10,000-path cap.
This qualifies reported digital stage/downstream paths, not MTBF or physical
reset behavior.

Raw input-video recovery still fails, minimum **−4.835 ns** (both stages).
HDMI/Avalon raw input reports remain empty due inherited clock groups, not
passes. Global eight-corner minima: setup **−15.064 ns**, hold **−0.033 ns**,
recovery **−4.835 ns**, removal +0.261 ns, pulse width +0.529 ns.
Only the existing four core reset input pins are excepted; no new scaler
raw-pin exceptions have been added. Next: separately probe precisely those
six raw pins while retaining all chain/downstream checks and reviewing
physical placement/pulse/MTBF, plus the remaining mux/HDMI/CDC/I/O gates.

## Six raw-input pin probe and experimental selection

`scaler_reset_input_candidate.sdc` matches exactly six named primary CLRN
pins in the three two-stage scaler release instances. It never targets
whole registers, D/CLK/Q or output fanout; legacy one-stage, unknown instance/
bit/replica and missing/duplicate pins refuse all cuts. The mocked scope
test rejects 11 invalid inventories. The optional release probe checks all
320 expected before/after reports, applying the cut only after the baseline.
Both targets are selected in CI. Four-rate/three-concurrent-domain helper
checks and failing early/coupled controls also pass again.

The exact probe finishes zero, no warnings, on the preserved `ed3c332` fit at
18:16:26 UTC; log `/tmp/x1-quartus-ed3c332-scaler-raw-pin-probe.log`. Separate
local reports: `output_files/quartus-linux-HMU7HdXp/scaler-raw-pin-probe/`.
Independent normalized comparisons pass **96** before/after pairs: all 48
stage setup/hold reports and 48 downstream recovery/removal reports are
unchanged. The existing +0.249/+0.261 ns minima and stage/downstream endpoint
coverage remain visible. All 48 after raw-input reports are empty by the
explicit pin cut, not considered physical reset passes.

Eight after global recovery reports retain 800 worst-path rows, minimum
**+4.280 ns**; global removal minimum +0.261 ns. Before raw input reports
retain 32 rows, minimum −4.835 ns. Global constrained recovery is positive in
this experiment; excluded/unconstrained input and physical reset acceptance
remain separate. No placement/pulse/MTBF or actual reset-mode-switching proof.
Native post-map six-pin syntax also finishes zero (one inherited netlist
warning), log `/tmp/x1-quartus-ed3c332-scaler-raw-mapped.log`; no clock timing
is performed by that inventory check.

Executed candidate SHA-256
`997d7d32c8fbf78ee2315b14c7f302e46b726444a70258ae42c88abb5b485b2d`,
probe `fc236f084d7cb9182ba25dd7cc36cf6864da98e037ab3aa5e12e31f3cc345197`.
The candidate is now selected only by experimental Z, pending fresh fit;
its selection-header change is comment-only. No RTL or RBF changed in this
probe. The independently scoped mux alias candidate is also selected for
that new fit; ordinary revisions keep their previous constraints. Repeat
all-corner endpoint/chain/downstream/payload/crossing checks and I/O review.
Setup/hold, other CDC and physical/native gates remain open.

The selected `6133f27` refit now completes zero. Native inventory retains
six stages and six input pins; 48 stage-transfer paths pass all corners,
minimum combined setup/hold +0.208 ns. Downstream counts change with fitting
to 1/14/8 for input/HDMI/Avalon (48 files/368 rows), all from stage 1 with
minimum recovery/removal +0.386 ns. Global recovery minimum is +4.375 ns;
global setup/hold still fail. Raw input reports are excepted, not physical
passes. Source/artifact identities, alias-aware failures and remaining gates
are in the [selected-refit evidence](TURBO_Z_BOARD_BUILD_STATUS.md#selected-resetmux-refit-and-real-remaining-crossings).
