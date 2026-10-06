# Pure-search Burst/continuous match-stop pipeline

October 6, 2026. Original GPL-2.0-or-later implementation in `rtl/x1_dma.sv`.
This advances the [full DMA search contract](DMA_SEARCH_CONTRACT.md), not
native DMA compatibility, completed work group 2 or Turbo Z support.

## Actual transactions and limits

Primary [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf),
printed 75–77/Table 12, and the older 1982/83 Data Book printed 60:
pure Burst/continuous search normally completes an additional source read
after a match; Ready loss while locating it has a short-count exception.
The untruncated **pure-search** rows are used here, not the unresolved
sequential transfer/search rows. Sequential non-Byte Stop on Match still
fails closed. Variable/simultaneous timing, IRQ/vector/service and physical
pin-phase qualification remain required and unimplemented.

The new serialized `search_stop_pending` latch records the matching read,
not a fabricated final status. With Ready active, an actual following source
read completes before match is exposed and ownership released: M+1 reads,
count M+1, source advanced M+1 and no destination access/counter step.
The extra read's data cannot replace the recorded match. WAIT and stopped
CE hold that read and pending state. Once it starts, Ready loss, DISABLE
or reset drains it once; reset then clears pending/match state.

If Ready is inactive at matching-read completion, or becomes inactive before
the extra read starts, stop at M reads/count M-1/source advanced M. The latter
requires rolling back the speculative count, not issuing an extra read then
pretending it never happened. Continuous must release in this terminating
case rather than hold an inactive-Ready grant indefinitely.

Match stopping overrides automatic restart. A terminal-byte match therefore
executes the real extra read, preserves match/EOB and clamps remaining length
at zero rather than underflowing or reloading. This is the explicit functional
coincident-EOB candidate policy derived from the general pure-search row;
the manual does not separately establish its silicon event/IRQ precedence.
Native/physical qualification remains open. WR3 immediate-enable supports
these pure-search stop modes; no IRQ pin or artificial bus grant was added.

DMA profile revision 6 adds bit 48 and rejects previous DMA command/model
states before restore because the pending latch is new. Ordinary non-DMA
v12 identity is unchanged. Regenerate affected states; never convert/patch.

## Executed checks

Verilator 5.044, timing/assertions enabled:

```sh
make -C verilator test-dma-search test-dma-compare test-dma-cpu \
    test-sio-dma test-sio-dma-cpu HEADLESS_DIR=obj_dir_v12_dma_search_stop
```

Exit zero. **24,576 search cases** at CE=1/4 retain existing Byte and
non-stopping cases and add 10,240 pure non-Byte stop cases: all 256 masks,
both sources, both ownership modes, first/middle/last/no match, including
fully ignored masks and terminal-match auto-restart precedence. Exact reads,
source/other counter, byte count, remaining length, pending state and RR0
are checked; a global assertion rejects every destination write.
Directed memory/I/O Ready sweeps distinguish three phases: before matching
completion, after completion/before extra read, and after extra read starts.
WAIT/stopped CE, DISABLE/C3/raw reset during extra read and WR3 immediate
enable pass. Existing long-count/repeat tests remain intact. No warning
suppression or shortened invocation was introduced.
Logs `/tmp/x1-dma-search-stop-qualified.log` (extended unit) and
`/tmp/x1-dma-search-stop-final.log` (comparison/CPU/SIO). Original 40-group
transfer/restart also exits zero at 11,942,240 fixture edges in
`/tmp/x1-dma-search-stop-transfer.log` (session 71232).

Final-source fast shared-CPU runner passes twenty generated-IPL cases:
both sources/modes, match positions/no match, genuine two/three/four/five-read
totals, one grant and zero writes, CPU RR0/all counters and untouched RAM.
Matched cases program automatic restart to verify it cannot override stopping.
Even match-position indices use real WR3 immediate-enable; odd positions
use WR6 ENABLE. Every invocation retains eight million 32 MHz reference
cycles (250 ms), normal ioctl loading and no private assets/debug injection.
Both read-only/transfer restart directions and GRAM/PCG regressions also pass.
Log `/tmp/x1-dma-search-stop-fast-qualified.log` (session 98479, terminal zero).
Final-source delay-aware matrix also completes all twenty profiles with exit
zero in `/tmp/x1-dma-search-stop-machine-qualified.log` (session 85903).
This is independently executed acceptance, not inferred from fast or earlier
pre-immediate-enable results.

| Artifact | SHA-256 |
|---|---|
| DMA source | `5de36f653b11d9d621888a3c7722a52750446f869e85b144b6fa994e14a70670` |
| Final extended search unit | `65450336aaac514d785a2d13f81bc18c60700e0a070670d9443fab54457a8fc7` |
| Final fast shared machine | `61bd9a09095158e8b5d73d3e2704bd11685d846c9154be92a87658d2e4e424c8` |
| Final delay-aware shared machine | `5db3f2738abc04032ac7e2ceff8acc3221d57e0deba2fa0fe2d6aa5a6ee641df` |

Fresh base savable runner remains byte-identical to the five-commercial-game-
qualified v12 executable, SHA-256
`159062a12920cb398d1bd348b8e901a7b6139d31cfcadd8d038b73235d962a8a`.
Snapshot/clock/mismatch/joystick checks exit zero in
`/tmp/x1-dma-search-stop-base-snapshot.log`. This is base/DMA-disabled
acceptance only; no native Turbo, current-source Quartus/CDC or MiSTer
signoff/RBF promotion is inferred. Hosted 25-target qualification needs its
own source-bound terminal result.
