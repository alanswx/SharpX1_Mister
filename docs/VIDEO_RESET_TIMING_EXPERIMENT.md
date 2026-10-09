# Video reset input timing experiment — not qualified

October 9, 2026. The source-bound Z fit's recovery failures include raw reset
sources into two `x1_reset_release` pipelines. Their downstream outputs release
after two local clock edges. These are different timing contracts: excluding
all paths to/from reset registers would also hide ordinary stage transfer and
synchronous downstream recovery, and is not proposed here.

`scripts/constraints/video_reset_input_candidate.sdc` is **analysis-only**, not
selected by any QSF. It checks precisely four pins: `release_pipe[0/1]|clrn`
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

`scripts/quartus_video_reset_probe.tcl` is prepared but **not yet executed**.
It is intended for a completed, idle experimental Z fit and will preserve
before/after D-chain setup/hold and output recovery reports, then repeat
chain, output recovery/removal and global recovery/removal at eight corners.
It changes no project assignments or RBF. Do not run it concurrently with
the live refit or describe these planned reports as passing evidence.

Required acceptance: native exact pin inventory; unchanged before/after chain
and release-output tables; every stage/downstream path still timed; all-corner
placement and reset pulse-width/MTBF review. The existing digital phase,
reassertion and stopped-clock tests do not simulate metastability. No new
reset RTL, physical reset qualification or work-group completion is claimed.

| Prepared artifact | SHA-256 |
|---|---|
| Input-only candidate | `cdd73e2db8e3a737780a6845090aeb3ed78b95f2fbeac5df38efebfab494db63` |
| Native probe | `23736d53597872686ecff765c1a23854648fad2f2bd9b7e9414ffd058afa8234` |
