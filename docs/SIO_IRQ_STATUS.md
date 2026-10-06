# Standalone SIO RX/TX interrupt subset

October 5, 2026. `rtl/x1_sio_irq.sv` adds original local priority/service RTL
and `x1_sio_interrupt`, which connects it to both real serial channels from
`rtl/x1_sio_async.sv`. **Neither wrapper is in `machine.qip` or instantiated
by the shared X1 machine.** Base/Turbo/X3 behavior and v11 snapshots are
unchanged. This is not native firmware, FPGA timing or physical acceptance.

## Primary contract and scope

Inspected [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf),
printed 227–230, 274–279 and 299–300 (PDF page numbers +20), using the existing
local manual. Local MAME `z80sio.cpp` priority, vector and return routines
were inspected as a second reference; no emulator code or ROM bytes were
copied, and no emulator was executed for these checks.

Implemented in the separate interrupt wrapper:

- WR1 RX modes `10`/`11` interrupt on available characters. Framing and
  overrun are special; parity modifies the RX vector in mode `10`, not `11`.
  The existing FIFO/error semantics remain in use. First-character mode
  `01` is **unsupported**, including its error-character locking/rearm.
- WR1 TX enable requests an interrupt when actual holding data enters the
  shifter, leaving the holding register empty. Merely enabling interrupts
  on an initially empty transmitter does not request an interrupt. A data
  write or WR0 `28` clears TX pending; neither action releases service.
  Same-edge take/write replacement remains full and generates no empty event.
- A RX > A TX > B RX > B TX. The controller reserves external/status source
  slots, but they are **tied inactive** in this wrapper; WR1 external enable
  is detected as unsupported. CTS/DCD remain polled, not interrupt-latched.
- Pending source conditions persist independently of service. ACK marks the
  eligible source under service; reading RX or clearing TX removes the source
  condition. Same/lower sources cannot interrupt while it is under service;
  higher ones can nest. Local RETI releases only the highest serviced source.
- B WR2 supplies the vector. B WR1 D2 optionally replaces vector bits 3:1.
  B RR2 reads the highest pending source; with none, modified bits are `011`.
  A RR2 returns `FF` and flags unsupported. A RR0 D1 reports either channel's
  pending source condition; B's D1 stays zero.
- Held ACK captures one owner/vector on its first SYS edge, independent of
  stopped channel/CPU advancement enables. A request arriving during a
  spurious held ACK cannot retroactively take ownership; that ACK stays `FF`.
- A WR0 `38` returns the highest interrupt under service. The same command
  on B flags unsupported. A channel reset also resets the prioritizer, but
  preserves B's FIFO/source conditions. B reset clears its service only.
  Chip reset clears both serial channels and priority on SYS with CE stopped.

`reti` is a **locally qualified one-SYS-edge event**, not raw broadcast RETI
from a future multi-device chain. Integration must select the highest device
actually under service; an upstream service must not also release SIO's
nested lower service. IEI qualifies IRQ/IEO and ACK ownership. Functional
SYS-edge arbitration does not establish real part daisy propagation or
half-clock bus timing. Unsupported first-character/external/WAIT/Ready modes
must not be used as capability probes that appear to succeed.

## Executed verification

```sh
make -C verilator test-sio-async test-sio-formats test-sio-irq test-sio-cpu \
    HEADLESS_DIR=obj_dir_v11_units
```

All four targets pass at **CE=1/4/7**. The previous polled 108-format matrix
and FIFO/TX collision assertions remain unchanged and pass. New checks:

| Fixture | Executed assertions |
|---|---|
| `sio_irq_tb.sv` | Real A/B pin arrivals and TX holding transitions; simultaneous A/B RX/TX priority; three nested service levels; source survives ACK until FIFO read/TX reset; 40 SYS-edge held ACKs with CE stopped; higher RX arriving during held TX ACK; fixed/modified/no-pending RR2; parity mode 10 vs 11 and framing vectors; WR0 return vs local RETI; A/B reset isolation; A reset retains B FIFO pending; spurious held ACK with late RX; simultaneous TX take/write has no phantom empty request and emits both actual bytes; unsupported A RR2/B return/first-character/external modes; chip reset with CE stopped. Each execution observes 16 non-spurious ACKs. |
| `sio_cpu_tb.sv` | Actual existing `cpu.v`/TV80 executes an original program: CPU programs SIO and IM2, waits in HALT, receives B byte `B6` via vector `E4`, A framing-error byte `37` via `EE`, and TX-empty via `E8`. Distinct handlers store actual read bytes, clear TX pending, and execute three RETIs decoded from real opcode fetches by the existing `x1_irq_bridge`. Held bus vectors stay stable. Actual TX pins emit CPU-written `69`, with each bit checked for 16 enabled ticks. Final state has exactly three ACKs/RETIs, no IRQ and IEO released. |

These are asset-free standalone fixtures, not machine/native tests. The CPU
fixture's RAM contains only its own original generated diagnostic and IM2
table; it does not force PC/registers or alter private media. Its opcode
decoder has idle CTC/keyboard inputs: there is no CTC device in this fixture.
No WAIT insertion or multi-device chain is implied by the CPU test.

Logs: `/tmp/x1-sio-irq-verified.log`. New RTL/test width warnings were fixed.
The CPU build retains the inherited `tv80_core.v:1026` missing `DIRSET` pin
warning; no new suppression or unrelated CPU edit was added.

## Remaining gates

1. First-character RX, locking/error reset, next-character command; CTS/DCD
   external-status latching/reset, break and other actual external sources.
2. Continuous/back-to-back phase coverage, x1 synchronization, modem
   auto-enables, live configuration, exact reset/error/pin-phase behavior.
3. Schematic-qualified board serial clocks/pins, full-machine `1F90..93`
   decode, DAM/ACK isolation and qualified CTC/SIO/keyboard service arbitration.
4. WAIT/Ready and DMA handshakes/serial transfers, actual CPU WAIT and
   multi-device nested ACK/RETI diagnostics.
5. Unchanged native serial/firmware execution, current-source Quartus timing/
   CDC review, and physical connector/voltage/loopback tests.
