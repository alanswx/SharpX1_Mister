# Completion DMA IRQ: next shared-machine integration gates

October 6, 2026. The [native-command device increment](DMA_COMMAND_IRQ_STATUS.md)
is executed; the machine connection below is a plan. Preserve ordinary
Turbo/DMA and base defaults until the new profile has independent acceptance.

## Model-specific evidence

Reused the hashed CZ-851/852 model-20/30 scan, PDF pages 1 and 5.
Page 1 full render and serial/CTC region were visually reread; page 5's DMA
chip and cross-sheet nets were newly rendered/read at 5000-pixel scale.
Temporary artifacts `/tmp/x1-dma-priority-p1-chain.png`,
`...-p5-chip.png`, `...-p5-chain.png`; primary
[schematic](https://eaw.app/Downloads/Manuals/Sharp/CZ851_2C_Schematic.pdf),
[inventory/hash](../references/manuals/README.md).

| Visible endpoint | Integration implication |
|---|---|
| Page 1 EXIEI net 88, cross-sheet 5-74; SIO IC52 IEI pin 6 | External priority precedes onboard SIO; absent upstream devices may be tied inactive only in an explicitly absent capability profile. |
| SIO IC52 IEO pin 7; named SIOIEO return on page 5 net 73 / 4-157; DMA IC19 IEI pin 38 | SIO precedes DMA in this model; never put a DMA-first fabricated priority above an implemented SIO. |
| DMA IC19 IEO pin **36**; page 5 DMA IEO net 75 / 4-89; page 1 net 89; CTC IC53 IEI pin 13 | DMA precedes CTC. Respect the chip pin label in this scan, not an unverified pin-number recollection. |
| CTC IEO and downstream sub-CPU qualification | Existing [CTC audit](CTC_STATUS.md) establishes CTC before keyboard with no invented keyboard IUS latch. Preserve its MR16 ACK settling contract. |

This corroborates the inherited `sharpx1_legacy.v` SIO→DMA→CTC→sub-CPU
ordering for the inspected model. Local MAME's `x1turbo_daisy` is marked
order-unverified and differs; it cannot override these connections. This is
not a complete decode/clock/modem/ASIC net audit or a Turbo Z chain signoff.
Trace CZ-880 sheets separately before using the same order for a Z profile.

## Required implementation

1. Add an explicit shared-machine `TURBO_DMA_IRQ` capability requiring real
   Turbo DMA; leave defaults unchanged. Connect completion IRQ pins, real
   reset/drain, SYS-domain service and 4 MHz transfer enables. Reject old
   serialized states under a distinct IRQ profile identity before restore.
2. Extend the ACK owner/vector latch, preserving default CTC/keyboard
   behavior. Until SIO exists in the machine, the inspected active chain is
   DMA→CTC→keyboard, with external/SIO capability explicitly absent. Route
   only the selected ACK to a device, even after IP drops or CE stops.
   Hold the selected vector through the actual CPU M1/IORQ cycle; no
   combinational reselection of the next pending device after acknowledgement.
3. Decode RETI once from completed, settled real opcode fetches, reusing the
   existing prefix-aware bridge. Release the highest in-service device, not
   every device on every RETI. A higher-priority DMA interrupt during CTC
   service must return to the still-active CTC service; nested higher CTC
   channels retain their current service rules. Do not invent keyboard service.
4. Gate ordinary DMA programming away from ACK/DAM and owned machine
   cycles. Register-read latency must use the real response/WAIT seam, not
   the stale second latch exposed by the device CPU diagnostic. Keep SD ACK
   processing on SYS while CPU/FDC/DMA enables are stopped during reset.

## Required independent acceptance

- Original bridge tests unchanged with capability off, plus actual CPU
  default CTC/MR16 and base game/snapshot identity checks.
- Concurrent pending DMA/CTC/keyboard; ACK held before/after each candidate
  drops; disabled/upstream-blocked DMA; pending-but-bus-owned DMA must not
  become an interrupt vector provider or erase a downstream event.
- Nested DMA-over-CTC service, CTC internal nesting, upstream IEI low during
  RETI, invalid ACK, AF/A3/C3 and raw reset at ACK entry/hold/handler/RETI.
- Generated shared-machine CPU transfers/searches with real WR4/AB/AF/RR0,
  count/status/guards, HALT recovery and handler stores; no forced registers,
  IRQs, BUSACK or patched private firmware. Test fast and delay-aware runners.
- Existing A/B disk/CRC/protection, pending SD ACK, owned PCG WAIT and reset
  drainage with IRQ profile enabled; no duplicates or false completion IRQ.
- Fresh native Turbo IPL/software continuity, clock/profile rejection,
  source-bound Quartus/CDC fit and actual MiSTer/Main reset/video acceptance.

Ready/IOR/B7, automatic-restart IRQ sequencing, variable timing and the
primary 8B/IP inconsistency are separate required DMA gates, not removed by
the completion-profile integration. Items 1–6 and Z0–Z9 stay in scope.
