# Current-source single-clock Turbo Quartus retry

October 6, 2026. The requested current-source hardware acceptance is **not
complete**. The first frozen build failed parsing; the separately frozen retry
has passed synthesis and is fitting. Neither is currently a new RBF or
timing/hardware signoff.

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
resource counts. The existing container's live process is now `quartus_fit`;
do not restart it because buffered logs lag. Warning review, fit, assembly and
timing remain outstanding, not implied by passing map.

The local cached amd64 Apple container runtime is used, not the unavailable
remote build host. Device `5CSEBA6U23I7`, top `sys_top`, project `sharpx1`,
revision `sharpx1_turbo_single`, seed 1, map one thread / fit eight, container
16 CPUs / 16 GiB. It uses the existing 28.571428 MHz single-clock board PLL,
not nominal X3 clocks. DMA/IRQ and the new Kanji profiles remain disabled in
this FPGA revision. Parsing their sources does not enable their capabilities.

Record the retry's terminal result, resource counts, actual RBF/hash, warning
review and source-bound supplemental all-corner timing before promoting it as
a test candidate. Physical video/audio/disk and Main/OSD reset acceptance still
require MiSTer. The October 5 artifact documented in
[the two-drive build report](DUAL_DISK_QUARTUS_BUILD.md) remains the available
recommended candidate until a newer qualified result exists.
