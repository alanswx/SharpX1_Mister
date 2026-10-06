# Standalone SIO asynchronous interrupt subset

October 5, 2026. `rtl/x1_sio_irq.sv` adds original local priority/service RTL
and `x1_sio_interrupt`, which connects it to both real serial channels from
`rtl/x1_sio_async.sv`. **Neither wrapper is in `machine.qip` or instantiated
by the shared X1 machine.** Base/Turbo/X3 behavior and v11 snapshots are
unchanged. This is not native firmware, FPGA timing or physical acceptance.
October 6: a separately opt-in [functional WAIT/Ready profile](SIO_FLOW_STATUS.md)
passes pin and actual-CPU stalled-access checks. Default `FLOW_ENABLE=0`
continues to reject WAIT/Ready settings; exact pin semantics remain open.
Subsequent [standalone SIO/DMA tests](SIO_DMA_STATUS.md) pass bounded
Ready-paced transfers/error recovery, not combined actual-CPU ownership or machine integration.

## Primary contract and scope

Inspected [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf),
printed 227–230, 235–237, 274–279 and 293–300 (PDF page numbers +20), using the existing
local manual. Local MAME `z80sio.cpp` priority, vector and return routines
were inspected as a second reference; no emulator code or ROM bytes were
copied, and no emulator was executed for these checks.

Implemented in the separate interrupt wrapper:

- WR1 RX modes `10`/`11` interrupt on available characters. Framing and
  overrun are special; parity modifies the RX vector in mode `10`, not `11`.
  The existing FIFO/error semantics remain in use.
- WR1 first-character mode `01` uses explicit WR0 `20` arming/re-arming.
  A marker travels with that particular FIFO entry: queued older words do
  not become first-character requests. Unarmed good data remains readable
  without IRQ. Framing/overrun still request a special interrupt; parity
  alone does not modify the vector or lock a word in this mode.
  Repeated reads return the locked framing/overrun word without popping it;
  WR0 `30` releases it and advances once, independently of service return.
  The first arm is explicitly required by this implementation, matching
  inspected MAME's initialization/command path. **An implicit native first
  arm after reset has not been established**; do not treat this as exact
  hardware reset behavior or native acceptance.
- WR1 TX enable requests an interrupt when actual holding data enters the
  shifter, leaving the holding register empty. Merely enabling interrupts
  on an initially empty transmitter does not request an interrupt. A data
  write or WR0 `28` clears TX pending; neither action releases service.
  Same-edge take/write replacement remains full and generates no empty event.
- WR1 external enable now detects CTS/DCD transitions on SYS even when
  advancement CE is stopped. The first sampled transition captures both
  inverted status bits and requests an external interrupt. Further changes
  cannot replace the snapshot until WR0 `10` clears pending and resamples
  current pins. ACK/RETI alone do not clear it. Disabled external mode uses
  live pin levels, clears pending, and does not replay disabled transitions
  when enabled again. This disabled-mode policy preserves the original polled
  wrapper; exact-part behavior across enable changes remains unqualified.
  SYNC, break and underrun/EOM external sources are **not implemented**.
- A RX > A TX > A external > B RX > B TX > B external. All six slots are
  now connected to actual serial/modem sources and checked together.
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
half-clock bus timing. Unsupported WAIT/Ready and remaining serial modes
must not be used as capability probes that appear to succeed.

## Executed verification

```sh
make -C verilator test-sio-async test-sio-formats test-sio-irq \
    test-sio-first-status test-sio-cpu \
    HEADLESS_DIR=obj_dir_v11_units
```

All five targets pass at **CE=1/4/7**. The previous polled 108-format matrix
and FIFO/TX collision assertions remain unchanged and pass. New checks:

| Fixture | Executed assertions |
|---|---|
| `sio_irq_tb.sv` | Real A/B pin arrivals and TX holding transitions; simultaneous A/B RX/TX priority; three nested service levels; source survives ACK until FIFO read/TX reset; 40 SYS-edge held ACKs with CE stopped; higher RX arriving during held TX ACK; fixed/modified/no-pending RR2; parity mode 10 vs 11 and framing vectors; WR0 return vs local RETI; A/B reset isolation; A reset retains B FIFO pending; spurious held ACK with late RX; simultaneous TX take/write has no phantom empty request and emits both actual bytes; unsupported A RR2/B return/WAIT-Ready modes; chip reset with CE stopped. Each execution observes 16 non-spurious ACKs. |
| `sio_cpu_tb.sv` | Actual existing `cpu.v`/TV80 executes an original program: CPU programs SIO and IM2, waits in HALT, receives B byte `B6` via vector `E4`, A framing-error byte `37` via `EE`, and TX-empty via `E8`. Distinct handlers store actual read bytes, clear TX pending, and execute three RETIs decoded from real opcode fetches by the existing `x1_irq_bridge`. Held bus vectors stay stable. Actual TX pins emit CPU-written `69`, with each bit checked for 16 enabled ticks. Final state has exactly three ACKs/RETIs, no IRQ and IEO released. |
| `sio_first_status_tb.sv` | Explicit A/B arming, queued-entry markers and re-arming; unarmed normal bytes; framing lock and repeated reads; fourth-byte replacement/overrun lock; parity-only exclusion; Error Reset collides naturally with receive completion at FIFO occupancy 1 and 3 without losing the new marked byte or falsely overrunning; one-SYS-sample CTS pulse with CE stopped; both channels' CTS/DCD snapshots; source reset vs service return; all six simultaneous sources; disabled external mode does not release service/replay transitions; stopped-CE chip reset clears a real external request. Each execution observes 20 ACKs. |
| `sio_cpu_tb.sv +first-status` | A second original program explicitly arms first-character RX, then runs the B RX and A special RX/TX handlers. It reads locked `37` twice, stores both actual results, issues Error Reset, and reads RR1=`01`. An additional CTS pulse dispatches vector `EA`; CPU reads retained RR0=`26`, issues external source reset and executes RETI. Exactly four ACKs/RETIs, no IRQ, IEO released; unchanged actual TX-byte assertions pass. |

These are asset-free standalone fixtures, not machine/native tests. The CPU
fixture's RAM contains only its own original generated diagnostic and IM2
table; it does not force PC/registers or alter private media. Its opcode
decoder has idle CTC/keyboard inputs: there is no CTC device in this fixture.
No WAIT insertion or multi-device chain is implied by the CPU test. These
functional fixtures use a 10 ns SYS period, eight initial enabled reset edges,
and deterministic CE periods 1/4/7. RX/TX events are synchronous CE events;
these fixture rates are not an X1 board-frequency or physical baud test.

Earlier RX/TX checkpoint log: `/tmp/x1-sio-irq-verified.log`.
Current first/status suite: `/tmp/x1-sio-first-verified.log`; initial new
fixture and CPU builds: `/tmp/x1-sio-first-status.log` and
`/tmp/x1-sio-first-cpu.log`. New RTL/test width warnings were fixed.
The CPU build retains the inherited `tv80_core.v:1026` missing `DIRSET` pin
warning; no new suppression or unrelated CPU edit was added.

## Remaining gates

1. Native first-character/reset arming and exact error-reset acceptance;
   SYNC/break/underrun external sources and minimum physical modem pulse width.
2. Continuous/back-to-back phase coverage, x1 synchronization, modem
   auto-enables, live configuration, exact reset/error/pin-phase behavior.
3. Schematic-qualified board serial clocks/pins, full-machine `1F90..93`
   decode, DAM/ACK isolation and qualified CTC/SIO/keyboard service arbitration.
4. Exact WAIT/Ready and broader DMA handshakes; separate functional fixtures
   pass actual CPU stalls and bounded SIO/DMA transfers/error recovery, not
   combined actual CPU/SIO/DMA ownership or machine acceptance.
   Multi-device nested ACK/RETI diagnostics remain open.
5. Unchanged native serial/firmware execution, current-source Quartus timing/
   CDC review, and physical connector/voltage/loopback tests.
