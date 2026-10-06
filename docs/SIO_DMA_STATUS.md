# Standalone SIO-to-DMA Ready qualification

October 6, 2026. Original `sio_dma_tb.sv` connects the actual
`x1_sio_interrupt #(FLOW_ENABLE=1)` and `x1_dma` modules. This is a standalone
functional fixture with a synthetic retained bus grant, not an actual CPU,
X1 schematic connection, native firmware run, fitted design or hardware test.
The shared machine still has no SIO; machine defaults and v11 states stay unchanged.

## Connection and coverage

The fixture selects one channel's active-low `ready_n` directly as DMA RDY,
with WR5 active-low polarity. It never substitutes a fabricated readiness
sequence or FORCE READY. Port A is fixed SIO data at `1F90` or `1F92`; B is
incrementing RAM at `5000`. TX uses the documented temporary-source LOAD
then reverse-direction LOAD to initialize the fixed destination counter.
DMA-owned I/O strobes select SIO exactly as host control strobes do. A grant
is retained until BUSRQ releases; host access during active DMA is rejected.
Memory side effects occur once at completed strobes. DMA source data is the
actual latched SIO response, not a fixture FIFO. Both modules advance on one
SYS clock with enables; serial advancement uses independent event inputs.

```sh
make -C verilator test-sio-dma HEADLESS_DIR=obj_dir_v11_units
```

Passes at CE=1/4/7, with 10 ns SYS period, eight enabled reset edges per case
and original generated 8N1/x16 patterns (no private assets or forced state):

- A and B RX/TX, each in byte and burst ownership modes: four exact bytes,
  four source/destination pairs, four grants, one effect per held I/O strobe,
  and actual stopped count readback `0003`. RX patterns are `53 64 75 86`;
  TX patterns `69 7C 8F A2` are checked bit-by-bit at the actual output pin.
- Eighty enabled edges without an RX character or TX holding space must not
  create a new pair. Serial arrival/holding consumption naturally resumes it.
- The first owned RX I/O read in each channel/mode is frozen for eighty SYS
  edges with CE stopped. Ownership, address and strobe stay stable; no pair
  completes prematurely. Resume preserves byte/order and exact pair count.
- Each channel's first-character framing error: one DMA read of `37`, then
  no repeated copy while good `B6` arrives behind the locked head. A host RR1
  read returns `41`; repeated data inspections still return `37` without
  reactivating Ready. Genuine WR0 Error Reset removes the error word and
  naturally resumes DMA for queued `B6`. Two pairs/two grants, terminal count
  `0001`, exact RAM bytes and cleared special IRQ are checked.

Ten transfer blocks / 36 byte pairs pass per enable rate. `finish_block`
also checks no SIO/DMA unsupported diagnostic, no remaining IRQ and released
IEO. This is not DMA IRQ or multi-device ACK/RETI qualification.

## Discovered error-lock defect and functional fix

The initial failing test is retained in `/tmp/x1-sio-dma-lock-before.log`:
the engine copied locked `37` twice, completed its block and never waited for
the queued good character. Prior CPU-only error-lock tests correctly retained
the error word, but the new Ready signal depended only on nonempty FIFO.

[Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf), printed 237 /
PDF 257, describes holding the first-mode error character after a read until
Error Reset, specifically to permit CPU intervention during block/DMA work.
The opt-in flow model now records an accepted read of that locked head and
inhibits RX Ready until Error Reset. The first read can still deliver the
error character; subsequent ordinary CPU reads remain available for inspection.
This is an inferred functional Ready policy from that description, **not an
exact W/RDY pin-waveform interpretation or a silicon timing claim**.
No default polled/IRQ behavior or machine RTL was changed.

The full seven-target SIO suite passes at CE=1/4/7, including all 108 formats,
IRQ/error collisions and nine actual-CPU profiles. Existing assertions remain
unchanged. Logs: `/tmp/x1-sio-dma-final-suite.log` (all seven targets),
`/tmp/x1-sio-dma-final.log` (final added host-inspection assertions).
The final SIO/DMA build has no default warnings; the CPU suite retains the
inherited TV80 missing `DIRSET` pin warning, without new suppressions.

## Still required

- Exact W/RDY half-clock/open-drain/opposite-channel behavior; native reset
  arming, other errors/configurations, simultaneous read/Error Reset/arrival
  collisions with the new Ready latch, and reset during owned serial pairs.
- Continuous ownership and bursts with multiple queued RX bytes; independent
  CPU/serial phase and DMA WAIT variations, beyond the covered CE pause.
- Actual CPU bus ownership plus SIO/DMA together, schematic-qualified clock,
  modem/Ready wiring and decode, DAM isolation, and shared CTC/SIO/keyboard
  ACK/RETI service. Do not connect SIO to machine RDY just from this fixture.
- Native unchanged diagnostics, current-source Quartus timing/CDC/reset and
  physical loopback. No new RBF or hardware acceptance follows from this test.
