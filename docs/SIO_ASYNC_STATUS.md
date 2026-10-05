# Standalone SIO asynchronous slice

October 5, 2026. `rtl/x1_sio_async.sv` is original local RTL, **not yet in
`machine.qip` or connected to the X1**. It is a bounded polled **8N1/x16**
slice, not a complete Z80 SIO. Machine serial and SIO IRQ support are absent.
No emulator source, firmware or private asset bytes are imported.

The [programming contract](SIO_REGISTER_CONTRACT.md) remains the roadmap.
Additional primary review: local Zilog UM008101-0601, printed 236–237 /
PDF 256–257. Three character/error buffers preserve the first two words;
a fourth arrival replaces the third. Framing belongs to its character and
adds half-bit recovery; overrun accompanies the overwritten slot, becomes
visible when that word reaches the head, and remains until Error Reset.
Local MAME `z80sio.cpp` FIFO and WR0 routines were inspected as a second
implementation, not copied, built or executed. Exact error/IRQ reset effects
outside the polled slice are not established by this increment.

## Implemented standalone behavior

- Two independently configured data/control channels. WR0 pointers select
  the next register access and return to zero. Held CPU strobes cause one
  write or FIFO pop; the read response stays latched during the strobe.
- WR3/4/5 select the supported 8N1/x16 profile; receive and transmit use
  separate enable events on the common clock. No generated pulse is a clock.
- RX samples a start midpoint, then eight data bits and one stop. Short
  false starts are rejected. Each three-byte FIFO carries framing status;
  overrun replaces the third character rather than dropping the oldest.
- TX has separate holding and shifting registers. RR0 holding-empty and
  RR1 all-sent are distinct while a character is being transmitted. Serial
  progression stops when serial tick enables stop, while CPU access continues.
- RR0 reports buffer state and actual active-low CTS/DCD inputs. RTS/DTR
  outputs follow WR5. No automatic modem gating is implied.
- WR0 channel reset affects only that channel; Error Reset clears the
  overrun latch. Chip reset works on SYS even when advancement CE is stopped.
- Unsupported configurations/commands set a sticky diagnostic output; it
  clears on channel/chip reset. RR2/IRQ vectors are not fabricated. WR2 storage
  alone does not imply interrupt capability. TX overflow flags unsupported.

## Executed original tests

```sh
make -C verilator test-sio-async HEADLESS_DIR=obj_dir_v11_units
```

All three independent executions **CE=1/4/7 pass**. Simultaneous channels
receive distinct original patterns and emit independently checked start,
data and stop bits. Assertions cover:

- false start, three buffered characters and one-pop held reads;
- fourth-character replacement, delayed overrun visibility and sticky reset;
- bad stop followed by good data, associated framing and recovery;
- two queued TX frames, exact bit values/16-tick duration and empty/all-sent;
- stopped serial ticks, independent modem status/output levels;
- unsupported parity-mode detection, A-only reset preserving B;
- chip reset with explicitly stopped advancement CE.

The test is asset-free. Logs: `/tmp/x1-v11-sio-and-scheduling.log` and
`/tmp/x1-v11-sio-async.log`. There is no machine, native serial, Quartus or
physical RS-232 acceptance. Adding this unconnected slice does not change
the serialized machine or require conversion of v11 states.

## Next gates

1. Parity, 5/6/7-bit characters, other stops and x1/x32/x64 clocks, break,
   auto-enable/modem latches and exact error-reset effects; simultaneous
   completion/access and configuration-change corner cases.
2. Genuine RX/TX/external IRQ generation, WR1/WR2 vectors, service/daisy
   priority, stable ACK, RETI/WR0 commands and an actual-CPU IM2 diagnostic.
3. Schematic-qualified external clock/pin events and `1F90..1F93` machine
   decode, memory/DAM/ACK isolation and CTC/keyboard arbitration.
4. WAIT/Ready semantics and DMA serial transfers. Current ports expose no
   fake WAIT/Ready/IRQ signal to firmware.
5. Native firmware/serial diagnostics, source-bound fitted timing/CDC and
   physical connector/voltage/pin-loopback validation.
