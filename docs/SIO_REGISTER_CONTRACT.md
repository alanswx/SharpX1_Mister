# SIO implementation contract — research, not a device

October 5, 2026. The active shared machine has no SIO implementation.
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

Before coding, resolve WR1 WAIT/READY prose-versus-figure bit-label discrepancies,
receive error/FIFO pop ordering and channel-reset spacing from the original
figures and exact part timing. Do not copy ambiguous OCR tables into RTL.
