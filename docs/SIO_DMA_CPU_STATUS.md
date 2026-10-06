# Actual CPU/SIO/DMA ownership diagnostic

October 6, 2026. `sio_dma_cpu_tb.sv` executes an original generated diagnostic
on existing `cpu.v`/TV80, connected to `x1_dma` and
`x1_sio_interrupt #(FLOW_ENABLE=1)`. It extends the
[synthetic-grant SIO/DMA tests](SIO_DMA_STATUS.md) with real CPU programming,
bus grants, resumed execution, data/count assertions and error intervention.
It is **not instantiated by the X1 machine, native firmware, FPGA timing or
physical serial acceptance**. No machine/CPU/peripheral RTL changes were needed;
default profiles and v11 machine states remain unchanged.

## Executed result

```sh
make -C verilator test-sio-dma-cpu test-sio-dma test-sio-async \
    test-sio-formats test-sio-irq test-sio-first-status test-sio-flow \
    test-sio-cpu HEADLESS_DIR=obj_dir_v11_units
```

All eight targets pass. The combined diagnostic runs both A/B at CE=1/4/7:
six executions, three blocks / ten pairs / four real grants each. SYS is
100 MHz (10 ns), with eight initial enabled reset edges and deterministic
enable phase. Original 8N1/x16 serial patterns are event-driven on the same
SYS domain. These frequencies test digital behavior, not X1 baud/clock wiring.
There are no private assets, snapshots, emulator imports, forced PC/registers,
fake RDY pulses or forced ACK. Memory holds only original emitted program
bytes and an initial `CC` sentinel; all post-reset data/control writes are
from the CPU or owned DMA bus. Read-only hierarchical probes monitor PC and
wait for device configuration; they do not manipulate execution.

## What the Z80 actually verifies

1. Programs the selected SIO and DMA through genuine OUT instructions.
   DMA Port A is fixed SIO data at `1F90` or `1F92`, Port B incrementing RAM.
   Active-low Ready is supplied by the actual selected SIO output, with WAIT
   sampling enabled. RX and TX use continuous ownership; a later error block
   uses burst mode. Fixed TX destination uses the documented two-LOAD sequence.
2. Receives `53 64 75 86` into `9000..9003`. The CPU polls actual memory, then
   loads/compares all four bytes and reads DMA's stopped count as `0003`.
   The host checks eighty enabled edges with empty RX cannot start DMA; once
   granted, eighty-edge inter-character gaps retain continuous ownership
   without creating extra pairs.
3. Writes `69 7C 8F A2` to `9100..9103` using CPU store instructions and starts
   memory-to-SIO DMA. Every actual TX pin bit is checked for sixteen events.
   Full holding with paused serial advancement retains ownership but cannot
   accept another byte. After DMA release the CPU polls actual RR1 all-sent,
   then reads the stopped count `0003`; no fixture completion/status port exists.
4. Programs first-character RX and a two-byte burst to `9200..9201`. Serial
   `37` has a deliberately bad stop. One DMA copy locks Ready and releases
   the burst bus, allowing CPU intervention. The CPU polls actual RAM, reads
   RR1=`41`, reads the retained data `37` twice and issues WR0 Error Reset.
   Subsequent good serial `B6` naturally resumes DMA; CPU checks `9201=B6`
   and terminal count `0001`. Unlike the earlier synthetic fixture, the
   good frame is not required to finish before CPU Error Reset, so this test
   does not independently qualify two already-queued error/good characters.
5. Emits `A5` in RAM and halts only after those original compare/assert
   instructions succeed. Failure branches emit `EE` and fail the fixture.

Independent bus monitors check exactly ten DMA source/destination pairs,
six SIO data reads, four SIO writes, four grants, one error-status read and
two CPU error-data inspections. The special IRQ must be present during error
inspection and cleared at completion. This program deliberately stays DI;
it neither ACKs an IRQ nor claims combined IM2/DMA error service qualification.

## Ownership and response contract

CPU's real BUSAK selects the sole bus owner. Its genuine BUSRQ input is driven
by DMA; no synthetic grant state exists. All CPU strobes must be inactive,
and PC/CPU side-effect count must remain unchanged, throughout continued DMA
ownership. DMA strobes without ownership, mixed memory/I/O selects, changed
pending transactions, ROM writes and unrecognized targets fail immediately.

The original target adapter inserts four enabled intervals before accepting
the returned read response or committing a memory write. Raw peripheral
selects can take their own effect earlier, on their first enabled edge;
this is not a delayed peripheral-write timing model. Control selects are presented
throughout the actual CPU strobe, including a WAIT-stretched ENABLE OUT that
can make DMA request before the CPU cycle has finished. CPU must not grant
until its own cycle completes. Each run observes blocked request/grant edges:
11 at CE=1, 12 at CE=4/7. These are fixture timing counts, not silicon cycles.

SIO/DMA reads are clocked responses allowed to settle during target WAIT;
one response register retains the byte through strobe release/idle sampling.
One memory side effect is accepted per stretched transaction. This implements
the response-persistence requirement found in the earlier
[CPU WAIT tests](SIO_FLOW_STATUS.md), not a fix to the unconnected machine.

Final log: `/tmp/x1-sio-dma-cpu-suite.log`. The build retains the inherited
TV80 missing `DIRSET` pin warning; there are no new default warnings or
source suppressions. The earlier continuous-only run remains in
`/tmp/x1-sio-dma-cpu.log`, and recovery development run in
`/tmp/x1-sio-dma-cpu-recovery.log`. Existing SIO regression assertions were
not weakened or removed.

## Remaining gates

- Combined IRQ/IM2 service during DMA (including ownership release and
  genuine RETI), shared CTC/SIO/keyboard daisy-chain service, reset/drain and
  independent CPU/DMA enable stoppage in the combined fixture.
- Multiple queued RX bytes in bursts, error/arrival/reset collisions and
  exact W/RDY phase, opposite-channel and open-drain handling.
- Schematic-qualified X1 clock/modem/Ready wiring, machine decode, DAM/ACK
  isolation and opt-in integration. The logical selected-channel Ready mux
  in this fixture is not evidence of the board's physical wiring.
- Native unchanged serial diagnostics, current-source timing/CDC fit and
  physical connector/loopback. No new RBF or hardware result is produced.
