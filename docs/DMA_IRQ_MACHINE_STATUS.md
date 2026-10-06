# Shared-machine completion IRQ increment

October 6, 2026. `TURBO_DMA_IRQ=1` explicitly requires `TURBO=1` and
`TURBO_DMA=1`. Board, base, ordinary Turbo/X3 and existing DMA defaults
remain unchanged. This connects the [native command path](DMA_COMMAND_IRQ_STATUS.md)
to the actual shared `rtl/sharpx1.v` CPU, not a stand-in machine. It does
not finish DMA, Turbo, work groups 1–6 or Turbo Z.

## Connection and model contract

The original `x1_dma_irq_bridge.sv` composes the unchanged prefix-aware
CTC/keyboard bridge with the [schematic-audited](DMA_IRQ_INTEGRATION_PLAN.md)
active DMA→CTC→keyboard chain. External/SIO capability is explicitly absent;
this is not a Turbo Z chain audit. Native DMA receives IEI, ACK and RETI,
provides IP/IUS/IEO and its current-status vector, and blocks its own bus
request while servicing an interrupt. The existing owner latch freezes the
vector for the entire physical M1/IORQ cycle. ACK is consumed only once by
the selected device. DMA's RETI releases DMA alone when it preempts CTC;
CTC's internal channel nesting remains unchanged. Keyboard retains its real
MR16 third-edge capture, without an invented service latch.

The initial opt-in simulator target is `turbo-dma-irq`; JSON identifies
`turbo_dma_irq=true`. Its reserved snapshot identity bit 47 distinguishes
the new service state from ordinary DMA revision 6. There is **no savable IRQ
build or executed IRQ snapshot gate at this initial checkpoint**. The
subsequent service/reset extension below adds those gates. Defaults retain the original
`machine.irq_bridge` instance/state path and v12 profile identity.

## Initial checkpoint executed local checks (`a666232`)

Verilator 5.044/macOS Clang; shared SYS 32 MHz, video 28,571,428 Hz,
normal ioctl IPL download/reset and real 4 MHz CPU/DMA enables. No private
assets, patched state, forced IRQ/BUSACK, debug memory injection or synthetic
machine Ready are used in the new CPU diagnostic.

- Connected real-DMA/CTC pin fixture at CE periods 1/4/7: simultaneous pending
  sources, upstream blocking, retained downstream pending, forty stopped-CE
  ACK edges, AF retaining IUS, isolated DMA-over-CTC RETI, internal CTC nesting,
  keyboard selection, invalid held ACK and raw reset. This fixture manually
  drives CPU bus pins; it is not itself a CPU or physical timing test.
- Generated shared-machine IPL: four completion profiles on **both fast and
  delay-aware builds**, each retaining the full 8,000,000 reference cycles.
  Each executes two blocks with real WR4/WR6 programming, IM2 `EI;HALT`
  recovery, handler RR0/AF/8B/AB and RETI, CPU guard checks and exactly two
  handler entries. Totals per profile are 8 reads/8 writes (EOB), 6/0 (early
  pure match), 4/4 (Byte transfer match, four grants), and 10/0 (combined
  pure match/EOB). Other profiles use two grants. No forced upstream gate.
- IRQ-enabled fast machine: all seven existing RAM/overlay/A/B read/write/
  CRC/protection cases pass, plus GRAM 576 pairs/36 grants and PCG 96 pairs/
  six grants, with CPU-visible counters and target isolation. These existing
  diagnostics do not program interrupts; they check IRQ-profile continuity.
- IRQ-profile delay-aware reset fixtures: all four RAM owned-pair reset
  profiles, five PCG-owned profiles (including stopped video WAIT), and eight
  held-reset A/B read/write pending-SD phases pass. Host ACK drains on SYS
  while enables stop; retained native diagnostic reboot and exact fresh
  transfers pass. IRQ programming/service-phase resets and short metadata
  matrices are separate gates, not established by these continuity fixtures.
- The existing generated shared-CPU CTC test also passes with this profile:
  all four IM2 channels/cascade/RETI and real MR16 cold F/I/J make/break,
  with deterministic report/RAM repeats.
- Original CTC/bridge/actual-MR16 tests pass unchanged, including MR16 at
  32 MHz, nominal single-clock and actual board single-clock frequencies.
- Fresh base snapshot/clock mismatch/joystick tests pass. An unchanged
  historical v12 native Xevious live snapshot, with its original disk,
  restores for 200,000 cycles on old/new base runners with **every existing
  report field identical**. This is restore continuity, not a new five-game
  qualification. Base cold/steady IM1 keyboard response tests also pass.

The initial regression failures are preserved in `/tmp` logs: an incorrect
CTC fixture byte `02` was a vector write, not the intended disable/control
`03`; expected RETI total was corrected to three CTC releases. New CPU
fixture fixes selected RR0 IRQ/match/EOB bits rather than comparing Ready's
live bits, placed an early search match before EOB (rather than accidentally
requesting a different combined vector), and counted Byte-mode grants per
byte. No RTL assertions, transfer durations or acceptance markers were
weakened to hide these failures.

Source-bound runner SHA-256:

| Artifact | SHA-256 |
|---|---|
| `obj_dir_v12_dma_irq_machine_fast/Vtop` | `da97fa671e537655fe9a59960bd50e1457ab8905a0763b9b8c4da91ca62c1f60` |
| `obj_dir_v12_dma_irq_machine_timing/Vtop` | `6cd087ccc530ea95c1862ad2b22d8652a3c7e9a5ab977d1f1d24681fe17600f3` |
| `rtl/x1_dma_irq_bridge.sv` | `bb6890c4927df10d65a7fb0ec45b7a68e0172662a95caacd5b430c5fbff09370` |

Logs: `/tmp/x1-dma-irq-bridge-corrected.log`,
`/tmp/x1-dma-irq-machine-{fast,timing}-accepted.log`,
`/tmp/x1-dma-irq-machine-{disk,video}-regression.log`,
`/tmp/x1-dma-irq-ctc-default-retry.log`,
`/tmp/x1-dma-irq-reset-regression.log`, `/tmp/x1-dma-irq-machine-ctc.log`,
`/tmp/x1-dma-irq-base-{snapshot,keyboard,historical-restore-new,historical-restore-old}.log`.
Hosted CI now schedules both connected-bridge and shared-machine IPL checks;
their hosted outcome must be recorded separately from local passes.

## Reproduction and remaining gates

```sh
make -C verilator test-dma-irq-bridge HEADLESS_DIR=obj_dir_irq_unit
make -C verilator test-machine-dma-irq DMA_IRQ_DIR=obj_dir_irq_timing
make -C verilator test-machine-dma-irq DMA_IRQ_DIR=obj_dir_irq_fast DMA_TIMING=--no-timing
make -C verilator test-machine-dma-reset test-machine-dma-pcg-reset test-machine-dma-sd-reset \
  HEADLESS_DIR=obj_dir_irq_reset DMA_TEST_IRQ=1
```

Use different output directories for different compiled profiles/timing.
Pending gates include full shared-CPU concurrent DMA/CTC/keyboard and
service-phase A3/C3/raw reset and short-pulse metadata/Ready/DAM cases;
delay-aware disk/video acceptance under this profile; additional snapshot
pending/owned/ACK phases; fresh native Turbo firmware/software; source-bound Quartus/CDC fit and
MiSTer/Main reset acceptance. Ready/IOR/B7, pulse/restart IRQ, variable timing,
sequential non-Byte Stop on Match and primary 8B/IP policy resolution remain
required. No new RBF was built or hardware-tested by this increment.

## Subsequent reset guard, native nesting and service snapshots

The new connected pin regression first **failed**: resetting during a held
DMA M1/IORQ forgot ACK ownership, allowing the same physical cycle to select
a downstream keyboard request after reset. Failure retained in
`/tmp/x1-dma-irq-service-reset-before.log`. This is a synthetic pin-level
transport finding, not a reproduced MiSTer/Main reset bug. The new IRQ bridge
quarantines ACK from reset until M1 or IORQ returns inactive, independently
of transfer CE. The default CTC/keyboard bridge is unchanged. Snapshot IRQ
revision 1 includes identity bits 47/46; ordinary DMA revision 6 and base v12
identities remain unchanged.

Executed checks on the corrected bridge:

- At all CE periods 1/4/7 the new held-reset ACK guard passes; a new idle/fresh
  keyboard ACK works afterward. Native A3/C3 clear DMA IP/IUS, preserve queued
  CTC and do not redirect the captured vector; CTC RETI releases service even
  with upstream IEI low. These are manual chip-programming/bus-pin stress
  fixtures, including programming while ACK is held; they do **not** claim a
  CPU can issue an ordinary I/O command during its own ACK cycle.
- All four original generated two-block CPU completion profiles pass again
  on fast and delay-aware corrected models, at the original full durations.
- A new generated real-CPU nested diagnostic passes fast and delay-aware,
  each with deterministic cold report and RAM/CPU dump repeat. Real CTC0 wakes
  HALT, its handler programs a real DMA block and queues CTC1, DMA preempts
  through IM2, and DMA RETI returns to still-servicing CTC0. The CPU keeps EI
  set during a real instruction delay; queued CTC1 must stay blocked until
  CTC0's own RETI, then execute with the correct phase. Native timers generate
  the requests; no injected trigger/IRQ/IEI/grants. Four exact read/write pairs,
  guard bytes and one handler entry per device are checked.
- A deliberately wrong `/tmp` bridge broadcasting DMA RETI into CTC fails
  this **same final nested test**: CPU publishes failure `EE`, phase remains
  `02`, CTC1 interrupts before CTC0 returns. Negative-control log
  `/tmp/x1-dma-irq-guard-nested-negative.log`. This verifies the test can detect
  the targeted defect; no mutation is in production RTL or the repository.
- New `turbo-dma-savable` and `turbo-dma-irq-savable` fast, SDL-independent
  targets have separate directories/identities. Four native-programmed IRQ
  profiles save at 200,000 cycles inside an actual IM2 handler, with CPU phase
  marker `1` and entry count `0`, then restore to 8,000,000 cycles. Both blocks,
  handler/RETI, source/destination/guards, every machine report field and all
  RAM/text/attribute/sub-RAM/CPU dumps agree with straight execution. Only
  invocation-local `download_bytes` and rolling `video_hash` are excluded;
  they are not serialized state. DMA↔IRQ cross-profile restores are rejected
  before deserialization, without editing headers or model bytes.

The first snapshot test incorrectly compared the invocation-window RGB hash;
its failure log is retained. The base-only generic snapshot fixture locates a
base-specific header and is not applicable to IRQ profile identities; its
failed attempt is not counted as a pass. The purpose-built native-service and
bidirectional profile checks above execute on real saved IRQ states.

| Corrected artifact | SHA-256 |
|---|---|
| `rtl/x1_dma_irq_bridge.sv` | `3e6c723338a65c69bfb8d8b6a9fc1cba393c415a2c983a6572c9d5116c962dd4` |
| `obj_dir_v12_dma_irq_service_savable/Vtop`, fast savable IRQ | `1806d6d16e239491ad7c08b745f079826e77927a8cea8ee59e6125302f992339` |
| `obj_dir_v12_dma_irq_guard_timing/Vtop`, delay-aware IRQ | `34ae0085c90eaa48a3b38f2ffe3255d51d38e145519e51cdc7078ff6a7ac27f4` |

Logs: `/tmp/x1-dma-irq-service-reset-after.log`,
`/tmp/x1-dma-irq-service-snapshot-qualified.log`,
`/tmp/x1-dma-irq-guard-{fast,timing}.log`,
`/tmp/x1-dma-irq-guard-nested-{fast,timing}-qualified.log`.
CI schedules the nested and service-snapshot tests separately; hosted success
is not yet inferred from these local results. No Quartus/RBF/hardware gate
was executed for this extension.

```sh
make -C verilator test-machine-dma-irq-nested DMA_IRQ_DIR=obj_dir_irq_timing
make -C verilator test-machine-dma-irq-snapshot \
  DMA_SAVE_DIR=obj_dir_dma_save DMA_IRQ_SAVE_DIR=obj_dir_irq_save
```
