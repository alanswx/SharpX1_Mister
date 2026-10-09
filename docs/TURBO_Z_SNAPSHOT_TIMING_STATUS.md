# Z video-measurement snapshot: bounded payload timing

October 9, 2026. This addresses one identified held-bus timing contract,
not full Turbo Z timing closure. No RTL behavior or private asset changes.

## Protocol window actually checked

`x1_cdc_snapshot` captures source data and changes acknowledgment together.
The destination observes acknowledgment through two registers and consumes
it on the next edge. Capture therefore follows publication by at least two
destination periods. Its new request must similarly traverse two source
registers before a later publication can overwrite `held_data`; the bundle
remains held for at least two source periods after capture. Clock stops
extend these windows rather than bypassing ownership.

The strengthened `test-cdc-snapshot` measures actual ACK/request transitions
and asserts these two windows, alongside independent counter/complement
coherence, monotonicity and both stopped-clock recoveries. It finishes zero
at six ratios, including fractional SYS/X3 and X3/SYS phases
(`/tmp/x1-z-snapshot-window.log`). Fixture SHA-256
`a42c0130dee0a0105dc29ab5360f5dd69f3245b5f78f3fd126b81ff44e9c269a`;
unchanged RTL `ee31d3edbe7446b96e727c6ca0dbe9cc9dfab41bc6954b675628ccab7cbb85e5`.
This is a digital protocol check, not metastability or placement qualification.

## Exact fitted endpoint scope

The source-bound `c05edb0` fit has a logical 74-bit
`video_calc.coherent_measurements.dimensions_to_sys` payload. A first probe
refuses the unexpected 72/72 endpoint counts before applying constraints;
inventory then confirms only bits 0/1 missing from both banks. They are the
two `vid_int` bits, fed by `f1` from `sharpx1.sv`'s constant `VGA_F1=0`.
The inventory is preserved in `/tmp/x1-quartus-c05edb0-z-snapshot-inventory.log`.
The new SDC requires exactly one retained register for each bit 2..73 on
both sides; any other optimized/partial/duplicate bit set fails closed.

`sharpx1_turbo_z_video.sdc` is selected **only** by the experimental combined
Z QSF. All other board revisions and simulation profiles remain unchanged.
The fixed bound assumes this revision's 32 MHz SYS clock (31.25 ns), not a
generic single-clock or future faster-CPU profile. It applies a one-SYS-period
maximum and zero minimum specifically from this bundle's `held_data` to its
`destination_data`, never between entire clock domains. The two-period SYS
capture window is 62.5 ns; X3's post-capture hold window is about 46.561 ns.

Quartus 17 [maximum](https://resources.altera.com/quartushelp/17.0/tafs/tafs/tcl_pkg_sdc_ver_1.5_cmd_set_max_delay.htm)
and [minimum](https://resources.altera.com/quartushelp/17.0/tafs/tafs/tcl_pkg_sdc_ver_1.5_cmd_set_min_delay.htm)
delay exceptions retain clock latency/skew. Therefore constraint slack alone
does not establish the physical payload-delay bound; full data-delay tables
are checked separately. No first-stage synchronizer, other held bus, reset,
HDMI or arbitrary inter-domain path is exempted.

## Executed native STA experiment, not a new RBF

`scripts/quartus_snapshot_bundle_probe.tcl` runs on the completed unchanged
fit, before and after loading the exact candidate SDC, then repeats all eight
Slow/Fast 1100 mV corners at −40/0/85/100 C. Exact-SDC invocation finishes
zero, no warnings (`/tmp/x1-quartus-c05edb0-z-snapshot-exact-sdc.log`).
Initial inline experiment also finishes zero and supplies independent
72-path-per-corner data tables under ignored
`output_files/quartus-linux-nyZrupn1/snapshot-eight-corners/`.

At Fast −40 C, the selected bus changes from −0.143 ns hold / −4.813 ns setup
to +0.257 ns hold / +26.067 ns setup. Every retained bit remains analyzed,
not false-pathed: 72 setup and 72 hold paths in each of eight corners. Across
the inline eight-corner reports, minimum selected setup/hold are
+21.565/+0.257 ns and maximum reported data delay is **11.800 ns**.
This is well below both the stricter 31.25 ns candidate bound and the
62.5 ns measured digital capture window. Unrelated global setup failures
remain visible. The original RBF's constraints are unchanged by the probe.

| Candidate artifact | SHA-256 |
|---|---|
| Narrow SDC | `2111e65f718c00bd56720ae886fa37d06305f2b793ea9a8e7f6809d8c9ce97af` |
| Exact-SDC probe | `203be4ac53f5507e5475ea7617aaf453eda35c374c1c27a2ad3b8e3c7c2b8b0a` |

## Remaining acceptance

The candidate is connected to the experimental QSF. Its fresh source-bound
full flow and supplemental all-corner analysis now complete on `misterubuntu`, source
`32a3210362ad8dfada8798a405a8f48f1e7a4ca8`, isolated folder
`/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-EDi2XntO`;
after clean-checkout and host-idle checks.
Log `/tmp/x1-quartus-32a3210-z-bundle-build.log`.
The full flow now finishes zero at 15:58:23 UTC after 8:24, with the new SDC
actually read during fitting and no endpoint-count error. Initial setup still
fails (−15.053 ns); all-corner/path/payload audits finish zero, but no new
timing-qualified RBF claim is made. Initial reports and RBF are preserved in
`output_files/quartus-linux-EDi2XntO/completed-flow/`. RBF SHA-256
`80328ef67899df477a97f09a97770e23e2abcd84c54a34932bf8cce9f642b4d9`;
it remains **unqualified**. Supplemental log
`/tmp/x1-quartus-32a3210-z-bundle-acceptance.log`.
Retrieved supplemental reports are kept separately in
`output_files/quartus-linux-EDi2XntO/acceptance/`. Independent table audit
confirms 16 selected corner files, each with 72 paths (1,152 total): minimum
selected setup **+20.244 ns**, hold **+0.642 ns**, maximum physical data delay
**13.119 ns**. Both before/after probe reports already include the integrated
SDC; they are not an unconstrained comparison. The post-flow input audit has
380 matching files and only Quartus's rewritten `sharpx1.qpf` mismatching.

The full eight-corner design still fails: global minimum setup **−15.053 ns**,
hold **−1.047 ns**, recovery **−9.402 ns**. Removal/pulse minima are
+0.462/+0.529 ns. Slow 100 C same-clock setup remains SYS +6.625 ns,
VID +7.656 ns and HDMI **−2.380 ns**. Therefore the dimensions bundle gate
passes on this fit, not the remaining clock crossings or real HDMI routing.
The exact-SDC prior-fit report audit
independently confirms 16 corner files, 72 nonnegative paths each and maximum
11.800 ns payload data delay; copied reports are retained separately under
`output_files/quartus-linux-nyZrupn1/snapshot-exact-sdc/`.
Other snapshot/PCG bundles, first-stage synchronizers, reset release,
clock-mux/data selection, HDMI routing and unconstrained I/O remain open.
No FPGA hardware, native software or full work-group completion is claimed.
