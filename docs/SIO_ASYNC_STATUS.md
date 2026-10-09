# Standalone SIO asynchronous slice

October 5, 2026. `rtl/x1_sio_async.sv` is original local RTL, **not yet in
`machine.qip` or connected to the X1**. It is a bounded polled asynchronous
**5/6/7/8-bit, no/even/odd-parity, x16/x32/x64**
slice, not a complete Z80 SIO. Machine serial and SIO IRQ support are absent.
A separate [standalone RX/TX/CTS/DCD interrupt wrapper](SIO_IRQ_STATUS.md) now passes
connected pin/service and actual-CPU IM2 tests; it does not change this
default polled wrapper or connect either wrapper to the machine.
No emulator source, firmware or private asset bytes are imported.

The [programming contract](SIO_REGISTER_CONTRACT.md) remains the roadmap.
Additional primary review: local Zilog UM008101-0601, printed 236–237 /
PDF 256–257, and printed 283–287 / PDF 303–307 of the
[official Zilog manual](https://www.zilog.com/docs/z80/um0081.pdf).
Short received characters fill unused upper bits with ones and retain parity
in the next bit when the data length is below eight. The receiver checks one
stop even when transmission selects 1½ or 2. Three character/error buffers
preserve the first two words;
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
- WR3/4/5 select independent RX/TX data lengths, parity, 1/1½/2 TX stops
  and x16/x32/x64 divisors; receive and transmit use
  separate enable events on the common clock. No generated pulse is a clock.
- RX samples a start midpoint, then the configured data/parity and one stop. Short
  false starts are rejected. Each three-byte FIFO carries framing status;
  overrun replaces the third character rather than dropping the oldest.
  Parity becomes sticky when its affected word reaches the FIFO head.
- TX has separate holding and shifting registers. RR0 holding-empty and
  RR1 all-sent are distinct while a character is being transmitted. Serial
  progression stops when serial tick enables stop, while CPU access continues.
  A subsequent [Transmit Enable drain](SIO_TX_DISABLE_STATUS.md) qualifies
  clearing/re-enabling WR5 D3 alone during a frame: finish that character,
  retain queued data while disabled, then resume normally. Other busy frame
  configuration writes remain diagnosed as unsupported. The expanded drain
  matrix passes 504 cases across 108 formats at each of CE=1/4/7, with exact
  parity/stop pins, queued resume and pre-final-tick RR1 checks.
- Idle/no-pending-data WR5 D4 Send Break forces TxD low independently of
  serial ticks and TX enable. Clearing it returns idle TxD high. Queued-data
  writes during break, asserting break with pending data, and WR5 changes
  during transmission remain explicitly unsupported; no frame continuity or
  receive-break detection is claimed.
- RR0 reports buffer state and actual active-low CTS/DCD inputs. RTS/DTR
  outputs follow WR5. A subsequent [automatic-enable increment](SIO_AUTO_ENABLE_STATUS.md)
  qualifies WR3 D5 CTS/DCD gating in addition to the software enables;
  physical pin phases remain open. The subsequent
  [asynchronous RTS increment](SIO_RTS_STATUS.md) retains a cleared request
  through the active character and queued data until all-sent; 3,024 actual
  pin/format/seam cases plus idle/reset/isolation tests pass.
- WR0 channel reset affects only that channel; Error Reset clears the
  overrun and parity latches. Chip reset works on SYS even when advancement
  CE is stopped.
- Unsupported configurations/commands set a sticky diagnostic output; it
  clears on channel/chip reset. RR2/IRQ vectors are not fabricated. WR2 storage
  alone does not imply interrupt capability. TX overflow flags unsupported.

## Executed original tests

```sh
make -C verilator test-sio-async HEADLESS_DIR=obj_dir_v11_units
make -C verilator test-sio-formats HEADLESS_DIR=obj_dir_v11_units
```

All three independent executions **CE=1/4/7 pass**. Simultaneous channels
receive distinct original patterns and emit independently checked start,
data and stop bits. Assertions cover:

- false start, three buffered characters and one-pop held reads;
- fourth-character replacement, delayed overrun visibility and sticky reset;
- bad stop followed by good data, associated framing and recovery;
- two queued TX frames, exact bit values/16-tick duration and empty/all-sent;
- stopped serial ticks, independent modem status/output levels;
- unsupported x1-mode detection, A-only reset preserving B;
- chip reset with explicitly stopped advancement CE;
- natural simultaneous receive-completion/CPU-pop at FIFO occupancy 1/2/3;
- natural TX-holding take/CPU-write replacement without losing either byte.

The added format fixture passes **108 configurations on both channels at
each CE=1/4/7** (324 matrix cases, each exercising RX and TX). It checks every
transmitted bit on every serial tick, including the final tick of 1/1½/2
stops, and RR1 all-sent before/after completion. RX checks short-character
one-fill/parity retention, deliberate A-only parity corruption, sticky error
reset, delayed parity visibility behind a good word, and A-only framing error.
A directed case receives five bits while transmitting eight. Polled IRQ,
sync and live TX reconfiguration are explicitly detected as unsupported.
The subsequent idle Send Break increment adds positive spacing/release checks;
queued/busy break remain unsupported.

The test is asset-free. Logs: `/tmp/x1-v11-sio-and-scheduling.log` and
`/tmp/x1-v11-sio-async.log`; expanded formats/collisions:
`/tmp/x1-sio-format-final.log`. There is no machine, native serial, Quartus or
physical RS-232 acceptance. Adding this unconnected slice does not change
the serialized machine or require conversion of v11 states.

## Next gates

1. Externally synchronized x1 mode, receive/busy-transmit break, exact modem phases,
   5-or-less variable-length encoding and
   exact error-reset effects outside this polled subset. Live frame changes
   are flagged unsupported and frame parameters are latched at start/take;
   the manual's live RX-length adjustment is **not implemented**. Validate
   continuous back-to-back input and arbitrary incoming clock phase.
2. The separate interrupt wrapper now has vectors, nested service, stable ACK,
   RETI/WR0 and actual-CPU IM2 checks, including explicitly armed first-character
   RX/error locking/rearm and CTS/DCD snapshots. Native reset arming, remaining
   external sources and full multi-device service qualification remain open.
3. Schematic-qualified external clock/pin events and `1F90..1F93` machine
   decode, memory/DAM/ACK isolation and CTC/keyboard arbitration.
4. WAIT/Ready semantics and DMA serial transfers. Current ports expose no
   fake WAIT/Ready/IRQ signal to firmware.
5. Native firmware/serial diagnostics, source-bound fitted timing/CDC and
   physical connector/voltage/pin-loopback validation.

## October 6 idle Send Break increment

Reviewed Zilog UM008101-0601 printed 288 / PDF 308, WR5 D4, and the local MAME
`z80sio.cpp` TxD override as a second implementation, not copied or run.
The primary [manual](https://www.zilog.com/docs/z80/um0081.pdf) specifies the
spacing override independently of transmitted data. This increment qualifies
only the unambiguous idle/no-pending-data case, not active-frame handling.
It changes only the standalone SIO slice; the shared machine does not include
it, so no snapshot version, game requalification or new RBF is implied.

`test-sio-break` passes on A/B at CE=1/4/7: held WR5 strobes, independent
channels, 80 SYS edges with CE and serial ticks stopped, TX-enable clear,
marking on release, channel reset isolation and chip reset with CE stopped.
Negative cases require sticky unsupported status for queued/busy break.
All other eight SIO targets pass unchanged except the format fixture's old
assertion that **idle** break must be unsupported: it now verifies both actual
spacing and release. Other unsupported-mode assertions remain intact.
The original failed assertion is retained in `/tmp/x1-sio-break-regression.log`;
passing full suite: `/tmp/x1-sio-break-regression2.log`. No warning suppressions
were added. Neither connector timing nor native serial software is qualified.

```sh
make -C verilator test-sio-break test-sio-async test-sio-formats test-sio-irq \
  test-sio-first-status test-sio-flow test-sio-cpu test-sio-dma test-sio-dma-cpu \
  HEADLESS_DIR=obj_dir_v11_units
```
