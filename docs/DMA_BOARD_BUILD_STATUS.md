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
