# Non-stopping Burst/continuous pure search

October 6, 2026. Original GPL-2.0-or-later increment in `rtl/x1_dma.sv`.
This qualifies the non-stopping operation/count/ownership part of the
[full search contract](DMA_SEARCH_CONTRACT.md); match-stop pipelines,
IRQ/service, variable/simultaneous timing, native and hardware gates remain
required and unfinished. It does not complete work group 2 or Turbo Z.

## Distinct class policy

Primary [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf),
printed 76/Table 11, 41–43/Figures 21–23. Pure search is read-only in every
accepted mode, never a disguised sequential copy. This increment accepts
Burst/continuous **only with WR3 Stop on Match disabled**, so a real masked
match is sticky while remaining reads continue to EOB.

| Pure search ownership | Programmed length L | Reads at EOB | Reported byte count | Inactive Ready between reads |
|---|---|---|---|---|
| Byte, existing | Nonzero L | L+1 | L | Release bus |
| Burst | Nonzero L | L+1 | L+1 modulo 65536 | Release bus, retain active counters |
| Continuous | Nonzero L | L | L | Keep grant, pause new reads |

Zero uses counter-wrap policies: 65,537 reads for Byte/Burst, 65,536 for
continuous, with the respective reported 16-bit counts. These are explicit
model policies derived from the manual's distinct operation/count rows and
existing special-zero handling, exhaustively boundary-tested here, not
independently measured silicon behavior. One common N+1 helper would make
continuous search wrong; `operation_size()` is class/ownership aware for
LOAD, CONTINUE and read-only automatic restart. Sequential-transfer sizing
and the already-qualified Byte behavior remain unchanged.

Completed source reads step only the source counter. Automatic restart
reloads both buffers but never issues a destination transaction. Burst/continuous
do not release after each read as Byte does. FORCE READY remains asserted
until actual ownership release; real physical Ready gates first grant and
normal pause/resume without reprogramming. An already-started read completes
despite Ready loss; WAIT/CE stop and reset/abort drainage retain ownership.

WR3 Stop on Match in either non-Byte class still fails closed. No extra-read
pipeline, truncated sequential table value or Ready exception is silently
substituted with Byte stop. These are next gates, not removed from the goal.
No new clock or serialized latch was added; DMA profile revision 5 adds bit
49 for changed command behavior. Ordinary non-DMA v12 identity is unchanged;
regenerate affected states, never edit serialized bytes to bypass rejection.

## Executed verification

Verilator 5.044, assertions/timing enabled:

```sh
make -C verilator test-dma-search test-dma-compare test-dma-cpu \
    test-sio-dma test-sio-dma-cpu HEADLESS_DIR=obj_dir_v12_dma_nonbyte_search
```

Exit zero. Search fixture runs **14,336** mask/source/polarity/position cases
at CE=1/4: original 10,240 Byte cases plus 4,096 new Burst/continuous mask
cases. Additional tests cover memory/I/O, fixed/inc/dec/wrap, Ready-gated first
grant, pause/release/resume at two completed reads, terminal read under WAIT
with CE stopped and DISABLE/C3/raw reset, identical programmed-one lengths,
three repeated blocks, actual match clearing on reload and both counter reloads.
Long 255/FFFF/zero lengths complete in both classes and directions, with
and without repeat, including a real first read of the next block. A global
assertion forbids every destination write. Search watchdog rises from 40 to
80 million fixture edges to cover added long cases, not fewer simulated reads.
No warning suppression was introduced. Final extended log
`/tmp/x1-dma-nonbyte-search-qualified.log`; other diagnostic log
`/tmp/x1-dma-nonbyte-search-final.log`.

The retained first failure in `/tmp/x1-dma-nonbyte-search-unit.log` was an
obsolete rejection assertion: it cleared Stop on Match then expected the
newly supported continuous search to be rejected. It now tests **actual
unsupported continuous match-stop** instead. RTL was not weakened to satisfy it.
The original 40-group transfer/restart suite also exits zero in
`/tmp/x1-dma-nonbyte-search-transfer.log` (session 53201), at 11,942,240
fixture edges. The extra rejection command accounts for the additional
24 edges; no original supported transfer duration/assertion was reduced.

Twenty original generated-IPL shared-CPU profiles pass on **both fast and
delay-aware runners**: both sources, both non-Byte ownership modes,
first/middle/last/no match, CPU-programmed lengths 4 continuous/3 Burst for
four operations, genuine one-grant/four-read/zero-write totals, real RR0/all
counter readback, preloaded other counter preserved, source/destination RAM
untouched and 8B. Every invocation retains eight million 32 MHz reference
cycles (250 ms). No firmware patch, fake grants, forced FDC Ready or debugger
RAM bootstrap. Logs `/tmp/x1-dma-nonbyte-search-fast.log` (session 93825) and
`/tmp/x1-dma-nonbyte-search-machine.log` (session 56288), both terminal zero.
Fast actual-CPU Byte-search/transfer restart and GRAM/PCG regressions also pass.

Additional actual-CPU programmed-one/zero-wrap fast matrices exit zero:
eight first-match/no-match length-one profiles (one continuous read versus
two Burst reads), then four full zero-wrap profiles (65,536 continuous reads
versus 65,537 Burst reads), both sources, each with one grant and zero writes.
All invoke the original eight-million-reference-cycle duration. Zero-wrap
uses FF ignore mask: match is necessarily genuine for every read, while
stopping remains disabled. All counter bytes and RAM guards are CPU checked;
the reported zero-wrap count is 0 continuous versus 1 Burst.
Log `/tmp/x1-dma-nonbyte-search-boundaries-fast.log` (session 56455).
The delay-aware boundary matrix also exits zero with all twelve cases in
`/tmp/x1-dma-nonbyte-search-boundaries-machine.log` (session 77843). Thus
both actual shared builds execute the full 65,536/65,537-read zero-wrap
operations and verify counters through the CPU, not just a fixture monitor.

| Tested artifact | SHA-256 |
|---|---|
| Current DMA source | `115150949d5e626f1711dfac213a3288ec013aa3dc1127acd5e66aa227ec6af4` |
| Final extended search unit | `64f181dafebde81cee6351e08202d8949de6a2443c99cf9a4191a583de7990c4` |
| Fast shared machine | `8980ee4db36baf4b87f2ecb260735e3023d677dddc73da43432834a4084f8a4b` |
| Delay-aware shared machine | `cf7f8990b703420486616bcfa21a1aaa1ea2ee4d638b9295fc36a8367e1a2136` |

After a comment clarification, both final-source shared builds were regenerated
in separate `*_qualified` directories: their executables are byte-identical
to the already-tested runners above, not assumed equivalent by source review.
Fresh base savable runner remains byte-identical to the five-game-qualified
v12 base runner, SHA-256
`159062a12920cb398d1bd348b8e901a7b6139d31cfcadd8d038b73235d962a8a`.
Snapshot/clock/mismatch/joystick checks exit zero in
`/tmp/x1-dma-nonbyte-search-base-snapshot.log`. This does not qualify native
Turbo or DMA software. Existing 25-target CI now includes this expanded
fixture; its current-source hosted gate remains separate. No current-source
Quartus/MiSTer acceptance is available, and no RBF is promoted by these results.
