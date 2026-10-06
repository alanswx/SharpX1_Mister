# SIO implementation contract — research, not a device

October 5, 2026. The active shared machine has no connected SIO implementation.
A subsequent [standalone polled asynchronous slice](SIO_ASYNC_STATUS.md) passes
108 dual-channel 5–8-bit N/E/O formats and original pin/FIFO/collision tests;
an additional [standalone RX/TX IRQ wrapper](SIO_IRQ_STATUS.md) passes connected
service and actual-CPU IM2 tests. First-character/external IRQs,
x1/break/live configuration and machine integration remain open.
Do not replace missing behavior with a successful capability signature.

## Primary evidence and local comparison

Inspected [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf)
SIO printed pages 225–231 and 272–301 (PDF page numbers are printed +20).
The existing ignored local PDF/hash is in the manual inventory. Programming,
FIFO/error and interrupt descriptions were read; physical timing signoff
was not performed. Local MAME `x1.cpp` and `z80sio.cpp` were inspected, not run
or imported. Its device contains variant-specific behavior; an SCC/8274 is
not interchangeable with the X1 Z80 SIO.

The combined reference contract is:

- `1F90/91/92/93`: A data/control, B data/control; offset bit 1 selects B,
  bit 0 selects control. Nonzero WR0 pointers select the next register access,
  then return to zero. WR0 also issues commands, not only pointer selection.
- RX buffering is three characters with associated errors; TX has a separate
  holding register and shifter. RR0 TX-empty differs from RR1 all-sent.
- WR3/4/5 configure receive/transmit length, parity, stop bits, enables,
  modem controls and x1/x16/x32/x64 serial clocks. Synchronous/SDLC are
  separate operating modes, not UART aliases.
- Channel A precedes B; within each, RX precedes TX then external/status.
  WR2/B supplies the vector, optionally modified by source. RR2/B with no
  pending interrupt uses modification `011`, not an invented ready vector.
- Parity/overrun/framing and external-status reset/latch policies differ.
  WR0 channel reset, error reset, next-character interrupt, TX-pending reset
  and A-only return-from-interrupt need distinct effects.

## Ordered implementation and original acceptance fixtures

1. Build a standalone, enable-clocked two-channel engine. Enumerate the
   supported subset explicitly. Use independent bit-edge events for serial
   timing; never clock logic from a synthesized output pulse. Keep parser,
   CPU read latch and one-side-effect-per-held-strobe tests separate from
   serial framing. Test reset/pointer sequences at CE=1/4/7, including delayed
   data/control accesses and unsupported-register/mode handling.
2. Drive actual serial pins with original patterns. Test both simultaneous
   channels, FIFO ordering, buffer/shifter distinctions, paused clocks,
   modem gating, break entry/exit and deliberately corrupted frames. Assertions
   must establish bytes and timing; counting register writes is insufficient.
3. Add interrupt service and an original real-CPU IM2 program. Cover simultaneous
   requests, highest-priority blocking/nesting, stretched ACK, vector stability,
   return-from-interrupt and re-arming. Do not connect an inert IRQ output just
   to satisfy software detection.
4. Integrate real X1 decode and board clock/modem wiring only after schematic
   trace review. Connect shared arbitration with CTC/keyboard and future DMA;
   prove ordinary memory/I/O, DAM and ACK isolation. Establish the WAIT/READY
   ownership/polarity contract before DMA serial transfers.
5. Execute unchanged native firmware/serial diagnostics, record asset hashes,
   enables, pin traces and source-bound fit. Physical RS-232 voltage levels,
   connector wiring and external loopback remain a separate hardware gate.

## WR1 WAIT/READY discrepancy audit

The primary PDF's Figure 115 (printed 279 / PDF 299) was visually checked,
alongside Table 15 (277) and printed 280–281 / PDF 300–301. Figure 115 and
Table 15 agree on the following encodings, as do the inspected local MAME
`WR1_WRDY_*` masks and `update_wait_ready`:

| Bit | Proposed implementation contract |
|---|---|
| D7 | Enable WAIT/READY function. Disabled Ready stays inactive/high; disabled WAIT is released/open-drain. |
| D6 | `1` Ready, `0` Wait. |
| D5 | `1` receive buffer condition, `0` transmit holding-buffer condition. |

Printed 279's prose calls the Ready selector D5, conflicting with its own
figure and printed 280's explicit D6 Wait selector. Table 18 on printed 280
also prints **D7=0 twice**: disabled and purported active-buffer behavior.
Both errors are visible in the original, not just OCR. The active section is
interpreted as enabled D7=1 by consistency with the enable description;
that is an explicitly reasoned correction, not an official erratum.

For the functional asynchronous subset, Ready is active low when the selected
RX buffer has a character or TX holding buffer can accept one. Wait instead
requests a stall on a selected data transaction that cannot complete. The
prose describes Ready temporarily releasing on a CPU access, independent
of selected channel, and particular half-clock edge delays. MAME's simple
level function does not establish those bus-phase effects or open-drain
physics. Test those separately before connecting WAIT/READY to machine DMA;
do not reproduce the table typo or treat a steady readiness level as exact
pin timing. Receive error/FIFO pop ordering and channel-reset spacing still
need original serial/CPU fixtures and exact-part review before acceptance.
