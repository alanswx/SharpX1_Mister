# Single-clock experiment

Opt-in, not the default machine or a hardware release. Both modes instantiate
`rtl/sharpx1.v`; no alternate behavioral machine is substituted.

```sh
make -C verilator single single-fast
make -C verilator test-single
make -C verilator boot-game-single
make -C verilator test-game-single
cd verilator
python3 tests/benchmark_clocks.py obj_dir_fast/Vtop obj_dir_single_fast/Vtop
```

The simulation master is 28,636,364 Hz, with system and video inputs driven
together in one evaluation. `--cycles` remains a **32 MHz reference-duration**
unit in both modes: 32,000,000 means one simulated second, not the single
model's actual edge count. JSON reports the actual frequency and edge counts.
This keeps audio, keyboard scripts and A/B workloads at equal physical duration.
Reset extends until all download bytes have been delivered at the actual rate.
The single model rejects independently changing its video clock. Snapshots are
configuration-specific; regenerate them after RTL changes. The snapshot magic
now includes the system frequency; older baseline snapshots need regeneration.

## Architecture

- `x1_clock_enables.v` uses separate phase accumulators for average 4 MHz
  CPU/FDC and 2 MHz PSG enables. They are sampled on master rising edges,
  prepared on falling edges, never connected to clock pins. CPU spacings are
  7/8 master cycles, PSG spacings 14/15. Average rate error remains bounded;
  individual emulated cycles are not uniformly spaced.
- Video retains integer phase/pixel enables. Optional `ENABLE_MODE` in the
  inherited CRTC replaces its fabric-divider clock with a master-edge enable.
  The enable occurs on the same divider transition as the legacy falling edge.
  CPU-side CRTC register writes already sample the system rising edge.
- Text/attribute/GRAM RAM ports, PCG transactions and renderer run on the same
  physical clock in board one-clock mode. The existing PCG handshake remains;
  removing its latency is a separate, unvalidated optimization.
- Motor hold time scales with the master frequency. FDC index/byte timing
  remains expressed in 4 MHz enable ticks.

The MR16 **timer now preserves its 32 MHz reference tick rate**, using one or
two virtual ticks per master edge and carrying overshoot across reloads.
The inherited interval is N+1 ticks (256 gives 257 ticks), not exactly the
firmware comment's 8 us. Independent timer-model tests cover both single-clock
frequencies and the unchanged 32 MHz baseline, including gating, reload and IRQ.
The MR16 instruction clock itself remains approximately 10.5% slower.
Passing mailbox/PS2/game tests does not prove every firmware delay, repeat,
cassette or RTC operation is correct. Fractional CPU edge jitter can also
affect raster-sensitive software. Keep the baseline while broadening coverage.

## FPGA selection

Defining `X1_SINGLE_CLOCK` in the wrapper ties `clk_sys` to the existing
video PLL output. Its **actual checked-in rate is 28,571,428 Hz**, not the
simulation's nominal crystal target; fractional enables use that actual rate.
The unused 32 MHz PLL output is left intact for the baseline. Do not claim the
PLL was regenerated or crystal timing corrected. A future PLL change needs
new synthesis, timing and frequency verification.

No blanket false paths or multicycle exceptions are added by this experiment.
External framework/PS2 crossings remain. One internal clock does not itself
prove safe asynchronous reset release, physical RAM collision behavior or
hardware correctness. Quartus comparison evidence belongs in `QUARTUS_BUILD.md`.

The timer-compensated single revision completed synthesis, fitting, assembly
and TimeQuest on 2026-10-03. Core setup/hold/recovery slack is
**+10.144 / +0.247 / +13.106 ns**;
there are **zero unconstrained clocks**, eliminating the legacy CRTC gap.
Whole-design worst setup slack is +0.513 ns (HDMI domain). Three input and
44 output ports remain incompletely constrained, and hardware has not been
tested. These positive analyzed results are not full board timing signoff.
The initial failing baseline build predates disk changes, so it is not an
identical-source controlled A/B fit; inspect actual path reports and manifests.

## Simulation results (2026-10-03)

Verilator 5.044: delay-aware `test-single` passes timing/FST/reset/rate,
CPU/RAM/overlay, firmware mailbox/PS2, keyboard IM1 make/break, graphics bus,
PSG tones/noise/all 16 envelopes, PPI/joysticks and generated D88 disk tests.
PCG CPU readback passes at the single master frequency. The savable model
passes snapshot continuity and joystick persistence/override. Unit tests prove
bounded enable count error and exact per-master-edge CRTC output equivalence
in both 40/80 modes; these are digital tests, not physical timing signoff.

Native boot: 13 simulated seconds, 4,095 IPL bytes, 4,159 actual reset edges,
372,272,732 system/video edges, 763 disk reads, 805 frames, 320x200 RGB,
frame hash `18dfa7a7557b20fb`. Assets are the existing IPL and ignored CROSS
Chase disk identified in `PLAYING.md`. After timer compensation, the unchanged
200 ms gameplay test **passes**: idle player (22,14), controlled player (21,13),
with both up and left movement. Idle/controlled frame hashes are
`2917b1d92124ea6c` / `16f792d1d2c74a8c`, matching the baseline and repeatable.
Before compensation, the same test missed left movement. This controlled
change supports the timer-rate mismatch as the cause of that regression,
not a claim of complete keyboard or game compatibility. Firmware
`fw_subcpu/x1sub.asm` specifies `CPU_MHZ=32`; the original regression was
retained rather than relaxing its duration or input spacing.

The positive Quartus results above describe frozen timer/clock commit `f45918d`,
not the later FDC silent-abort change. Normalized enable accumulators eliminated
the two latch warnings without suppressions; other warnings remain. Consult
`QUARTUS_BUILD.md` for source hashes and constraints before claiming signoff.

An interleaved three-run IPL-wait benchmark used equal 1-second durations and
28,636,364 Hz video in both fast models, without frame/bus capture:

| Model | Wall-time samples (seconds) | Median |
| --- | --- | --- |
| Baseline | 38.278, 34.135, 32.340 | 34.135 |
| Single clock | 21.954, 20.966, 18.580 | 20.966 |

Measured speedup: **1.63x**. Other tests/builds were active; this is a preliminary
workload-specific comparison, not an isolated benchmark or guaranteed gameplay
speedup. `benchmark_clocks.py` retains deterministic reports and checks equal
physical duration. A cleaner repeated comparison remains useful.

A second interleaved five-run comparison at 250 ms duration measured median
3.544 s baseline versus 2.254 s single (1.57x). Concurrent tests/Quartus were
still active; both comparisons suggest approximately 1.6x for this workload.

## Original clock sources

The locally inspected CZ-800C schematic page 1 shows a 16.000 MHz crystal
and CPU divider logic; page 4 shows a separate 28.636 MHz crystal and video
divider/multiplexer logic. This is the base schematic, not MAME's 42.954545 MHz
Turbo board listing. See [manual provenance](../references/manuals/README.md).
