# Experimental combined Turbo Z video FPGA profile

October 9, 2026. New default-off `sharpx1_turbo_z_video.qsf` inherits
`sharpx1_turbo_video.qsf` and enables only the explicit
`X1_TURBO_Z_VIDEO_EXPERIMENT` wrapper macro. It requires Turbo foundation,
independent X3 video and no single-clock mode. It does not advertise a native
Turbo Z machine identity or complete CZ-880 behavior.

The shared machine enables external palette CPU access/video, multi-mode
fetch/shifting, internal-eight palette and text/priority CPU/composition
together. Existing board revisions remain unchanged. SYS is requested at
32 MHz, VID at nominal 42.954540 MHz through the inherited experimental PLL;
fitted frequency must be recorded separately. DMA/SIO/FM/Kanji remain off;
audio remains unsigned PSG. Existing RGB12-to-eight-bit-component wrapper
outputs carry the result. No private BIOS/font bytes are added.

## Executed checks / pending build

Ordinary, X3, FM, DMA and new combined-Z wrapper lint all finish zero with
Verilator 5.044 (`/tmp/x1-z-board-profile-lint.log`). This uses a PLL interface
stand-in, not physical clock simulation, Quartus or pixel acceptance. Both
build helpers pass `bash -n` and explicitly admit the new revision. Existing
shared-machine experimental pixel/control evidence remains source-bound;
lint does not qualify every combination of the jointly enabled features.

Read-only inspection of `misterubuntu` finds the authorized checkout clean at
`a7e100731cae6eb450737d1a7a0ebb78c487f57e` and no active Quartus flow. The next
step is to fast-forward from alanswx and start the frozen-source native 17.0
helper for this revision. Until its process terminates successfully and the
reports/manifests are audited, no fitted resource/timing/RBF claim is made.

```sh
QUARTUS_REVISION=sharpx1_turbo_z_video bash scripts/build_quartus_linux.sh --build
```

No timing exceptions or constraints are changed for this experiment. The
combined palette/control/GRAM reset and CDC paths need source-bound timing
and ownership review, all constrained corners and unconstrained I/O audit.
Physical scaler/analog output, native opacity/intensity/bank policy,
BIOS/software, pin timing and full multi-mode hardware qualification remain
open. No MiSTer is contacted/loaded. The prior FM RBF remains a different
feature profile; do not promote it to Turbo Z hardware evidence.
