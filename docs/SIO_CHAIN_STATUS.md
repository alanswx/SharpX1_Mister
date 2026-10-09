# Standalone SIO interrupt-chain integration

October 9, 2026. Original GPL-2.0-or-later `rtl/x1_sio_irq_bridge.sv`
composes the existing prefix-aware CPU-bus owner with the CZ-851 functional
SIO → DMA → CTC → keyboard priority order. It is not in `machine.qip`,
the shared machine or any FPGA revision. Ordinary profiles, private states,
snapshot format v14 and the fitted RBF are unchanged.

## Contract

SIO now exports `service_active` from its actual six IUS bits. Neither low
IEO nor a pending interrupt establishes service: IEO can also be low because
upstream IEI is low. The bridge routes decoded RETI to SIO when SIO has IUS,
otherwise serviced DMA, otherwise CTC. Keyboard retains its existing mailbox
ACK behavior; no keyboard service latch is invented. Any external upstream
device must qualify RETI before this bridge; its service is not modeled here.

ACK selection occurs once, before the selected device changes its pending
or service state. The shared owner holds that vector throughout M1/IORQ,
including a later higher SIO request or channel reset. Global reset quarantines
an already-held ACK until its physical release. This is SYS-edge functional
arbitration, not physical daisy propagation, half-clock timing or Turbo Z ASIC
qualification.

## Verification

`make -C verilator test-sio-irq-bridge HEADLESS_DIR=obj_dir_v14_sio_chain`
uses a 10 ns SYS fixture, eight initial reset edges and held ACKs of forty
edges. `sio_irq_bridge_tb.sv` instantiates the **real SIO priority engine**;
DMA and CTC in this new fixture are explicit synthetic request/service models,
not actual chips. It checks:

- CTC service, nested DMA, then two nested SIO slots and isolated returns.
- Low upstream IEI does not suppress the actual local service's return.
- Pending, unacknowledged SIO cannot steal DMA's RETI.
- Late higher SIO arrival cannot replace DMA's held vector.
- Channel reset preserves held ownership; global reset prevents stale ACK replay.
- Keyboard ACK and CB-prefixed operand rejection before a genuine ED/4D RETI.
- A fixture-only `+BAD_SERVICE` substitutes `!IEO` for actual SIO IUS and must
  fail the pending-SIO/DMA-return assertion. The DUT is not modified or forced.

Existing serial/CPU/DMA fixtures exercise the newly exported output with no
behavioral changes; the separate `test-dma-irq-bridge` uses real DMA and CTC.
Passing these separately does **not** prove a combined real-device/CPU chain.
Next: connect real serial requests, DMA and CTC with the actual CPU, cover
concurrent service/reset phases, then integrate a default-off shared-machine
profile with source-bound native clock phases and snapshot qualification.
Native serial/mouse software, physical pin/CDC timing and hardware remain open.

### Executed local checkpoint

Both commands exit zero with Verilator 5.044:

```sh
make -C verilator test-sio-irq-bridge test-sio-irq test-sio-first-status \
  test-sio-flow test-sio-cpu test-sio-cpu-irq-reset test-sio-dma \
  test-sio-dma-cpu test-dma-irq-bridge HEADLESS_DIR=obj_dir_v14_sio_chain
make -C verilator test-sio-decode test-sio-clock-select test-sio-edge-clock \
  test-sio-ctc-clock test-sio-async test-sio-tx-disable test-sio-auto-enable \
  test-sio-rts test-sio-short-tx test-sio-break test-sio-formats \
  HEADLESS_DIR=obj_dir_v14_sio_chain
```

Logs: `/tmp/x1-sio-chain-final.log` and `/tmp/x1-sio-chain-remaining.log`.
The first reports 74 PASS lines, including the expected-failure control;
the second reports 98, for 172 across the twenty targets.
newly built CPU fixtures retain only the inherited TV80 missing `DIRSET`
warning. The new chain fixture and bridge have no reported build warnings.
The earlier initial log includes a missing `service_active` connection in a
CPU fixture; all existing wrapper users now explicitly connect or leave this
output open, and the final CPU rebuild no longer reports that warning.

Source SHA-256:

| Source | Hash |
|---|---|
| `rtl/x1_sio_irq.sv` | `42812033d329fcc47944a2f6fc530ca0dd52983cc75dbaeca99f47ce50fb6d2d` |
| `rtl/x1_sio_irq_bridge.sv` | `da6d680c862617b61e456fd7c69ca0a8db7343dd63b1bb63742f5e488710db33` |
| `verilator/tests/sio_irq_bridge_tb.sv` | `8fe46a8ab9a9354060783e23bb3790d9b389e3ce95afa3874ee6dfcf789ba7f5` |

The asset-free hosted workflow selects the new target; a hosted result is
not claimed here. No private media, firmware, screenshots or state was added.
