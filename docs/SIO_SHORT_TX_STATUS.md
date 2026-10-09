# Standalone SIO five-or-less transmit encoding

October 9, 2026. Original RTL and external-pin oracle, not native serial or
shared-machine acceptance.

## Contract

[Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf), printed
289–290 / PDF pages 309–310, tables 27–28, defines WR5 D6:D5=`00` as
five-or-less, not always five bits. Each data byte encodes its own length:

| Transmit data byte | Payload bits |
|---|---|
| `1111000D` | 1 |
| `111000DD` | 2 |
| `11000DDD` | 3 |
| `1000DDDD` | 4 |
| `000DDDDD` | 5 |

Payload is transmitted least-significant bit first. Marker bits are not
payload/parity. WR5's other length settings remain 6/7/8 bits; receive length
selection is separate and still 5/6/7/8 bits.
The existing local manual retains SHA-256
`b4efc81540c05990883cf4c7792c2a3d49fb7471bb5502931383ab55b4540886`.
Local MAME's asynchronous shifter setup and parity/stop marker recognition
were inspected as a second implementation, not copied, built or executed.
Its length getter alone returns five; the marker-preserving shifter path is
important to understanding its short-frame behavior.

## Reproduced failure and implementation

Before the RTL change, the new independent pin oracle terminates nonzero
in `/tmp/x1-sio-short-before.log`: case 1, one-bit/no-parity character, stop
bit tick zero has actual A/B pins `00` instead of `11`. The old channel sends
extra zero bits because it always selects five payload bits.

`transmit_bits` now decodes the holding byte only in five-or-less mode.
The real take latches a frame containing only the selected payload, its parity
and the programmed stop duration. A subsequent queued byte independently
selects its length without changing WR5 or modifying the current shifter.
Receiver lengths are unchanged. The 194 bytes outside table 28 set the
subset's `unsupported` diagnostic when taken; that flag is not a native SIO
status bit. Their fallback five-bit output is not claimed to emulate physical
behavior. No synchronous, x1 or live frame-configuration support is implied.

## Fixture correction and terminal evidence

Two older five-bit fixtures used unspecified nonzero upper marker bits and
relied on the old model ignoring them. Their five-bit CPU data is now masked
to legal `000DDDDD` encodings. Expected low data bits, parity, all pin ticks,
stop duration, RR1, queue, reset and negative configuration assertions are
unchanged. This is a documented input correction, not a relaxed oracle.
The original new-test failure remains preserved separately.

```sh
make -C verilator test-sio-short-tx test-sio-rts test-sio-auto-enable \
  test-sio-tx-disable test-sio-async test-sio-break test-sio-formats \
  test-sio-irq test-sio-first-status test-sio-cpu test-sio-flow \
  test-sio-cpu-irq-reset test-sio-dma test-sio-dma-cpu \
  HEADLESS_DIR=obj_dir_v14_sio_short
```

This fourteen-target invocation terminates zero on Verilator 5.044,
`/tmp/x1-sio-short-full.log`, 87 PASS records. Only two inherited TV80
missing DIRSET warnings appear; the new pin test has no warning suppressions.
The initial valid-encoding run also terminates zero in
`/tmp/x1-sio-short-after.log`.

At each CE=1/4/7, the new test executes:

- 1,674 cases: all 62 valid encoded payloads, no/even/odd parity,
  1/1.5/2 stop bits and x16/x32/x64 clocks. A/B use complementary payloads;
  A queues a different-length byte with unchanged WR5. Every actual pin tick,
  full stop period, held CPU read/write, RR1 immediately before the final
  tick, holding-buffer status and deferred RTS release are checked.
- All 194 unspecified encodings: require a diagnostic and successful channel
  reset/isolation, without guessing their physical waveform.
- 768 exact A/B pin cases: every byte in each 6/7/8-bit mode, proving short
  marker prefixes cannot truncate those ordinary data frames.

Total: 7,908 new cases across the three CE profiles. Existing polled/RX
format/FIFO, WR5/CTS/RTS drain, automatic enables, break, IRQ, actual-CPU,
flow/reset and SIO/DMA checks pass. No private firmware or forced DUT state
is used. Hosted CI selects the new target; its new result is not yet known.

Short frames combined with native IRQ/Ready/DMA service, serial/CPU collision
phases, native software, physical timing and X1 clock/modem/decode/daisy-chain
integration remain open. SIO is still outside `rtl/machine.qip`; default
snapshot layout, frozen game runners and the fitted Turbo-single RBF are
unchanged by this standalone correction.
