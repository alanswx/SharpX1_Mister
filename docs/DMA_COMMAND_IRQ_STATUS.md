# DMA command-path completion interrupts (opt-in device diagnostic)

October 6, 2026. `x1_dma #(.COMPLETION_IRQ(1))` connects the original
service/vector engines to real WR3/WR4/WR6 programming and completion flags.
This advances work group 2 beyond the [standalone foundation](DMA_SERVICE_STATUS.md).
It is not native firmware/game acceptance or yet a shared-machine IRQ path.
Board, ordinary Turbo and existing opt-in machine DMA leave this parameter
**zero**. The manifest includes the dependencies, not permission to expose
unqualified machine interrupt behavior.

Subsequent work adds a separate [shared-machine opt-in profile](DMA_IRQ_MACHINE_STATUS.md)
with connected priority and actual shared-CPU IM2 diagnostics; the device
checkpoint described here remains independently scoped.

## Observable contract

- WR3 b5 and WR6 AB/AF control delivery. WR4 b4 selects the associated
  interrupt-control byte; its b4 selects the following vector, b5 enables
  current-status modification and b1/b0 select EOB/match conditions.
  Associated vector bytes are always data, including C3/A3/87/8B values.
- Completion flags remain real: transfer writes and pure search's actual
  extra read complete normally. Conditions become eligible when the operation
  is disabled/stopped, not by fabricating an early match or count. Pending
  can be stored behind IEI or outstanding grant drain; IRQ is never delivered
  while either BUSRQ or BUSACK indicates ownership.
- RR0 b3 now reports not-pending. ACK clears IP and enters IUS; accepted
  vectors remain stable for the whole held ACK, independent of transfer CE.
  IUS inhibits the actual DMA IDLE→REQUEST transition, not an external mask
  hiding a DMA request from the CPU. CPU ENABLE/CONTINUE during service can
  prepare work but cannot acquire the bus until service is released.
- AF preserves IP and IUS. AB can expose stored completion after disabled
  delivery. A3 clears IP/IUS, disables delivery and unforces Ready. C3 and
  hardware reset clear service independently of transfer CE while the owned
  operation follows the inherited one-pair drain contract. RETI releases IUS
  regardless of IEI; an uncleared condition can re-pend after release.
- 8B clears match/EOB, not IP/IUS. This chosen functional policy follows the
  [February 1980 product specification](https://bitsavers.trailing-edge.com/components/zilog/z80/Z80_DMA_Product_Specification_Feb80.pdf),
  visually inspected PDF page 9/Figure 8b, and
  [UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf) printed 110–111's
  command/status prose. The later Figure 34's IP reset label disagrees.
  Preserve that primary inconsistency for physical/native qualification; the
  tests prove this explicit policy, not silicon resolution of the disagreement.
  If pending survives 8B, an enabled modified vector reflects the newly
  cleared current flags (00), not a remembered fabricated cause.

Ready/IOR, pulse generation, reserved interrupt-control bit 7, and automatic
restart with completion interrupts remain rejected. B7 is not implemented.
The caller must not silently enable these just because completion IRQ works.
The subsequent [device-only Ready/IOR profile](DMA_READY_IRQ_STATUS.md) adds
explicit `READY_IRQ=1` and B7 qualification separately; completion-only and
all existing machine profiles still reject Ready IRQ.
Status-vector modification uses bits 2:1 = EOB:match, corroborated in the
clearer primary scan. The pure terminal-match/EOB operation policy remains
the separately documented [functional candidate](DMA_SEARCH_STOP_STATUS.md),
not physical event-precedence acceptance.

## Executed checks

```sh
make -C verilator test-dma-native-irq test-dma-native-irq-cpu \
    test-dma-service test-dma-service-cpu \
    HEADLESS_DIR=obj_dir_v12_dma_native_irq_final
```

Exit zero, Verilator 5.044 with timing/assertions. No new warning suppression.
**36,864 native-register unit cases**: CE=1/4/7, all 256 vector bytes, three
real completion classes (transfer EOB, early pure match, terminal pure match
plus extra read), modification on/off, all four interrupt masks and delivery
enabled before/after completion. WR3 enable and WR6 AB paths both execute.
Exact reads/writes, held RR0, disabled/IEI retention, AF/AB, 8B pending
preservation/current-status vectors, held ACK with stopped CE, AF preserving
IUS, A3's full clear and actual request inhibition are asserted.
Directed RETI, real C3 reset during service, sampled reset with held ACK, and source-read/destination-write
owned resets pass at all three rates, including stopped CE and WAIT. Reset
drains exactly one real pair and emits no completion interrupt. Unsupported
Ready/pulse/reserved/restart options are explicitly tested as fail-closed.

**Twelve real CPU native-command cases** execute four completions at CE=1/4/7:
4R/4W transfer EOB, 3R/0W early pure match, 2R/2W sequential Byte match, and
5R/0W terminal pure match with genuine extra read. IRQ control/vector/AB/AF
are programmed through the real DMA port; the old F1 service-enable fixture
is unused. The diagnostic uses a synthetic 10 ns master and CE=1/4/7 to
exercise scheduling, not to claim the physical X1 oscillator/phase. The CPU
initializes source/guards and IM2 pointers, enters HALT
behind an explicit upstream IEI gate, then takes one D4/D2/D6 vector,
executes a handler with real RR0 readback and AF/8B/AB, stores its result and
executes RETI. Both enables stop for 80 system edges during the genuine
ACK. Destination bytes/guards, transaction totals, single ACK/RETI and
released service are checked. This uses a single-owner diagnostic bus, not
the machine's Main/OSD or multi-device IRQ bridge.

The final unit extension with real C3 reset also exits zero in
`/tmp/x1-dma-native-irq-c3-qualified.log`. The prior service-only fixture remains independently executable with
`NATIVE_IRQ=0`: all twelve CPU cases, 4,096 arbitration and 2,048 vector
cases pass on the final source. Log `/tmp/x1-dma-native-irq-final-pins.log`.
The initial CPU RR0 test exposed a stale second I/O response latch; the
diagnostic now presents the DMA's accepted read directly and holds WAIT until
the real `read_seen` edge. Original failure/trace remain in
`/tmp/x1-dma-native-irq-cpu.log` and `...-trace.log`, not erased or solved by
changing expected status. A fixture reference to a hierarchical enum constant
caused a Verilator internal error; final owned-reset tests use actual RD/WR
pins to select phases. The failed build remains in `...-final.log`.

Default, IRQ-disabled regressions also exit zero: original 40 transfer/restart
groups, 10,240 comparison/Byte stop cases, 24,576 search cases, CPU ownership,
SIO/DMA and CPU/SIO/DMA pin/IRQ/reset profiles. Logs
`/tmp/x1-dma-native-irq-default-regressions.log` and
`/tmp/x1-dma-native-default-search.log`.

Fresh base savable runner is byte-identical to the five-commercial-game
qualified v12 executable:
`159062a12920cb398d1bd348b8e901a7b6139d31cfcadd8d038b73235d962a8a`.
Fresh snapshot/clock/header/joystick checks pass in
`/tmp/x1-dma-native-irq-base-snapshot.log`. This is DMA-disabled baseline
evidence, not native completion-IRQ game qualification. No model identity
change is needed for unchanged machine profiles: the newly instantiated
service registers exist only in the standalone `COMPLETION_IRQ=1` profile,
which has no savable runner yet. A future machine IRQ profile must have its
own identity rejection before restoring earlier states.

| Final-source artifact | SHA-256 |
|---|---|
| DMA RTL | `1afa6ed01b965a61dbb8494b745f23918da462d8ff82269205048d9a4fb1c1f8` |
| Service RTL | `bb35f829ac7f3925895f66df157fdbf44dde26bc9bfc5e28074bfc02df7a8616` |
| Final native unit executable including C3 | `af10a2b39a7ba146ab985fb1e22178a72afb539cf22d82a3efad7c6aae0b5a6f` |
| Native CPU executable | `1753b78c2d665e05c2441240087c626fccbaa883a62d8fd3eb25c993a7577edd` |

Default-machine fast search-stop/restart/video requalification and all twenty
delay-aware search-stop profiles both exit zero in
`/tmp/x1-dma-native-irq-machine-fast.log` (session 65867) and
`...-machine-timing.log` (session 37648). These are independently executed,
IRQ-disabled machine gates. Their executable hashes are
`58c521cbe8db145332c958b8cb28b7dc50d9283cbf197bf1922c0e4b020f3094`
(fast) and `5d0be5ccb53a3c3edc585ffa2c2a8a18c6591b1f84a256e76a3c4f72aa8c7c77`
(delay-aware). They do not qualify an as-yet-unimplemented machine IRQ bridge.
Two new hosted targets make 29 diagnostics; hosted terminal result is pending.

## Still required

Ready/IOR/B7, auto-restart stop/ACK/resume, pulse/variable timing, full native
reset/8B precedence, shared-machine ACK/RETI ownership and multi-device
qualification, unchanged native IPL/disk/video/software, and source-bound
Quartus/CDC/hardware acceptance remain open. Local MAME's Turbo daisy table
is explicitly marked order-unverified and differs from the inherited RTL's
SIO→DMA→CTC→sub-CPU chain. Do not choose a physical priority from the emulator
alone or globally expose this device slice as full Turbo/Z interrupt support.
The new [schematic-qualified integration plan](DMA_IRQ_INTEGRATION_PLAN.md)
records model-20/30 signal endpoints and required next tests.
