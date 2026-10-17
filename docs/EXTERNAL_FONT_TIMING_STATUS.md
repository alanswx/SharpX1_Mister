# External-font snapshot timing follow-up

October 16, 2026. Local work only; MiSTer remains with the user and is not
accessed. This addresses the dimensions snapshot payload in the separate
`sharpx1_turbo_z_font` qualification revision, not global timing closure.

**Final gate: build PASS, selected payload timing PASS, global timing FAIL,
hardware UNEXECUTED.** The corrected local full flow and its independent
source/assignment/eight-corner audits complete. RBF
`c783fb3ee0c9e0a8ea424b32bb1fa2dc12a7d7aaae34994bab0aaf7a0071a720`
is in `output_files/quartus-O1IV3KIp/source/output_files/`.
Only the font qualification revision selects the new loader. No RTL changes.

| Gate | Final result |
| --- | --- |
| Full flow | Quartus 17.0.0 build 595, terminal zero, 14m08s, 171 stage warnings |
| Source | 429 hashed inputs; only old font QSF changes, one new font SDC |
| Fitted resources | 25,525 ALMs; 37,234 registers; 534/553 M10Ks; 32 DSPs; four PLLs |
| Exact snapshot payload | 72 bits, 1,152 setup/hold rows across eight corners; minimum +20.504/+0.498 ns; maximum data delay 12.876 ns |
| Actual max/min bounds | Every selected row retains relationship 31.25 ns setup / zero hold under the assigned SDC order |
| Global timing | Worst reported setup −15.149 ns, recovery −8.300 ns; global timing fails |
| Other digital checks | Six-ratio snapshot/HPS/measurement gates; 57 cache lease cycles and three runtime mutations; sixteen SDC scope cases pass |
| Hardware | Not executed; MiSTer remains with the user |

## Completed same-fit experiment

Evidence: `output_files/TIMING_FONT_20261016T2302/`. A complete copy of the
previous `quartus-9o5ChatI` fit is used for native Quartus 17.0.0 build 595
analysis. `original-before.json` hashes every file in the original build;
the original RBF/source/database/reports remain untouched.

The original-SDC slow 100 C reports show same-clock SYS/VID setup
**+7.633/+8.507 ns**. Global setup is **−15.031 ns**, from HDMI `d[23]` to
`hdmi_out_d[23]`; recovery is **−8.167 ns**, into video-local reset release.
The new Fast −40 C analysis finds a **−0.120 ns hold failure** on
`dimensions_to_sys.held_data[36]` to `destination_data[36]`. The previous
full flow ran only the slow corner and therefore did not expose this hold
failure. Global top-path reports are reconnaissance, capped at 30 paths.

The dimensions payload already has a separately checked digital handshake
and bounded-path constraint in `sharpx1_turbo_z_video.sdc`. It was selected
by Z revisions, but absent from the external-font QSF. Its exact-bit guard
requires the 72 retained bits 2..73 at both endpoints; it sets maximum
31.25 ns and minimum zero only on those held payload paths. Capture follows
publication by at least two SYS periods (62.5 ns). It cuts no synchronizer,
reset, HDMI or unrelated inter-clock path. See
[the original protocol/constraint evidence](TURBO_Z_SNAPSHOT_TIMING_STATUS.md).

The explicit same-fit probe passes all eight Slow/Fast 1100-mV corners at
−40/0/85/100 C: **1,152 selected setup/hold rows**, minimum setup/hold
**+21.569/+0.280 ns**, maximum physical data delay **11.810 ns**. All 72 bits
remain timed in every report; unrelated global failures stay visible.
Session 83956 is terminal zero, `/tmp/x1-font-snapshot-probe.log`, no warnings.
The independent auditor passes in `probe-audit.json` and its later mode-aware
`probe-audit-v2.json`. The earlier reporter/auditor source copies are preserved.

Fresh `test-cdc-snapshot`, `test-hps-video-cdc` and `test-hps-hdmi-measure`
complete zero (99066, `/tmp/x1-font-snapshot-protocol-v2.log`): six snapshot
clock ratios and actual two-period capture/hold checks, four connected HPS
ratios, live measurement/readout and two runtime bypass rejections.
`protocol-audit.json` checks frozen inputs and all five PASS markers. The
first isolated launch lacked the nested parent output directory and failed
before execution; its log is preserved, not counted as a negative.

Copied-report auditor controls reject a missing row, wrong clock domain and
physical data delay reaching 31.25 ns. These test audit policy, not DUT
behavior. Native cache discovery also resolves all thirteen `held_glyph`
bits to actual `held_descriptor` aliases in the original map report. A
glyph-prefix-only constraint would miss them. Cache publication and its
toggle replica remain separate open CDC work; no cache exception is added.

The new standalone `test_z_kanji_cache_windows.py` also passes three clock
ratios, each with 19 actual publication/commit/ACK/release/completion events.
It observes the complete 50-bit held bundle, two-VID publication and two-SYS
ACK capture windows, the extra ACK retirement edge, stopped SYS/VID recovery,
first-row payload and idle/in-flight invalidations. Three real runtime
mutants reject early commit, early release and unheld payload. Frozen evidence
is `x1-cache-windows-wfkjx07f` in the macOS temporary directory, with
`cache-windows-audit.json` here and `/tmp/x1-font-cache-windows-v4.log`.
Earlier fixture style/initialization and mutant-basename compile failures
remain preserved; none counts as a negative. This adds a digital prerequisite
for future cache bounds, not a physical CDC or whole-machine qualification.

## Source-bound rebuilds

Only `sharpx1_turbo_z_font.qsf` changes among the original 428 compiler inputs:
it selects the existing dimensions SDC. No RTL or SDC bytes change; ordinary,
DMA and other board revisions retain their assignments. Exact before/after
source identities are in `source-change.json`.

First full-flow snapshot `output_files/quartus-ztUzRhR3/`, session 79326,
`/tmp/x1-font-snapshot-quartus.log`, completes zero. Slow setup remains
−14.864 ns. Its separate integrated eight-corner analysis (74148,
`/tmp/x1-font-first-fit-integrated.log`) adds no exception: all 1,152 selected
rows pass, minimum setup/hold +20.368/+0.409 ns, maximum data delay 12.985 ns.
`first-fit-audit.json` independently confirms this. The first RBF/build
identities remain in `first-build.json`; it retains the synthesis warning below.

Warning review finds one added map warning 330000: timing-driven synthesis
could not initialize its netlist. Native synthesis-only diagnostics identify
the exact guard failure: the first quartus_map pass still has all 74 logical
bits, including the two constant interlace bits. Later passes fold these to
the original strict 72-bit inventory. `early-inventory-final.json` checks all
148 actual names and the terminal log. Its earlier interim log prefix remains
byte-exact in `early-inventory-interim.log`; the original discovery manifest
is preserved. An initial diagnostic omitted generated build_id.v and is
retained as an unrelated input failure, not a constraint rejection.

The corrected **font-only** `sharpx1_turbo_z_font.sdc` accepts exactly those
fully named logical bits 0..73 during quartus_map. It retains the same bounded
payload paths without a false-path exception. Once optimization gives 72 bits,
it delegates to the original SDC; **Fitter and STA always require the original
strict bits 2..73**. The original shared SDC is unchanged. No other revision
selects this loader. Sixteen synthetic scope cases pass, including wrong
stage, partial/duplicate/foreign/extra logical bits rejecting before any bound.

Corrected full flow completes zero as session 19144 in
`output_files/quartus-O1IV3KIp/`, `/tmp/x1-font-snapshot-quartus-v2.log`.
Its 429-input manifest adds only this loader and changes only the font QSF
among the old 428 inputs. Native synthesis is terminal successful with the
74-bit profile followed by both observed 72-bit passes. Warning 330000 is
gone: all 159 synthesis warnings and normalized warning identities match
the original build. No warning suppression or RTL change is used.

Isolated project queries preserve all 2,231 effective assignments and the
machine HDL/QIP order. Four isolated PLL-library rows and three unique global
macros move as in the previous tool rewrite. The tool also moves the font
node-payload SDC ahead of the two clock-definition SDCs; their relative order
is retained. Unlike clock/mode constraints, this payload script queries no
clock name, and the inherited clock files have no dimensions endpoint
exception. Final assigned-order native reports confirm all 72 paths remain
timed, with explicit setup relationship 31.25 ns and hold zero at every
corner. Terminal QPF/QSF identities match the isolated query copies.
`retry-assignment-review/final-audit.json` closes this review; SDC ordering
is recorded as changed, rather than incorrectly called identical.

The frozen reporter's `integrated` mode requires exactly one recognized
snapshot SDC assigned, loads assigned constraints normally and adds no
analysis-only exception. Session 90316 completes zero, no warnings, in
`/tmp/x1-font-retry-fit-integrated.log`, reports `retry-fit-integrated/`.
`retry-fit-audit.json` independently qualifies all 1,152 selected rows and
physical delays. Actual Delay Model headers match all eight corners.

The source/build audit `final-build-audit.json` passes, SHA
`c0fe091376102b10dd40f40128fd1481db4355611dd583d7b02ed38d885a8a53`.
The 429-input manifest SHA is
`1d02bc33d1437f687780c77f33f40ddd37c04efa11c365c56fbaa06d6fcb9912`.
`preservation-audit.json` verifies every file in both original and corrected
completed builds remains byte-identical after all supplemental work. Current
compiler input enumeration and frozen source hashes match. The first final
auditor rejected its singular `1 warning` log grammar; its source/log remain
preserved. Correcting that parser changes no timing or source predicate.

Main Slow 100 C setup/hold/recovery/removal are −15.149/+0.194/−8.300/+0.830 ns.
Across eight corners, reported global minima are −15.149/+0.080/−8.300/+0.333 ns.
Global top-path reports remain capped at 30; setup/hold I/O requirements are
incompletely constrained and the tool does not calculate design MTBF while
timing fails. These positive selected payload results are not full CDC signoff.
All jobs are terminal; no hardware access, deployment or native boot was done.

Global setup/recovery, remaining held bundles and synchronizers, HDMI clock
selection, I/O constraints, reset placement/MTBF and hardware remain open.
The completed flow establishes this bounded payload timing gate. Global
timing closure and hardware acceptance remain open. Next local timing work
is the remaining cache publication/synchronizer, reset and HDMI clock paths.
