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
step fast-forwards from the user's fork and starts the frozen-source native
17.0 helper for this revision. The flow is now running, not terminal:

- Source `c3906aeda8b5d3b560e772579a3ee3424d4d46de`.
- Frozen host folder `/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-yoGgHbzg`.
- Observation log `/tmp/x1-quartus-c3906ae-turbo-z-build-retry.log`.

The first fetch fails before Quartus because the host calls the fork remote
`origin`, not `alanswx`; its log is preserved separately. The retry fetches
the explicit alanswx URL, verifies a clean checkout and expected commit, and
checks no competing Quartus process before launching. Until the flow terminates
successfully and reports/manifests are audited, no fitted resource/timing/RBF
claim is made. Do not start supplemental STA while the full flow is active.

The exact jointly enabled video combination also builds a delay-aware C++
runner successfully. Two original CPU-written custom/retained-reset pixel
tests are running: 640x400 internal-eight and paired64 text-between-screens
with priority 12h/screen 1. Frozen runner/emitter/oracle/ANK source are under
`verilator/obj_dir_headless/z-board-combined/qualification-CBgbK8/`, hashed
before either run. Logs `/tmp/x1-z-board-combined-internal8.log` and
`/tmp/x1-z-board-combined-paired-text.log`. These bounded tests are not yet
accepted and cannot establish the full mode matrix or fitted hardware.

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
