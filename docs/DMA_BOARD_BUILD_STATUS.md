# DMA single-clock FPGA qualification revision

October 8, 2026. `sharpx1_turbo_dma_single` is a separate opt-in FPGA revision,
inheriting `sharpx1_turbo_single` and enabling the existing shared-machine DMA,
completion IRQ and EOB-only restart IRQ. SYS/video use the checked-in actual
28,571,428 Hz PLL output and enables. Existing revisions remain DMA-disabled.
This is not full DMA, native Turbo firmware or Turbo Z support.

The wrapper passes the three capability parameters together under
`X1_TURBO_DMA_RESTART`. Invalid combinations without single-clock Turbo
foundation, or with X3 video, are rejected. No framework, clock constraints,
private assets, device engine, reset drain or interrupt bridge are changed.
The Linux and Apple-container build helpers accept this revision explicitly.

Both baseline and DMA-profile wrapper lint pass (Verilator 5.044); inherited
framework warnings remain, log `/tmp/x1-dma-board-wrapper-lint.log`. Shell
syntax checks pass. The native Quartus 17.0.2 full flow is running from frozen
commit `818b0de28e6a3331e3894fd0313369bad618e534`, in build-host directory
`output_files/quartus-linux-mlCE5xen/`. Input-manifest SHA-256 is
`0ea6cc295cca21472203cb1a08cf8e56ebd66c8d3fc4dfd3ec68700c7ba00d99`.
This paragraph does not claim its pending fitting/timing result.
Analysis/synthesis has completed successfully and its hierarchy report retains
the DMA IRQ bridge/reset guard. Quartus warns that reset-guard `pending` powers
up high despite the RTL initializer (`18061`/`18010`). Do not suppress this or
claim cold-start equivalence from the RTL initializer; physical startup/reset
must be qualified. Inherited framework mode-array/CDC warnings remain too.

The shared-machine clock-matched simulator previously passed six memory and
twelve A/B FDC restart cases; see [exact scope](DMA_RESTART_MACHINE_STATUS.md).
That is not fitted or hardware evidence. The dedicated wrapper lint target
uses the same PLL interface stand-in as the other wrapper checks.

```sh
make -C verilator lint-wrapper-turbo-dma
ssh misterubuntu 'cd /home/alans/mister/SharpX1_Mister && QUARTUS_REVISION=sharpx1_turbo_dma_single bash scripts/build_quartus_linux.sh --check'
# Only after checking for competing Quartus jobs:
ssh misterubuntu 'cd /home/alans/mister/SharpX1_Mister && QUARTUS_REVISION=sharpx1_turbo_dma_single bash scripts/build_quartus_linux.sh --build'
```

Build/fit/all-corner timing and source/RBF identities must be recorded before
deployment. No new RBF is qualified by this source addition. Actual CPU-driven
hardware diagnostics need visible RGB success/failure markers: the existing
RAM-completion-only simulation fixtures do not prove hardware success from a
black screen. Protected disposable A/B media, restart/RETI, native boot/input,
owned/pending-SD reset and broader video/audio must be tested separately.
Do not contact or use reserved mister192. The recommended previously qualified
experimental RBF remains `quartus-linux-ZOMREvtv/sharpx1_turbo_single.rbf`.

## Visible CPU diagnostics

`test_dma_visible_ipl.py` now emits eighteen original, 32 KiB IPLs based on
the existing memory/A/B restart programs. A real CPU prologue programs PPI,
40-column CRTC and palette/VRAM. Pending/failure stays red; green is published
only after the original buffered-address/payload/guard/status and three-handler
assertions. GRAM power-up data cannot affect the uniform palette marker.
No machine debug writes, forced IRQ/grants or private assets are used.
The six default memory and twelve default FDC fixture byte streams are unchanged.

All eighteen pass the board-matched 28,571,428 Hz fast runner
`3058ff48dce8da0527ffc8afe7a21b47c584a0871c473f5b3c121ee673e67004`:
exact CPU completion/counts, unchanged generated disk images and 1,152,000
green pixels. The completion-only control stays red with zero pairs. The
earlier isolated first-destination-buffer bug control produces CPU `EE` after
eight pairs and all 64,000 red pixels; production RTL is untouched.
Outputs: ignored `output_files/dma-visible-818b0de/`; logs
`/tmp/x1-dma-visible-ipl.log`, `/tmp/x1-dma-visible-bug-negative.log`.
The separate SYS32 delay-aware visible matrix is still running; its result
must not be inferred from the fast profile.

```sh
make -C verilator test-machine-dma-restart-visible
```

`scripts/mister_dma_matrix.py` stages unique MGLs/configs, verifies RBF/IPL/disk
hashes, accepts only mister126/mister14 and defaults to no core loading.
`--execute` loads each test and records actual PNGs, requiring exact 320×200
green pixels and unchanged disposable disks. It refuses incomplete local
fixture qualification. No hardware run of those tests is yet recorded.
