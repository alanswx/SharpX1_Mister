# Standalone SIO asynchronous RTS drain

October 9, 2026. Original implementation and pin-driven tests; SIO remains
outside the shared machine and board revisions.

## Primary contract and reproduced bug

[Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf), printed
288 / PDF page 308, specifies that an asserted RTS request goes low, while
asynchronous release waits until the character has finished and the transmit
holding buffer is empty. The local manual retains SHA-256
`b4efc81540c05990883cf4c7792c2a3d49fb7471bb5502931383ab55b4540886`.
Local MAME `z80sio.cpp` RTS-update and transmit all-sent routines were inspected
as a second implementation; none is copied, built or executed for this test.

The expanded original pin fixture fails before the RTL change, terminal
nonzero in `/tmp/x1-sio-rts-before.log`: case 1 releases RTS on the first
start-bit disable while a character is active and another byte is queued.
It observes actual external outputs; internal shifter state is not forced.

## Implemented behavior

`x1_sio_async_channel` now remembers an asserted RTS request. Clearing WR5
D1 retains low RTS while the real shifter or holding register remains occupied.
The post-edge state releases it at the final programmed stop tick, exactly
when the current subset's RR1 all-sent becomes true. A queued byte blocked by
software TX disable or CTS keeps RTS asserted. Reasserting the software request
does not wait for serial clocks. Pending data cannot assert RTS on its own
after an idle release. Chip/channel reset clears the retained request.

During an active frame, real changes limited to WR5 TX-enable and/or RTS are
now accepted. Repeating an unchanged WR5 configuration remains diagnosed, as
do active length, break, DTR and CRC changes. The original negative format
and busy-break assertions are retained. DTR remains directly programmed;
synchronous behavior, exact pin delays and busy-break handling are not newly
qualified.

## Terminal verification

```sh
make -C verilator test-sio-rts test-sio-auto-enable test-sio-tx-disable \
  test-sio-async test-sio-break test-sio-formats test-sio-irq \
  test-sio-first-status test-sio-cpu test-sio-flow test-sio-cpu-irq-reset \
  test-sio-dma test-sio-dma-cpu HEADLESS_DIR=obj_dir_v14_sio_rts
```

This thirteen-target invocation terminates zero on Verilator 5.044:
`/tmp/x1-sio-rts-full.log`, 81 PASS records. The initial RTS-only post-fix
run also terminates zero in `/tmp/x1-sio-rts-after.log`. The full rebuild emits
only two inherited TV80 missing DIRSET warnings; the pin fixture adds no
warning suppressions.

`test-sio-rts` runs 504 cases across 108 current asynchronous format settings
at CE=1/4/7, with software TX disable and separately CTS gating: 3,024 cases.
RTS clears during start/data/parity/stop; a mid-frame reassert/clear case is
included. Every actual TX bit and complete 1/1.5/2-stop duration, RR1 before
the final tick, blocked queued-data marking and retained RTS, resumed byte,
exact RTS release and unaffected B are checked. Serial ticks stop during
held CPU access while CPU CE continues.

Each of the six profiles also checks idle release, no spontaneous RTS
assertion from queued data, immediate software assertion without serial
ticks, queued-only retention, stopped-CE retention, A channel reset while B
is transmitting, and stopped-CE chip reset. Existing WR5/CTS drain matrices,
automatic RX gating/restart/FIFO preservation, polled/format/break/IRQ/CPU/
flow/reset/DMA fixtures pass their unchanged assertions.

These generated format tests do not establish native serial compatibility,
the 5-or-less variable-length encoding, all simultaneous CPU/serial-edge
collisions, physical pin timing or modem/IRQ/Ready combinations. Machine
decode, schematic clocks/modem/Ready pins, daisy chain and native serial
software still require integration/acceptance. No default snapshot layout,
frozen five-game runner or fitted Turbo-single RBF changes. Hosted CI now
selects this target; its new source-bound result is not yet known.
The subsequent [short-transmit increment](SIO_SHORT_TX_STATUS.md) separately
qualifies table-28 one- through five-bit encodings and corrects the older
five-bit fixtures' non-data upper bits; this RTS checkpoint stays historical.
