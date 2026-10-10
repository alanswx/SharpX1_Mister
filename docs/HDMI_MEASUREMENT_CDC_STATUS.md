# HDMI measurement and palette reset CDC follow-up

October 10, 2026. These are RTL repairs with local tests, not accepted FPGA
timing or a new hardware build. The preserved fifth-fit audit still reports
global setup -9.659 ns; see `HDMI_MODE_STATUS.md` for that exact source/fit.

## Actual fitted causes

The worst fifth-fit setup path ends at `video_calc.old_vs~reg1|d`, from
`hdmi_out_vs~_Duplicate_1` on the selected HDMI clock into the HPS 100-MHz
measurement clock. Its first raw sample also feeds edge detection directly.
The separate `hdmi_vsync_to_sys` exception does not cover this consumer.

The next two setup paths (-9.533/-9.526 ns) end at external/internal palette
`display_selected|d`. The raw reset button `cfg[1]` passes through machine
reset and `display_allowed` into these video-domain selection D inputs.
These are setup/data paths, not recovery/removal checks. Reset-release CLRN
exceptions correctly do not hide them.

## Implemented repairs

`video_calc` now adds dedicated preserved `hdmi_vs_meta/hdmi_vs_sync` stages
on `clk_100` only when its existing `COHERENT_SNAPSHOTS` option is enabled.
Only the second stage feeds the inherited HDMI-period edge detector. Legacy
framework/default behavior is unchanged; no measurement-input timing cut is
added. This narrow framework edit is necessary because that measurement
consumer is inside `sys/hps_io.sv`, not the machine wrapper.

The palette owner's video permission now uses `!video_reset && !video_grant`,
without the redundant raw `!reset` bypass. Local reset already asserts
asynchronously from the same raw request and releases after two video edges.
With local release disabled, `video_reset` equals raw reset, preserving the
compatible equation. CPU permission, storage contents, ownership handshake
and WAIT rules are unchanged. No RAM reset or new clock is introduced.

## Executed local gates

- `test-hps-hdmi-measure`: three live unrelated source/measurement clock
  ratios, exact independent period counts, second-stage-only observations,
  stopped-clock retention/recovery and unchanged legacy behavior pass.
  An actual legacy-bypass instance fails the unchanged two-stage oracle at
  the expected assertion, not a timeout. No measurement registers are forced.
- `test-hps-video-cdc`: existing register mapping, four snapshot clock ratios,
  stopped-source recovery and legacy mapping pass unchanged.
- `test-z-palette-owner` and `test-z-palette-owner-local-reset`: connected
  physical storage/WAIT/retained-read checks and three independent-domain
  reset cases pass, including stopped clocks and fresh lease acquisition.
  The inherited raw-release negative still rejects its expected assertion.
- `test-machine-z-combined-control-reset`: real CPU cold/warm controls and
  stopped-video pending reset pass at three video rates, with its rejecting
  disabled-priority control. Wrapper PLL-stand-in lint passes separately.

Logs: `/tmp/x1-hps-hdmi-measure-connected.log` and
`/tmp/x1-z-palette-reset-bypass-regression.log`, both terminal zero.
The first live measurement fixture stopped immediately after dropping raw
VS and incorrectly expected the previous high sample to disappear without
clock edges. That attempt fails as recorded in
`/tmp/x1-hps-hdmi-measure-first.log`. The corrected fixture drains the low
before stopping, preserving the same period/synchronizer assertions.

| Source | SHA-256 |
| --- | --- |
| Palette owner | `20bac5d0bb3e2d187601c613c961c16da5b11e1216368f26832583d8d5aef09d` |
| HPS integration/measurement | `5881470b83532a7534b022542ed5f0faf19db36298057083aa4f9f13ad2c5d6a` |
| Live measurement fixture | `bb4f363d15a17f30f2bb289e0b040f48183800e86fb6902485eda47da94df03f` |

### Review-driven verification strengthening

A separate read-only review identifies two gaps in that first fixture:
correct period values can hide a consumer updating at the wrong edge, and
forced register-mapping tests do not establish live HPS readout. The strengthened
fixture varies source intervals and checks the actual period register on
**every** 100-MHz edge against independently held expected data. It then
generates an actual interval longer than 65,535 cycles and reads both HPS
halves through the live snapshot/selector path, without forced registers.
All three opt-in ratios and the unchanged legacy route pass.

`test_hps_hdmi_consumer_negative.py` changes only the edge-detector input in
a disposable source copy, leaving the dedicated sync signal intact. The
same unchanged live oracle rejects this consumer-only bypass at its exact
update-edge assertion. Production source and fixture hashes remain unchanged.
This closes the observed test gap, not native fitted fanout or MTBF acceptance.
Connected log `/tmp/x1-hps-hdmi-measure-consumer-final.log`, terminal zero;
current strengthened fixture SHA-256:
`232850a77e99ebe08144f64072ca90869dd5423a459f8ed70189f963e3966890`.
The earlier table records the original fixture used by the earlier logs.

The fresh combined Z pixel matrix has started from frozen runner
`f6eb69653a34db659ce253ad1fde8f09e5cfcb23aea2d86bde9a68197c0124a6`
under ignored `verilator/obj_dir_v17_z_reset_bypass/qualification-cfbnUw/`.
All seven requested profile flags and SYS32/VID42.954540 pass actual preflight.
Runner/oracle/emitter/ANK are frozen before execution, alongside a source
archive; `all-120/completed.json` is the incremental authority. Log
`/tmp/x1-z-reset-bypass-all-120.log`. Launch/preflight is not pixel acceptance.

## Remaining physical gates

Fresh fitting must prove the raw reset no longer reaches palette selection
D pins and that HDMI stage one has only stage two as a consumer. Review actual
stage placement, downstream setup/hold and source pulse widths/MTBF. Any future
input exception must be narrowly guarded against that fitted topology; no
blanket measurement, reset-register or inter-clock cut is justified here.
Global timing, PCG-WE, I/O, native measurement behavior and hardware remain open.

The requested fresh `aa05dd2` full flow is not launched at the first host
check, 10:30:32 UTC: DSPPC604 Quartus shell/fitter PIDs 2001830/2002631 are
active. No source snapshot or probe is created and no competitor disturbed.
This is a busy-host observation, not a compilation failure or timing pass.

The next idle-host check permits launch at 10:35:07 UTC. The source-bound
`aa05dd2` flow finishes synthesis, fitting and assembly, then exits 3 at
10:43:50 UTC: the existing handoff input guard rejects the fitted
`completed_generation~DUPLICATE` source replica. This is not acceptance of
the new measurement synchronizer or reset repair, nor completed constrained
timing. Reporting-only inspection must establish the actual replica's
fan-in/fan-out before any constraint change. See
[the build record](DMA_BOARD_BUILD_STATUS.md#october-10-current-source-build-gate)
for frozen inputs and the unaccepted artifact hash.

Reporting-only inspection subsequently completes on the same fitted database
after the host becomes idle at 11:00:25 UTC. No SDC is loaded or timing cut
changed. Exact-edge and driver logs show `hdmi_vs_meta` feeding only
`hdmi_vs_sync`, which feeds `old_vs~reg1`; both stages use the HPS user clock.
The external/internal palette selection D endpoints each have 78 upstream
register fanins, without raw `cfg[1]`, `status[0]` or `ioctl_download`.
Their CLRN pins are driven by the video-local release pipe. This confirms
those narrow fitted connections, not timing closure or MTBF.

The handoff primary and `completed_generation~DUPLICATE` each expose exact
CLK/ASDATA/Q pins. CLK has a common `gate|outclk` driver and ASDATA a common
`completed_generation~3|combout` driver. `completed_meta` takes primary Q,
not duplicate Q. The duplicate feeds the primary/duplicate feedback cone,
not a first-stage synchronizer directly. Identical D/clock routes alone do
not establish reset/startup/control equivalence; that review remains before
any guarded replica allowance. The original refusal remains intact.

Preserved local reporting evidence:
`/tmp/x1-aa05dd2-topology.Eu3NqBQI/topology-aa05dd2-QaH3AJQC`.
The agent records three terminal-zero probes, unchanged fourteen original
source/artifact hash pairs and 409 snapshot inputs. Main reads the exact
pin/driver logs independently. Driver-log SHA-256:
`99343dce92bc33cf77898a3e2a41a318ffcf4319f571407b3ee423f4bca1d191`.

### Same-fit control inventory follow-up

An idle-host reporting-only follow-up finishes at 11:29:11 UTC, native exit
zero. Main independently reads the exact control log, checks its SHA-256 and
compares the fourteen before/after artifact hashes and provenance manifests;
both pairs are identical. The agent's frozen-input audit separately records
409 unchanged snapshot inputs. Local evidence:
`/tmp/x1-aa05dd2-topology.Eu3NqBQI/control-aa05dd2-kanIjW7N`.
Native log SHA-256:
`038305a7ebf672b6215765a467e775fd69bb63e1af63284157c3838a8b506e7d`.

Both fitted FF atoms expose the same noninverted CLK and SDATA drivers;
SLOAD is constant VCC with no inversion. ENA/CLRN/SCLR have no represented
atom port (query returns -1), not a claim that physical resources do not
exist. Both atoms have power-up zero, power-up-don't-care disabled and an
inverted registered Q, in ARRIAV_FF/LAB mode. PRN/ALDN queries are unsupported,
not evidence of absent controls. Eight warnings concern unavailable pointer
metadata; the supported control queries complete successfully.

The primary reports DATAIN-promoted-to-ADATASDATA=1 and router-created=0;
the duplicate reports 0 and 1 respectively. Matching represented controls
and startup strengthens the ideal sequential-equivalence evidence but does
not prove physical hazard freedom, timing or MTBF. Installed primitive edge
semantics and a fail-closed replica guard remain under review. No SDC change,
new cut, full-flow acceptance or hardware loading follows this inventory;
the original replica refusal remains intact.

The documented reporting-only post-fit Verilog export is attempted once when
the host is idle, 12:21:52–12:21:54 UTC, against the exact frozen aa05 database.
`write_atom_netlist -verilog` crashes in Fusion name conversion; native exit 2,
no `post-fit.vo` generated. Main reads the stack/terminal result and verifies
native-log SHA-256 `2076156f9eeca7479ff13702c4869ff1fd24035ec0002aa1a9f05d5a4419ae3e`.
Main compares the fourteen artifact/source before/after manifests unchanged;
the agent additionally records 512 database and four provenance pairs unchanged,
and 409 frozen inputs verified. Preserved evidence:
`/tmp/x1-aa05dd2-topology.Eu3NqBQI/atom-export-aa05dd2-vMWSeF6r`.
This tool failure supplies no omitted-control/promotion semantics. A documented
ASCII ATM reporting alternative is under investigation; the guard remains closed.
No SDC, new timing cut, full-flow acceptance or MiSTer loading follows the crash.

### ASCII inventory and narrow replication-prevention candidate

The reporting-only ASCII ATM export subsequently completes zero on the idle
host, 12:28:25–12:28:33 UTC, without warnings or errors. Preserved evidence:
`/tmp/x1-aa05dd2-topology.Eu3NqBQI/atom-ascii-aa05dd2-hZdVa5qZ`.
Main reads the decoded completion-source records and verifies the raw ATM
SHA-256 `a225ad159c8feeef873001bf377b8a7978cabf9127e14c871a597a4c80b3d216`
and native log `ba0e5131eee2f4a27449c4ab10ed512f289e078a70a6a13fd71e31302cbcede2`.
The primary and duplicate share represented CLK/SDATA/SLOAD and startup
controls; the duplicate identifies the primary as its synthesis provenance.
This still does not resolve omitted-control defaults or promotion semantics,
and supplies no timing or replica-equivalence acceptance. Before/after
artifact/source manifests remain unchanged.

Instead of allowing that replica through the SDC, the candidate applies
`(* dont_replicate *)` only to `completed_generation`, alongside the existing
`gate_request` attribute. Scalar initial values and sequential logic are
unchanged. The installed Quartus 17.0 Verilog template explicitly supports
this variable-declaration syntax; the earlier fitted gate-request attribute
maps to `ADV_NETLIST_OPT_ALLOWED = Never Allow`. Neither proves that a new
fit will preserve the completion source or close timing.

The SDC remains unchanged, with six exact source/first-stage cuts and all
identity/driver/fanout guards before exceptions. A new mock negative models
the exact `completed_generation~DUPLICATE` failure; ten invalid inventories
reject before any cut. The board-profile check permits only the two exact
attributed declarations. The historical 3c source-integrity fixture now reads
immutable 3c fit/cef diagnostic sources, rather than misbinding a changed
controller to old fitted results; the auditor's literal hashes and rejecting
source controls are unchanged. Fresh native-primitive and full-flow fitted
acceptance remain required. No new RBF is qualified or loaded by this edit.

The connected local `test-hdmi-handoff-input-sdc` and
`test-hdmi-handoff-board-profile` targets complete zero after the fixture
repair. Log: `/tmp/x1-handoff-completed-no-replica-local-repaired.log`.
The original attempt failed the historical source-binding assertion and is
retained in `/tmp/x1-handoff-completed-no-replica-local.log`; this was not a
native timing failure. Synthetic positives and rejecting controls do not
replace a new fitted inventory. CI now fetches complete project history for
the immutable historical fixture; no hosted CI result is claimed here.

### Fresh 16fa816 native gates and launched fit

The exact `16fa816713d4bf418e04f34fc5f4949c660246eb` detached worktree
passes 96 native reset cases, six normal extracted-policy cases and six
synthetically delayed-policy cases. Main independently reads their completed
footers and terminal files and compares source/runtime before/after manifests
unchanged. Normal: 5,030 exact output checks, 204 first-edge holds and 10,273
native-HS policy checks; skew: 5,032, 192 and 13,143 respectively. Skew is
transport-delay qualification, not fitted routing. The known primitive-model
warnings remain; this is not a zero-warning synthesis claim.

Evidence root on misterubuntu:
`/home/alans/mister/SharpX1_Mister/output_files/handoff-16fa816-L1wzVxzQ`.
SHA-256 of the completed driver logs:

- `reset.log`: `3b02e0320b80a80471089ae04aaa86534a4463b8cc1ad9473acc194f4e06c34c`
- `normal.log`: `1da15f11ccc1f751711cd77a86e44fa01fe5f26b298b7646486b4ca8cd56359e`
- `skew.log`: `a33e3441afead5744e332fc40fce7e35fd8a592b9683b75eba9fb96b2b597820`

After another idle-host check, the source-bound handoff flow launches at
12:44:21 UTC October 10. Main confirms actual Quartus shell PID 2134800
running, not merely a launch/state file. Frozen source:
`worktree/output_files/quartus-linux-MS3GQ1PO/source` under that evidence root;
input manifest SHA-256
`365713fe66c9a70a69e497468646f8a4549ed98079bebc64462ce2d340b38992`.
Remote log: `/tmp/x1-quartus-16fa816-handoff-OcwH65RD.log`.
Primary checkout remains unchanged and all SDCs match the prior source.
Final topology, full timing/MTBF/I/O and RBF acceptance remain pending;
no MiSTer is contacted or loaded for this build.

The flow subsequently terminates **exit 3 at 12:52:48 UTC**, elapsed 8m27s.
Main reads the actual stage outcomes: synthesis, fitting and assembly complete;
final STA rejects a newly fitted whole-prefetch D/ASDATA profile. The previous
completion-source replica rejection is not the reported failure on this fit,
but full native topology remains an independent gate. No pin-profile guard or
exception is relaxed. Partial STA reports setup -9.879 ns, incomplete setup/
hold constraints and no design MTBF; because SDC loading failed, this is not
an accepted final timing result.

Main verifies completed driver-log SHA-256
`74661c53a50c08777ee3808601eba58d1f7e1342f4aad990727599bd7d6ca68d`.
The assembled but **unaccepted** RBF SHA-256 is
`45110cb947f00fa690e2b28a24cf666fc363bf9b37513d151c270645dbb6f483`.
It is not deployed. Reporting-only fitted discovery and before/after path
preservation are next; the host's independently running MacPPC fit prevents
launching another native probe until idle. Preserve that other build.

### Exact 16fa816 inventory and same-fit constraint qualification

The subsequent idle-host inventory (13:03:21–13:03:29 UTC) preserves the exact
51 keepers, 205 pins, 77 DATA pins and 109 drivers. The six prefetch ASDATA
keepers are `hdmi_dv_hs`, `hdmi_dv_vs`, and data bits 5/6/9/11; the remaining
observed prefetch keepers use D. All 24 canonical DV drivers and the six guarded
input driver/fanout records match, with no completion-source replica. Raw
inventory SHA-256 is
`fdda3bcc5f139f8691d497ab1dffd16072653205d80f24d908a2f5733c173b6d`.
This supports the narrow replication-prevention attribute, not global timing.

An isolated, initially unselected sixth-bank proposal then runs on the same
preserved fit, 13:15:25–13:16:58 UTC, exit zero with no native errors/warnings.
Main independently audits all 384 actual reports, verifies every report hash
and source/ordered manifest equality, and checks all eleven actual bound files
on the build host. The study preserves 928 held-budget rows and 6,816 active/
raw/mode rows, excluding only 848 inactive-parent rows. It does not broaden
the cut to CLK/SLOAD, raw CDC, I/O or arbitrary per-bit packing. Diagnostic
global setup/hold are **-9.721/+0.054 ns**, not accepted timing closure.

Copied evidence: `/tmp/x1-16fa-context-evidence-G51hHNFH/held-context-16fa816-v1`.
Native log SHA-256:
`ea5fcde85afb610532ccfe0a1a2c0a0cc1875090c7b40b00f047372fe59402e8`.
Original source/proposal/five-artifact hashes remain unchanged. Database
preservation is explicitly partial: 508 existing files unchanged, four changed,
13 added, none removed. Main verifies the original database archive SHA-256
`a20fba498e28f8f6447e30f70fae022fdf62aa1dfcec74d7e7de4ae5d4df2dcd`.
Neither the database nor diagnostic global path ranking is claimed unchanged.

The reviewed production candidate now allows this exact sixth whole-bank
profile only. `--fit-16fa816` binds the original fit and staged study bytes,
including all five actual artifacts; it deliberately retains the staged hash
rather than replacing it with today's selected SDC hash. New synthetic checks
pass 26 provenance, 22 actual-byte/missing-file, substituted-fit and 16 report-
preservation negatives. Historical 048/3c bindings remain separate. Main's
independent staged six-profile test completes zero, including 120 scope negatives
and 131,066 mixed-bank rejections before any cut; log
`/tmp/x1-16fa-independent-scope-test.log`. The selected production-scope rerun
and a fresh committed-source full flow remain required before this candidate
can produce another accepted build; no new RBF is loaded.
