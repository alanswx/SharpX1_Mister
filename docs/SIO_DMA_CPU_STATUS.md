# Actual CPU/SIO/DMA ownership diagnostic

October 6, 2026. `sio_dma_cpu_tb.sv` executes an original generated diagnostic
on existing `cpu.v`/TV80, connected to `x1_dma` and
`x1_sio_interrupt #(FLOW_ENABLE=1)`. It extends the
[synthetic-grant SIO/DMA tests](SIO_DMA_STATUS.md) with real CPU programming,
bus grants, resumed execution, data/count assertions and error intervention.
It is **not instantiated by the X1 machine, native firmware, FPGA timing or
physical serial acceptance**. No machine/CPU/peripheral RTL changes were needed;
default profiles and v11 machine states remain unchanged.
A subsequent `+im2` profile now qualifies one genuine vectored error service
after burst release, including stopped-enable ACK and decoded RETI. This is
SIO IRQ service during DMA work, **not implementation of DMA's own IRQ engine**.

## Executed result

```sh
make -C verilator test-sio-dma-cpu test-sio-dma test-sio-async \
    test-sio-formats test-sio-irq test-sio-first-status test-sio-flow \
    test-sio-cpu HEADLESS_DIR=obj_dir_v11_units
```

All eight targets pass. The combined diagnostic runs both A/B at CE=1/4/7,
with original DI and new `+im2` profiles: twelve executions, three blocks /
ten pairs / four real grants each. SYS is
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
two CPU error-data inspections. The original DI profile requires the special
IRQ during inspection and no ACK/RETI. The IM2 profile requires IUS instead
(its IRQ is blocked after ACK), as described below. Both require an IRQ
observed while DMA owns the error pair and no IRQ/service at completion.

## IM2 error service and stopped-enable ACK

`+im2` retains the preceding RX/TX, bytes, counts, PC isolation and grant
assertions. The generated program additionally sets I=`70` and IM2, programs
B's vector register `E0` and status-affects-vector, and installs an original
handler at `1000` through vector `70EE` (A special RX) or `70E6` (B special RX).
This vector page is separate from the main original program; it is not a
native firmware mapping. B's status-vector bit is retained across its flow
configuration changes. The first-character mode is still explicitly unarmed;
the framing-error special source itself raises IRQ.

After polling the actual first DMA copy `9200=37`, CPU executes EI/HALT.
IRQ remains a real device level, with no fixture gating, but the program
deliberately enables it only after that copy. This directed phase does not
qualify every IRQ/BUSRQ ordering at initial serial arrival. Each ACK must
occur with DMA ownership released, BUSRQ inactive and exactly five SIO DMA
reads (the four normal RX bytes plus the error word). Its vector is checked
throughout the real M1/IORQ bus level. ACK must not select SIO/DMA ordinary
registers or the delayed memory target.

The fixture stops the shared advancement CE for **80 SYS edges during that
real ACK**, while SYS continues. CPU PC/vector/ACK remain stable, ownership
stays released, and SIO must consume the level exactly once: ACK count one,
RETI count zero and IEO inactive. Serial advancement also pauses because its
engine uses that CE; this is not independent CPU/DMA-clock testing.

The CPU handler pushes AF/BC, reads framing status `41`, reads locked `37`
twice and sends actual WR0 Error Reset. It stores an original handler marker,
restores registers, then executes EI/RETI. Clearing the error must **not**
clear SIO IUS: IEO must remain inactive until the genuine RETI is decoded
from completed ED/4D instruction fetches by existing `x1_irq_bridge`.
CTC/keyboard inputs are idle; its RETI event is qualified to the sole SIO,
not broadcast into a real multi-device chain. Final CPU memory/count checks
still require the next DMA byte `B6`, then `A5`/HALT. Exactly one ACK and one
RETI, no pending IRQ and IEO released are required; no manufactured service
completion or WR0 return-from-interrupt shortcut is used.

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

Current complete-suite log: `/tmp/x1-sio-dma-im2-suite.log`. Earlier DI-only
checkpoint: `/tmp/x1-sio-dma-cpu-suite.log`; initial IM2 development:
`/tmp/x1-sio-dma-im2.log`. The build retains the inherited
TV80 missing `DIRSET` pin warning; there are no new default warnings or
source suppressions. The earlier continuous-only run remains in
`/tmp/x1-sio-dma-cpu.log`, and recovery development run in
`/tmp/x1-sio-dma-cpu-recovery.log`. Existing SIO regression assertions were
not weakened or removed.

## Remaining gates

- Broader IRQ/BUSRQ phases, nesting and shared CTC/SIO/keyboard daisy-chain
  service, DMA's own unimplemented IRQ engine, reset/drain and
  independent CPU/DMA enable stoppage in the combined fixture.
- Multiple queued RX bytes in bursts, error/arrival/reset collisions and
  exact W/RDY phase, opposite-channel and open-drain handling.
- Schematic-qualified X1 clock/modem/Ready wiring, machine decode, DAM/ACK
  isolation and opt-in integration. The logical selected-channel Ready mux
  in this fixture is not evidence of the board's physical wiring.
- Native unchanged serial diagnostics, current-source timing/CDC fit and
  physical connector/loopback. No new RBF or hardware result is produced.
