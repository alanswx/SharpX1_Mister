# Standalone SIO automatic modem enables

October 9, 2026. Original RTL/tests, not shared-machine integration or
physical modem timing acceptance.

## Contract and prior failure

[Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf), printed
211–212, 231, 234–235 and 283, describes WR3 D5 Auto Enables: active-low
CTS enables TX and active-low DCD enables RX. WR5 D3 and WR3 D0 still must
enable transmission and reception. Without Auto Enables, modem pins are
status inputs, not data-path gates. The existing local manual hash remains
`b4efc81540c05990883cf4c7792c2a3d49fb7471bb5502931383ab55b4540886`.

Existing local MAME `z80sio.cpp` receive/transmit permission, CTS/DCD change,
receive restart and transmit completion routines were inspected, not copied,
built or executed. They corroborate the software-enable AND and restart a
receiver on carrier return. The exact disposition of a physical character
across brief carrier pulses is not established by this comparison.

Before the RTL change the original external-pin test terminates nonzero:
`/tmp/x1-sio-auto-before.log`, WR3 Auto Enables configuration rejected.
The unchanged new assertion is retained; no internal DUT state is forced.

## Implemented behavior

The standalone channel accepts WR3 D5 in asynchronous modes. New holding-byte
takes require both WR5 enable and, when automatic gating is enabled, low CTS.
CTS going high does not truncate an already-started character; its latched
data/parity/complete stop period drains, while queued data stays pending.
Reception requires WR3 enable and low DCD when automatic gating is enabled.
An inactive DCD observed at an advancement edge abandons the partial receiver
and preserves already-completed FIFO entries. A new start after carrier return
begins fresh. This is a functional restart policy, not proof of exact physical
carrier-drop timing. Gate decisions use current synchronized input levels,
not the external interrupt's retained RR0 snapshot.

Unsupported synchronous, x1, CRC/hunt and live receive reconfiguration still
remain diagnosed. The caller must synchronize modem pins. RTS/DTR output
timing is unchanged at this checkpoint; the subsequent
[RTS drain increment](SIO_RTS_STATUS.md) separately qualifies deferred
asynchronous release, not physical pin timing.

## Terminal verification

```sh
make -C verilator test-sio-auto-enable test-sio-tx-disable test-sio-async \
  test-sio-break test-sio-formats test-sio-irq test-sio-first-status \
  test-sio-cpu test-sio-flow test-sio-cpu-irq-reset test-sio-dma \
  test-sio-dma-cpu HEADLESS_DIR=obj_dir_v14_sio_auto
```

This twelve-target invocation terminates zero on Verilator 5.044, 75 PASS
records, `/tmp/x1-sio-auto-final.log`. The initial full rebuild in
`/tmp/x1-sio-auto-full.log` emits only two inherited TV80 missing DIRSET
warnings. Neither new standalone test emits warnings; the final rerun uses
those already-built neighboring fixtures and rebuilds the strengthened pin test.

- `sio_auto_enable_tb.sv`, CE=1/4/7: inactive CTS keeps queued TX marking;
  independent A/B DCD blocks/allows actual receive bytes; independent RX/TX;
  pins changing with CE stopped cannot take a byte; exact enabled TX pins;
  partial RX abandonment/fresh restart with completed FIFO preservation;
  active modem pins cannot override
  either software enable, separately and together; disabling one direction
  does not stop the other; non-auto mode treats inactive pins as status-only;
  actual held CPU read/write ports and stopped-CE chip reset.
- `sio_tx_disable_tb.sv +MODEM=1`, CE=1/4/7: 504 cases each over all 108
  supported formats. CTS rises at start/data/parity/stop and falls during a
  frame in the re-enable case. Every output tick, complete stop, queued-byte
  marking/resume, pre-final-stop RR1 and unaffected B are checked. The original
  `MODEM=0` WR5 matrix also passes, unchanged expected pins/status assertions.
- Original polled, formats/FIFO, break, IRQ/first-status, actual-CPU IM2,
  flow/reset and SIO/DMA tests pass their existing assertions.

Hosted CI selects the new target; no new source-bound hosted result is claimed.
Short modem pulses while CE is stopped, exact pin phases, auto-enable combined
with retained IRQ snapshots/Ready/DMA pacing, concurrent multi-device service,
native serial software and X1 schematic/decode/clock integration remain open.
SIO is still outside `rtl/machine.qip`; no baseline snapshot version, five-game
runner or fitted Turbo-single RBF is changed by this standalone increment.
