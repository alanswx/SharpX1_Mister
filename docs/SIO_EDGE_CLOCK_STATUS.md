# SIO event-preserving clock adapter

October 9, 2026. Original standalone RTL, not connected X1 SIO, native mouse
acceptance, FPGA pin CDC or physical timing signoff.

`rtl/x1_sio_edge_clock.sv` converts caller-synchronized clock **levels** to
RX-rising and TX-falling events consumed on the existing system-clock enable.
It captures RX data at the event, not when a later enable consumes it. All
logic remains clocked by `clk`; clock levels are data inputs, not fabric clocks.
The [schematic audit](SIO_MACHINE_WIRING_AUDIT.md) explains why directly
connecting a one-master-edge CTC pulse loses events between SIO enables.

## Bounded transport contract

Each channel/direction has one pending slot. With an empty slot, an event on
an enabled edge is consumed directly. With a full slot, that edge consumes the
old event/sample and retains a simultaneous new event/sample. With enables
stopped, an arrival fills an empty slot; another arrival is dropped and sets
sticky overflow while preserving the oldest sample. This is deliberately
**not unlimited buffering or a promise of native behavior under overrun**.

Global reset clears pending events and diagnostics independently of CE and
tracks current clock levels, so release with a held high/low clock does not
manufacture an edge. External pin synchronization and clock selection belong
to the caller. Future channel-reset/selector integration must define what
happens to an already queued event; this standalone global-reset contract
does not establish that machine policy.

## Executed verification

```sh
make -C verilator test-sio-edge-clock test-sio-ctc-clock \
  HEADLESS_DIR=obj_dir_v14_sio_edge
```

Terminal exit zero, Verilator 5.044, `/tmp/x1-sio-edge-final.log`:

- Nine independent queue-oracle profiles: 22,591 checked master edges each,
  203,319 total. All previous/next clock-level combinations, independent A/B
  data, direct delivery, delayed delivery, consume/arrival collision,
  stopped-enable overflow, oldest-sample retention and reset are checked.
- Thirty-six real CTC/adapter/SIO profiles: CE periods 1/4/7, every relative
  enable phase, at each of the three master labels 32,000,000 / 28,636,364 /
  28,571,428 Hz. CPU-port writes configure real devices; real CTC timer pulses
  drive both channels, receive distinct `96h`/`3Ch` bytes, and transmit `A5h`
  with every x16 8N1 tick and full final stop checked. Held reads and stopped-CE
  global reset/status checks pass. This is a diagnostic shared source from
  CTC channel 0, **not a guessed native A/B CTC assignment**.
- A direct-edge bypass negative control fails specifically because RX events
  disappear between enables. The recipe requires that failure message; it
  rejects an unexpected pass or an unrelated failure.

The physical step uses integer-picosecond half-periods. Frequency labels are
test configurations, not fitted clocks. CE1/4/7 exercise event transport; they
do not claim to reproduce the native 4 MHz SIO clock at every master rate.
An initial fixture check mistakenly expected reset RR0 `04h` while CTS/DCD
were asserted; corrected expectation `2Ch` includes those retained pin levels.
No engine behavior was changed to satisfy it. Width warnings were corrected
with explicit constants/casts, without warning suppressions.

All fourteen existing SIO targets also terminate zero after this addition,
87 PASS messages in `/tmp/x1-sio-edge-existing-regressions.log`, using
`HEADLESS_DIR=obj_dir_v14_sio_short`. New targets are selected by hosted CI;
no new hosted outcome is asserted here.

## Remaining integration gates

The subsequent [CZ-851 selector checkpoint](SIO_MACHINE_WIRING_AUDIT.md#numbered-pin-correction-and-tested-cz-851-selector)
adds 16 pin-level truth cases and extends all 36 CTC/SIO profiles with real
B WR5/DTRB source switching. The original command evidence above remains
historical; `/tmp/x1-sio-selector-all.log` is the terminal extended result.
The subsequent [end-to-end route checkpoint](SIO_MACHINE_WIRING_AUDIT.md#end-to-end-cz-851-ctc-routes-and-connected-diagnostic)
traces CZ-851 CTC1 to A's alternate input and CTC2 to B. Its 128 routing truth
cases and all 36 distinct-rate CTC/SIO profiles terminate zero in
`/tmp/x1-sio-routes-final.log`; the earlier shared-source recipe remains
historical, not proof of native routing. Pin waveform qualification, CZ-880
differences and shared-machine integration remain open.

Finish native internal clock routes/LS157 selection, external pin CDC and
model-specific inputs. Then default-disabled machine decode, real CPU daisy
ownership/reset and snapshots, clock/mouse/short-frame/modem/IRQ combinations,
authorized native software and source-bound fit/hardware acceptance. The
adapter is not in `machine.qip`; ordinary machine behavior, v14 states,
private assets and the current RBF are unchanged. Group 1/Z7 remains open.
