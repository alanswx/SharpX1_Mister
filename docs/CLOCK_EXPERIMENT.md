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

**MR16 is not frequency-compensated.** The inherited replacement sub-CPU and
its timer formerly ran at 32 MHz, now approximately 10.5% slower in the simulator.
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

The single revision completed synthesis, fitting, assembly and TimeQuest on
2026-10-03. Core setup/hold/recovery slack is **+10.397 / +0.245 / +12.244 ns**;
there are **zero unconstrained clocks**, eliminating the legacy CRTC gap.
Whole-design worst setup slack is +0.401 ns (HDMI domain). Three input and
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
Chase disk identified in `PLAYING.md`. The standard 200 ms gameplay test
**fails**: idle player (22,14), controlled player (22,13), with up but not
left movement. A 300 ms replay with extra key spacing also missed left;
a 400 ms endpoint sampled a transient erased player text cell. Do not relax
the default regression or mark full gameplay equivalence complete.
Bus tracing observed the up-key response but no subsequent left-key response;
the cause has not been established. The known slower MR16 timer is a candidate,
not a proven diagnosis. Firmware `fw_subcpu/x1sub.asm` explicitly specifies
`CPU_MHZ=32` and a 256-clock/8-us interrupt interval.

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
