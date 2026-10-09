# Standalone SIO transmitter-disable drain

October 9, 2026. Original RTL/regression increment, not shared-machine SIO,
native serial or physical timing acceptance.

## Contract and reproduced failure

The existing hashed Zilog UM008101-0601 manual, printed 288 / PDF 308,
was read for WR5 Transmit Enable. It requires an already-started character
to finish when D3 clears. This is distinct from Send Break, reset, synchronous
CRC handling, automatic CTS/DCD enable and changing frame parameters.
Source: [official Zilog manual](https://www.zilog.com/docs/z80/um0081.pdf),
[local inventory](../references/manuals/README.md).
Existing local MAME `z80sio.cpp` transmit-enable/completion routines were
inspected as a second implementation, not copied, built or executed here.

The original pin-driven `sio_tx_disable_tb.sv` fails before the RTL correction:
active A character truncates at start bit, actual A/B pins `01` rather than
the two required start zeros. `/tmp/x1-sio-tx-disable-before.log` retains
that terminal failure. No internal shifter/register state is forced.

## Implemented scope

`x1_sio_async.sv` separates valid transmitter configuration from permission
to take the next holding byte. Clearing WR5 D3 inhibits new takes, but the
current shifter advances through its latched data/parity/stop timing. Queued
data remains full and RR1 cannot report all-sent until it is transmitted.
Re-enabling resumes that byte normally; chip/channel reset still cancels
the transmitter as before.

Only an actual D3-only transition is newly accepted during an active frame.
Other busy WR5 commands retain the subset's existing diagnostic restriction,
including repeat configuration writes. This diagnostic is not a physical
SIO status bit. The initial broader exception accidentally stopped reporting
the unchanged format test's busy configuration write; that terminal failure
is preserved in `/tmp/x1-sio-tx-disable-after.log`. The exception was narrowed,
not the original assertion or format fixture weakened.

## Terminal verification

The complete following invocation exits zero on Verilator 5.044:

```sh
make -C verilator test-sio-tx-disable test-sio-async test-sio-break \
  test-sio-formats test-sio-irq test-sio-first-status test-sio-cpu \
  test-sio-flow test-sio-cpu-irq-reset test-sio-dma test-sio-dma-cpu \
  HEADLESS_DIR=obj_dir_v14_sio_disable
```

Log: `/tmp/x1-sio-tx-disable-final.log`. The new pin fixture runs CE=1/4/7
with four cases each: disable at start/data/stop, plus disable/re-enable during
the same character. It checks every serial tick of both actual output pins,
five-enable held writes, A's retained queued byte and RR0/RR1, B isolation,
200 disabled ticks of marking and exact resumed queued data. Independent
serial ticks stop during CPU programming; SYS/CPU access still advances.
No byte is supplied by a patched CPU register or firmware asset.

### Expanded disable-format matrix

The same fixture now exercises 504 cases per CE profile: 5–8 data bits,
none/even/odd parity, 1/1.5/2 stop bits and x16/x32/x64 serial clock rates
(108 formats). Each format covers start/data/stop disable and mid-frame
disable/re-enable; parity formats additionally disable on the parity bit.
Every actual A/B pin is checked on every serial tick, including the full
programmed stop duration. RR1 must remain not-all-sent immediately before
the last stop tick, both for the original character and the resumed queued
character. The original 8N1 disable/re-enable seams are retained.

The eleven-target invocation above is rerun with the expanded fixture and
terminates zero: `/tmp/x1-sio-tx-disable-formats-full.log`, 69 PASS records.
The new matrix contributes 1,512 cases across CE=1/4/7; its rebuild emits no
warnings. No RTL, CPU fixture assertion, firmware or shared-machine setting
is changed for this expansion.

As a negative control, the unchanged expanded fixture is built against
`a569417^:rtl/x1_sio_async.sv` in a separate temporary directory. It terminates
nonzero at case 1 (5-bit/no parity/one stop/x16), start-bit disable: actual
A/B pins `01`, expected `00`. Logs:
`/tmp/x1-sio-tx-disable-formats-negative-build.log` and
`/tmp/x1-sio-tx-disable-formats-negative.log`. The old behavior is not accepted
by the stronger matrix; neither internal state nor the expected pins are
patched to obtain the result.

The original polled, 108-format, idle-break, IRQ/first-status, actual-CPU
IM2/flow/reset and SIO/DMA fixtures also pass unchanged assertions. Hosted
CI now selects the new target; its new source-bound result is not yet known.

SIO remains outside `rtl/machine.qip` and the shared machine. Existing
baseline snapshots, frozen five-game qualification and the separate fitted
Turbo-single RBF are unchanged. Native decode/clocks/modem/Ready/IRQ integration,
busy/receive break, exact modem phases, x1/synchronous modes and physical validation
remain open; this increment does not finish work group 1 or Turbo Z.
The subsequent [automatic-enable increment](SIO_AUTO_ENABLE_STATUS.md) separately
qualifies functional CTS/DCD gating, not physical modem timing or machine wiring.
The later [RTS drain increment](SIO_RTS_STATUS.md) additionally qualifies busy
WR5 changes limited to TX-enable/RTS, retaining the unchanged-configuration
negative guard and length/break/DTR restrictions.
