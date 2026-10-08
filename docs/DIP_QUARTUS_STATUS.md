# DIP-fix single-clock RBF (October 6/7)

October 8 follow-up: this artifact now has native game-start observations on
mister126; a newer separately hashed Linux build was also fitted and tested.
See [hardware matrix](HARDWARE_126_STATUS.md). Statements below describing
no hardware execution refer to the original publication date.

Recommended experimental tester candidate:
[sharpx1_turbo_single.rbf](../output_files/quartus-5ge19D0o/source/output_files/sharpx1_turbo_single.rbf).
3,756,448 bytes; SHA-256
`437375668ece99c3de325ce66ed50c85cc7da2f5f430c67e53db2f111a55b60c`.
No hardware execution has occurred. This replaces the previous recommended
artifact for testing, not as a compatibility-certified release.

Frozen main-project Quartus 17 revision `sharpx1_turbo_single`, DE10-Nano
`5CSEBA6U23I7`, top `sys_top`, seed 1, map one thread / fit eight. Local cached
Apple amd64 runtime, installation mounted read-only; no remote host needed.
Build started `2026-10-07T01:57:52Z`, finished `02:08:40Z`, exit zero.
Snapshot directory: `output_files/quartus-5ge19D0o/`.
All **358 FPGA input hashes** match commit
`bcc43495ba35900d1147c395d8c76de43ae157a9`, zero differences, individually
recomputed from Git objects. The original manifest preserves its snapshot-time
working-tree status; subsequent simulator/documentation edits do not enter
this FPGA manifest. Manifest SHA-256
`2978d2ea4d3cb2144d8d127f18ff7331c3c4acba230ecb85a69c52a454ba372c`.

This board revision uses one actual **28.571428 MHz** master with enables,
partial Turbo/CTC foundation and static DIP `F1` (2D boot profile). It includes
the DIP decoder and newer optional source modules, but **does not enable X3,
DMA/completion IRQ, Kanji rendering, SIO or FM**. The native Arcus DMA/logo
simulation result cannot be attributed to this RBF. Full Turbo/Z remains open.

## Executed fit and timing

Map: 0 errors / 118 warnings. Fit: 0 / 9. Assembly and original STA: 0 / 0.
Actual fit: **20,493 / 41,910 ALMs (49%)**, **393 / 553 RAM blocks (71%)**,
3,143,528 / 5,662,720 block-memory bits (56%). Resource estimates do not prove
the larger Z ROM or all missing devices fit when enabled.

Original STA reports were copied to `original-sta-reports/` before running
`quartus_sta sharpx1 -c sharpx1_turbo_single --multicorner=on --all_corners`
and the unchanged `scripts/quartus_timing_paths.tcl` helper on the same fitted
database. Both supplemental commands exit zero, no errors or warnings;
log `all-corners-and-paths.log`. No source/refit/assembly/constraint changes.
The RBF hash remains identical afterward.

All eight slow/fast 1100 mV models at -40/0/85/100 C have positive constrained
setup, hold, recovery, removal and minimum-pulse-width slack. Across all eight:

| Check | Worst slack (ns) |
|---|---:|
| Setup | 0.348 |
| Hold | 0.115 |
| Recovery | 4.209 |
| Removal | 0.534 |
| Minimum pulse width | 1.122 |

The supplemental default-model PCG destination report contains 20 paths,
worst setup 23.991 ns; MR16 destination worst is 15.455 ns. These are separate
focused reports, not physical CDC acceptance or all-corner path-specific proof.

Inherited width/connectivity/RAM optimization/ignored assignment warnings remain.
Quartus ignores `async_reg` attributes; external I/O assignments/constraints
are incomplete, and PLL lock/startup/loss-of-lock warnings remain. Positive
constrained timing is not full timing signoff. No MiSTer cold boot, keyboard,
physical audio/video, disk bandwidth or Main/OSD-reset test has run on this
artifact. Follow the [tester handoff](TESTER_HANDOFF.md), use unique names and
disposable protected disks. Keep the previous artifact and its evidence intact.
