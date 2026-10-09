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

## Connected real-device and actual-CPU follow-up

Two subsequent original, asset-free fixtures use the same bridge and actual
`x1_sio_interrupt`, `x1_dma(COMPLETION_IRQ=1)` and `x1_ctc`. They do not change
machine RTL, default profiles, snapshot format or any fitted RBF.

`test-sio-device-chain` opts the existing `dma_irq_bridge_tb.sv` into
`SIO_CHAIN=1`. All original DMA/CTC assertions remain in that run, followed by
actual A/B receive-pin frames (`B6`, `A5`), nested FIFO/completion/counter
service, low-IEI isolated returns, unacknowledged FIFO pending vs DMA IUS,
and stopped-CE global reset during a held B ACK. Fresh `96` reception/read/RETI
passes after reprogramming the reset devices. Baseline `SIO_CHAIN=0` also
passes separately. CPU bus phases in this fixture are task-generated.

`test-sio-chain-cpu` uses the actual `cpu.v`/TV80 instead. An original RAM
program configures all three devices through real OUT instructions at the
conservative SIO ports, DMA `1F80` and CTC `1FA0`. No DUT registers, PC or
service bits are forced. The generated IM2 table dispatches vectors
`A0 → C4 → E4 → EC`: CTC channel 0, DMA completion, B RX, then higher A RX.
Each handler saves/restores AF/BC. Real IN instructions store `B6` and `A5`;
the actual DMA owns the CPU bus via BUSRQ/BUSACK and copies four bytes
`31..34` from diagnostic RAM `8000..8003` to `9000..9003`. Exact reads/writes,
payload, stable held vectors, all four ACKs/owned RETIs and empty final
service stacks are asserted. A fixture-only `FFF0` host-release input holds
lower handlers so nesting is deterministic; it is not proposed machine I/O.

The `+RESET_NESTED` execution waits until A returns, while B, DMA and CTC
remain serviced and the **DMA bus is drained**, then holds CPU/all devices in
reset for eight SYS edges with CE stopped. Twenty stopped-CE release edges
must not replay IRQ/ACK/service. Without program or RAM reload, the actual CPU
reboots and repeats the entire nested program with fresh serial frames and
DMA bus transfers. This is one concurrent-service reset phase, not a held
CPU ACK reset or an owned-DMA-pair drain replacement. `+BAD_IUS` is a
fixture-only disconnected SIO service input: unchanged CPU ownership
assertions must fail at its first real SIO RETI, at every CE divisor.

Executed command (Verilator 5.044, exit zero):

```sh
make -C verilator test-sio-chain-cpu test-sio-device-chain \
  test-dma-irq-bridge test-sio-irq-bridge HEADLESS_DIR=obj_dir_v14_sio_devices
```

`/tmp/x1-sio-real-chain-final.log` records 23 PASS reports: six successful CPU
executions (ordinary/reset at CE=1/4/7), three required wrong-owner failures,
the two device profiles and earlier standalone bridge controls. The only
reported build warning is inherited TV80 `DIRSET`; no new width suppression
was added. SYS is 10 ns, not an X1 physical-frequency/pin-phase qualification;
RX bits each use sixteen enabled events. The CPU fixture uses eight initial
enabled reset edges; the device fixture retains four initial reset and four
post-reset enabled edges. The initial CPU log failed because DMA's intentionally unsupported
unprogrammed state was checked before the generated configuration; the final
check, as in existing DMA CPU fixtures, requires supported configuration once
the actual DMA is loaded. Valid-transfer, payload and ownership assertions
remain unchanged. Nested handlers were also made register-preserving before
qualification; early logs are retained, not substituted as passing evidence.

| Source/artifact | SHA-256 |
|---|---|
| `verilator/tests/sio_chain_cpu_tb.sv` | `24b045219c3e3152eb37929e4336e503e8e6f5ff8f7144e954305bba24b73bdc` |
| `verilator/tests/dma_irq_bridge_tb.sv` | `bf21f2157ba94d216d40707d813efcf128c5a83f6136660c4f4eb5eb67c80cd5` |
| `obj_dir_v14_sio_devices/sio-chain-cpu/Vsio_chain_cpu_tb` | `3fa4445ddf363e2d5350750ff9231e50c0cb6c9029b8638e6779d928a2eb603f` |

Both targets are selected by hosted CI; a hosted result remains unclaimed.
Next gates are default-off shared-machine integration, additional concurrent
reset/Ready/serial modes, native clocks/pin CDC, snapshot and FPGA/native
software acceptance. This does not complete work groups 1–6 or Turbo Z.

The subsequent [shared-machine increment](SIO_MACHINE_STATUS.md) connects this
bridge and the real SIO in a default-off functional profile. Generated IPL
CPU/RX/WAIT/nested service and retained reset pass with DMA present/absent;
native clocks/pins/software, enabled snapshots and hardware remain open.
