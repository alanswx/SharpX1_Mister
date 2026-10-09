# Conservative SIO bus decode qualification

October 9, 2026. Original standalone bus qualifier and real Z80 diagnostics;
not connected shared-machine SIO, complete ASIC aliases or native pin timing.

`rtl/x1_sio_decode.sv` selects only onboard ports `1F90..1F93`, corresponding
to A data/control then B data/control. This follows the previously inspected
local MAME map and schematic A0/A1 endpoints in the
[machine-wiring audit](SIO_MACHINE_WIRING_AUDIT.md). It does not invent mirrors
from ASIC CE pins or select the external slice at `1F98..1F9F`.

The qualifier rejects reset, disabled selection, DAM traffic, interrupt
acknowledge (`M1` low), inactive `IORQ`, no strobe and invalid simultaneous
read/write strobes. It returns distinct read/write and combined select wires.
It adds no clock, state, IRQ ownership, ROM signature, pin waveform or chip
reset policy. Disabling this **bus selection** gate does not reset or power
down an instantiated SIO; a future default-disabled machine profile must also
explicitly determine its IRQ/output behavior.

## Executed tests

```sh
make -C verilator test-sio-decode test-sio-cpu test-sio-cpu-irq-reset \
  HEADLESS_DIR=obj_dir_v14_sio_decode
```

Terminal exit zero, Verilator 5.044, `/tmp/x1-sio-decode-final.log`:

- 8,388,608 exhaustive cases: every 16-bit address times all 128 combinations
  of enable/reset/DAM/M1/IORQ/RD/WR. An independent inclusive range oracle
  checks select plus both directions; no DUT slice is reused by the oracle.
- Nine actual CPU decode profiles: CE1/4/7 times ordinary, first/status IRQ
  and WAIT-flow diagnostics. Before the unchanged serial tests, real OUT/IN
  instructions touch sixteen adjacent ports (`1F8C..8F`, `1F94..9F`), then
  all four onboard ports under DAM and separately disabled selection.
  Re-enabled A/B RR0 remains `04h` with inactive modem pins, rather than
  showing accidental holding-buffer or pointer changes. RAM results prove
  blocked reads and both-channel retained reset status. Program/vector
  overlap is checked before execution.
- The original nine actual CPU IRQ/flow and twelve stopped-CE IRQ-reset
  profiles also pass with the decoder instantiated. Existing vector order,
  actual handler bytes, FIFO/error behavior, held response, TX pins and RETI
  acceptance checks remain intact.
- Three required actual CPU negatives fail for the intended reason:
  `BYPASS_DAM` and `BYPASS_ENABLE` cause a forbidden selected bus cycle;
  `WIDE_DECODE` aliases neighbor writes into SIO and triggers the device's
  unsupported-register diagnostic. The recipe rejects an unexpected pass
  or an unrelated failure message. Negative knobs exist only in the bench.

The CPU harness now explicitly returns/retains `FFh` for unselected I/O until
the next memory read, just as it already retains a selected clocked SIO
response across TV80's I/O wait tail. This is the **isolated test bus policy**:
on the real machine neighboring addresses can belong to DMA, external devices
or other hardware and need their own response. No claim is made that every
neighboring port is physically unmapped or reads `FFh` on an X1.

One inherited TV80 missing-DIRSET warning appears in this scoped build; no new
warning suppression was added. New asset-free `test-sio-decode` is selected
by the hosted diagnostics workflow; no new hosted result is asserted here.
The complete eighteen-target SIO/clock/decode recipe also terminates zero,
167 PASS messages in `/tmp/x1-sio-decode-full.log`, using
`HEADLESS_DIR=obj_dir_v14_sio_short`. This includes all fourteen pre-existing
SIO targets and the three route/selector/edge targets, not just the new decoder.

## Remaining machine integration

The decoder is not yet in `machine.qip` or instantiated by `sharpx1.v`.
Connect a separate default-disabled profile, real CPU response retention,
DMA ownership/DAM handling and explicit SIO-before-DMA/CTC/keyboard ACK/RETI
ownership. Qualify live gate changes/held strobes and concurrent reset/service,
not just this initial masked-access sequence. Native model clocks, pin CDC,
mouse input, IRQ/Ready modes and ASIC aliases remain open. Counter/pulse
phases follow the unresolved [CTC timing gate](CTC_PIN_TIMING_AUDIT.md), not a
fixed baud shortcut. Shared snapshots, fitted timing, native software and
hardware acceptance remain required. No private assets, default machine
behavior, v14 state format or RBF changed in this increment.
