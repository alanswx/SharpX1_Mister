# Opt-in shared-machine DMA integration

October 5, 2026. `rtl/sharpx1.v`, shared by simulation and MiSTer, now has
an explicit `TURBO_DMA=1` subset requiring `TURBO=1`. Defaults, ordinary
Turbo/X3 and FPGA revisions keep DMA disabled. This is generated-diagnostic
acceptance, **not native Turbo firmware, complete DMA or hardware support**.

## Connected behavior

- Real CPU BUSRQ/BUSACK selects one shared address/data/memory/I/O bus.
  BUSRQ alone never grants ownership. DMA M1 stays inactive, so payload
  cycles cannot acknowledge interrupts or fetch RETI through the IRQ bridge.
- CPU register aliases `1F80..1F8F` select the DMA stream only when the CPU
  owns an ordinary, non-DAM I/O cycle. Reads return the engine's latched data.
- DMA memory/I/O uses the existing IPL/RAM, peripheral and graphics decode.
  FDC DRQ feeds inverted Ready, matching the chosen active-low WR5 setting
  and inspected local MAME connection. No base FDC CPU interrupt was added.
- CPU, DMA and FDC use system-clock enables, not new generated clocks.
- `x1_dma_reset` retains short raw reset requests. CPU execution stops at
  once, but its actual ACK stays held while the started source/destination
  pair drains. DMA and target CE keep running; machine reset follows BUSRQ
  release and holds for four SYS edges. A stalled pair is not forcibly freed.
- Loader `ioctl_wait` blocks IPL/RAM/font writes during drain. Both the
  simulator and MiSTer HPS upload connection honor that signal. The physical
  HPS upload handshake has not been tested. An already-started DMA write may
  commit; reset is not a rollback guarantee.

Serialization advances to **v11**, including default-model instrumentation.
The DMA profile has a distinct identity bit. Never convert historical states;
regenerate native boot. No private software/fonts/states are committed.

## Executed acceptance

Delay-aware runner: SYS 32,000,000 Hz / VID 28,571,428 Hz, Turbo enabled,
X3/single disabled, standard four-MHz CPU/DMA/FDC enables. Initial reset
includes the ordinary ioctl download, then the reset guard's release hold.
`test_machine_dma.py` executes original Z80 diagnostics and generated D88
through real loader/SD paths, with **8,000,000 reference cycles per case**.
No CPU PC/register forcing, fabricated grants or injected game RAM occurs.

| Test | Result |
|---|---|
| Continuous Force-Ready high-RAM copy | 16 read/write pairs, one actual CPU grant, byte-exact RAM and primary address/count readback |
| DRQ-paced byte-mode drive A read | 256 pairs / 256 real grants, byte-exact sector and readback, zero CPU payload reads |
| DRQ-paced byte-mode drive B read | Same assertions with distinct B payload |
| Drive A write | 256 pairs/grants, fixed-destination two-LOAD workaround, whole-image output matches; B unchanged |
| Drive B normal write over deleted B0-CRC sector | 256 pairs/grants, whole-image payload/mark/CRC repair; A unchanged |
| Drive B D88-protected write | Zero DMA pairs/grants; write-protect status; both whole images unchanged |

Writes use explicit new disposable output copies, never overwrite originals.
Protected setup still enables DMA, but no invented DRQ is supplied.
The fixtures poll **FDC**, not DMA control registers, during byte transfers.
UM0081 Table 13 requires disabling before reading in enabled/inactive state;
this subset's disabling read policy remains documented rather than silently
changed to make the fixture pass. Counter reads occur only after completion.

Whole-machine `dma_machine_reset_tb.sv` also passes four independent runs:
request during source read, during destination write, a 2 ns pulse while SYS
is physically stopped, and a reload write held through a real blocked SYS
edge. Every case drains exactly one pair, retains CPU ACK, restarts from the
original loaded diagnostic in retained RAM, then finishes all 16 pairs with
exact total 17/17 counts and two grants. HALT alone is not completion: the
fixture also waits for all pairs and actual grant return.

Existing standalone DMA 32 groups, actual CPU/DMA 18 cases plus direct-read,
and standalone reset-guard tests pass unchanged. Baseline delay-aware timing,
reset/divider/FST/repeatability and v11 base snapshot/SDL checks also pass.
Build warnings remain inherited; compilation does not establish synthesis.

Commands from the repository root:

```sh
make -C verilator test-machine-dma HEADLESS_DIR=obj_dir_v11_units
make -C verilator turbo-dma DMA_DIR=obj_dir_v11_dma_fast DMA_TIMING=--no-timing
python3 verilator/tests/test_machine_dma.py verilator/obj_dir_v11_dma_fast/Vtop
```

Both complete delay-aware and fast matrices pass all six cases with the same
counts/payload/counter/whole-image assertions and original per-case duration.
Fast ignores inherited intra-assignment delays; it is not the scheduling
reference. Base wrapper lint passes with the PLL stand-in, not an Intel fit.

| Tested executable | SHA-256 |
|---|---|
| Delay-aware Turbo DMA | `3e1a686362076cf1282c7153fbd61735ca1c4aa9eb3e1abfc75c78786d8f56ff` |
| Fast Turbo DMA | `c9b48d27f87487609e846bba439d060c7658606ed163113ce3cee884ab2d3a33` |

These identify the generated-diagnostic checkpoint, not a native game boot.
Local logs: `/tmp/x1-v11-machine-dma-expanded.log`,
`/tmp/x1-v11-machine-dma-reset.log`, `/tmp/x1-v11-dma-units.log`,
`/tmp/x1-v11-base-timing.log`, `/tmp/x1-v11-base-snapshot.log`.

## Remaining gates

1. DMA read/write resets with outstanding SD ACK, partial payload/metadata
   publication, lost-data/CRC failure and no-ready/Ready-loss continuity.
2. CPU and DMA accesses to RAM beneath IPL, PCG WAIT, graphics pages/DAM and
   other side-effect targets; preserve single peripheral transaction semantics.
3. X3/single combinations and programmable Ready polarity; current generated
   machine fixtures exercise active-low Ready only.
4. Unchanged native Turbo IPL disk streams, authentic counter continuation
   and Turbo FDC aliases; native Arcus/Bastard remain unqualified.
5. DMA IRQ/daisy/service, search, variable pin timing and auto restart remain
   unsupported. Do not fake these capabilities or enable the default profile.
6. Source-bound Quartus reset/CDC/bus fit and physical hardware validation.
   The frozen `15a0655` artifact predates this work and fails timing.
