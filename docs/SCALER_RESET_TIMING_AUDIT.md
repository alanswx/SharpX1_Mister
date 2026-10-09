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

Next acceptance: execute the reporting tool on an idle fitted database;
inventory every input and downstream reset path, including clock selection;
then qualify a destination-local multi-stage release proposal separately
with assertion, near-edge deassertion, reassertion and stopped-clock tests.
Any necessary inherited-framework change must preserve ordinary revisions
and address all three scaler domains, not simply hide the reported failure.
Fresh fit, all-corner checks, reset pulse/placement/MTBF review and physical
video/memory/reset acceptance remain required.
