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

The opt-in simulator target is `turbo-dma-irq`; JSON identifies
`turbo_dma_irq=true`. Its reserved snapshot identity bit 47 distinguishes
the new service state from ordinary DMA revision 6. There is **no savable IRQ
build or executed IRQ snapshot gate yet**. Defaults retain the original
`machine.irq_bridge` instance/state path and v12 profile identity.

## Executed local checks

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
Pending gates include real shared-CPU concurrent/nested DMA/CTC/keyboard,
service-phase A3/C3/raw reset and short-pulse metadata/Ready/DAM cases;
delay-aware disk/video acceptance under this profile; savable profile/mismatch
tests; fresh native Turbo firmware/software; source-bound Quartus/CDC fit and
MiSTer/Main reset acceptance. Ready/IOR/B7, pulse/restart IRQ, variable timing,
sequential non-Byte Stop on Match and primary 8B/IP policy resolution remain
required. No new RBF was built or hardware-tested by this increment.
