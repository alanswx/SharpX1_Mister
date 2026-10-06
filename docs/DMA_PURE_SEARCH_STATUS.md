# DMA pure Byte search increment

October 6, 2026. Original GPL-2.0-or-later implementation in
`rtl/x1_dma.sv`, shared by the opt-in `TURBO_DMA=1` machine and standalone
tests. This does not complete work group 2, Turbo or Turbo Z.

## Observable contract and limits

WR0 operation class `10` now supports **pure search in Byte ownership**,
standard memory/I/O intervals, both sources and increment/decrement/fixed
addressing. The completed source read samples the real input byte, compares
masked bits and updates sticky RR0 match. There is no WRITE_SETUP/WRITE_CYCLE
transition, destination access or destination-counter advance. CPU LOAD of
the other port before searching remains observable and must be preserved.

Primary [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf),
printed 76/Table 11 and Table 12: Byte search ending at EOB performs N+1
reads and reports count N; Byte search stopped at match M performs M reads
and reports count M. The latter is deliberately **not** sequential
transfer/search's M-1 policy. Source advances once per completed read.
The inherited special-zero length policy remains 65,537 reads; full count
and source-address rollover are tested, not silently truncated at 65,536.
A match on the terminal byte sets match and EOB and retains the match-stop
count. Stop disabled allows later reads without losing an earlier match.
8B/LOAD/CONTINUE/software/hardware reset retain their explicit status policy.

WAIT and stopped CE preserve the owned read. Ready loss or DISABLE during
that read cannot truncate it or generate a write. Software/hardware reset
drains it once, then clears active programming/state according to the
existing reset contract. Raw hardware reset is recorded even with CE stopped.

Pure Burst/continuous, pure-search automatic restart, IRQ/vector/service,
variable/simultaneous timing and non-Byte sequential stop still fail closed.
These remain required work, not excluded from the active goal. See the
[full search contract](DMA_SEARCH_CONTRACT.md) for extra-read/Ready policies
and unresolved primary-reference discrepancies. No physical pin-phase or
native firmware acceptance follows from functional bus diagnostics.

DMA snapshot profile advances to revision 3 (additional bit 51). No new
serialized latch or supported DMA snapshot target is introduced, but old
DMA commands now have different behavior and require rejection. Non-DMA
base/Turbo/X3 identity remains v12; never patch/convert states.

## Executed checks

Verilator 5.044, timing/assertions enabled:

```sh
make -C verilator test-dma-search test-dma-compare test-dma-cpu \
    test-sio-dma test-sio-dma-cpu HEADLESS_DIR=obj_dir_v12_dma_pure_byte
```

All exit zero. New search fixture: **10,240** mask/source/position/stop
cases at CE=1/4, including fully ignored masks, first/middle/last/no match,
exact read counts and both address counters. Additional memory/I/O
increment/decrement/fixed/wrap, WAIT/Ready loss, stopped CE, DISABLE/C3/raw
reset and 256/65,536/65,537-read boundary cases pass. A global assertion
rejects every destination strobe; held read address/type and stretched
register readback are checked. No warning suppression was added. Existing
10,240 comparison/sequential-Byte-stop cases and CPU/DMA/SIO regressions
also pass, unchanged except the obsolete pure-search rejection now explicitly
checks unimplemented Burst ownership instead of a newly supported mode.

Logs `/tmp/x1-dma-pure-byte-search-qualified.log` and
`/tmp/x1-dma-pure-byte-unit-final.log`.
The original 40-group transfer/restart rerun also exits zero at
11,942,216 fixture edges in `/tmp/x1-dma-pure-byte-transfer.log`. Its rejection
case now programs non-Byte pure search explicitly, explaining the extra
24 fixture edges rather than weakening an assertion or shortening duration.

New actual shared-CPU fixture programs twenty original generated IPLs:
two source directions, stop enabled/disabled, four match positions/no match.
Each runs eight million 32 MHz reference cycles, preloads the other counter
through real source selection/LOAD, uses CPU Force Ready, verifies RR0 and
all six counter bytes, source/destination RAM preservation and 8B, and
halts with a CPU-written marker. The runner must report reads/grants and
**zero DMA writes**; no forced grants, debugger injection or private assets.
All twenty pure-search cases pass on the fast runner. Its following twenty
comparison/Byte-stop profiles, both automatic-restart directions and
GRAM/PCG regression pipeline also exit zero in
`/tmp/x1-dma-pure-byte-fast.log` (session 25562). The delay-aware pure-search
matrix is still live in `/tmp/x1-dma-pure-byte-machine.log` (session 31207),
not declared terminal/pass.

| Artifact | SHA-256 |
|---|---|
| DMA source | `a609892a95b0f83a0eb8c8e9bbb0ed82c5baffbf745290a01a68f7dee1514035` |
| Final pure-search unit | `4c7138b133a268a03f9a049ea45e74e98df7425351abf4dd72d14a61c338b03c` |
| Comparison/Byte-stop unit | `a9582d4ef5e9c3e03f3b11c6c34c9b68b5cd60d9ecfff9fb543e381b1443c997` |
| Fast shared machine | `42c445cb05df7d423196fd96762ac2d7b9e8671551b42e63c4c509967f041d8e` |
| Delay-aware shared machine | `ae75080ce96a31e536c3ca448cd40b31cd4fc9924d336005c3c74957a883afc1` |

Fresh base savable executable is byte-identical to the five-game-qualified
v12 base runner, SHA-256
`159062a12920cb398d1bd348b8e901a7b6139d31cfcadd8d038b73235d962a8a`;
snapshot/clock/mismatch/joystick checks exit zero in
`/tmp/x1-dma-pure-byte-base-snapshot.log`. This only qualifies the DMA-disabled
base profile. CI adds this fixture as target 25; hosted acceptance needs its
own terminal result, not an older green run. Quartus/MiSTer remain unavailable.
