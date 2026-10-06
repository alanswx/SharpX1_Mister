# Standalone SIO functional WAIT/Ready experiment

October 6, 2026. `x1_sio_interrupt` now has an explicitly opt-in
`FLOW_ENABLE=1` profile. Its default stays off; existing default-wrapper
WAIT/Ready rejection remains tested. Neither SIO wrapper is in `machine.qip`
or instantiated by the X1. **No machine, DMA, native firmware, Quartus or
physical handshake acceptance is claimed by that checkpoint.** v11 machine states are unchanged.
The subsequent [standalone SIO/DMA fixture](SIO_DMA_STATUS.md) separately
qualifies bounded Ready-paced transfers and adds locked-error Ready inhibition;
it does not connect the machine or establish exact pin timing.

## Contract and deliberate limits

Reviewed [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf),
printed 279–281 / PDF 299–301, using the existing local manual, alongside
local MAME's `update_wait_ready` (inspected, not copied or executed).
The existing [WR1 discrepancy audit](SIO_REGISTER_CONTRACT.md#wr1-waitready-discrepancy-audit)
records the conflicting prose/table labels. This experiment uses Figure 115/
Table 15's D7 enable, D6 Ready-versus-Wait and D5 RX-versus-TX selection.

Functional outputs are separated into two per-channel active-low vectors,
`wait_n` and `ready_n`. High means released/inactive, **not physical open-drain
or tri-state voltage modeling**. All inputs are synchronous to SYS.

- WAIT mode gates selected RX data-read acceptance while FIFO empty, or
  selected TX data-write acceptance while holding is full. A blocked strobe
  does not mark the transaction seen, pop a FIFO, latch an empty response,
  replace queued TX data or set overflow unsupported.
- WAIT remains asserted through the actual accepting enabled edge so a
  clocked RX response settles before the CPU proceeds. Even an available
  selected data access has that acceptance latency in this experiment.
  After acceptance a held strobe stays completed: it cannot reassert WAIT
  merely because the consumed buffer becomes empty/full.
- Control accesses and the nonselected channel do not request WAIT.
  Opposite-channel WAIT behavior described by printed 281 is **not modeled**;
  this selected-transaction contract must not be promoted to exact-part wiring.
- Ready is active low for RX FIFO nonempty or TX holding empty, independent
  of channel selection. Either channel's data/control CPU transfer releases
  both Ready outputs; readiness returns after bus release. This is a
  combinational functional suppression, not the manual's half-clock delays.
- Disabled flow and chip reset release both outputs. Reset clears stalled
  state on SYS even when advancement CE is stopped.

The [interrupt subset](SIO_IRQ_STATUS.md) remains separately tested. The later
SIO/DMA increment inhibits RX Ready after one accepted locked-error read until
Error Reset; ordinary CPU inspection stays readable. This fixes the repeated
DMA error-word copy exposed by that fixture. No machine WAIT connection was added.

## Executed checks

```sh
make -C verilator test-sio-async test-sio-formats test-sio-irq \
    test-sio-first-status test-sio-flow test-sio-cpu \
    HEADLESS_DIR=obj_dir_v11_units
```

All six targets pass at **CE=1/4/7**. The CPU target runs three profiles at each
rate: original RX/TX IM2, first-character/CTS IM2, and new `+flow`. The prior
format/FIFO/interrupt assertions remain in place; no golden byte assertion
was removed. Fixtures use a 10 ns SYS period, eight initial enabled reset
edges and deterministic CE periods. Assets are original test patterns/programs,
not BIOS/game bytes, snapshots or forced CPU state.

`sio_flow_tb.sv` checks forty enabled edges of empty RX/full TX stall, delayed
acceptance, one effect per held strobe, isolation from the other channel,
actual queued TX `69` then `17` bits (16 events per bit), RX/TX Ready polarity,
both-channel suppression during a control read, disable and stopped-CE reset.

The actual `cpu.v`/TV80 `+flow` profile preserves its three IM2 ACK/RETI checks,
then holds a real empty RX IN for **100 enabled edges** until serial `53`
arrives. CPU stores actual `53`. It fills holding with `55` behind shifting
`69`, then holds an OUT of `17` for **100 enabled edges** while TX advancement
is stopped. Natural holding transfer releases WAIT; CPU completes and halts.
All three actual TX pin frames `69`, `55`, `17` are checked bit-by-bit.

Two response issues were exposed during development, not hidden by relaxing
the expected `53` assertion:

1. Releasing WAIT on FIFO arrival before acceptance let CPU sample the old
   `37` response. The handshake now holds through response-latching acceptance.
2. The test fixture's idle-bus mux replaced a valid I/O response with RAM `00`
   while TV80 retained its automatic I/O sampling phase after releasing its
   strobes. The fixture now preserves I/O response through idle bus release,
   bypasses it for actual memory reads, and clears it at the next memory read.
   Original IM2/first-status assertions still pass. `+flow-trace` provides
   optional read-only bus/response/T-state diagnostics; no CPU RTL was edited.

That second requirement is **not fixed in the machine**: there is no connected
SIO there. Future machine integration must test response persistence at bus
release rather than assume IORQ alone covers the full CPU sampling phase.

Current full-suite log: `/tmp/x1-sio-flow-suite.log`. CPU build/diagnosis logs:
`/tmp/x1-sio-flow-cpu3.log`, `/tmp/x1-sio-flow-trace.log`; earlier failures are
retained. The inherited `tv80_core.v:1026` missing `DIRSET` pin warning remains;
no new warning suppression or unrelated CPU changes were added.

## Remaining acceptance

- Exact W/RDY bus edges/delays, open-drain pin handling and opposite-channel
  effects; broader RX/TX phase/cancellation/reset coverage.
- Broader SIO-to-DMA readiness/error/reset collisions and actual CPU ownership;
  bounded standalone paced transfers/locked-error recovery now pass separately.
- Schematic-qualified machine pin/clock/decode integration, stretched CPU
  sampling/WAIT, DMA isolation and multi-device ACK/RETI ownership.
- Remaining SYNC/break/EOM sources, modem auto-enable, x1/live configuration,
  native reset arming, firmware and source-bound timing/hardware tests.
