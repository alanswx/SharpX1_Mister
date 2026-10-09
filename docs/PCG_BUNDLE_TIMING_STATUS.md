# PCG request/response bundle window audit

October 9, 2026. This qualifies digital handshake timing in the shared
`rtl/x1_pcg_access.v` module, not a new constraint or hardware pin contract.
Production RTL is unchanged (SHA-256
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

`scripts/constraints/pcg_response_candidate.sdc` is **not selected by any
QSF**. It checks eight unique indexed registers on each side, then applies
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
