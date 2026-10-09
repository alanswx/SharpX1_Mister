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
