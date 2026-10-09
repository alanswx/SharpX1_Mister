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
