# PCG request/response bundle window audit

October 9, 2026. This qualifies digital handshake timing in the shared
`rtl/x1_pcg_access.v` module, not a new constraint or hardware pin contract.
At the original bundle-window checkpoint, production RTL was unchanged (SHA-256
`578e37ddba614e1c8c68734c1e08d337b75215e4abf424a19eff6deea84fb767`).
Source-bound FPGA PCG setup failures remain recorded in
[Z fit evidence](TURBO_Z_OWNER_RESET_STATUS.md).

## Observed transfer windows

The real CPU-side request toggle accompanies frozen transaction fields.
The video side observes it through `request_meta`/`request_sync`, then starts
an access on a later edge (or later still when the high-speed window is
closed). Minimum request-consumption window is two video periods. RAM access
and response/ACK publication follow additional video stages. CPU consumption
follows ACK through `ack_meta`/`ack_sync`, giving at least two SYS periods
from response publication. These are master-clock windows, not CPU CE ticks.

The strengthened fixtures timestamp actual request changes, actual stage-zero
admission and actual stage-two response publication. They assert the minimum
windows when the real CPU-side completion condition is met, rather than
assuming that a changed `cpu_q` necessarily means a completion. No DUT state,
response, RAM contents or clocks are forced. Existing reset cancellation,
waits, memory values and one-write-per-transaction assertions stay unchanged.

`test-pcg-bundle-windows test-turbo-pcg-access` finishes zero
(`/tmp/x1-pcg-windows-final.log`):

- Base fixture: three inherited clock ratios and SYS=32 MHz with video
  half-periods 17,500/11,640/25,000 ps. Each completes 28 request and 28
  response window checks, all planes/bounds/ROM protection and held strobes.
  The accepted 11-bit plane/write/data bundle stays unchanged until ACK.
- Turbo fixture: three inherited video ratios and two recurring-window widths,
  each with 16,395 original high-speed transactions. All PCG/font addresses,
  frozen live-input mutation, held read tail, unsupported writes, closed-window
  WAIT, stopped video and staged/post-ACK reset regressions still pass.
  Window counters report 16,399 admissions and 16,396 responses, including
  separately issued reset probes; they must cover every completed transaction.
  The complete 37-bit accepted field group stays immutable while busy. This
  group includes the CPU-only font address: it is **not** a claim that all
  37 bits cross into video. These inherited cases use SYS=100 MHz.

The additional `test-turbo-pcg-native-windows` finishes zero with
`test-pcg-bundle-windows` (`/tmp/x1-pcg-native-windows.log`). It preserves all
six inherited Turbo profiles and adds six SYS=32 MHz cases: video half-periods
17,500/11,640/25,000 ps, each at recurring-window widths 1 and 3. Every added
case passes the same 16,395 transactions and 16,399/16,396 window counts.
Response assertions now derive their bound from the selected SYS period;
request assertions likewise use the selected VID period. The 11,640 ps case
approximates X3 at fixture picosecond resolution, not an exact PLL waveform.
No native CPU/firmware, metastability or pin-timing claim follows from this
standalone fixture.

Both sets are selected in local CI, alongside the six-ratio snapshot test.
No new warnings/suppressions are introduced by the timing observations.

| Fixture | SHA-256 |
|---|---|
| Base | `958ff9423e1f5966ad00c4f3976f3f334605f5f56aa7f7610d400e0ede51133f` |
| Turbo, including native-rate extension | `fce93833625dcd2e9448fa862bb1b4a0f79a763446f47afd3d95186f055bf564` |

## Remaining constraints/acceptance

### Local-reset write-permission repair

The follow-up removes the redundant raw CPU `!reset` qualifier from
`access_write`. With `SEPARATE_VIDEO_RESET=0`, `video_reset_active` is already
CPU reset, so ordinary base/single behavior is unchanged. With separate
reset, the caller must supply asynchronous assertion together with CPU
reset and destination-clock release. Every current separate-reset caller
uses `x1_reset_release`; independent uncoordinated reset inputs are not a
supported cancellation contract. The existing VID stage and frozen write/
plane payload still qualify exactly one RAM write per accepted transaction.
No timing exception, reset register, or payload/ACK protocol is added.

This addresses the direct combinational CPU-reset-to-VID-WE source route
identified in the joint HDMI probe. Only fresh fitting and exact RAM-WE
fan-in/timing inspection can establish that the physical route is removed;
reset recovery, payload timing, raw synchronizers and whole-core timing still
require their separate gates. No older RBF qualifies the repair.

X3 snapshot identity adds bit 38 (revision 3), leaving ordinary v17 and the
other device identity bits unchanged. An actual frozen previous X3 runner,
SHA-256 `da47f228c34a9d095fcccc47398ea114d3fee2dc35cd01dcb40d2d20ac33f5c2`,
generates an unmodified state rejected before deserialization by the new
runner. Fresh continuation, same-rate base/Turbo rejection and asset-upload
rejection pass (`/tmp/x1-pcg-reset-prior-state-rejection.log` and
`/tmp/x1-pcg-local-reset-snapshot.log`). No snapshot bytes were converted.
The earlier frozen combined-Z matrix is historical source evidence and
continues independently; its results cannot qualify this newer machine.

Repair RTL SHA-256:
`05a0f8434dc5097fd3ba7cf2b71e912c94e3ae97f40626c0fe08f858e2c9919b`.

Fresh checks finish zero on this repair:

- All twelve Turbo helper profiles pass the stopped-stage cancellations and
  16,397 transactions each. Base/helper dependencies also pass.
- Three connected Kanji ROM/WAIT profiles pass 131,082 transactions each;
  six real-Z80 Kanji profiles pass 2,579 IN/INI checks per cold/warm run.
  Log: `/tmp/x1-pcg-local-reset-tests.log`.
- Shared-machine real-CPU PCG checks pass at both ordinary 28,571,428 Hz
  and X3 42,954,540 Hz video, with loaded/unloaded ANK16 and retained-asset
  warm reset. Log: `/tmp/x1-pcg-local-reset-real-cpu.log`.
- Request/response/reset constraint scope tests and experimental Z wrapper
  lint pass (`/tmp/x1-pcg-reset-scope-wrapper.log`). Lint uses the PLL stand-in,
  retains inherited warnings, and is not Quartus or hardware validation.

A fresh delay-aware combined-Z runner builds zero and passes its actual
seven-feature/clock preflight. Its full 120-case CPU/pixel matrix is now
running under
`verilator/obj_dir_headless/z-pcg-local-reset-combined/qualified-inputs-Eqh95G/all-120/`,
log `/tmp/x1-pcg-reset-z-combined-all-120.log`. Runner SHA-256:
`5622a916f4629e7d6d15fb3d7d5798d88c044e5350e36a79fb7d8195a8181437`.
Runner, oracle, emitter, scheduler, ANK source and RTL are frozen separately
from the older live matrix. An initial launch stopped before preflight because
the ANK copy used a nonexistent path; that failure log remains preserved as
`/tmp/x1-pcg-reset-z-combined-missing-font.log`. Copying the actual checked-in
`rtl/legacy/x1_cg8.v` fixes fixture staging, not an oracle or RTL assertion.
Started is not passed. The build host has source `d2df8a1` preflighted but
other users' active Quartus jobs prevent starting our fresh flow; none was
stopped, and no MiSTer was loaded.

`scripts/quartus_pcg_reset_inventory.tcl` now prepares a reporting-only
fresh-fit check: twelve fitted WE keepers (four per physical plane), exact
raw `ioctl_download` and both local-reset stages, native registered fan-ins,
then 64 reports across eight corners. It separately reports raw-download,
local-reset and all-source WE setup/hold, plus local-reset recovery/removal.
The 10,000-path cap must be checked against actual counts before claiming
coverage; absent raw paths alone do not establish removal or timing closure.
No exceptions or project assignments are issued. Script SHA-256:
`6817dc81f3c3ccc9221b1408b22720163c14f27c4ffa3df983b93e1918eda7f4`.
`test-pcg-reset-inventory` passes the mocked 64-report plan and eleven invalid
identity/count/alias/fan-in controls; invalid cases produce no report directory
or partial evidence. It is selected in CI. Native execution and independent
report/artifact-hash auditing remain pending a fresh completed fit.

The independent `scripts/audit_pcg_reset_inventory.py` now checks the prepared
64-report inventory: every fitted WE must appear in all-source setup/hold;
raw/local launch sources and clock domains must match; actual summary counts
must stay below the report cap; endpoint/clock multisets must stay unchanged
across corners. Eight original source/reporter/STA/RBF hashes are required
before and after, with the five source/reporter hashes checked against the
requested source tree. Empty raw/local discovery reports are not called
timing passes, and negative slack is retained explicitly as open timing.
CI's `test-pcg-reset-inventory` now also passes synthetic raw-present/raw-absent
cases, thirteen invalid report/scope controls and four invalid provenance
controls (`/tmp/x1-pcg-reset-inventory-audit.log`). These controls are not native
STA, physical source-route removal or timing closure evidence.

### Stopped-clock reset cancellation follow-up

The strengthened `test-turbo-pcg-native-windows` completes zero in
`/tmp/x1-pcg-stopped-reset-windows.log`. All twelve inherited/native-rate
profiles additionally stop VID at accepted stages 1 and 2, assert CPU reset
off-edge, and release CPU reset while VID remains stopped. They require
asynchronous local-reset assertion, zero write permission, no write-count
change during the stop or subsequent clock restart, retained font contents,
and a fresh successful read after each cancellation. Stage 2 permits the
write already completed before cancellation; it must never replay it.
Each profile now completes 16,397 transactions, 16,403 request-window checks
and 16,398 response-window checks. The two inherited `video_half_ps`
conditional-width warnings remain; no new warning suppression was added.

Fixture SHA-256:
`89e9a812042d447dd78e1e1d913d5be2d331deaeb40e6818e6d53def4922afe6`.
Machine RTL remains unchanged at the hash above. This adds cancellation
coverage before investigating the fitted CPU-reset-to-VID-RAM write-enable
path; it does not fix that timing path or qualify hardware placement, reset
skew, independent uncoordinated reset inputs, or native PCG scanline timing.

### Fresh fitted endpoint inventory

The reporting-only `scripts/quartus_pcg_bundle_inventory.tcl` executes on the
completed `32a3210` Z fit, with the existing project SDC unchanged. Native
Quartus 17.0.2 finishes zero, no warnings, at all eight Slow/Fast 1100 mV
temperature corners (`/tmp/x1-quartus-32a3210-pcg-merged.log`). Reports are
preserved under ignored `output_files/quartus-linux-EDi2XntO/pcg-inventory/`.
Script SHA-256 `9c7504273065d39884d3da1b4903fda5eed3cd55175f676747aaf99a65fd3a20`.

Map explicitly merges `frozen_addr[4..10]` into `font_cpu_addr[5..11]`.
Only four frozen-address registers retain their original names; blindly
constraining that prefix would miss seven address bits. The reporting group
therefore also includes all twelve font-address registers (28 source
registers total), deliberately retaining their ordinary SYS-only paths.
This broad source group is **not** a proposed exception. Request reports are
capped at 100 paths per check/corner, so they are reconnaissance, not proof of
complete coverage; unsupported/write-window control and each RAM pin path
still require dedicated enumeration before constraints.

The response group is exact: eight `response` and eight `cpu_q` registers.
Independent table audit finds eight response paths in each of sixteen
setup/hold reports (128 total). Worst existing setup is **−8.832 ns**,
minimum hold **+0.661 ns**, maximum data delay **11.290 ns**. This physical
delay is below the digitally checked 62.5 ns SYS capture window, but the
existing cross-clock edge relationship still reports violations. A scoped
bounded response constraint must be tested separately and refitted before
qualification; no PCG exception has been applied by this inventory.

### Analysis-only response bound

At the time of the completed-fit experiment,
`scripts/constraints/pcg_response_candidate.sdc` was not selected by any
QSF. It checks eight unique indexed registers on each side, then applies
31.25 ns maximum/zero minimum only from `response` to `cpu_q`. This is
stricter than the checked two-SYS-period (62.5 ns) consumption window.
Neither request/ACK synchronizers nor font/other SYS-only paths are excepted.

`scripts/quartus_pcg_response_probe.tcl` reads the completed fit's existing
SDC, reports the original selected timing, sources this exact candidate,
then reports selected and global setup/hold at all eight corners. Native
Quartus finishes zero, no warnings (`/tmp/x1-quartus-32a3210-pcg-response-bound.log`).
Independent table audit confirms 16 reports/eight paths each (128 total),
minimum selected setup **+22.048 ns**, hold **+1.061 ns**, and maximum data
delay **11.290 ns**. Reports are separately preserved under ignored
`output_files/quartus-linux-EDi2XntO/pcg-response-probe/`. Global setup/hold
still fail at **−15.053/−1.047 ns**. Original RBF and project constraints are
unchanged. This proves a completed-fit experiment, not a newly fitted candidate.

`make -C verilator test-pcg-response-sdc` also passes exact valid bounds and
twelve negative inventories (missing/duplicate/extra/out-of-range/wrong-field/
duplicate-suffixed endpoints on either side). Every negative refuses all
constraints. This mocked Tcl test is selected in CI, not a substitute for STA.

| Analysis-only artifact | SHA-256 |
|---|---|
| Response candidate | `9b0519981d3a2e2456527208521a102ec8172bf0a6fbeee094bbc154d1cd3cd9` |
| Native probe | `4ae2a938ff90f3a42a0d710d22f87c913f54e1e1ebd1768f7f33b6386e75cc2d` |

Project selection, source-bound refit, all-corner endpoint/physical-delay audit,
request/RAM-control enumeration and hardware acceptance remain open.

### Expanded request path enumeration

The reporting-only `scripts/quartus_pcg_request_paths.tcl` separates address,
control (including `unsupported_request`) and byte payload sources, then
reports SYS and VID destinations separately. It executes on the unchanged
`32a3210` fit at Slow 1100 mV 100 C, zero errors/warnings
(`/tmp/x1-quartus-32a3210-pcg-request-paths.log`). SHA-256
`16de557a8f23db4b00b37e0aecbc1a03af0bdbd466b7c08c8bd4d74b628ebd7f`.
Reports are retained under ignored
`output_files/quartus-linux-EDi2XntO/pcg-request-paths/`.

| Source group | Retained sources | VID paths / distinct destinations | Worst existing setup | Maximum data delay |
|---|---:|---:|---:|---:|
| Frozen/font addresses | 16 | 11 / 11 | −8.202 ns | 1.625 ns |
| Plane/write/high-speed/unsupported controls | 5 | 90 / 35 | −9.771 ns | 4.034 ns |
| Byte payload | 8 | 192 / 192 | −8.400 ns | 1.839 ns |

All reports use a 10,000-path budget; none hits it. There are 293 reported
VID paths per check and 154 SYS paths per check (144 address, ten control,
zero payload), 894 rows across twelve setup/hold files. This is static
critical-path reconnaissance, not every possible logic sensitization or an
all-corner request qualification. SYS address/control minima are +27.034/
+22.293 ns setup, +0.940/+0.482 ns hold and must remain ordinarily timed.

VID address endpoints cover all eleven `access_addr` bits, including the
map-confirmed font aliases. Controls reach eleven address bits, eight
response bits, `seen`, three fitted stage registers (including a duplicate),
and twelve physical PCG RAM write-enable registers. Payload reaches 192
replicated physical RAM data destinations. Merely bounding response or
`access_addr` therefore does not cover all request contracts. Dedicated
source/destination groups must include these real RAM pins and state-enable
paths, keep SYS-only font/control checks intact, and reject unexpected
endpoint inventories before any production constraints. No request exception
or new RBF is introduced by this enumeration.

### Eight-corner request bounds and experimental project selection

`scripts/constraints/pcg_request_candidate.sdc` validates all inventories
before issuing any exception: 16 address sources (including merged aliases),
five control sources, eight payload sources, eleven address destinations,
36 control destinations and 192 RAM data destinations. Exact source/vector/
stage identities are checked, with four write-enable and 64 data endpoints
per RAM plane. One control destination (`stage.10`) has no direct request
path; it is retained in the destination inventory rather than silently dropped.
Only these explicit source/destination pairs receive 23.28 ns maximum/zero
minimum bounds, stricter than the measured two-VID-period admission window.
CPU-only font/control paths and request/ACK synchronizers are unchanged.

The strict native probe finishes zero, no warnings at all eight corners
(`/tmp/x1-quartus-32a3210-pcg-request-bound-final.log`). Independent audit
confirms 48 reports and **4,688 paths**: exactly 11 address, 90 control and
192 payload paths per setup/hold/corner. Selected minimum setup/hold are
**+13.539/+1.092 ns**, maximum physical delay **4.046 ns**. Four normalized
SYS-domain setup/hold tables compare exactly with the unconstrained request
inventory. Global setup/hold still fail **−15.053/−1.047 ns**. Reports are
preserved separately in ignored
`output_files/quartus-linux-EDi2XntO/pcg-request-probe/`.

`test-pcg-request-sdc` passes the three exact bound pairs and 24 negative
inventory cases, all refusing every exception. It is selected in CI alongside
the response inventory test. Both tests finish zero after project selection;
they mock collections, not native timing or metastability.

The experimental **Z QSF only** now selects both PCG SDC files. Both Linux
and Apple snapshot builders now include/hash `scripts/constraints/*.sdc`;
other revisions and machine RTL are unchanged. Shell syntax checks pass.
A fresh source-bound full flow must validate fitting, endpoint retention and
all corners before this selection is qualified. Earlier probes do not
qualify new placement or the RBF. Native/physical acceptance remains open.

| Artifact | SHA-256 |
|---|---|
| Request SDC executed in strict probe | `62799e806df5243935524db9b7548f4f9c5dc3a5f007cdcf3195d5e503c6b736` |
| Request SDC after comment-only project-selection update | `14dbcb6181dbdc6d60a9ce04260ca61fea6bcfbf43ed946e48875882c53b0123` |
| Response SDC after comment-only project-selection update | `9d12a546dd9cbf1c89a53942ff99fe353755fe98b4ee4ce7cbbc05c7c7a34b9b` |
| Request probe | `3fe3b9c818afdb6399906945a68555635302f336ca7559b42bec1b67b5165be4` |

### Integrated refit fails closed; mapped inventory differs

The source-bound `bec30d0522af33314ce21181cd46c9259fae3d05` full flow in
`quartus-linux-kMsFZAWz` **fails**, terminal exit 3 at 16:29:07 UTC (1:57).
Log `/tmp/x1-quartus-bec30d0-pcg-build-final.log`; failed manifest/fitter report
are preserved in ignored `output_files/quartus-linux-kMsFZAWz/failed-flow/`.
Fitting reads both PCG SDC files but refuses the request `control_dest`
inventory, also warning that fitted `PORT_A_DATA_IN_*` aliases do not yet
exist. The later generic cannot-fit message is not independent evidence of
resource exhaustion. No RBF is produced or hardware loaded.

`scripts/quartus_pcg_mapped_inventory.tcl` then inspects the failed build's
post-map database **without loading any SDC**. It finishes zero with five
netlist warnings, recorded in `/tmp/x1-quartus-bec30d0-pcg-mapped-inventory.log`.
There are 23 machine state registers (no fitted `stage.01~DUPLICATE`) and
192 RAM registers: exactly 48 each of write-enable, data-in, A-address and
B-address, with sixteen logical RAM banks per plane. This differs materially
from the completed fit's twelve write enables and 192 replicated data
destinations. Neither a blanket count relaxation nor silently ignoring missing
endpoint patterns is acceptable.

**Current selection:** the request SDC is analysis-only again; its QSF
assignment is removed until the map/fitter endpoint transition is verified.
The response SDC remains selected only for experimental Z, not yet
fresh-fit-qualified. Completed-fit experiments above remain valid history,
not acceptance of this failed full flow. Next: enumerate the constraint-read
stage, establish explicit validated early/fitted profiles and preserve every
physical destination in post-fit checks, then repeat full flow/all corners.

### Verified early/fitted profiles; experimental selection restored

The revised request SDC first enumerates the RAM register bank, classifies
actual data/write-enable names, then requests those existing names. It no
longer queries nonexistent aliases or suppresses empty-filter warnings.
Exactly two recognized profiles are accepted:

| Profile | WE / data destinations | Control destinations | Per-plane WE / data |
|---|---:|---:|---:|
| Mapped | 48 / 48 | 71 (23 machine state + 48 WE) | 16 / 16 |
| Fitted | 12 / 192 | 36 (24 machine state + 12 WE) | 4 / 64 |

Source vector identities and merged address aliases remain mandatory. The
mapped state has three stage registers; fitted state additionally requires
the audited `stage.01~DUPLICATE`. Mixed, missing, duplicate and wrong-identity
inventories fail before **any** bounds are issued. Neither the SYS-only paths
nor synchronizer checks are broadened. No machine RTL changes.

Native sequential execution finishes zero
(`/tmp/x1-pcg-mapped-fitted-native.log`): post-map inventory/exception syntax
passes on the preserved failed `bec30d0` database (the five preexisting PLL/
netlist warnings remain). This does **not** perform timing without clocks.
The completed `32a3210` fit then passes the full eight-corner request probe,
zero warnings. Independently retrieved reports under ignored
`output_files/quartus-linux-EDi2XntO/pcg-two-profile-probe/` again contain
48 files / 4,688 paths, minimum slack +1.092 ns and maximum delay 4.046 ns.
`test-pcg-request-sdc` passes both profiles and 48 invalid inventories;
negative cases refuse all three bound pairs.

Experimental Z request selection is restored. These native checks validate
the two observed inventories, not every possible intermediate fitter
representation or a new RBF. A new full flow must still verify constraint
loading/packing, final profile retention, eight-corner timing and physical
delays. The failed prior full flow is preserved, never relabeled successful.
Executed revised request SDC SHA-256
`8201246c2a489c749e03426511668c03eee11ec1aed487525d8be81ae5caaeeb`
(subsequent project-selection header change is comment-only). Revised mapped
inventory helper SHA-256
`d4f2cbe80d3cec09e1432ecf29862dc9cb434e857d626eda245d712dc819e344`.

### Corrected fit completes; response replicas stop final STA

The `3dc37274ca56cdcd6264922dc6ceb9cb93fb583d` flow in
`quartus-linux-LWmGXN2m` fits successfully (zero fitter errors, eleven
warnings), then final STA rejects `cpu_q[0]~DUPLICATE`. Full flow ends
**exit 3**, 16:48:14 UTC, elapsed 8:19; log
`/tmp/x1-quartus-3dc3727-pcg-build.log`. The strict gate is not silently skipped.
Initial partially loaded STA reports still fail setup/hold/recovery, and
must not qualify any bus or complete project timing. Original manifest,
reports, input audit and RBF are preserved under ignored
`output_files/quartus-linux-LWmGXN2m/completed-fitter/`. The generated RBF
`21612f4cad108978e11efa257a5c433794dcff54c8cdf7b7fca68ae61c5bde13`
is **unqualified**, never loaded. Input audit: 382 matching files, only the
Quartus-rewritten QPF mismatch; frozen RTL/SDCs are unchanged.

The fitter's router-duplication table explicitly associates `cpu_q[0/3]`
with same-bit `~DUPLICATE` captures. Native fitted inventory without SDC
reports eight response bits, ten CPU capture registers, four stage registers,
four frozen-address and twelve font-address registers. The revised response
guard requires eight primary bits and includes at most one exactly named
CPU `~DUPLICATE` replica per bit. Missing primaries, duplicate replicas,
wrong field/bit/suffix and unchecked source replicas fail before bounds.
Every accepted CPU replica receives the same bounded response bus timing.

Native inventory/exception-syntax checks on the completed fit finish zero,
no warnings (`/tmp/x1-quartus-3dc3727-replica-inventory.log`), including the
strengthened request classifier. Unknown RAM data/WE suffixes now fail rather
than being skipped during name classification. Mocked tests pass 52 request
negative inventories and the response's twelve original/four extra replica
negatives (`/tmp/x1-pcg-replica-tests.log`). These native checks do not load
clocks or qualify physical timing; full source-bound refit/all corners remain
required. No machine RTL change or hardware/native-software claim.

| Revised artifact | SHA-256 |
|---|---|
| Replica-aware response SDC | `c7febd679ea944e88c314d6f5947eee44780511ca0b4e2240d51cfb71dcc6aba` |
| Unknown-RAM-alias rejecting request SDC | `b2d5aa5752b13febd99284e835acd445420fe24196980f12fbc459bb686c2bbe` |
| Fitted inventory/syntax helper | `6db2a0b73edede738f89137d5fa87e3e506415c5d7b11825c0120ebd9e5126a3` |

### Reusable report audit

`bash scripts/audit_pcg_timing_reports.sh REPORT_DIR FITTED_CPU_CAPTURE_COUNT`
now independently audits 48 request and sixteen response setup/hold corner
files. Supply the response count from the native fitted inventory, **not**
from the reports being qualified. It requires all eight primary CPU bits and
every supplied replica, exact same-bit response paths, source/destination
clock direction, all eleven address destinations, all five control sources/
35 known destinations, and all eight payload sources/192 distinct RAM data
destinations (64 per plane). Control write enables must cover four per plane.
It checks nonnegative numeric slack and physical data delay from column nine,
not clock skew, against 23.28/31.25 ns request/response bounds. A missing file,
wrong count/endpoint/clock, duplicate capture or failing bound fails closed.

The auditor passes the preserved `32a3210` native reports (eight captures)
collected in ignored `output_files/quartus-linux-EDi2XntO/pcg-audit-known-fixture/`.
`test-pcg-report-audit` additionally passes generated 8/10/16-capture fixtures
and rejects fifteen invalid report/count cases. These generated fixtures do
not prove native replica timing. The new target is selected in CI. The
auditor's fixed request inventory is the observed fitted profile, not a
generic substitute for revisiting endpoint coverage on future architectures.

The `67de103f105cafe31dfdb7e6e93ece1219728e5d` full flow now finishes
**exit zero**, 17:01:42 UTC, elapsed 8:20, in `quartus-linux-5wJWPc6b`;
log `/tmp/x1-quartus-67de103-pcg-replica-build.log`. Final SDC loading no
longer fails the replica inventory. Original manifest/reports/RBF are
preserved in ignored `output_files/quartus-linux-5wJWPc6b/completed-flow/`.
RBF SHA-256 `21612f4cad108978e11efa257a5c433794dcff54c8cdf7b7fca68ae61c5bde13`
matches the prior failed-STA run's binary, but the flow result/constraints
must still be qualified separately. Initial setup/hold/recovery fail at
−14.856/−0.552/−10.127 ns; the RBF remains **unqualified**. Input manifest
SHA-256 `6aff05809308fca9c8d999c006378345e773ebc40fc3f248eb2b35d9039f7d18`.

Sequential all-corner, fitted-inventory, same-clock/global, snapshot and PCG
audits now finish zero after host-idle/original-artifact checks; log
`/tmp/x1-quartus-67de103-pcg-acceptance.log`. Their before/after probe reports
already include integrated bounds, not an unconstrained comparison. No
current-fit payload timing claim was made until those reports were retrieved
and independently audited. No hardware is loaded.

### Fresh-fit payload acceptance, not full timing closure

The local report auditor now passes the actual `67de103` fit at **ten CPU
captures** (eight primary bits plus bits 0/3 replicas), as confirmed by native
fitted inventory. All 48 request / sixteen response corner files pass endpoint,
coverage, clock-direction, nonnegative-slack and physical-delay checks.
Request setup/hold minima are **+11.617/+1.106 ns**, maximum data delay
**5.960 ns**; response minima **+22.061/+1.085 ns**, maximum data delay
**11.294 ns**. Counts remain 4,688 request and 160 response paths, including
every primary capture and replica. This qualifies these bounded buses on the
source-bound fit, not native scanline-trap behavior or the entire design.

The independent snapshot audit confirms 16 files / 72 paths each (1,152
total), minimum selected slack +0.498 ns and maximum data delay 12.929 ns.
Retrieved reports and post-input audit are retained in ignored
`output_files/quartus-linux-5wJWPc6b/acceptance/`. Input audit confirms 383
matching files, only the Quartus-rewritten QPF mismatch; no RTL/SDC drift.

Global eight-corner setup/hold/recovery remain **−14.856/−0.591/−10.127 ns**,
removal/pulse minima +0.409/+0.529 ns. Slow 100 C same-clock setup is SYS
+7.199 ns, VID +8.503 ns, HDMI **−2.183 ns**. Thus the RBF remains unqualified
despite the newly accepted PCG and snapshot bus gates. The separate
[reset-input experiment](VIDEO_RESET_TIMING_EXPERIMENT.md) preserves chain/
downstream timing, but framework scaler recovery and actual HDMI routing
remain open; a further experimental reset-constraint refit is required.

Audit source payload paths into RAM data/write controls, selected addresses
and response selection separately; response-to-CPU is a distinct held bus.
First-stage request/ACK synchronizers require their own treatment, with the
second stages and ordinary same-clock logic still timed. Reset assertion/
destination-local release and owned DMA/video drain must remain correct.
One generic clock-to-clock false path would hide these separate contracts.
Use the checked window and measured fitted data delays to choose bounded
paths, then refit/all-corner/hardware qualify them. No PCG timing constraint
has been added in this increment, and digital success does not establish
native scanline-trap behavior, metastability, physical reset or native firmware.

## Later scaler-reset fit: optional state replica

The `8d94709` scaler-release flow fits/assembles but final STA rejects the
mandatory `.01~DUPLICATE` assumption. Native no-SDC fitted inventory shows
only primary `.00/.01/.10`; the revised guard includes the known `.01` clone
when present rather than requiring it. Both fitted profiles validate every
source/bit/RAM plane before any bound; mapped remains unreplicated. Native
35-control-destination syntax passes and three-profile mocks reject 84
invalid cases. This is not timing acceptance of the failed full flow.
Fresh refit and report-auditor qualification of actual native paths remain
required. See [fit/inventory evidence](SCALER_RESET_TIMING_AUDIT.md#first-destination-local-fit-fitted-final-sta-rejected).

The report auditor now takes optional explicit fitted `stage.01` replica
count 0/1 (default 1 preserves historical calls), alongside the independently
observed CPU capture count. The prepared unreplicated profile requires 34
distinct control destinations/89 rows, versus 35/90 for the prior replicated
fit. The prior native report has exactly one path to the optional stage clone;
new unreplicated native reports must still validate this profile before any
acceptance claim. Every primary destination/plane/source remains mandatory;
the auditor never infers the supplied replica count from passing reports.
Generated controls pass captures 8/9/10/16 at both stage profiles and reject
the wrong profile, in addition to the prior corrupt/missing reports (23
negative controls total). The prior `89f8226` native replicated fit still
passes with nine CPU captures. No new-fit timing qualification is claimed.

The subsequent `ed3c332` full flow finishes zero. Native fitted inventory is
eight CPU captures, primary PCG states without the optional clone. Independent
report audit now passes the actual 0-replica profile: 48 request reports /
4,672 paths, 16 response reports /128 paths, all corners, every mandatory
endpoint and physical bound. Explicit call:
`bash scripts/audit_pcg_timing_reports.sh output_files/quartus-linux-HMU7HdXp/acceptance 8 0`.
Snapshot payload also passes 16 files/1,152 rows with all 72 bits, minimum
combined setup/hold +0.495 ns, max physical data 12.973 ns.
Source/artifact identities and failed global timing are in the
[corrected-flow evidence](SCALER_RESET_TIMING_AUDIT.md#corrected-full-flow-and-native-stage-timing).
No native firmware, whole-design CDC or hardware compatibility is established.

The selected reset/mux `6133f27` refit also passes the same independently
inventoried 8-capture/0-stage-replica report profile: all 48 request and 16
response corner reports pass. Snapshot audit retains 72 bits in every one
of 16 files (1,152 rows), minimum combined setup/hold +0.533 ns, maximum
physical data 13.138 ns. This does not excuse newly exposed VSYNC or other
clock-domain crossings; see the [selected refit](TURBO_Z_BOARD_BUILD_STATUS.md#selected-resetmux-refit-and-real-remaining-crossings).
