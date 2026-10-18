# Sharp X1 development handoff

## October 18, 2026 — single-clock X3 master (latest)

Later October 18: merged D88/raw-2D mount by extension
(`docs/RAW_2D_DISK_STATUS.md`): simulation, full regressions, board timing and
MiSTer 192 OSD/MGL boots pass. `sharpx1_turbo_z_video_single` closes timing
(RBF `61c1526d…`), with no hardware run yet. misterubuntu builds may run
concurrently with other projects when the user says so; use
`X1_ALLOW_CONCURRENT_QUARTUS=1`.

User decision: move X3 off two unrelated clocks onto one 42.95 MHz master
with enables. See `docs/X3_SINGLE_CLOCK_STATUS.md`. Revision
`sharpx1_turbo_z_font_single` (commit `97bf6d2` plus docs/test follow-up)
has **zero failing timing paths at all eight corners**; RBF `242e0bea…`.
On user-authorized **MiSTer 192** only (not 14 or 126), the 80/40-column
font diagnostics match their oracles exactly, and Galaga boots from D88 and
starts Stage 1. 192 was returned to MENU. Hardware availability is granted per
session; ask again before using it.

This supersedes the two-clock "Next/Then" timing items (scaler reset/size,
cache publication, HDMI mux) for this revision: those crossings are now
same-clock or follow stock MiSTer clock groups. The two-clock revisions and
their evidence are unchanged. Open: I/O constraints, physical reset/MTBF,
moving `sharpx1_turbo_z_video` to the single master, then the broader
priorities (fonts, Turbo/Z modes, IRQ/RTC coexistence, dual drive/2HD,
including the user's merged D88/2D-by-extension mount).
The black-box comparison with the closed-source core is in
`docs/OTHER_X1_CORE_COMPARISON.md`.

## Restart here — October 17, 2026

This entry is the starting point for a new LLM/Codex session. The user asked
to save a handoff before restarting. This handoff update starts no build,
simulation or hardware work. All preceding task jobs are terminal.

Suggested new-session prompt:

> Read AGENTS.md and docs/DEVELOPMENT_HANDOFF.md in
> /Users/alans/dev2/SharpX1_Mister, then continue the local TODO from scaler
> reset release. Preserve the dirty workspace and frozen evidence. MiSTer
> is unavailable; do not access it until I explicitly make it available.

### Read and preserve

1. Read root `AGENTS.md`, `Readme.md`, then the remaining priorities at the
   top of `docs/SHARP_X1_TODO.md`.
2. Read `docs/EXTERNAL_FONT_RESET_TIMING_STATUS.md` for the latest completed
   build and `docs/SCALER_RESET_TIMING_AUDIT.md` for the next implementation
   seam. Dated sections below preserve detailed prior evidence and limits.
3. Inspect `git status --short`. As of `d26ce1f` (October 17) all earlier
   dirty/untracked work is committed and pushed to `alanswx/master`. Do not
   reset/clean/stash away later work as routine startup.
4. The 13 stale tracked `verilator/obj_dir/` files were deleted by user
   decision and committed in `d26ce1f`; do not re-add them. Use unique
   ignored output directories for new builds.
5. Preserve ignored `output_files/`, private media, local snapshots, frozen
   runners/oracles and rejecting attempts. Do not convert snapshot formats,
   normalize saved states or modify an oracle to accept the wrong profile.

Restart support artifacts are in
`output_files/HANDOFF_20261017T133130Z/`: `restart-state.json`,
`git-status.txt`, twenty copied terminal logs under `terminal-logs/`, and the
fifteen-case frozen reset-SDC scope test under `reset-sdc-scope/`. This is
supporting evidence, **not a source-tree backup**. The original qualified
evidence directories remain unchanged. `/tmp` paths below are historical;
use the persistent copies if the originals disappear.

### Current checkpoint

- Latest revision: **`sharpx1_turbo_z_font`**, a separate default-off
  external-font qualification profile. FPGA top `sys_top`; machine
  `rtl/sharpx1.v`, also instantiated by `verilator/sim.v` (sim top `top`).
  Shared dependencies belong in `rtl/machine.qip`; keep board-only files
  separate. Ordinary/DMA/other experimental profiles are not enabled by
  this checkpoint.
- Latest full flow: `output_files/quartus-tIvlttNZ/`, Quartus 17.0.0 build
  595, terminal zero, 13m08s, 171 stage warnings. Resources: 25,442 ALMs,
  37,179 registers, 534/553 M10Ks, 32 DSPs/four PLLs. SYS 32 MHz / fitted
  X3 VID about 42.954545 MHz; these are tool-derived, not physical clock
  measurements. Generated `build_id.v` records UTC October 17.
- RBF: `output_files/quartus-tIvlttNZ/source/output_files/sharpx1_turbo_z_font.rbf`,
  SHA `b570e529302c20dbf06858533c318c37c9b12997270398090c502f416f38384c`.
  The latest RBF is **not hardware-tested**.
- Latest evidence: `output_files/TIMING_FONT_RESET_20261017T020358Z/`.
  `final-build-audit.json` passes, SHA
  `4116fbe37a304871383751734582dc50bf27b4b1113318c7cc56544d6cc10884`;
  `final-checks.json` records the final source/preservation/whitespace checks.
- Scoped timing passes all eight corners: reset chain, released-reset
  recovery/removal, all 487 native release fanouts via the data/recovery
  endpoint union, and all 72 dimensions bits / 1,152 payload rows.
  Source/assignment/report hashes are bound independently.
- **Global timing still FAILS:** eight-corner minima setup **−15.124 ns**,
  hold **−2.988 ns**, recovery **−4.852 ns**. The hold failure is new in
  this fit; do not call it a global improvement. Scaler input-size/downscale
  logic crosses into HDMI output-size registers, and some HDMI output data
  paths also fail hold. Remaining recovery is raw scaler reset. I/O timing,
  physical reset pulse/placement/MTBF and global CDC acceptance remain open.
- Latest change is constraint-only: the font QSF selects a new exact-two-pin
  reset SDC. No machine RTL was edited during that timing step. Earlier
  dirty RTL contains important completed work and must be preserved.

### Next concrete task: scaler reset release

The font profile still selects inherited single-edge scaler reset release.
`sys/ascal.vhd` has an existing `LOCAL_RESET_RELEASE` generic (default false)
and three two-stage instances of `rtl/x1_scaler_reset_release.vhd`, one each
for input-video, HDMI-output and Avalon. `sys/sys_top.v` currently enables
that generic only under `X1_TURBO_Z_VIDEO_EXPERIMENT`.

1. Inspect the existing helper, generic mapping and prior scaler report
   tools/tests before choosing a narrowly scoped font-profile opt-in.
   **Do not enable the Z-video experiment wholesale**: it changes other
   video behavior and conflicts with the external-font profile.
2. Preserve ordinary profile defaults. Explain the narrow framework edit
   if one is needed: the scaler owns its three clock-domain releases, so
   synchronizing only its single wrapper input cannot release all three
   domains correctly. Use actual destination clocks independently.
3. Reuse/adapt meaningful checks: `test-scaler-reset-release`,
   `test-scaler-reset-domains`, and the relevant native inventory/chain/
   downstream reporting under `scripts/quartus_scaler_*`. Earlier tools
   intentionally require specific revisions and native names; do not pass
   this font fit to an incompatible old collector and claim coverage.
4. Obtain fresh fitted six-stage/six-pin inventories before considering
   `scripts/constraints/scaler_reset_input_candidate.sdc`. It is for the
   **two-stage** topology and cannot justify cutting the current one-stage
   releases. Retain stage transfer, data fanout and downstream recovery.
5. Build a new hashed source snapshot, audit actual assigned SDC ordering
   and all eight corners. Use a copy of a completed idle fit for probes;
   do not mutate completed evidence or run supplemental STA on a live fit.
   Preserve failed attempts; a timeout is not a reason to restart unchanged.

After scaler reset: qualify scaler size CDC, cache publication and HDMI
clock switching, then remaining I/O/physical gates. A source comment saying
`<ASYNC>` is not a stable-bundle proof. Do not add broad clock-group cuts.
Cache window prerequisites already pass 57 leases plus three runtime
mutants, but fitted aliases and a physical request-toggle duplicate require
exact inventory; a `held_glyph` prefix misses thirteen merged descriptor
aliases. See `EXTERNAL_FONT_TIMING_STATUS.md` before starting cache bounds.

### Local tooling and earlier functional work

Installed local Quartus is under
`/Users/alans/dev2/apple-containers-example/build/quartus/intelFPGA_lite`.
The existing Apple-container amd64 image is
`docker.io/library/quartus17-runtime:apple-amd64`. Do not install or download
another toolchain/image as routine startup. Container access may require
the sandbox's normal escalation. The last container check showed only an
unrelated `buildkit` service; leave it alone. No task container was active.

After a justified source change, the existing build entry point is:

```sh
QUARTUS_REVISION=sharpx1_turbo_z_font QUARTUS_CPUS=8 QUARTUS_MEMORY=16g bash scripts/build_quartus.sh
```

Use a fresh log name when redirecting. The script captures dirty/untracked
compiler inputs and creates a unique `output_files/quartus-*` source tree,
manifests and reports. It uses map1/fit8. Do not rebuild merely to recreate
the completed checkpoint; source-bound evidence is already saved. Native
`.fit.rpt` can contain Latin-1 degree symbols, so use Latin-1 for reading
that text and raw bytes for hashes. A successful Quartus flow alone does
not establish timing closure.

The user-authorized sibling `../common_source_code` has a working macOS
headless X1/Turbo/Z CLI, revision 4, including explicit writable **new disk
copies**; defaults preserve originals. Only its previously modified CLI/
guide files were in that authorized scope; preserve unrelated changes.
See `CSP_MAC_REFERENCE_STATUS.md`, `BASIC_SAVE_LOAD_REFERENCE_STATUS.md`
and `BASIC_COLOR_REFERENCE_STATUS.md`. Native SAVE/NEW/LOAD/LIST/RUN and all
eight PSET colors/PRESET pass bounded local reference gates. New color cases
still need RTL comparison; SAVE/LOAD and new colors need hardware acceptance.
Earlier MiSTer checkpoints cover bounded games/BASIC/reset/graphics, not
this newest timing RBF or full X1/Turbo Z compatibility.

Reuse local MAME at `../FM-7_MiSTer_alanswx/refs/mame`; do not clone another
checkout. `../SharpMZ_MiSTer/verilator/` is a read-only design reference.
Broader remaining work is in `SHARP_X1_TODO.md`: native fonts and wider
video/text modes, IRQ/RTC/device coexistence, dual-drive/2HD/disk boundaries,
software/tape/audio coverage and release provenance. Private ROMs, games,
disk copies and states must not be bundled or committed.

## MiSTer availability: user has taken it back

The user explicitly requested MiSTer back during the October 16 SAVE/LOAD
follow-up. No hardware job was running and this turn had only read status;
no core load, reset, key input or media staging was performed. Do not access
or control MiSTer again until the user makes it available. Continue local
reference/RTL work. Earlier ownership checkpoints below are historical and
do not authorize taking the device back.

## October 16 video reset timing (complete bounded local gate)

MiSTer is untouched and unavailable. No RTL edits. New report:
`EXTERNAL_FONT_RESET_TIMING_STATUS.md`; evidence
`output_files/TIMING_FONT_RESET_20261017T020358Z/`.
Native same-fit probe 16398 is terminal zero/no warnings,
`/tmp/x1-font-reset-probe-v2.log`. Exactly two raw CLRN inputs are excluded;
one chain and 147 asynchronous downstream paths per check/corner remain
identical before/after across eight corners (2,368 retained rows).
Minima setup/hold +21.618/+0.328 ns, recovery/removal +17.818/+0.414 ns.
Global recovery remains −4.864 ns in the scaler; setup remains −15.149 ns.
`probe-audit.json` passes, plus seven fresh digital rates, two actual runtime
RTL mutants, fifteen SDC scope cases and five copied-report audit controls.
The first probe fails on unsupported `get_fanouts -synch`, is preserved and
is not accepted as a negative. All digital/control jobs are terminal.

**Full flow 93032 is terminal zero:** `output_files/quartus-tIvlttNZ/`,
`/tmp/x1-font-reset-quartus.log`, local installed Quartus 17.0.0 build 595,
8 CPUs/16 GiB, map1/fit8. Only the font QSF selects new
`sharpx1_turbo_z_font_reset.sdc`; 430 compiler inputs. Generated build date
is now UTC October 17. Full flow takes 13m08s, 171 stage warnings;
25,442 ALMs/37,179 registers/534 M10Ks. RBF SHA
`b570e529302c20dbf06858533c318c37c9b12997270398090c502f416f38384c`.
Main setup/hold/recovery/removal: −15.124/−2.988/−4.846/+0.705 ns.
**Global timing remains FAIL.** Eight-corner setup/hold/recovery/removal
minima are −15.124/−2.988/−4.852/+0.259 ns. The new hold failures are VID
scaler input-size/downscale to HDMI output-size captures, plus HDMI data
outputs in some corners. `global-timing-discovery.json` records exact native
rows and the unchanged scaler source. Its `<ASYNC>` comments are not a
qualified stable-payload contract; no cut is added. Do not describe this
new fit as a global improvement. Hardware is unexecuted.
Map/fitter warning identity reviews pass. The old and new completed trees
are hashed in `baseline-build.json` / `completed-build-before.json`.

Reports 68175 and assignment query 29460 are **terminal zero**. The three
frozen reporters run sequentially on `fresh-fit-work/`, using assigned SDCs
only and returning zero/no warnings. Logs `fit-reset.log`, `fit-snapshot.log`,
`fit-data.log` are copied byte-exact to `/tmp/x1-font-reset-fit-{reset,
snapshot,data}.log`; outer `/tmp/x1-font-reset-fit-all.log`.

`reset-fit-audit.json` passes: eight corners, one chain and **144** downstream
asynchronous paths per check/corner (2,320 retained rows). Minima chain
setup/hold +21.722/+0.232 ns; recovery/removal +16.713/+0.259 ns. Both raw
inputs are excluded, not called physical timing passes. First stage still
feeds only second stage. `release-data-audit.json` passes 8,272 synchronous
data rows / 413 targets, minimum setup/hold +13.030/+0.568 ns. The union of
413 data and 144 asynchronous targets covers all **487** native second-stage
register fanouts, with 70 overlaps and no unclassified endpoint. This is
register endpoint coverage under assigned constraints, not every-pin CDC or
physical reset acceptance. Do not reuse the old fit's 496/147 counts.

`snapshot-fit-audit.json` passes 1,152 rows / all 72 bits at eight corners:
setup/hold +20.128/+0.517 ns, maximum physical data delay 13.215 ns. Actual
relationships remain exactly 31.25/0 ns. Assignment audit passes all 2,232
effective values, machine HDL/QIP order except four isolated PLL-library
rows and three unchanged macros. Font node-only SDCs move before base clock
files; base clock order is preserved. The first assignment auditor omitted
the `sys/sys_top.sdc` QIP ownership tag in its exact-row expectation. Its
source/log are retained; v2 restores that exact tag and all predicates pass.

`final_build_audit.py` passes in `final-build-audit.json`, SHA
`4116fbe37a304871383751734582dc50bf27b4b1113318c7cc56544d6cc10884`.
It binds compiler inputs, native reports, selected scripts, assignments and
unchanged original/new completed build trees. Its v1 rejects the isolated
original query copy's QPF metadata rewrite; source/log are preserved. Exact
review verifies only the dated header and explicitly queried font revision
are added, retaining version/base revision and all other query-copy inputs.
`assignment-review/original-query-rewrite.json` records it. Root QPF and
completed builds are untouched; timing/source predicates remain unchanged.

All new jobs are terminal. Preserve frozen inputs/rejected attempts and the
13 old tracked generated-file deletions. Next: separately opt this font
profile into the existing destination-local scaler reset helper and qualify
all three clocks, without enabling the incompatible Z-video profile. Scaler
size CDC, cache publication, HDMI switching, I/O constraints, native fonts
and physical reset/hardware acceptance remain open. MiSTer stays with user.

## October 16 external-font snapshot timing (complete bounded local gate)

MiSTer was not accessed. No RTL change. Only the font QSF changes among the
previous 428 compiler inputs, adding the new font-only SDC loader as input 429.
Other revisions and the shared original dimensions SDC remain unchanged.
Report: `EXTERNAL_FONT_TIMING_STATUS.md`. Evidence:
`output_files/TIMING_FONT_20261016T2302/`.

Corrected full flow 19144 is terminal zero, snapshot **quartus-O1IV3KIp**,
`/tmp/x1-font-snapshot-quartus-v2.log`, local Quartus 17.0.0 build 595:
14m08s, 171 stage warnings, 25,525 ALMs, 37,234 registers, 534/553 M10Ks,
32 DSPs/four PLLs. RBF SHA
`c783fb3ee0c9e0a8ea424b32bb1fa2dc12a7d7aaae34994bab0aaf7a0071a720`.
Input manifest SHA
`1d02bc33d1437f687780c77f33f40ddd37c04efa11c365c56fbaa06d6fcb9912`.
Generated build-ID hash remains 302c3f62 (same October 16 date).

Integrated STA 90316 is terminal zero/no warnings,
`/tmp/x1-font-retry-fit-integrated.log`, `retry-fit-integrated/`. The frozen
`snapshot-retry-integrated.tcl` requires exactly one assigned snapshot SDC,
loads only assigned constraints and adds no analysis exception. Independent
`retry-fit-audit.json` passes: all eight corners, 72 exact bits / 1,152 rows,
minimum setup/hold **+20.504/+0.498 ns**, maximum data **12.876 ns**.
Final audit additionally verifies each actual Delay Model header and every
selected setup/hold relationship (31.25/0 ns) under the assigned SDC order.

**Global timing remains FAIL.** Main slow setup/hold/recovery/removal are
−15.149/+0.194/−8.300/+0.830 ns; eight-corner global reported minima are
−15.149/+0.080/−8.300/+0.333 ns. Setup/hold I/O requirements are incomplete;
MTBF is not calculated while timing fails. Hardware/native boot on this RBF
is unexecuted. Next local work: remaining cache publication/synchronizer,
reset and HDMI timing paths; native fonts and broader video also remain open.

New loader fixes the observed early-synthesis guard mismatch without changing
fitted acceptance. Native diagnostic v3 captures exactly 74 logical bits
0..73 during quartus_map; later optimization removes constant interlace bits
0/1. The font-only loader validates all full logical names during map, then
uses the unchanged strict bits 2..73 once 72 remain. Fitter/STA always require
that original 72-bit guard. Sixteen synthetic scope cases pass; wrong stage,
partial/duplicate/foreign/extra logical bits fail before any bound.
Corrected native map shows the early 74-bit and later 72-bit profiles, no
warning 330000; all 159 normalized synthesis warnings match the original.
`retry-map-gate.json` / `retry-map-warning-review.json` record this.

`retry-assignment-review/final-audit.json` passes: all 2,231 effective values,
machine HDL/QIP order, and four isolated PLL-library rows / three unique
macro reorderings reviewed. **SDC order changes**: the font node-bound script
moves before the two clock-definition SDCs. Their relative order is retained;
the payload script queries no clock name. Native exact-path relationships
and all eight corners confirm its bounds remain active. Terminal QPF/QSF
hashes match the isolated project queries. Do not call SDC order unchanged.

`final-build-audit.json` passes source/build/selected timing, SHA
`c0fe091376102b10dd40f40128fd1481db4355611dd583d7b02ed38d885a8a53`.
`final_build_audit.py` is its reproducible source. The first final auditor
rejected singular `1 warning` grammar; v1 source/log remain preserved and
only that parser grammar changes. `preservation-audit.json` confirms every
file in the original and corrected completed builds stays exact after
supplemental work, plus current compiler enumeration/source identities.

Initial same-fit probe 83956 and first direct-SDC full flow 79326 are preserved,
not overwritten: first RBF in `quartus-ztUzRhR3/`, `first-build.json`.
Its integrated STA 74148 / `first-fit-audit.json` passes selected minima
+20.368/+0.409 ns, maximum data 12.985 ns; it retains the TDS warning.
Diagnostic first attempt lacks generated build_id.v and rejects before
meaningful synthesis. v2/v3 diagnostics complete and identify the native
early 74-bit shape. `early-inventory-final.json` hashes the terminal log;
the earlier prefix used in the initial discovery manifest remains byte-exact
as `early-inventory-interim.log`.

Digital prerequisites also complete: fresh six-ratio snapshot protocol,
connected HPS mapping/measurement and two bypass controls (99066), five PASS
markers in `protocol-audit.json`, `/tmp/x1-font-snapshot-protocol-v2.log`.
The first launch lacked its nested output parent and failed before execution.
Cache window collector 98200 passes three ratios, each with 19 publications,
commits, delayed ACKs, releases and completions (57 total), stopped SYS/VID,
retained 50-bit packet, first-row payload and two invalidations. Early commit,
early release and unstable payload mutants fail their exact runtime assertions.
Frozen `x1-cache-windows-wfkjx07f` is under the macOS temporary directory;
`cache-windows-audit.json` and `/tmp/x1-font-cache-windows-v4.log` bind it.
Earlier fixture style/initialization and mutant-basename compile failures stay
preserved; only the final six runtime cases qualify. No suppressions added.
Native cache map discovery resolves all thirteen held_glyph bits into actual
held_descriptor aliases; a glyph-prefix-only bound would miss them. No cache
exception is introduced by these prerequisite tests.

All new jobs are terminal. Preserve all frozen inputs/rejected attempts and
the 13 pre-existing tracked generated-file deletions. Continue locally;
MiSTer remains with the user until explicitly made available again.

## October 16 local digital-color/PRESET gate (complete bounded reference)

`output_files/BASIC_COLOR_20261016T2253/qualification/`, session 75182 terminal
zero, `/tmp/x1-basic-colors-qualification.log`: all 22 cases pass with 66 PNGs,
3,248,128 exact pixels and 192 native CPU GRAM writes. Frozen collector
`scripts/qualify_csp_basic_colors.py` and oracle `check_basic_colors.py` use
the existing qualified CLI v4 base executable, not a new reference build.
No RTL/CLI/VM change. Commands separately seed adjacent white x=400/401
pixels, then PSET x=400 with each color 0..7 or PRESET. The shared-byte neighbor
must survive. All nine operations cold-repeat with exact whole PNG/frame
logs. Missing Enter for PSET/PRESET, wrong color and wrong erase coordinate
each reject unchanged RGB; missing Enter also rejects command/Ok completion.
Exact native CPU plane-write order/data and per-command frame intervals pass.

Independent auditor `scripts/audit_csp_basic_colors.py` checks all pixels,
emitted command/key arguments, source/artifact hashes, protected private copies,
frame clocks and CPU writes. Result `independent-audit.json` passes; auditor
source copy is `auditor.py`, SHA
`c358a8300bfd7dc216a9a366684871d77a2e7c7730b7f1fbcb9b24f23541cc2b`.
Original D88 and all 156 qualified reference source inputs remain exact.
The matrix compares PNG/frame-clock repeats only; all other raw files happen
to match too, without extending the contract across host calendar boundaries.

Earlier `explore.py`/`explore.json` are syntax observations only. Embedded
PSET color works, embedded LINE color gives Syntax error. Two colon-based
exploratory strings omitted the colon because that helper's VM-key mapping
was incomplete; do not interpret them as native colon-syntax tests. The
frozen matrix uses separate commands and audited punctuation/key events.

Report `BASIC_COLOR_REFERENCE_STATUS.md`; TODO now has a short remaining-local
priority list. These new graphics cases are not RTL/hardware acceptance.
MiSTer was not accessed and remains with the user. Current RBF timing still
fails; no new Quartus claim. All new jobs are terminal; preserve frozen runs.

## October 16 native SAVE/LOAD follow-up (local bounded gate complete)

Output `output_files/BASIC_SAVE_20261016T223258Z/`. Previous qualified
reference sources are preserved in `before/` and `before.json`; only the
user-authorized sibling `common_source_code/src/mac/x1_cli.mm` changes.
CLI revision 4 adds explicit `--disk-output-a/b NEW_COPY`: default protected
private copies unchanged, writable copies exclusively created, source disks
never mounted directly. Existing paths/symlinks/hardlinks/originals, duplicate
drive outputs/options and missing companion input reject before VM use.

Fresh workspace build session 92288 terminal zero, logs
`/tmp/x1-save-cli-configure.log` and `/tmp/x1-save-cli-build.log`, builds
x1/x1turbo/x1turboz/x1twin/mz700; Twin/MZ are link checks. CLI qualification
session 95715 terminal zero, `/tmp/x1-save-cli-qualification.log`,
`cli-qualification/terminal.json`: all 22 cases pass against 156 canonical
source inputs. Five old/new default CPU/keyboard/reset/model cases have
byte-identical machine artifacts; four disk-policy cases and eight rejecting
path controls pass. Original BASIC D88 remains exact.

Native syntax exploration session 83229 is terminal zero,
`/tmp/x1-save-explore.log`, `explore/report.json`, observed only. Native
`SAVE "X1TST01"`, NEW, empty LIST, LOAD, LIST/RUN yields 9 on a new writable
copy; actual disk changes. Drive-0 prefix also writes; drive-A prefix does
not. Keep these trials separate from the next frozen qualification.
Full final transcript scrolls four rows: banner moves to row0, program
transcript starts row9; earlier SAVE/cleared/loaded captures retain row4.
The later frozen marker program is `10 PRINT "94217365"`, saved as X1TST01.
`scripts/qualify_csp_basic_save.py` / `check_basic_save.py` freeze exact
native transcripts, empty LIST after NEW, restored LIST/RUN and transport
metadata/source checks. First matrix session 71469 rejects its all-artifact
repeat assertion after all nine individual native/control cases pass:
one directory minute-like byte (40→41) and its RAM buffer differ. Source
`PSUB::initialize` samples host time. Preserve `native-qualification/` and
`/tmp/x1-save-native-qualification.log`; do not normalize those raw files.

New `native-qualification-v2/`, session 80126 terminal zero, log
`/tmp/x1-save-native-qualification-v2.log`: all nine cases pass with 34 PNGs /
1,802,240 exact pixels. Repeat scope is frozen to exact RGB and frame/clock
logs; raw disk/RAM hashes are recorded unchanged, byte identity unclaimed.
Both separately saved images are each reopened in a fresh protected-copy
process. Protected SAVE, missing Enter, same-process no LOAD, cold no LOAD
and one-byte saved-literal mutation reject unchanged completion. Mutation
offset 83406 changes ASCII 5→4 in sector data only; native LOAD/LIST/RUN
prints the altered marker. Original disk and all frozen inputs stay exact.

Independent auditor session 20909 terminal zero,
`/tmp/x1-save-independent-audit.log`, `independent-audit.json`, SHA
`b4abf198d24517bfa8476b1208ba2e31d7d4578cdc682f329336e7aa414000fa`.
Source copy `auditor.py`. It recomputes all pixels, 22 CLI checks/artifacts,
five rejecting native controls, both cold source selections, disk changes,
single-byte payload mutation and preserved originals. Sibling CLI guide now
documents revision 4; only CLI/guide differ from preserved prior reference
files. Five build targets pass, no CLI-source warnings were reported.

Report: `BASIC_SAVE_LOAD_REFERENCE_STATUS.md`. No RTL/Quartus changes.
Root `git diff --check`, Python compilation and whitespace checks of both
modified sibling files pass. The sibling's whole-worktree diff check still
returns 2 for pre-existing CRLF/trailing whitespace in untouched files;
`sibling-preexisting-whitespace.log` and `final-checks.json` preserve this.
Do not clean unrelated sibling changes. Reviewable exact CLI/guide delta is
`reference-changes.patch`; `change-audit.json` proves only those prior
reference files differ from the captured inputs.
No new live jobs remain. MiSTer is still with the user: hardware SAVE/LOAD
is unexecuted, and earlier ownership IDs must not be used to reclaim it.
Continue independent local TODO items unless the user makes hardware available.

## October 16 base-compatible packet implementation (complete bounded gate)

New RTL simulation gates, ordinary regression, source-bound Quartus build
and bounded native hardware qualification pass. Timing still fails.
Pre-change bytes/hashes are in `output_files/BASE_TEXT_20261016T1524/before/`
and `before.json`. Preserve all pre-existing work and previous frozen evidence.
The external-font machine now permits mask03 packets only with VID-local
simple-low-scan permission (high scan/Y2/underline off), request/reply checks,
held-packet revocation and glyph-LOAD blanking after reverse/blink. Unknown
Kanji bytes remain unknown; partial glyph bytes are not interpreted as Kanji.
Journal rebuild includes mask03 without changing known bits. Ordinary profiles
have no new state. Strict standalone packet default remains all-three-known.

Strict unit session 49326 terminal zero, `/tmp/x1-base-text-unit.log`: fourteen
original positive/mutation runs pass. Wrapper lint passes. Default generated
state session 83575 terminal zero, `/tmp/x1-base-text-default-state.log`, folder
`x1-machine-fdc-default-state-836sa9s_`: all eight original base/Turbo v17
headers/serializers match; inherited warnings remain 60/60 with none added.
New partial unit first rejected compile (unused observer pins/clock style)
and second rejected mutation compile remain preserved (`y2b24o82`, `7tbi6stj`).
Neither compiler failure is accepted as a negative. Corrected new test session
10473, `/tmp/x1-partial-ank-unit-v3.log`, is terminal with 778 positive cases
and six matched runtime rejections, no warnings (`x1-partial-ank-slvklq1s`).

Existing five-case full external-font machine gate is terminal zero session 33661,
`/tmp/x1-base-text-machine-existing.log`, frozen `x1-z-external-machine-vw1m1_60`.
All five original positives/mutations pass. Existing renderer session 4999 is
also terminal zero (`/tmp/x1-base-text-render-existing.log`,
`x1-z-kanji-render-wwchvapw`): both original exact 80/40-column five-frame
positives and both runtime mutations pass. Its fixture now enables external
packet validity with the real packet-valid signal. All 63 normalized warning
identities/counts remain exact; only reviewed source hashes/locations change.

New real-Z80 machine gate session 76715 is terminal zero,
`/tmp/x1-partial-ank-machine-v2.log`, `x1-partial-machine-wn726n64`:
six cold/warm positives (base80/base40/missing-text/high/underline/expanded)
check 88 CPU reads and 1,408,000 exact pixels in twelve frames. No warm asset
upload or VRAM rewrite; actual M1 boots and retained journal rebuild required.
No-reset, omitted-partial-rebuild and unsafe-mode mutants reject their exact
runtime oracles. The first attempt rejected a fixture argument-width warning
(`1f5q0jov`); it is not an accepted negative. Session 33399 is terminal zero,
`/tmp/x1-text-packet-load.log`, `x1-text-packet-load-1ww6n4q_`: 34 actual CRTC
glyph-LOAD checks and two runtime mutants distinguish late permission and
post-reverse blanking. Focused input/artifact audit is
`output_files/BASE_TEXT_20261016T1524/focused-audit.json`.

Ordinary headless build/run smoke is terminal zero. Full regression session
21833 is terminal zero, `/tmp/x1-base-text-regression-v2.log`, all 164 PASS
reports, same `cb28813e…` runner. Audit is
`BASE_TEXT_20261016T1524/regression-audit.json`.
The first regression exposed another natural unforced VPATH reuse subtype
(`runner-isolation-anhdbsxh`): both parent CPP and RTL objects linked into a
local byte-identical parent executable. The checker now requires exact link,
missing-child-object and identical-binary proof for that subtype. Forced
CPP=2/RTL=23 and internal `-B` assertions remain unchanged; isolated rerun
5040 is terminal zero (`/tmp/x1-base-text-isolation-recheck.log`).

`misterubuntu` has Quartus 17.0.2 but a SunSparcStation fit was running at the
availability check; do not start a competing flow or stop it. The installed
local Apple container's Quartus **17.0.0 build 595** is terminal zero session 28018,
`/tmp/x1-base-text-quartus.log`, snapshot `output_files/quartus-9o5ChatI/`.
Map/fit/ASM/STA finish in 16m11s / 171 stage warnings, 25,228 ALMs,
37,234 registers, 534 M10Ks, 32 DSPs/four PLLs. RBF SHA is
`4c0a95f2cc91c91df46eff8e3b22577b809fa6247725bd91294c3db1ce300a23`.
Original 428-input manifest SHA is
`ea2221dcf50ecb65f4977ce1853fb6da8abf581db24bfdaf96245bf0a395d357`.
The hook query rewrites copied QPF/QSF; isolated effective-assignment audit
in `BASE_TEXT_20261016T1524/assignment-review/audit.json` proves the same
2,230 assignments, unchanged machine source order, only isolated PLL QIP/
library movement and reordered uniquely named global macros. Root inputs
are unchanged. Terminal build/generated build_id/RBF/report/source audit
passes in `BASE_TEXT_20261016T1524/build-audit.json`. Original SDC Slow
1100mV 100C setup −15.031 ns/recovery −8.167 ns/hold +0.251 ns;
fast corner unexecuted and hold requirements incompletely constrained.
Timing acceptance fails. No new cuts or frequency changes.

`scripts/mister_base_text.py` prepares four unique native Turbo/base cold
boots, missing-Enter controls, then base Main R/T retained reset/LIST/RUN.
It requires a terminal source-bound build audit before staging. Actual
hardware session 61234 is terminal zero, `/tmp/x1-base-text-hardware.log`, output
`BASE_TEXT_20261016T1524/hardware/`. Unique deployments use the new RBF;
Unmodified base/Turbo arithmetic both cold-repeat. Base Main R/T reset,
no-selection/no-reset controls and LIST/RUN pass without warm upload/remount.
`scripts/audit_mister_base_text.py` is terminal zero session 93856,
`/tmp/x1-base-text-hardware-audit.log`: 21 fresh raw PNGs / 245,760 exact
pixels, every action/MGL/config/disk, source/remote/Main/full DDR checked.
Independent audit SHA is
`4e6e5f11bd86cd40162723d3d6189fe69de537dbd8df366ed43c7250c8a74813`.
Final owned core `X1BTEXT_20261016T155231Z_04` remains at base native BASIC
after the stored program. Preserve this ownership checkpoint before another
hardware collection. Report: `BASE_TEXT_COMPATIBILITY_STATUS.md`.

## October 16 native BASIC graphics follow-up (complete bounded gate)

The user asked to continue, so graphics is the next bounded BASIC item.
No further RTL or reference VM changes. The local CZ-856C BASIC PDF is
scanned/textless; it is not being treated as CZ-8FB01 syntax authority.
Qualified CSP base executable/assets and all 303 original inputs are frozen
and checked before new private-copy runs. Existing accepted outputs unchanged.

`output_files/BASIC_GRAPHICS_20261016T1602/`, session 38920 is terminal zero,
`/tmp/x1-basic-graphics-explore.log`: four syntax observations only.
PSET with trailing `,7` sets a point but returns Syntax error; plain syntax
also errors and LINE with trailing color returns Type mismatch. Exact
font-based recheck verifies complete echoed commands and all error/Ok rows
(`...1602/syntax-error-audit.json`); do not infer dropped input from tiny
preview text. These are failed probes, not graphics acceptance. No emulator
timing policy changes or isolated cadence-causality claim.
Slower explicit 16/16-frame events without trailing color finish session
39184 in `BASIC_GRAPHICS_20261016T1605/`, log
`/tmp/x1-basic-graphics-explore-v2.log`: point/point-repeat/no-Enter/LINE.
Both proper commands pass exact native transcript/Ok and pixels. Independent
checker/emitter is then frozen before `qualification/`, session 72454,
`/tmp/x1-basic-graphics-csp-qualification.log`: all seven cases pass,
346,112 exact pixels / 105 native CPU GRAM writes, byte-identical cold
repeats and two no-Enter / wrong-coordinate rejections. Independent CSP
audit passes; original auditor bytes are preserved as `csp-auditor-v1.py`.

First hardware attempt 24429 is terminal nonzero: native point works, but
collector rejects two fresh captures. Preserved `...1605/hardware/` and
`hardware-rejection-review/`: actual native640×200 passes point+Ok; auxiliary
1024×768 is rejected as a native raster. Source copy remains exact. No cause
for the auxiliary capture is assumed. Revised collector freezes a format-
based policy before new cases: preserve every PNG, qualify every native
640×200 frame, require at least one per phase, auxiliary formats unqualified.
Pixel/command/CPU checks unchanged. Session **5894** is terminal zero in
`...1605/hardware-v2/`, `/tmp/x1-basic-graphics-hardware-v2.log`: five cases
after Main R boots, no warm upload/remount/load. All five cases pass, 15 raw
native640×200 PNGs / 168,960 exact pixels, no auxiliary frames in this final
matrix. Current MiSTer stays `X1BTEXT_20261016T155231Z_04`, at native
PSET(401,160)/Ok after the wrong-coordinate witness/control.
`scripts/audit_basic_graphics.py` is terminal zero session 15431, log
`/tmp/x1-basic-graphics-final-audit.log`: reference and hardware logical
pixels, all frozen/artifact/source hashes, action/control sequences, remote
payloads/Main/full DDR pass. Final audit SHA is
`58d3d46eddfb566271d046ad709bf5f9ae4965f2e610410da72e809f66c7a85b`;
source preserved as `...1605/final-auditor.py`. No live new jobs remain.
Report: `BASIC_NATIVE_GRAPHICS_STATUS.md`. SAVE/LOAD is next: current CSP
CLI only mounts protected private copies, so first add explicit writable-
new-copy output with existing-target/original-path/default-policy controls.
Do not modify qualified reference sources until preserving the historical
source binding. Wider graphics/colors/modes, native fonts and timing remain.

## October 16 native IPL metadata diagnosis (complete)

Report: [base IPL/metadata startup](BASIC_METADATA_STARTUP_STATUS.md).
No machine RTL, firmware, native default-value, RBF or Quartus changes.
All jobs are terminal; MiSTer is restored to the unmodified Turbo+ANK16
native BASIC prompt with fresh exact banner/Ok pixels. Strict all-three-known
masking remains; unmodified base-profile/cache policy and timing stay open.

Initial `scripts/observe_native_ipl_startup.py` / native SV observer freezes
current shared graph, MR16 image and exact IPL/font assets before build.
Output `output_files/IPL_STARTUP_20261016T1429/`, session 89299 terminal zero,
log `/tmp/x1-native-ipl-startup.log`. Four 200-ms runs, no disks/keys:
base makes all prescribed 2,084 OUTs / 2,048 VRAM commits, no Kanji writes,
and reaches its real 0F26 delay with WAIT released. Turbo initializes all
2,048 Kanji cells too (6,144 commits). All machine CSVs cold-repeat exactly.
Raw logs retain differing host performance footers; initial all-file repeat
flags are false, not a machine repeat failure. Independent audit SHA
844588320114388e8486169735dfab6a7cf3ffb5d75c36274438689f79ee64f9.
Initial frozen sources remain preserved; next revision corrects one observer
IF-width warning and scopes repeat comparisons to exact machine artifacts.

New `scripts/mister_basic_metadata_control.py` stages two explicit diagnostic
32-KiB IPLs. Both patch only entry JP to a generated 21-byte shim at 1000,
then return to native 0006. Initialize executes 2,048 real OUT(C),H=0 at
3800–3FFF; Skip replaces only that two-byte OUT with NOP/NOP. Native bytes
0003–0FFF remain exact. OUT/NOP costs differ; no timing oracle is claimed.
No assumed native power-on Kanji value or unmodified base acceptance.

Hardware `output_files/BASIC_METADATA_20261016T1435/`, session 64352 terminal
zero, `/tmp/x1-basic-metadata-control.log`: skip/init/skip/init cold runs,
same fd9a0850 RBF/full synthetic font/protected D88, no ANK16, unique paths.
Both init cases pass PRINT6*7/42/Ok; both skips stay black at all four phases.
Both initialized no-Enter frames reject unchanged completion and retain
exact banner. Independent session 58953 verifies 16 fresh raw PNGs, 40,960
exact positive pixels, every action/MGL/config/disk, prescribed shim bytes,
frozen inputs/all 428 compiler files, immutable remote payloads/Main and DDR.
Audit SHA 59a776ab61805cfbe69f3eee2204deaa8a5f09faa23a89f1210dc16fc645357f.
Collectors/oracles/assets were frozen before loading; originals are unchanged.
Actual `screenshots.html` includes matched black/positive cases.

Corrected SV observer freezes the SAME generated hardware payloads in
`output_files/IPL_METADATA_SIM_20261016T1438/`, session 46849 terminal zero,
`/tmp/x1-native-metadata-startup.log`. Four 200-ms cold/repeat runs:
skip has 1,024 masks03 / 1,024 masks00 and zero valid packet phase samples;
init has 1,024 masks07 / 1,024 masks04 and 71,124 valid samples each.
Independent exact I/O/M1/journal/repeat audit SHA
b5480d33218b2ce7a0caac5da6decbaa3163b4b0b2271f21069ad79063046db5.
First 4,096 completed M1 samples per case are recorded, later reads form a
histogram; packet samples are not rendered pixels/frames. No disk or native
boot is qualified by these short runs. All sixty warnings are inherited,
with none in the new observer; no new suppression.

Session 75034 cold-restores recorded prior native Turbo MGL, then captures
fresh exact banner/Ok (10,240 pixels) in `restored-native-turbo/`.
`/tmp/x1-basic-metadata-restore.log`, terminal zero. Current ownership,
original native payloads/Main, full-font DDR and compiler inputs recheck.
No keys after load, no warm-reset claim. Python compilation, seven existing
BASIC oracle methods and diff checks pass. Prior accepted hardware/CSP gates
and the earlier timeout remain preserved; no timeout is restarted.

## October 15 matched BASIC IPL/font follow-up (complete)

Report: [matched IPL/input observations](BASIC_IPL_MATRIX_STATUS.md).
Output: `output_files/BASIC_IPL_20261016T030331Z/`; actual `screenshots.html`.
No RTL, firmware, emulator VM, RBF or Quartus changes in this follow-up.
All jobs are terminal; MiSTer is left on the passing Turbo+ANK16 native BASIC
prompt with fresh exact banner/Ok pixels. Base boot and timing stay open.

Hardware driver `scripts/mister_basic_ipl_matrix.py` freezes source/oracles/
assets before eight new cold cases: base 4-KiB versus native Turbo 32-KiB IPL
x ANK16 omitted/present, twice each. Same fd9a0850 RBF, synthetic full font,
protected disposable BASIC disk, zero config and actual Main/mrext sequence.
All four Turbo cases complete PRINT6*7/42/Ok, with 81,920 exact pixels and
rejecting no-Enter controls. All sixteen base frames are entirely black.
Missing completion is an observation, never a successful native failure test.
Session 89747 terminal zero; `/tmp/x1-basic-ipl-matrix.log`.
Independent session 84683 audits all 32 raw PNGs, MGL/config/key sequences,
source/assets and all 428 compiler inputs. Audit SHA
880a3318e1af6311f1dddcad74734c2534afbcb515a7568448554afdefa4790e.
Separate session 96043 passes 22 immutable staged/Main files, retained font
DDR and terminal ownership before the next load; `remote-audit.json`.

The Turbo IPL aperture is 32 KiB, so a 4-KiB upload leaves upper bytes
unspecified. Two separate explicit FF-tail cold controls preserve the exact
base prefix and fill 1000–7FFF with FF. Derived ROM SHA
f0f3e3e07c268fd001eebbd4c841711688e23b5ca85a6ddaba4a79b980a0f836.
Frozen source transformation and hashes are in `tail-inputs/derivation.json`;
output `ff-tail-followup/`, session 84113 terminal zero, log
`/tmp/x1-basic-ff-tail.log`. Both remain black in all eight actual PNGs,
with zero native completion pixels. Independent terminal session 18454
checks derived bytes, source transformation, all inputs/428 compiler files,
remote payloads/Main and full-font DDR. Audit SHA
4badd386a76b6b3e13ff2997ff620a9c928e84c9bf0e9e763567e42e05e5b332.
This policy does not resolve the blank observation; no RTL fix is inferred.
Do not relabel the derived image as native Turbo firmware or a base board.

Session 78909 cold-restores the prior observed Turbo+ANK16 MGL after both
controls, checks current ownership and captures a fresh raw native BASIC
prompt with 10,240 exact banner/Ok pixels in `restored-turbo/`.
`/tmp/x1-basic-restored-turbo.log`, terminal zero. No key input after load;
Main/RBF/payloads, full-font DDR and all compiler inputs remain unchanged.
This restoration is a cold RBF/MGL load, not another warm-reset gate.

CSP Turbo observer session 97797 is terminal zero but neither cold/repeat
arithmetic completes: both identically echo print6* and report Missing
operand. Preserve `csp-turbo-reference/`, frozen collector and log
`/tmp/x1-basic-csp-turbo.log`. Independent exact error/banner audit confirms
that observation; successful process exit is not native completion.
Separate `scripts/observe_csp_basic_cadence.py`, session 5327 terminal zero,
log `/tmp/x1-basic-csp-cadence.log`, freezes four cases in `csp-cadence/`.
4/4-frame input reproduces missing 7; 8/8 cold/repeat passes 81,920 exact
pixels and matches every artifact. Missing Enter rejects the unchanged
completion oracle. Real mailbox reads at slow frames 928/944 show 7/Enter;
fast trace has no 7. All inputs and expected protected disk-copy headers/
payloads independently verified. Audit SHA
1552b7564706e365f303d27ed1fd72b34d3efde9cd6ae71b6e77a3ed79d46229.
PSUB source has an eight-entry FIFO that drops full writes, but internal
fullness was not traced; no physical timing/overflow claim or VM fix.

Seven existing BASIC oracle unit methods, Python compilation and diff checks
pass. Earlier accepted CSP/HW gates and the timed-out RTL attempt remain
preserved; no timeout was restarted. SAVE/LOAD, graphics, wider native/model
coverage, active-device reset, licensing and physical timing remain open.

## October 15 BASIC reference/hardware follow-up (complete; RTL timeout)

New reports: [CSP reference/reset](BASIC_REFERENCE_RESET_STATUS.md),
[actual MiSTer BASIC](BASIC_HARDWARE_RESET_STATUS.md).
No RTL, firmware, emulator VM, RBF or Quartus change this turn. Helper tools
and exact-pixel oracles are original code; private data stay ignored.

CSP session `17579` is terminal zero, `/tmp/x1-csp-basic-gate.log`.
`output_files/CSPBasic_20261015T234906Z/accepted-csp/` passes eight fresh cases:
arithmetic/repeat, stored program/repeat, warm/repeat, no-reset and no-Enter.
450,560 exact positive banner/transcript pixels and 30,720 appended-control
pixels pass. Real IPL PC0000/C3 restart appears only after reset at frame 1600.
All native artifacts cold-repeat exactly. 303 input paths / 167 frozen files
rehash unchanged; terminal SHA 59aec6bf17bdedcb4ab44feae6c9169a85d17ad95cbddb4402415223b3c9c7ba.
CSP lowercase/Caps and actual font differ from RTL; expectations preserve them.

Actual MiSTer is confirmed still owned on prior X1OSD06 before loading new
unique files. Initial generic helper omitted required physical font, so CPU
stayed paused; noisy unbooted attempt preserved in X1HW_20261016T000411Z_fd9a0850.
Corrected base-IPL+synthetic-font trial X1BASIC_20261016T000625Z stays blank after
F and is not accepted. Passing profile supplies native Turbo IPL and ANK16 as
well; this is not an isolated IPL-versus-font comparison or a diagnosed defect.
Deployment helper now takes exact-size explicit IPL/ANK16/physical font options,
hashes them remotely and orders indices 0/4/5 before mounting the private disk.
Three bad-size preflights reject before staging/network use. Old helper saved.

Turbo-IPL deployment `output_files/X1HW_20261016T000959Z_fd9a0850/` boots
CZ-8FB01. New `scripts/mister_basic_reset.py` gate session `4896` is terminal zero,
`/tmp/x1-basic-hardware-gate.log`. Its BASICRESET_20261016T001300Z subdirectory
contains seven fresh mrext PNGs: noEnter, arithmetic 42, no-selection, no-reset
appended 81, R reset fresh 81, T reset fresh 64, stored 10 PRINT 9 / LIST / RUN result 9.
All **148,480 exact banner/transcript pixels** pass. 75 recorded key actions;
no warm RBF load/upload/mount/reset chord/Linux reboot. T requires F12 to close
OSD; R closes it. Actual PNGs reviewed. Original/staged assets, Main/RBF, all 428
compiler inputs and font DDR d18c rehash unchanged. Hardware manifest SHA
500390006382533142634ac2736d89bf776dcbb4a22d1104a763eb73b5e2b847;
independent final-audit SHA 5b8c2d86cdb04e45b5c630baa2a15487202837f67b9a6d730fbf196167fe4411.
MiSTer remains on this accepted deployment, native program/result visible,
all keys released and no OSD overlay. Timing still fails; native Kanji, wider
BASIC/model coverage, SAVE/LOAD, active-device reset and exact timing stay open.

`make -C verilator test-basic-reference-oracle` passes seven asset-free methods;
Python compilation, preflights, actual MGL upload ordering and diff checks pass.
Final independent audit session `92700` is terminal zero. Actual galleries:
`output_files/CSPBasic_20261015T234906Z/screenshots.html` and
`output_files/X1HW_20261016T000959Z_fd9a0850/BASICRESET_20261016T001300Z/screenshots.html`.
CSP/build/hardware jobs are terminal. Scripts/logs/original failed controls
are archived under the CSPBasic output. Do not overwrite accepted manifests.

The separate historical fixed-FDC RTL session `33526` is terminal nonzero.
Its first 26-second warm child hit the 1,800-second execution limit; no child
produced terminal evidence and repeat/no-reset were not launched. Log
`/tmp/x1-basic-warm-rtl.log`; preserved output
`output_files/CSPBasic_20261015T234906Z/rtl-explore/`. No restart was made.
`rtl-timeout-audit.json` proves all frozen inputs/executable remain unchanged;
the terminal checker refuses incomplete evidence before writing acceptance.
This is an execution limit, not a machine correctness rejection or pass.
The checker was frozen after exploratory launch, not before it. c244826e is
a historical checkpoint, not a current source-bound RTL build. Its optional
warm gate remains open; future work must preserve this attempt and use a
separate planned collection. All jobs started in this turn are terminal.

## October 15 Common Source macOS CLI/reference follow-up (complete)

User authorized edits in sibling `../common_source_code`. Its substantial
existing work is preserved; `before.json` / `before/` and an incremental
`sibling-change-review.patch` distinguish this turn's changes. The existing
Z80 hook is byte-unchanged. New X1/Turbo/Z `--headless` route provides isolated
ROM/config lookup, synchronous frames, real VM keys/reset, protected private
D88 copies, CPU/I/O/frame logs, actual PNGs and CPU-visible memory. See
[CSP reference status](CSP_MAC_REFERENCE_STATUS.md) and sibling `MAC_X1_CLI.md`.
No X1 machine algorithm, RTL, Quartus or MiSTer change was made.

Isolated build passes all five targets: x1/x1turbo/x1turboz/mz800/x1twin;
MZ/Twin are compile/link checks only. Final build session `26326` is terminal
zero, `/tmp/x1-csp-build-v4.log`. The first rejected compile and earlier gates
remain preserved. Revision 1 native disposable-copy audit exposed backend
header-1A persistence; originals stayed unchanged. Revision 2 protects private
mount copies. Its native input attempt then exposed the macOS adapter's
missing VM key callbacks. Revision 3 repairs those after updating key state.
The same CPU-polled F/R fixture fails unchanged `KEYS` completion on the old
frozen adapter, and passes on revision 3; no-key also rejects it.

Accepted gate session `90648` is terminal zero,
`/tmp/x1-csp-qualification-v3.log`, frozen `qualification-v3/`: 293 inputs,
CSP X1/Turbo/Z plus unchanged ordinary RTL executable. Cold/repeat/bad/warm
cases pass exact RAM/status and 22/22/20/44 ordered I/O records. Warm reset
boots twice without asset reupload. Cold CSP CPU/I/O/frame/memory/PNG repeats
are exact. Keyboard positive/absent controls, Turbo/Z synthetic smoke, six
argument rejections, malformed D88 and actual generated-disk open/close pass.
Sources and binaries rehash unchanged. See terminal JSON for full hashes.
CSP CPU-visible versus RTL physical overlay dumps are checked separately.

Native session `95199` is terminal zero, `/tmp/x1-csp-native-v3.log`.
CROSS 3,500 frames and Arcus 4,000 frames have actual reviewed PNGs: CROSS
instructions/playfield/You lost; Arcus logo and labelled panel interface.
Session `99682`, `/tmp/x1-csp-native-verify-v3.log`, is terminal zero: both
cold repeats match CPU/I/O/frame logs, memory, all eight PNGs and mounted
copies. Matched CROSS idle/movement has identical pre-input frame 2600;
I at 2601/J at 2607 moves release-specific player (22,14)->(21,13), active=1,
by 2615 with changed actual RGB. A further movement cold repeat is recorded
in `native-verify-v3.json`. Original and input assets remain unchanged;
mounted media match exact protected headers and original payloads.
Native controller is pseudo, ANK is existing user data, Kanji explicitly zero
306,176-byte CSP virtual layout, sound PSG-only. Do not infer native Kanji,
Arcus gameplay or matched CTC/IRQ policy against older combined profiles.

Output root: `output_files/CSPMac_20261015T225930Z/`. Final native reports,
commands and source/binary audits are retained there. RAM-resident timing
matches exactly 25.624750 ms, while IPL-restored-to-PSG interval differs
CSP 16.5 us versus RTL 14.75 us. CSP adds an IPL M1 wait; native timing remains open.
Do not change RTL merely to match this one reference. No hardware state was
changed this turn. All build/qualification/native jobs are terminal.
Movement repeat session `64666` is terminal zero; its memory, PNGs, CSVs and
protected disk match byte-for-byte. Final independent audit passes all 293
inputs, frozen executables, original assets, mounted disk payloads and timing
arithmetic. Manifest SHA-256
`b7e1a87678a4d8c32fa486d229865da53f12428d360275c17c26d88a8e5c736e`.
Python compilation and `git diff --check` pass. The
[actual PNG gallery](../output_files/CSPMac_20261015T225930Z/screenshots.html)
and `final-audit.json` are ignored local evidence. Native CPU/I/O traces cover
frames 0–2; frame logs cover each full run. No full native bus trace is claimed.

## October 15 Main OSD reset follow-up (complete)

New reusable `scripts/mister_z_font_osd_reset.py` stages six unique MGL/config
cases from the accepted active-reset ROMs/oracles. Both T[0] Reset and R[0]
Reset-and-close pass good80, good40 and the wrong-last-retained-byte80 controls.
Each case first navigates/closes without Enter, then R must preserve yellow.
After selecting T, F12 closes OSD before R; after R, R is sent directly.
Only successful 6,144-byte readback publishes magenta; the bad ROM stays yellow.
No warm load/upload/mount, reset chord, Main config change or RTL edit.

First stage 10223 is terminal zero; matrix 77388 is terminal nonzero, preserved
`X1OSD_20261015T190220Z`. Its checker incorrectly expected active yellow before
R restored Turbo SCRN/high scan. Actual fresh raw PNG is black. Source confirms
CRTC programming is retained, while `turbo_scrn` resets to zero and initial
Kanji eligibility requires high scan. The shell restores SCRN only after F/R.
This is a rejected harness assumption, not evidence of a new RTL defect. Its
manifest/driver/three PNGs/log are preserved and copied into the accepted output.
No failed attempt is counted as a rejecting control pass.

Corrected stage 10741 and matrix 66295 are terminal zero, logs
`/tmp/x1-z-font-osd-stage-v2.log` and `/tmp/x1-z-font-osd-matrix-v2.log`.
Accepted `output_files/X1OSD_20261015T190610Z/`: six cases, eighteen raw PNGs,
**3,840,000 exact control pixels**. Four warm positives accept the original
magenta oracle; six no-selection controls and two wrong-final-byte warm frames
reject it. Only post-readback frames use the retained pixel oracle; it is not
changed to accept the invalid intermediate frame. All six per-case fresh DDR
reads match g0. [Scope](Z_FONT_OSD_RESET_STATUS.md),
[actual screenshots](../output_files/X1OSD_20261015T190610Z/screenshots.html).

Final audit terminal zero: all sixteen staged files, 127 qualification inputs,
428 compiler inputs, unchanged fd9a0850 RBF, installed Main and full DDR match.
Final manifest SHA `03360a1e074f27231aef674ef99d51d8e4c95a28cb914cd9f6f405707c0d120e`;
hardware driver SHA `8922eeab54c6fab08251d5d2662cceb5a98dfd37de8141b198757cdb9b12c692`;
reused qualification archive SHA `90a034832da7636b641e7e3b4bf72af7f6bde57514f4ebd0afba3d590b3cf312`.
Supplemental review rechecks local bundle/oracles and the one-byte bad-ROM
change, all no-selection/bad-warm PNG identities, explicit T close and six
per-case full DDR reads. Prior accepted manifest remains unchanged.
No fresh simulation/ordinary/Quartus run for orchestration-only changes; the
accepted active gate and previous 164-PASS ordinary executable remain unchanged.
Local Main sources are read-only navigation references, not established as the
installed binary source. `/tmp/OSD_VISIBLE` is absent; no global logging change.
Raw PNGs are core video, not the OSD overlay. Menu identity is inferred from
bounded inputs, unchanged no-selection controls and successful retained readback.
Physical owned phase/reset edge, stopped clocks, native fonts, wider modes/
devices and timing closure remain open. SYS32/fitted VID42.954545 MHz is not
physically measured. **No job started here remains live.** MiSTer is left on
intentional bad R-control `X1OSD_20261015T190610Z_06`; MGL 01/02/04/05 pass.

## October 15 active-traffic reset follow-up (complete)

User requested continuation. New test-only `test_z_font_active_reset.py` /
`z_font_active_reset_tb.sv` leave the older frozen gates unchanged. Real F
initializes VRAM then loops over three idempotent highest-cell writes and
sixteen checked font reads. First verified iteration publishes yellow; Main
reset + R must check all 6,144 retained bytes before magenta. No-reset R and
the one-byte wrong-last-table control reject the unchanged recovery oracle.

Session `75463`, `/tmp/x1-z-active-gate.log`, frozen `x1-z-font-active-4mhn4iv9`
is terminal nonzero: write case passes, but the read checker tests WAIT after
reset disables the CPU port. Preserved as failed development evidence.
Corrected session `71090`, `/tmp/x1-z-active-gate-v2.log`, frozen `x1-z-font-active-cmu3g_zf`
is terminal zero. It captures pre-reset WAIT/current address and held font/DDR
word alignment, then separately records the cancelled next read at reset+1 SYS.
All four cases pass: 34,544 completed reads, twelve frames/2,688,000 pixels;
three exact one-commit writer drains, one read cancelled without a commit,
stopped DDR-reply/VID recovery and retained cache/journal. Initial uploads only.
Supplemental review checks every active commit payload and real mailbox command
sequence; all 60 warnings match earlier gates. 127 frozen inputs remain
unchanged. Terminal SHA `f21518ab4e74f19ff6bb8fdc7af150eecd413c8279d69f90945b9dc335285f5d`.

Hardware evidence `output_files/X1Active_20261015T184644Z/` is terminal pass: three cases,
nine raw PNGs / 1,920,000 exact pixels. Main chord reset during
the firmware loop recovers at 80/40; no-reset and bad-final-byte controls reject.
[Scope](Z_FONT_ACTIVE_RESET_STATUS.md),
[actual screenshots](../output_files/X1Active_20261015T184644Z/screenshots.html).
Final manifest SHA `8e8f74593ea9b57c3a25286f8acfababde4f85357432a7b4bd1410a6f978a2f8`;
qualification archive SHA `90a034832da7636b641e7e3b4bf72af7f6bde57514f4ebd0afba3d590b3cf312`.
All eleven staged files, 127 qualification inputs, 428 compiler inputs,
fd9a0850 RBF and full fresh font DDR hashes pass. No core/asset reload requested
between active/no-reset/warm phases. No new Quartus/ordinary rerun for test/IPL-
only changes; prior 164-PASS executable unchanged. Physical exact ownership,
stopped clocks, OSD-menu reset, native fonts, wider modes/device coexistence
and timing closure remain open. SYS32 / fitted VID42.954545 MHz is not a physical
frequency measurement. Main/HPS SPI pins and physical CPU counts are untraced.
**No job started here remains live.** MiSTer is left on intentional bad-final-
byte control `X1Active_20261015T184644Z_03` (yellow); MGL 01/02 pass.
Earlier cores/config/media/manifests and failed evidence remain preserved.

## October 15 retained-asset reset gate (complete)

User requested continuation. New test-only IPL boots through real F/R keys:
F initializes all VRAM and publishes white corner before DI/HALT; R without
reset must not change it; actual reset + R reads every retained text/Kanji/
ATTR byte (6,144 CPU reads) before publishing magenta. A wrong final warm
expected-byte control must also fail the unchanged warm pixel oracle. No
uninitialized cold-RAM sentinel and no host state forcing/reupload.

First session `89029` is terminal nonzero (`x1-z-font-warm-lehkoh1j`): no
initial C event, CPU remains in the key poll; timeout is a failure, never a
control pass. Trace sessions are terminal failures, preserved in `d16tpec_`, `3agy8nls`,
`xrpinh7t`: C's valid raw packet decodes, then firmware `JOY_EN` consumes it
through the joystick C/T3 table (PC 035C → 0372 → 04E6, no ASCII key store).
The checker correctly refused initial C. A subsequent compile-only typo
`jlmfzlom` is also preserved. No failure is accepted as a qualification.
Session `70848` is terminal zero, log `/tmp/x1-z-warm-gate-keyfix.log`, frozen
`x1-z-font-warm-m_g5y0ve`; terminal SHA
`ad0d2ea55f8b1f2572d4936e2cbb0f52b8cfa553644f65fa9456932fd5305d1b`.
All three cases pass: 18,570 traced reads, nine exact frames; no-reset and
wrong-final-table-byte controls reject the unchanged warm oracle. F replaces
C at the same 25-ms input timing with unmodified firmware. Only initial
294,912 public IPL/font bytes per case, no reupload in retained phases.

Hardware matrix `30864` and final audit `61854` are terminal zero. Unique
evidence `output_files/X1Warm_20261015T165542Z/`: all nine PNGs match
**1,920,000 control pixels**. Good80/good40 warm frames accept the unchanged
warm oracle; all three no-reset frames and bad-final-byte warm frame reject it.
No core/asset reload is requested between cold, no-reset and warm captures.
Actual reset path is Main LeftCtrl+LeftAlt+RightAlt keyboard chord, not the OSD
menu or physical pins. [Full scope](Z_FONT_RETAINED_RESET_STATUS.md),
[actual screenshots](../output_files/X1Warm_20261015T165542Z/screenshots.html).

Final audit passes all nine PNGs, eleven staged files, 126 qualification inputs,
428 compiler inputs, unchanged fd9a0850 and fresh full DDR. Manifest SHA
`755a4bda7b851040fe8965b73b19ea2e5889b879463abe0c3ed8e9d055bb2ba7`.
All 60 inherited warnings match the earlier gate. No new Quartus flow or
ordinary rerun for these test/IPL-only changes; prior executable unchanged.
**No job started here remains live.** MiSTer is left on intentional failing
retained-byte control `X1Warm_20261015T165542Z_03` (white corner); MGL 01/02 are
the passing controls. Earlier cores/configs/media/frozen manifests preserved.
Post-HALT retained IPL/font/VRAM and chord causality now pass these bounded
controls. OSD-menu/owned-transfer/stopped-clock resets, native fonts, broader
modes/devices, physical timings and timing closure remain open.
Earlier qualified outputs below remain immutable.

## October 15 CPU-visible completion gate (complete)

User requested continuation. A new cold-only diagnostic adds a visible ATTR=7
corner cell only after the existing 46 CPU reads and final VRAM comparisons.
A matched one-byte wrong last-compare IPL must fail the unchanged completion
pixel oracle. No RTL/compiler inputs changed; reuse source-bound fd9a0850.
New `test_z_font_completion.py` / `z_font_completion_tb.sv` gate is terminal
zero (`15864`), frozen `x1-z-font-completion-611hbrfy`, terminal SHA
`4daaf4680a86de9a772409d5f690c3761c7fa36987d44e9d668b26f89ea7fe80`.
All four cases pass: 184 CPU reads, 768,000 exact pixels including controls;
only good IPLs match the completion oracle. The first `yrg0a31a` failed
checker-select assertion is preserved; it expected ATTR select 4 instead of 2.

Hardware matrix `16871` and final audit `72792` are terminal zero. Unique
evidence `output_files/X1Done_20261015T155523Z/`: good80, bad80, good40, bad40,
repeatgood80 match **1,024,000 control pixels**. Three completion frames accept
the unchanged oracle; both bad-last-compare frames reject it and match the
full unmarked image. Each reloads RBF/IPL/font and requests MGL startup reset;
physical warm-reset causality remains open. All five PNGs, 16 staged files,
125 qualification sources, 428 compiler sources, unchanged RBF and fresh
complete DDR readback pass the final hash audit. All 60 inherited warnings
match the prior machine gate; no new diagnostic warnings.

[Completion scope](Z_FONT_CPU_COMPLETION_STATUS.md),
[actual screenshots](../output_files/X1Done_20261015T155523Z/screenshots.html).
Final manifest SHA `d0061422acc4335790a6f733d0f4164572e527ac6f781461d7e3e83a84cb8cd0`.
No new Quartus flow or ordinary regression was needed for these test/IPL-only
changes; all compiler inputs and the prior 164-PASS executable remain unchanged.
**No job started here remains live.** MiSTer is left on the repeated marked
80-column diagnostic, `X1Done_20261015T155523Z_05`. The earlier final CPU
readback gap is closed only for these new cold/RBF-load diagnostics; older
IPLs/malformed-retry PNGs retain their original limited scope. Native fonts,
wider modes, physical warm-reset/retention and timing closure remain open.
Prior complete evidence below remains immutable.

## October 15 upload-error recovery continuation (complete)

Quartus session `81057` and timing reporter are terminal zero: frozen
428-input archive in `misterubuntu:/tmp/x1-z-font-error-drain-g1603x4v/source`;
evidence `output_files/X1ErrorDrain_20261015T145753Z/rebuild/`. RBF fd9a0850,
25,384 ALMs/534 M10Ks, 17m34s/170 warnings; timing FAIL slow setup −14.851 /
recovery −8.257 ns, fast hold −0.098 ns. All source/QPF audits pass.
Ordinary session `73707` is terminal zero: headless/build, 200,000-cycle smoke
and `test`, 164 PASS reports and unchanged `afcf9711…` executable.

All jobs started here are terminal; do not restart completed evidence. Hardware
trials use unique `X1ErrorDrain_20261015T145753Z` folders. Valid80,
oversized-then-retry80 and short-then-retry40 match **640,000 exact pixels**
and full DDR hashes. Oversized-only Main capture and the following core load
succeed without a Linux reboot. Each retry occurs within its loaded core.
Native CROSS Chase on fd9a0850 has a visually inspected populated playfield
and 14 frames matching the 531-pixel border signature.

Final audit: 38 screenshot records, 30 staged files, three private originals,
428 compiler inputs and fresh full-DDR readback all pass. Manifest SHA
`9afac5f022c53f46ae101b3ef15dd51dfa5406d92ab8cf6c1ace4f72dafecfbb`.
[Gallery](../output_files/X1ErrorDrain_20261015T145753Z/screenshots.html),
[recovery/build scope](Z_FONT_HPS_UPLOAD_STATUS.md). The MiSTer is left on
`X1ED_20261015T145753Z_05` CROSS Chase. Shortened unique setnames avoid the
31-character Main name-report truncation; initial files/logs remain preserved.
Original c6/52be and unrelated cores/config/media are preserved. The
oversized-only PNG equals the old g0 image and may be held; it is not physical
readiness/error-state evidence. Final CPU readback/reset causality remain open.

Frontend error WAIT now drains rejected payload instead of trapping Main;
write admission separately rejects every byte after error. The new actual
HPS decoder/ACK gate passes one positive plus four exact rejecting controls
(`test-z-font-hps-upload`, terminal SHA `6e33de6f…`). Its positive checks
1,048,596 DDR writes, four full-size streams, three malformed streams and two
recoveries. All 39 frontend cases, five whole-machine cases and wrapper lint
also pass. Physical malformed/retry testing now passes its bounded gates. Timing remains
unclosed. Do not treat the previous c6 RBF as containing this repair.

Matched CROSS Chase controls now show populated playfields with both IPLs on
both historical single-clock and c6 external-font cores. Six start taps were
needed for the local source's four separate input waits. See
[CROSS Chase controls](CROSS_CHASE_HARDWARE_CONTROLS.md). Both the insufficient
three-tap matrix and successful six-tap matrix remain preserved.
The user's local XMIL 0.26 archive has been inspected read-only, not built;
see [reference audit](XMIL026_REFERENCE_AUDIT.md).

## October 15 earlier hardware continuation (complete)

The user authorized local ROM copies/MGLs and mrext screenshots on mister14.
See [current hardware evidence](TURBO_Z_EXTERNAL_HARDWARE_STATUS.md).
Initial RBF `52be576d…` physically uploads all 256 KiB correctly, then stalls
Main at the final SPI ACK because terminal-count WAIT prevents FILE_TX=0.
The MiSTer was synced/rebooted to recover. A minimal frontend repair passes
39 standalone cases, including an exact old-condition rejecting control;
the five-case whole-machine CPU/pixel gate and wrapper lint also pass.

**Quartus session `94988` is terminal zero**, remote
`/tmp/x1-z-font-hps-fix-H3qQo2ok/source`, 13:25:57–13:42:11 UTC, 16m14s.
Repaired RBF `c6a2ac02…`: 25,419 ALMs/534 M10Ks. Source/archive, QPF audit,
raw reports and RBF are in `output_files/X1ZF_20261015T131918Z/rebuild/`;
all 428 local inputs match, only the frontend differs from the prior source.
Timing reporting is terminal zero (initial missing-script error preserved);
original SDC setup -14.956/recovery -8.277 ns, fast hold -0.084 ns. No cuts.
Hardware cold/post-reset-request 80/40-column PNGs match 768,000 pixels exactly.
Native Turbo IPL boots Galaga/Mappy/Xevious titles on the repaired core.

**No job started here remains live.** Ordinary `headless`, 200,000-cycle smoke
and `test` sequence `32746` is terminal zero, **164 PASS reports**, unchanged
ordinary runner `afcf9711…`. Log `/tmp/x1-z-font-hardware-default-test.log` and
copied ordinary logs in the evidence folder. All hardware burst sessions are
terminal. Final audit passes 90 screenshot-record hashes, all 44 staged files,
six original firmware/media assets, all 428 compiler inputs and a fresh exact
256-KiB DDR readback. Final manifest SHA-256:
`16a5dbeae440228ad1f49356b6ecb19d207d159427201faf0590f396da2f03fe`.
The gallery is `output_files/X1ZF_20261015T131918Z/screenshots.html`.

All test files use unique `/media/fat/_Computer/X1ZF_20261015T131918Z/` and
`games/SharpX1/HWTest/X1ZF_20261015T131918Z/` folders. Test setnames 06/07/08
select the separate historical `eaca279a…` single-clock control core and
reach native Galaga/Mappy/Xevious title screens. Local manifest records real
PNG names/results. Explicit mrext `raw_screenshot` works; ordinary scaled
capture is black. Test setnames 10/11 are the repaired exact diagnostics,
12–15 are repaired native Turbo IPL game trials; initial failed 01–05 MGLs/RBF
remain as `.disabled` files. Native-font and timing gates remain open.
Repaired Mappy reaches a populated stage/score 30; Xevious reaches AREA 1 with
aircraft/changing landscape. Galaga reaches its title. Repaired Turbo-IPL
CROSS Chase shows score/Press key without a captured playfield in its extended
burst; only the separate historical single-clock control has an inspected
live playfield. Match IPL/clock/profile before attributing that difference.
The MiSTer is left on repaired Mappy, `X1ZF_20261015T131918Z_13`.
The original MacPPC7300 files/config/media remain preserved.

Updated October 14, 2026. **Resumed at the user's request.** The goal remains **unfinished**:
complete work groups 1–6 and documented Turbo Z. Component diagnostics,
historical game screenshots and a fitted RBF do not close that goal.

## October 14 continuation

**Final external-font continuation: no jobs started here remain live.**
[Full status](TURBO_Z_EXTERNAL_MACHINE_STATUS.md). Final current-source Quartus
session `35333` is terminal zero in `/tmp/x1-z-font-board-syksUXgN`: 24m52s,
170 warnings, 25,512 ALMs, 534/553 M10Ks. RBF `52be576d…` is delivered under
`output_files/z-font-20261014-52be576d/`, with manifest, source snapshot, fit/
STA summaries, raw evidence and simulation/state reviews. Input archive SHA
`57799209…`; all 428 source inputs match current working tree. Post-build review
verifies 427 unchanged plus only the expected generated QPF metadata rewrite.
All 59 retrieved files match hashes (archive `27dcd377…`).

**Timing FAIL / hardware feature UNEXECUTED.** Original-SDC slow 100C setup
-14.978 / recovery -8.570 ns; fast -40C hold -0.045 ns (measurement snapshot
bits 59/44). Same-clock SYS/VID setup +5.548/+7.034 ns does not qualify HDMI,
cache payload, measurement or reset-release crossings. Sidecar `31234` is
terminal zero and changes no exceptions. No RBF load/reset/input occurred.
Read-only mister14 (through misterubuntu) confirms mem=511M, System RAM ending
1FEFFFFF; backing 30000000–3003FFFF is outside Linux RAM. Existing MacPPC7300
core preserved. Memory-map evidence SHA `31820aee…`.

Final five-case machine gate `87292` is terminal zero in
`x1-z-external-machine-0gobqu2p` (`/tmp/x1-z-external-machine-frozen-final.log`):
280 actual CPU reads, 12,358 commits, six exact RGB frames / 1,152,000 pixels,
changed-font/retained rebuild, owned write/read cancellation, short upload
retry and three exact controls. It imports captured helpers before generating
assets. Independent read-only review `x1-z-external-review-zyky8esq` verifies
source/executable/log/IPL/CPU/pixel/PNG preservation; review SHA `87cf4cbd…`.

Final headless/run/test `18371` is terminal zero with unchanged runner
`afcf9711…`; log `/tmp/x1-z-font-default-test-final.log` has 164 PASS lines /
28 JSON reports. Base/Turbo generated-state audit `1epbd84l` and ordinary X3
`b2ft0ntx` give 12 exact files, unchanged sixty warnings; no state conversion.
Three wrapper lints pass. Review `x1-z-font-default-final-review.json` SHA
`8a2bffa0…`. Earlier mixed-source default run `25965` also passed.

Earlier prototype `46389` and sidecar `41489` are terminal zero, preserved in
`/tmp/x1-z-font-board-RBcNDcMC`, retrieved `x1-z-font-board-_08vrlhp` (RBF
`d454e315…`, 25,740 ALMs / 534 M10Ks, timing failed). It precedes the wrapper
address guard and disabled-profile state repair. Intermediate `x22j7daY` was
cancelled before compile while queued to include that repair; inputs and
cancellation record remain. Preserve all failed audit and historical gate
folders documented in the full status. No timeout restart.

Remaining: native font conversion / broader raster/ANK/PCG policies; physical
CDC/bundle/reset/HDMI timing; Main/OSD and actual DDR/cache/hardware execution;
wider device coexistence. This separate prototype does not complete Turbo Z
or work groups 1–6. Ordinary profiles leave it off.

Latest cache-renderer continuation: standalone `rtl/x1_z_kanji_video.sv`
requests the real cache at phase 0 and holds a validated descriptor/glyph
packet through the unchanged real x1_vid phase-10 capture / phase-14 LOAD.
Strict unit qualification is terminal pass (session `18918`,
`x1-z-kanji-video-n4o8gsl6`, log `/tmp/x1-z-video-unit-final.log`): 65,548
positive scenarios and thirteen exact RTL mutants. Earlier failed mutant
compiler evidence remains in `x1-z-kanji-video-8udp_4td`; no compiler failure
is counted as rejection. The first frozen real-renderer review also passes
five complete 640x400 RGB frames, CPU traces and the per-edge RGB oracle in
`x1-z-render-review-dh8l0pr2` (session `72669`, terminal zero).
Full connected qualification session `21336` is terminal zero in
`x1-z-kanji-render-870corcr`, log `/tmp/x1-z-render-first-full.log`: 80/40-column
SYS32/100 positives plus exact live-VRAM-metadata and wrong-glyph controls.
The unit/connected gates give eighteen builds/runs. Final read-only review in
`x1-z-render-final-review-bxeblzfa` verifies source/executable/log/artifact
preservation and warning inventories, independently repeats 116 real CPU
writes / 114 read samples and all ten RGB frames (1,920,000 exact pixels),
and regenerates matching PNGs outside the original evidence. See
[cache-renderer status](TURBO_Z_CACHE_RENDER_STATUS.md) for exact hashes,
contracts, counters and limits. Adapter SHA-256 `8016d155…`. All existing
qualified RTL is unchanged; new component remains outside machine.qip.
No started job remains live. No Quartus/MiSTer action this turn. Actual
shared-machine CPU/renderer/DDR wiring, writer-drain/lifecycle order, retained
rebuild, native policy and combined board timing remain open.

Latest VRAM-write continuation: new standalone
`rtl/x1_z_kanji_vram_write.sv` captures one held CPU write, merges the other
synchronous VRAM bytes with retained per-cell known masks, publishes the full
glyph/descriptor, then emits one real VRAM strobe and releases WAIT. This is
provisional refill-before-write timing, outside the machine manifest. No
existing qualified RTL changes. A small real-TV80/three-VRAM/cache/backend
smoke gate passes with two complete boots plus an interrupted owned write.
Full frozen qualification session `18539` is terminal zero in
`x1-z-kanji-vram-ccu5g0xa`, log `/tmp/x1-z-kanji-vram-first-full.log`: three
positives, fourteen exact RTL mutants and one actual-CPU bad-readback control.
SYS32/100 positives cover all 2,048 cells; the smaller SYS32/CPU2M/slow-VID
case is a separate functional stress profile. Read-only final review in
`x1-z-vram-final-review-0qzvqiq0` verifies all frozen/current inputs, artifacts,
programs and exact warning inventory, then independently rechecks 174 CPU
OUT intents/descriptor expectations and 171 sampled IN values. The real
bad-readback control reaches the unchanged program's `EE` failure-handler HALT.
See [VRAM write status](TURBO_Z_VRAM_WRITE_STATUS.md) for hashes/counters and
provisional policies. All jobs started here are terminal; no inputs need polling.
The exact 32 inherited CPU warnings are reviewed; new writer/fixture/RAM are
warning-free, with separate strict writer lint. Current writer SHA-256:
`229bfa92bec64878a078cf8f92ef998f57ce6bf6f219d6f28d4195adbd28418c`.
Actual renderer request/load, Main/OSD/lifecycle integration, invalidation
rebuild policy, native visibility and board fitting remain open. No MiSTer
contact or new Quartus flow has been performed for this component.

Latest descriptor-half follow-up: current cache `e9671fb7…` has an opt-in
committed descriptor-bit selector and unconditional synchronous payload reads.
Default caller-half behavior and two-edge response latency are retained.
All current focused half/default/lifecycle/CPU gates are terminal pass
(17/19/13/11 runs):
`x1-z-kanji-cache-half-t5ez__di`, `x1-z-kanji-cache-fqlxtk26`,
`x1-z-kanji-quiesce-jz3781bk`, `x1-z-kanji-cpu-service-iknm9csp`. Read-only
review `x1-z-cache-half-review-y9kkuwuv` verifies all sources/executables/logs,
warning inventories, twelve complete CPU boots and 12,504 CPU port reads.
All default/lifecycle/CPU positive counters equal their original frozen runs.
Remote probe session `26174` is terminal zero under
`/tmp/x1-z-sync-half-quartus-build-ylqMb5g3`: bit 22 `asZgXCno` fits at
138 M10Ks/3,715 ALMs/4,314 registers; default `kInFAoiz` at
138 M10Ks/3,717 ALMs/4,327 registers. Log:
`/tmp/x1-z-kanji-cache-sync-half-quartus.log`. Retrieved reports, all six bound
inputs, post-build hashes and actual elaborated parameters pass review in
`x1-z-cache-probe-retrieval-6mnss6j8`. See
[cache-half status](TURBO_Z_CACHE_HALF_STATUS.md) for exact contracts, warnings,
hashes and all logs. Earlier cache `8e5d431f…` passed all
60 simulations but its bit-22 Quartus map failed RAM inference (276003),
without fitting. Preserve failed/default evidence under
`/tmp/x1-z-half-quartus-build-TcCWoQRu/output_files/` (`vsMjX5zf` / `mjupExsp`),
retrieved in `x1-z-cache-probe-retrieval-938gk4hh`. Do not treat that old
simulation/default fit as qualification of the repair. No MiSTer contact or
deployment occurred. No qualification started here remains live. Actual CPU
VRAM-write admission/publication and coherent renderer request/load are next;
the standalone half selection does not integrate them.

Latest CPU-service continuation: `make -C verilator test-z-kanji-cpu-service`
returns zero in session `51078`, folder `x1-z-kanji-cpu-service-ddlsilck`, log
`/tmp/x1-z-kanji-cpu-service-final.log`. Three positive configurations and eight
exact RTL mutants pass; separate strict bridge lint is warning-free. Connected
CPU builds preserve exactly 34 reviewed warning headers (32 inherited CPU,
two fixture reset observations), rejecting any new/changed warning.
This connects actual TV80/PCG components to the unchanged qualified font
service in a new fixture, outside the shared machine/board source graph.
The independent audit confirms 12 complete boots and 12,504 actual CPU port
reads, including retained-font reset and interrupted-owned-read recovery. A
read-only current/frozen source, executable, program/trace/log and asset review
also passes in `x1-z-cpu-service-final-review-u3o6kua6`. All jobs are terminal.
See [CPU-service scope](TURBO_Z_CPU_SERVICE_STATUS.md). Earlier full attempt
`x1-z-kanji-cpu-service-eeu0rsj0` is preserved: its premature-valid mutant
reached the real failure handler on read five rather than its required first
read. A deterministic 200-SYS-cycle first-reply witness now covers that case
without weakening the CPU or independent data oracle.
At that checkpoint, actual shared-machine/renderer integration was next. A
renderer cache request's half selection must come from its committed Kanji
descriptor; live `kan_vid[6]`
could select a different version even with a complete cached glyph. The later
standalone half extension above now supplies that selection. Real CPU
text/attribute/Kanji write admission/publication, Main/OSD reset, missing-font
boot policy, combined fit/timing and hardware gates remain open.

No matching local qualification process remained at resume. Current HEAD and
the local `alanswx/master` reference are `9ca0416`. Existing worktree edits,
including the pre-existing tracked `verilator/obj_dir/` deletions, are preserved.
No MiSTer load/reset/input has been sent during this continuation. Subsequent
isolated remote Quartus work is recorded below.

Latest service continuation: new standalone fair font arbitration and
cache/arbiter/consumer drain coordination remain outside `machine.qip` and all
boards/runners. `make -C verilator test-z-kanji-arbiter` returns zero, session
`55100`, folder `x1-z-kanji-arbiter-a_lyb7ux`, log
`/tmp/x1-z-kanji-arbiter-final.log`: two SYS32/100 positives and twenty exact
mutants. `make -C verilator test-z-kanji-quiesce` returns zero, session `59813`,
folder `x1-z-kanji-quiesce-btz0dt19`, log
`/tmp/x1-z-kanji-quiesce-final.log`: two connected real-cache/frontend/backend
positives and eleven exact mutants. All 35 builds/runs are warning-free.
Full source-bound contracts/counters and remaining gates are in
[service status](TURBO_Z_FONT_SERVICE_STATUS.md). New cold-upload quarantine
requires raw download low before retry, preventing an old held transaction
from creating a fresh START when permission returns. Earlier attempts and
all prior qualified dependencies are preserved. No new remote build or MiSTer
action was needed. Actual Z80/VRAM/renderer integration and consumer-hold/
Main/OSD dispatch are the next machine gates, before combined fit/timing.
The final read-only source/frozen-input/executable/log/rejection review passes
in `x1-z-font-service-review-2380tk29`. All jobs started here are terminal.
Both new targets are scheduled in CI; no hosted result is claimed.

Subsequent cache continuation: a standalone full-glyph cache/publication
component is now implemented, outside `machine.qip`, using the unchanged
qualified frontend/backend. Corrected Quartus 17.0.2 mapping/fitting on
`misterubuntu` returns zero at 138 M10Ks/3,720 ALMs/4,318 registers. All frozen
probe inputs and retrieved reports pass hash review in
`x1-z-cache-quartus-review-t0lbxjey`; see
[cache status](TURBO_Z_CACHE_STATUS.md). Final behavioral qualification returns
zero in session `76750`, folder `x1-z-kanji-cache-ibnd2_68`, log
`/tmp/x1-z-kanji-cache-final-qualified.log`: nineteen warning-free builds/runs,
three positives and sixteen exact mutants. Both full configurations require
all 262,144 font bytes through refill and checked VID replies. A final read-only
source/executable/log/probe recheck passes in
`x1-z-kanji-cache-final-review-6ik7sz8w`. The earlier owned resource-counterfactual fitter was deliberately stopped
after synthesis exposed uninferred descriptor RAM; its evidence is preserved.
No MiSTer is loaded. Fair arbitration and upload/reset coordination now have
the later standalone qualification above; actual machine integration remains open.

- Hardened machine suite: session `7943`, folder
  `x1-z-kanji-machine-suite-g9t3irkg`, log
  `/tmp/x1-z-kanji-resumed-hardened-suite.log`: terminal exit zero. All eleven
  phases pass, including seventeen auditor controls and three exact machine
  negatives with independent provenance audits. The full audit confirms fifteen
  cases, 262,688 CPU reads, fifteen frames and 3,072,000 exact pixels; frame
  periods and source/artifact preservation pass. A separate read-only review
  rehashes all 1,191 final-manifest files and phase seals. Manifest SHA-256:
  `219ae368f56b632f52a9310ef47df05ffe1bbeeba6108390dd424f03d37fcc35`.
  Collector binding remains `b05977f6…`; shared-machine RTL is unchanged.
- Frontend: the checker now verifies exact terminal counts and covers both
  rates, full changed-image retries after reset/error, CPU address changes
  after capture, clean START WAIT and held-consumer-reset upload admission.
  Final `make -C verilator test-z-kanji-frontend` returns zero (session `53716`),
  folder `x1-z-kanji-frontend-bbr7fokk`, log
  `/tmp/x1-z-kanji-frontend-final-address-ledger.log`: twenty-four positive
  profiles, fourteen exact RTL mutants and sixteen warning-free builds.
  The independent read-address ledger and bit-15 mutant guard byte-pattern
  aliases. Separate source/executable/run-log rechecks pass. See
  [frontend status](TURBO_Z_FRONTEND_STATUS.md). Earlier attempts remain
  preserved; a surviving START mutant exposed the clean-START coverage gap.
- The new `make -C verilator test-z-kanji-suite-driver` completes zero:
  two synthetic positive/prepared cases and twelve source/artifact/count/
  child-failure/deadline/interruption controls in `x1-z-kanji-suite-driver-c_4qgilm`.
  This executes mock child drivers, not machine RTL. New standalone DDR,
  frontend and driver-regression targets are scheduled in CI; no hosted result
  is inferred.

Final read-only cross-check: `x1-z-kanji-resume-review-h7fp02oi`, log
`/tmp/x1-z-kanji-resume-final-review.log`. All current/frozen source hashes,
frontend executables/logs and machine manifests/seals match. This continuation
qualifies standalone/frontend and synthetic-machine gates only; native fonts,
display caching and physical FPGA acceptance remain open.
The supplemental negative-evidence regression also returns zero against the
new negative folders: all fifteen exact controls, with original evidence and
sources unchanged, in `x1-z-kanji-negative-audit-regression-ctpc6b2q`, log
`/tmp/x1-z-kanji-resume-negative-audit-regression.log`. All jobs started in
this continuation are terminal; no local qualification needs to be polled.

## Historical October 10 stop/resume boundary

Latest verified pushed checkpoint is `3a6f5b4` on `alanswx/master`: passive
cassette PCG/GRAM observations, generated CPU-written GRAM checks and status
updates. Main interrupted only its own two local jobs on request; both return
130. No remote Quartus job or MiSTer was stopped, loaded, reset or sent input.
Preserve interrupted evidence; do not label it a functional failure or a pass.

- Native plane probe: session `26507`, PID 3960, folder
  `/tmp/x1-native-rallyx-cassette-iFzAfm/run83-plane-control/`. Interrupted before
  terminal report/dumps; partial waveform log remains. It does **not** provide
  the PCG/GRAM comparison yet.
- Hardened suite: session `6320`, driver PID 7884, folder
  `x1-z-kanji-machine-suite-khu9v_gz`, log
  `/tmp/x1-z-kanji-hardened-suite-main.log`. Early collector/audit and seventeen
  auditor controls pass; interrupted during full collector build. Its owned
  child group 8219 was drained/terminated by the wrapper; source/artifact
  preservation reports true. Whole hardened-suite acceptance remains open.
- Earlier complete suite `t859nax6` remains terminal pass and untouched. Three
  supplemental Main negative-provenance audits pass; the reusable regression
  also passes all fifteen exact controls in `x1-z-kanji-negative-audit-regression-bp4dzjk1`,
  log `/tmp/x1-z-kanji-negative-audit-regression-main.log`.

Uncommitted drafts must be reviewed/staged selectively on resume:

- `rtl/x1_z_kanji_frontend.sv`, `verilator/tests/x1_z_kanji_frontend_tb.sv`
  and `test_z_kanji_frontend.py`: standalone external-font CPU/ordered-upload
  frontend, outside machine manifest. Frozen 32-MHz review smoke passes one
  full 262,144-byte upload/readback plus eleven focused cases, zero warnings,
  in `x1-z-kanji-frontend-review-h5qgfl2m`. **Latest fixture additions are
  unexecuted**, and checker still expects the older marker. Update the checker,
  freeze final inputs and run the full 32/100-MHz/reset/ownership/malformed/retry
  matrix with matched mutants. Do not claim current draft qualification from
  the older smoke. Backend remains unchanged `638861b6…`.
- `audit_z_kanji_machine_negative.py`,
  `test_z_kanji_machine_negative_audit.py`, `run_z_kanji_machine_suite.py`:
  qualified negative-provenance audit/regression plus hardened orchestration.
  Hardened wrapper hash `8f55095e…`; complete real rerun was interrupted.
  Reusable mock-driver port remains unfinished.
- `mame_rallyx_reference.lua` and `docs/RTC_CASSETTE_PLAN.md`: completed
  read-only MAME observations and a **proposal**, not a combined device build.
- Separate pending HDMI files: workflow/Makefile hunks, context auditor,
  inactive-data SDC, Tcl mock and `test_held_sdc_context_9cc.py`. Main's latest
  synthetic 9cc test passes 26 provenance, 22 byte/missing-file and 37
  scope/preservation negatives; no native timing acceptance follows.

On resume, first inspect `git status` and verify no previously owned process
remains. Explicitly stopped jobs may be rerun in **new** disposable directories;
never overwrite frozen evidence or restart a merely slow live process.

## Pushed checkpoints

- `35b4dbf`: strengthened independent Z machine auditor and external-font
  implementation plan; seventeen bad-evidence controls reject.
- `8305e17`: opt-in full-size Z Kanji shared-machine CPU/display integration,
  exhaustive physical CPU reads, bounded loader/reset/pixel diagnostics and
  reusable evidence-audit regression. **Not native fonts or FPGA storage.**
- `7dfcfeb`: standalone full-font DDR command backend; Main's independent
  32/100-MHz/max-base full-byte rerun and nine matched mutants/overflow checks
  pass without warnings. External loader/cache and board integration remain open.

- `5438892`: separate delay-aware cassette runner passes 25 generated-asset
  checks: exact 40/80-column pixels, actual PS/2 Ctrl+C/plain-C behavior and
  retained tape cursor/partial-slot phase over repeated warm resets.
- `e7c4f6a`: independent cassette evidence/pixel audit and primary-document
  Kanji source/level/half/row controls. Four disposable evidence mutations
  reject at their matched assertions.
- `58ad1de`: full 256-KiB Z simulation-reference store and highest-cell
  selector, independently rerun. All physical bytes and loader/reset/clock
  gates pass with three rejecting mutants. **Not machine or FPGA acceptance.**

Remote: `alanswx/master`. Preserve existing worktree changes; stage selectively.
Private ROMs/media, dumps, snapshots and native screenshots remain ignored.

## Worktree and live qualification

Shared-machine Z Kanji integration is **opt-in and synthetically qualified**:
`rtl/sharpx1.v`, `rtl/x1_pcg_access.v`, `rtl/legacy/x1_vid.v`,
`rtl/machine.qip`, and new machine fixtures. `TURBO_Z_KANJI` is default-off,
requires the Turbo/X3/Kanji/render combination and excludes DMA. Ordinary
boards/runners do not enable it. CPU requests freeze an 18-bit address and
retain the real WAIT/response protocol. Display requests capture character,
Kanji controls, attributes and raw raster together; response validity is checked
at glyph load. The initial supported Kanji raster is high-resolution 25-line,
16-raster normal-size text. Unsupported/invalid Kanji suppresses text ink after
reverse/blink; that does not force underlying graphics to black. Other row,
double-width ANK/PCG, underline and native ASIC policies remain unqualified.

Latest isolated generation audit against `e7c4f6a` passes: **two ordinary
base/Turbo models**, eight core files total; five headers and three serializers
per model compare byte-identical, with unchanged 60 warnings each. This is
not eight different machine profiles or runtime snapshot acceptance. Evidence:
`/tmp/x1-ordinary-state-e7c4f6a-latest.0gLaZm/`, report SHA-256
`5e32e886bb0b9e6d1faf8383ca943f187f2e5a47f1b987a94f2f3b88b7b37b27`.
Current enabled-Z lint, ordinary headless build/smoke and adjacent CG/WAIT/CPU
checks pass. The early frozen `zgfae1jf` probe/render80 collector completes;
Main's independent read-only audit confirms 32 actual CPU reads, three frames,
768,000 exact RGB pixels and frame periods with unchanged evidence. This is
synthetic high-resolution normal-size Kanji, not native font or FPGA acceptance.
The larger `hhofb8uy` collector now finishes zero. Main's strengthened audit
confirms all fifteen cases, 262,688 CPU reads (including every physical font
byte), fifteen frames and 3,072,000 exact pixels with frame-period checks.
Frozen/current sources and evidence remain unchanged. Three separate disabled,
half-major and missing-display-response controls reject at matched assertions.
The reusable auditor regression also passes two baselines and seventeen
evidence-mutation/optimized-execution controls; Main rerun evidence is
`x1-z-kanji-audit-regression-d9pqixzx`, log
`/tmp/x1-z-kanji-audit-regression-main.log`. These are synthetic diagnostics,
not native fonts, FPGA backing storage or hardware acceptance.

Existing jobs must be polled, **not restarted because observation times out**:

| Job | Handle / evidence | Last verified state |
|---|---|---|
| Native Rally-X, older frozen cassette runner | session `53472`; `/tmp/x1-native-rallyx-cassette-iFzAfm/run130-autoload/` | Terminal exit zero, 130 physical seconds, 524,717 samples, zero underflow; partial score/map/car display, no gameplay acceptance |
| Native Rally-X exploratory keyboard / no-input control | sessions `21805` / `56833`; `run83-input` / `run83-control` under same native folder | Both terminal exit zero; input reaches PUSH START BUTTON/CREDIT 02, no-input remains partial; not gameplay or release-correct controls |
| Native Rally-X passive plane observation | session `26507`; `run83-plane-control` under same native folder | User-stopped, exit 130; no terminal dumps/report, not a result |
| Ordinary delay-aware regression | session `53793`; `/tmp/x1-z-kanji-ordinary-regression.log` | Terminal exit zero; 164 PASS lines; pre-final Z-only repair source scope below |
| Ordinary fast/snapshot regression | session `26203`; `/tmp/x1-z-kanji-ordinary-fast.log` | Terminal exit zero; 144 PASS lines |
| Final-current ordinary delay-aware repeat | session `67295`; `/tmp/x1-z-kanji-final-current-regression.log` | Terminal exit zero, 164 PASS reports after final Z-only repairs |
| Exhaustive shared-machine Z Kanji | `hhofb8uy`; Main audit log `/tmp/x1-z-kanji-full-main-audit.log` | Terminal collector and independent audit pass, not hardware/native acceptance |
| Reproducible complete Kanji suite | session `64002`; folder `x1-z-kanji-machine-suite-t859nax6`, log `/tmp/x1-z-kanji-complete-suite-main.log` | Terminal exit zero: early/full collectors and independent audits, seventeen auditor controls and three machine negatives; supplemental Main negative-provenance audits also pass |
| October 14 hardened Kanji suite | session `7943`; folder `x1-z-kanji-machine-suite-g9t3irkg`, log `/tmp/x1-z-kanji-resumed-hardened-suite.log` | Terminal exit zero: eleven phases, full independent CPU/RGB audit, seventeen auditor controls, three independently audited machine negatives, 1,191 sealed artifacts preserved |

The delay-aware regression began before the final Z-only blanking/eligibility
repair; its executable/source scope must be distinguished from final-current
acceptance. Do not edit a frozen collector's inputs while its job is live.
Regenerate final-current checks after integration stabilizes. The native tape
job uses an older immutable executable/assets and is unaffected by these edits.

Full-font external backing work is now described in
`TURBO_Z_EXTERNAL_FONT_PLAN.md`. Original standalone DDR backend and tests are
pushed as `7dfcfeb`, outside the machine manifest. Full-font 32/100-MHz/max-base
checks, nine rejecting mutants and overflow checks pass. The standalone ordered-
upload/CPU frontend now also passes twenty-four positive profiles and fourteen
exact mutants; see [frontend status](TURBO_Z_FRONTEND_STATUS.md). No display
cache, native write-visibility policy or board integration is yet qualified.

The local MAME Rally-X no-input reference completes zero with protected media
and unchanged inputs. Actual 83/130-second PNGs have a changing left playfield,
unlike RTL's partial frame. It observes repeated PLAY and STOP/REWIND; different
PB0/rewind policies are not a proven cause. Evidence is
`output_files/mame-rallyx-reference-siRvI2/`. Read-only memory follow-up
`output_files/mame-rallyx-memory-mStnwi/` also completes zero. A third reference,
`output_files/mame-rallyx-gram-4US3JD/`, adds direct-pointer mapped-bank-0 GRAM
captures at 83/130 seconds, with no I/O side effects or bank changes.
All previous evidence is preserved. Never compare RTL's bus `cpu_address` to
MAME's instruction PC. Main confirms matching code at 1540h..1576h but differing
random-generator seed words: RTL 0000h versus MAME FC1Ah/70F7h in the memory
follow-up. Native initialization reads minute/second from EF; the cassette-only
inherited clock does not advance. This is a concrete lead, **not** a proven
gameplay fix. The combined RTC/cassette and explicit clock-initialization
proposal is in `RTC_CASSETTE_PLAN.md`; implementation remains unapproved/unmade.

Uncommitted passive cassette-runner PCG/GRAM dump extension now passes all
25 diagnostics in `x1-cassette-runner-2rjkcn2t` (session `94866`). Four video
cases verify eighteen actual CPU-written GRAM sentinels per case and physical
plane sizes; PCG payloads are not programmed/qualified by these fixtures.
Main separately verifies all 72 sentinels, rejects 28 in-memory width/boundary/
plane-swap controls and preserves all 431 original files and bound sources.
The same sixty HDL warnings remain after location normalization; sixty-six
warning-containing log lines include explanation links, with no C++ warnings.
This extension changes no shared machine RTL or private native assets.

The new `make -C verilator test-z-kanji-components` entry completes zero:
both clock-rate component scans and three matched mutants remain intact.
CI now schedules this asset-free entry; a hosted result is not inferred.

Uncommitted HDMI work remains separate: exact seventh whole-prefetch SDC bank,
strict 9cc provenance/report auditor, mock and CI time-budget changes. Original
full mock completes seven profiles/140 faults/1,048,569 mixed rejections.
Native same-fit preservation and a fresh accepted full flow remain pending.
The faster disposable pin-cache candidate is not the selected `b80a0946…`
candidate; never silently substitute its hash or reuse the original binding.

## Hardware and build-host ownership

October 14 user update: **misterubuntu is available for builds**, and
**mister14 (10.0.2.14) is available as the MiSTer test target**. This supersedes
the earlier instruction to leave mister14 untouched. Inspect its current core
and preserve existing configuration/media before the first deployment. This
availability update is user-provided. SSH confirms Quartus 17.0.2 on
`misterubuntu`; isolated cache resource probes are recorded above. The later
read-only memory/core inspection is recorded in the newest continuation above;
no deployment/reset/input has been performed to the target.

Historical October 10 target: **mister126 (10.0.2.126)** through `misterubuntu`,
with read-only identity `SharpX1` / `X1M_20261009T005633Z_01`. No load/reset/input
was sent during that follow-up. Leave `mister192` untouched.

At the October 10, 19:15 UTC read-only check the build host still had foreign `MacPPC7300`
`quartus_sh` PID 2459977 and STA PID 2477096, plus `SunSparcStation20` STA
PID 2476895. Recheck current host activity before launching Quartus; preserve
foreign jobs rather than assuming that historical PIDs are still active.
The isolated 9cc timing-study launcher remains deferred, not
completed. Primary remote checkout and fitted originals must remain preserved.

The current local TAP parser rerun completes zero with 356 synthetic checks
(`/tmp/x1-z-kanji-continuation-tap-parser.log`); transport/native loading is
not inferred from parser success.

Latest hardware-tested DMA RBF and scope are in
[the hardware feature matrix](HARDWARE_DMA_FEATURE_MATRIX_STATUS.md) and
[build status](DMA_BOARD_BUILD_STATUS.md); no current cassette/Z Kanji RBF
exists. The tester's black-screen report remains unresolved on their exact
RBF/ROM/Main; use [IPL loading instructions](IPL_LOADING.md), not a claim that
the reported hardware failure has been fixed.

## Next work, preserving the full goal

1. Connect the qualified writer and renderer adapter to actual machine decode/
   WAIT/readback, selectors and DDR ports in a separate non-savable profile.
   Drain the writer before lifecycle cache invalidation; resolve retained-cell
   reconstruction and missing-font boot policy. Use the committed descriptor
   for glyph half, all metadata and known-byte eligibility.
   Qualify actual machine RGB/reset/coexistence and ordinary identity, then
   integrate full FPGA backing memory and physical timing/CDC—do not truncate
   the font to fit spare BRAM. Resolve native font conversion and broader modes;
   current synthetic machine pixels cover only high-resolution normal-size cells.
2. Audit the new Rally-X plane observation and MAME memory comparison, then
   native cold repeats and release-correct controls.
   Cassette still needs other format/rate policies, recording/APSS, coexistence
   and board loading; diagnostics alone do not close base completeness.
3. Preserve the completed current ordinary/snapshot regressions. On an idle build host,
   run exact 9cc same-fit preservation, then source-bound full-flow timing/CDC
   qualification. Negative global setup is not timing closure.
4. Complete remaining SIO, DMA, HD/FDC and multi-device/reset/native gates;
   establish Arcus and Bastard Special gameplay rather than handler activity
   on black. Requalify the commercial-game matrix for each exact profile/RBF.
5. Finish Turbo Z native model/BIOS, palette/multi-mode/text ASIC behavior,
   FM/native sound, second-level font/hardware storage, mouse/serial/RTC and
   capture/effects pipeline. Run native software and physical acceptance.

Full requirements and open checkboxes remain in
[SHARP_X1_TODO.md](SHARP_X1_TODO.md), [Turbo Z roadmap](TURBO_Z_PLAN.md),
[Kanji status](TURBO_Z_KANJI_STORAGE_STATUS.md) and
[cassette status](CASSETTE_STATUS.md). Keep historical evidence scoped to its
actual source; do not convert v17 snapshots or relabel incomplete runs as passes.

October 16 00:10 UTC BASIC hardware continuation: generic first attempt omitted
index5; external-font lifecycle intentionally holds CPU until a complete font
is loaded. Its unbooted/noisy PNG is preserved, not a functional test pass.
Corrected stage session22668 is terminal zero, output
`output_files/X1BASIC_20261016T000625Z/`: complete synthetic d18c font, same
4-KiB base IPL and protected native BASIC. F produces blank640x200; later PNG
is byte-identical, no prompt accepted. RBF/media/original hashes pass. A third
isolated native Turbo-IPL/ANK16 probe runs in session24050,
`/tmp/x1-basic-hw-turbo.log`. The deploy helper now explicitly accepts 4/32-KiB
binary IPL, index4 ANK16 and index5 physical-font inputs, all exact-size checked
and remote-hash checked. Original helper bytes are saved in the CSPBasic output.
No RTL/RBF/compiler input changes. Do not infer BASIC hardware acceptance from
successful MGL deployment. The historical RTL session33526 remains running;
its reset trace window has not emitted yet. Do not restart on timeout.
