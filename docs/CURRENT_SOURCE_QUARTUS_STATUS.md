# Current-source single-clock Turbo Quartus retry

October 6, 2026. The requested current-source hardware acceptance is **not
complete**. The first frozen build failed parsing; the separately frozen retry
has completed map, fit, assembly and original STA with exit zero and produced
an RBF. Supplemental all-corner/path analysis now passes. This is not physical
acceptance or full timing/CDC signoff.

## Original failure, preserved

`QUARTUS_REVISION=sharpx1_turbo_single bash scripts/build_quartus.sh` froze
356 inputs at clean source commit `191009a8e4da566f86eae1f843f9c284d909c0b9`.
Build directory:
[quartus-bL74DEv2](../output_files/quartus-bL74DEv2/).
The input manifest SHA-256 is
`c5cb1c036db65426ee03f851c782f6fc83c779e86facdca18ce06fa24feb4ed4`.
The snapshot, original log and failure manifest remain unchanged.

Quartus Prime Lite 17.0.0 Build 595 ran the pre-flow build-ID hook successfully,
then map failed after 25 seconds, 7 errors / 12 warnings, wrapper exit 3.
Start/end: 23:25:27–23:26:02 UTC. Fit, assembly, STA and supplemental timing
did not run; no RBF was produced.

The first error is at `rtl/x1_dma.sv:64`, an implicit conditional-generate
`if(COMPLETION_IRQ)`. Quartus expected `endmodule`; errors around its `else`
and output declarations follow the parse failure. Verilator accepted that
SystemVerilog syntax, so prior simulator passes did not prove Quartus support.

The correction adds explicit `generate/endgenerate`, with no register,
expression, profile or state-layout change. Notices remain intact. Inherited
and new-source `async_reg` attributes are still reported unsupported by this
Quartus version; no attribute suppression or CDC signoff is implied.
Local `test-dma`, `test-dma-native-irq`, `test-dma-native-irq-cpu` and
`lint-wrapper` all exit zero after this edit. The twelve real-CPU completion
IRQ profiles, 36,864 native register/vector cases and default DMA stream/
payload/wrap/Ready/restart checks are preserved. Log
`/tmp/x1-dma-quartus-generate-regression.log`. The wrapper lint still uses a
PLL interface stand-in, not fitted timing or Intel PLL simulation.

## Frozen retry

New directory:
[quartus-L7gRiDWX](../output_files/quartus-L7gRiDWX/), started 23:48:21 UTC.
Its snapshot-time HEAD is still `191009a`, with the explicit-generate edit
included as a working-tree change. Never relabel that original manifest as a
clean commit; bind the completed implementation separately once committed.

Implementation binding is now verified: all **356 frozen input hashes** were
recomputed directly from commit
`889f23c8112600defc12ad6a3b24a992142478e8`: **356 match, zero differences**.
The snapshot-time HEAD/dirty manifest above remains unchanged. This binding
identifies source bytes, not a completed build, artifact or timing result.

Input manifest SHA-256:
`f091971e62d936076621d7cad928ffb3384535cd8724e19c19a8fe97983b68ec`.
Comparison of all 356 input manifests shows exactly one changed source:

| Input | Original SHA-256 | Retry SHA-256 |
|---|---|---|
| `rtl/x1_dma.sv` | `1afa6ed01b965a61dbb8494b745f23918da462d8ff82269205048d9a4fb1c1f8` | `853ff4f79e3bb3f86bd21bf1456fa342d64c078aec0c5c97e8a622777cd03dcc` |

All 356 retry input hashes were also checked against the post-fix working
tree: zero differences, log `/tmp/x1-current-quartus-retry-input-check.log`.
Subsequent documentation and simulator-only fixture edits are outside this
FPGA manifest. Retry map completed successfully with **0 errors / 118 warnings**
in the build log; the report also records successful synthesis, 32,171 registers
and 3,143,528 block-memory bits. These are synthesis estimates, not fitted
resource counts. The fitter subsequently completed; see actual fitted counts
below. Warning/constraint review and supplemental timing remain outstanding,
not implied by passing map or the main flow.

The local cached amd64 Apple container runtime is used, not the unavailable
remote build host. Device `5CSEBA6U23I7`, top `sys_top`, project `sharpx1`,
revision `sharpx1_turbo_single`, seed 1, map one thread / fit eight, container
16 CPUs / 16 GiB. It uses the existing 28.571428 MHz single-clock board PLL,
not nominal X3 clocks. DMA/IRQ and the new Kanji profiles remain disabled in
this FPGA revision. Parsing their sources does not enable their capabilities.

The warning review and source-bound supplemental checks below now support
using this as the recommended **experimental hardware test candidate**.
Physical video/audio/disk and Main/OSD reset acceptance still require MiSTer.
It replaces the October 5 candidate for testing, not as a compatibility-certified
release. See [tester handoff](TESTER_HANDOFF.md).

## Completed main flow and supplemental analysis

The frozen retry exits **0**, ending `2026-10-07T00:53:59Z` in its manifest.
The stage logs report map 0 errors/118 warnings, fit 0/9, assembly 0/0 and
original STA 0/0. The original STA still explicitly reports incomplete
setup/hold constraints; a zero exit code is not full signoff.

Actual fit: **20,545 / 41,910 ALMs (49%)**, 32,105 registers,
3,143,528 / 5,662,720 block-memory bits (56%), **393 / 553 RAM blocks (71%)**
and 32 / 112 DSP blocks (29%). Thus 160 RAM blocks remain before a new Kanji
profile; do not assume the larger Z ROM fits or reduce its required capacity.

Recommended experimental hardware test artifact:
[sharpx1_turbo_single.rbf](../output_files/quartus-L7gRiDWX/source/output_files/sharpx1_turbo_single.rbf),
3,860,876 bytes, SHA-256
`0a996f49c67e585fe63351659db068260fbb779e3be67c51ba7f6d6d571a632e`.
SOF SHA-256 `61763e4c4de8d7a8226e10057804e2d9faf9299bad96acdfe18e19eba312ee99`.
It binds `889f23c` FPGA inputs, not subsequent simulator/asset/documentation
work. No MiSTer deployment, game boot or hardware reset test occurred.

Original constrained summary minima are setup **0.781 ns**, hold **0.205 ns**,
recovery **3.739 ns**, removal **0.899 ns**, minimum pulse width **1.122 ns**,
all TNS zero. Original STA reports were preserved in
`output_files/quartus-L7gRiDWX/single-corner-reports/` before supplemental
analysis. These numbers are not all-eight-corner acceptance.

The same fitted database subsequently completed the existing
`quartus_sta sharpx1 -c sharpx1_turbo_single --multicorner=on --all_corners`,
followed by the tested path-report helper. Log:
`output_files/quartus-L7gRiDWX/all-corners-and-paths.log`.
No source, refit, assembly or constraint change is made for that analysis;
RBF/SOF hashes above are identical afterward. All 356 original input hashes
also still match the working tree, log `/tmp/x1-current-inputs-after-sta.log`.
Both supplemental commands exit zero, no errors/warnings. No MiSTer deployment
or physical input/reset/boot test occurred.

### All-corner constrained timing

The complete log contains all eight models and all five checks per model;
no negative worst-case slack was found. Values in ns:

| Model (1100mV) | Setup | Hold | Recovery | Removal | Pulse width |
|---|---:|---:|---:|---:|---:|
| Slow 100C | 0.781 | 0.205 | 3.739 | 0.899 | 1.122 |
| Slow -40C | 0.641 | 0.132 | 3.907 | 0.842 | 1.122 |
| Slow 85C | 0.769 | 0.212 | 3.779 | 0.892 | 1.122 |
| Slow 0C | 0.736 | 0.143 | 3.905 | 0.828 | 1.122 |
| Fast -40C | 3.873 | 0.081 | 5.221 | 0.367 | 1.122 |
| Fast 0C | 3.803 | 0.086 | 5.160 | 0.378 | 1.122 |
| Fast 85C | 3.522 | 0.099 | 4.971 | 0.420 | 1.122 |
| Fast 100C | 3.507 | 0.102 | 4.908 | 0.427 | 1.122 |

The separate path helper executes on the current fitted database, default
slow 100C model. Setup/hold/recovery reports contain 30/20/20 paths with zero
violations. Twenty PCG destination setup paths have worst slack 24.821 ns;
twenty MR16 destination setup paths have worst slack 14.512 ns. Those two
destination filters are not an exhaustive CDC/beam/arbitration verification.

### Warning review and unaccepted limits

No warning suppression, false path, multicycle or I/O constraint was added.
The review includes the actual map/fit log and these remaining classes:

- `async_reg` is ignored by Quartus 17 on core/framework synchronizers. Passing
  timing does not prove synchronization constraints or metastability signoff.
- Unused DMA/IRQ/diagnostic nodes reflect disabled profiles, not newly enabled
  devices. Kanji-source parsing is not an instantiated Kanji FPGA feature.
- Width truncations remain in inherited CPU/MR16/video/timer code; the unused
  legacy decoder still reports implicit `text_cs`. These were not silently
  changed or covered by broad correctness claims.
- Dual-clock RAM collision warnings remain. Supported ownership/reset protocols
  are tested separately; no arbitrary simultaneous read/write values are claimed.
- PLL reset/lock/output connectivity warnings remain, including loss-of-lock
  recovery. Their presence is a physical startup/recovery gate, not a waiver.
- Framework bidirectional/undriven ROM-write ports, unused pins, incomplete I/O
  assignments and ignored fast-I/O/fitter assignments remain reported. External
  setup/hold paths are not fully constrained. No board electrical signoff exists.

This build is appropriate for coordinated, disposable-media bring-up testing,
not evidence that all work groups or Turbo Z are finished. The X3 FPGA profile
still needs its own current-source refit/timing/hardware gates; these positive
single-clock results must not be attributed to it.

## Timing-report helper qualification (historical fit only)

`scripts/quartus_timing_paths.tcl` now accepts the two checked-in Turbo
revisions as well as base/single, and adds a hold report. It changes no
assignment, constraint or RTL. The revised script SHA-256 is
`b92a41c29a78cbe6fb4aa587933fee023acd15b3872cffce9f070a0338ffd502`.

The actual Quartus 17 command was executed on a disposable copy of the
**October 5 `ffc1c1c` fit**, not the current retry:
`output_files/timing-helper-q7VjSYsA/source/`.
`quartus_sta -t /x1scripts/quartus_timing_paths.tcl sharpx1_turbo_single`
exits zero, no errors/warnings, log `/tmp/x1-timing-helper-turbo-single.log`.
All five reports exist and contain real paths. The copied RBF SHA-256 remains
`78ca9ecf057e167fdbb38fafe4fe149c41ea416e259214bdd09b016a65ddc301`
before/after; the original historical build was not modified.

| Report | Paths / violations | Worst slack (ns) |
|---|---|---:|
| Setup | 30 / 0 | 0.632 |
| Hold | 20 / 0 | 0.248 |
| Recovery | 20 / 0 | 4.373 |
| PCG destination setup | 20 / 0 | 23.305 |
| MR16 destination setup | 20 / 0 | 16.029 |

This is the default slow 1100mV/100C model, a helper execution check on old
source, not all-corner or current-source acceptance. Run the helper and the
separate all-corner STA on the current fitted database after the main flow
finishes. Other revision branches in the helper are not newly executed here.
