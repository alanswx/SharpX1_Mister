# Working on Sharp X1 for MiSTer

`sharpx1_turbo_dma_single` is a separate DMA/IRQ/restart FPGA qualification
revision; other board revisions stay disabled. Use
`make -C verilator lint-wrapper-turbo-dma` for its interface check, not hardware
acceptance. Record build/timing/hardware gates in `docs/DMA_BOARD_BUILD_STATUS.md`.

## Scope and working tree

This is an experimental FPGA core under bring-up. Read `Readme.md` and
`docs/SHARP_X1_TODO.md` before changing machine behavior. Inspect `git status`
and preserve changes belonging to the user or earlier work. Keep documentation
honest about what has been built, executed, booted, and verified on hardware.

## Architecture

- `sharpx1.sv` is the MiSTer integration wrapper and instantiates
  `rtl/sharpx1.v`.
- `verilator/sim.v` instantiates the same `rtl/sharpx1.v` machine as MiSTer.
  Legacy RTL is reference-only in the headless build.
- `rtl/sharpx1_legacy.v` defines feature and CPU macros in source, including
  an X1 Turbo subset and FZ80. Source ordering and macro visibility matter.
- `rtl/sub_cpu.v`, `rtl/mr16_x1.v`, and `rtl/mr16core.v` implement the
  replacement sub-CPU path. Firmware references live under `bios/reference/`.
- `rtl/x1_pcg_access.v` transfers beam-addressed CG/PCG transactions to the
  video domain; CPU WAIT is CDC latency, not a validated native scanline trap.
  Preserve bundled-data stability and one-write-per-transaction semantics.
- `sys/` is inherited MiSTer framework code. Prefer implementing core-specific
  changes in the wrapper or `rtl/`; explain any required framework edits.

Track machine dependencies in `rtl/machine.qip`, read by Quartus through
`files.qip` and by the Verilator Makefile. Keep board-only dependencies separate. The FPGA
top is `sys_top`; the simulator top is `top`.

## Simulation and verification

From the repository root:

```sh
make -C verilator headless
make -C verilator run CYCLES=200000
make -C verilator test
git diff --check
```

The headless target uses Verilator 5.x and a C++20-capable compiler. It does not
need SDL. The historical GUI path is incomplete; do not advertise it as working.

The timing regression checks independent clocks, deterministic reset/divider
phase, delayed events, repeatability, and FST output. The video clock defaults
to the checked-in PLL's 28.571428 MHz, not the intended 28.636 MHz; the PLL
needs hardware review. A run without an IPL-programmed CRTC can still have
zero HS/VS. Native IPL frames are captured from real RGB signals; record the
ROM and initialization before comparing images. The runner now loads IPL
through ioctl. Successful execution alone does not establish game boot.

`single`/`single-fast` and `test-single` are opt-in one-clock experiments.
Baseline defaults stay unchanged. In both runners `--cycles` measures physical
duration in 32 MHz reference units; single JSON reports actual 28,636,364 Hz
edges. Do not confuse reference units with edge counts. The board single
revision uses the existing actual 28,571,428 Hz PLL output instead. See
`docs/CLOCK_EXPERIMENT.md`: the compensated MR16 timer restores the short
gameplay regression, but its instruction clock remains slower. Preserve the
timer's inherited N+1-tick period and test both actual master frequencies.
Never claim compatibility or timing closure from a boot screenshot.
`turbo-video`/`turbo-video-fast` are separate, opt-in X3 video experiments:
32 MHz system and nominal 42.954540 MHz video with high/low-scan enables.
Do not run the compensated single-clock MR16 at X3 or silently change the
default model. Index 4 / `--font16` accepts character-major 4096-byte ANK;
do not embed private font bytes. See `docs/TURBO_VIDEO_CLOCK_STATUS.md` for
exact checks and missing Kanji/text/high-speed PCG behavior. The FPGA revision
`sharpx1_turbo_video` requests its own PLL; record the fitted frequency,
source-bound timing and hardware results separately from nominal simulation.
`turbo-z-multimode` is a separate, delay-aware, non-savable experiment;
ordinary board/runner defaults do not enable it. See
`docs/TURBO_Z_MULTIMODE_STATUS.md`: reduced effective-pair expansion is
provisional, not reconciled native ASIC behavior. CPU palette programming
in its fixtures uses full/40-column mode before switching. Do not claim
reduced CPU bank controls or simultaneous two-screen composition from a
selected-screen pixel pass. `test-machine-z-multimode` freezes the executable,
oracle and emitter for its sixteen cases. `x1_cdc_snapshot.sv` now belongs
to the shared machine manifest; do not also add it to wrapper source lists.

Snapshot format v13 rejects older states after transaction-bound DAM arming
(v12 added the RGB12 output port; v11 added opt-in CPU/DMA bus and instrumentation;
v09 added text-raster state;
v08 added X3 PPI sampling; v07 added PCG/metadata state). Regenerate from native boot,
never convert or patch state bytes to bypass model compatibility checks.
DMA-enabled states also require DMA revision 7 after separating an auto-loaded
first destination from later starting-buffer writes; all current profiles need v13.
Use `docs/TURBO_TEXT_RASTER_STATUS.md` for the provisional digital expansion/
underline policy and CRTC R9=31/R5=0 regression. Unit success does not complete
the documented row/width or native BASIC acceptance matrix. Mode 01 graphics
interleaves both GRAM pages; pixel fixtures must initialize both through CPU
writes. Freeze/hash each runner before a long test, not after another build
may have replaced it. Older frozen game qualifications remain historical.
Simulator disk writes require `--disk-output NEW_COPY`; private originals and
snapshots remain ignored. See `docs/DISK_STATUS.md` for tested and missing cases.
`TURBO_DMA=1` / `turbo-dma` is a separate, opt-in shared-machine DMA subset,
not enabled by ordinary Turbo/X3 or board revisions. See `docs/DMA_MACHINE_STATUS.md`.
`TURBO_DMA_RESTART_IRQ=1` additionally requires `TURBO_DMA_IRQ=1`. Its independent
snapshot identity uses bit 40; do not reuse it for other profiles or convert
completion states. See `docs/DMA_RESTART_MACHINE_STATUS.md` for actual handler/
FDC tests and the still-open Ready/mixed/native/board gates. Build separate
directories for `DMA_RESTART=0/1`; no existing RBF enables this profile.
`TURBO_Z_PALETTE_CPU=1` / `turbo-z-palette-cpu` is a separate CPU-only,
non-savable experiment, not a Z machine or analog renderer. It rejects DMA
combinations, disables palette display reads and qualifies only the explicit
low-scan/40-column external palette sequence. Upper read bits and native ASIC
reset controls remain provisional. Use `test-machine-z-palette-cpu` and
`test-machine-z-palette-disabled`; see `docs/TURBO_Z_PALETTE_CPU_STATUS.md`.
Its functional blank-window handshake now supplies CPU permission; it is not
native ASIC BUSRQ/WAIT timing. Any future display consumer must honor
`display_allowed` and response validity. Use `test-z-palette-owner` and
`test-machine-z-palette-video` for connected lease and actual-CRTC WAIT checks.
The completed palette read tail is only eligible until memory/ACK/other I/O;
do not broaden it into a general unmapped-data override.
`TURBO_Z_VIDEO=1` / `turbo-z-video` is a separate non-savable full-color
prototype requiring the palette CPU experiment and X3 timing. Ordinary board
and simulator defaults stay unchanged. Preserve per-byte shifts, phase-zero
fetch/phase-14 load and one-edge palette/selection/blank alignment; honor the
palette owner's display permission and response validity. See
`docs/TURBO_Z_VIDEO_STATUS.md`: standalone shifter tests are not native pixels,
reduced-mode/text support or hardware acceptance. CPU fixtures must clear DAM
with a real IN after PPI mode-set before writing width; never loosen timing or
pixel assertions to accept an incorrectly initialized diagnostic.
Palette RAM is indexed by logical CPU `{AB[7:0],DB[7:4]}`, not physical
PA pins. Table 4-22 reverses each display-source nibble: the first fetched
QH?0 supplies logical component bit 3. Use `test-z-palette-pins` to cover the
whole GRAM/fetch/shifter/palette chain; earlier unreversed pixel passes are
historical internal agreement only. Freeze the Python oracle/emitter as well
as the runner for long multi-case matrices.
During an owned reset drain, CPU CE stops while DMA/target CE and host SD ACK
processing continue. Do not replace actual BUSACK ownership with BUSRQ or
reset the CPU before the already-started pair completes. Uploads must honor
`ioctl_wait`; do not modify IPL/font assets during drain. Generated diagnostics
do not establish native Turbo firmware, IRQ/search or exact pin timing support.
Warm reset events use repeated `--reset-at MS` and `--reset-for-us US`, relative
to the invocation/restore. See `docs/RESET_STATUS.md`: CPU/FDC enables stop during
reset, but host SD ACK processing must continue on `clk_sys`. Transport fixtures
must cover stopped enables, not just constant CE. Check retained IPL overlay,
HALT recovery, disk continuity and game input without reloading assets. Direct
machine reset simulation does not verify Main's OSD reset-command dispatch.
`scripts/mister_x1.py` deploys source-bound hardware tests under unique names
with disposable protected disk copies. Coordinate availability before loading
a core; preserve other cores/config/media. Record RBF hashes and actual PNGs
in ignored outputs, and scope hardware claims as in `HARDWARE_BRINGUP.md`.
Base-X1 FDC INTRQ/DRQ are unconnected, as in local MAME; do not invent a CPU
interrupt connection to prevent Quartus from optimizing a diagnostic output.

Optional `interactive` and `fast` targets require SDL2. `fast` uses
`--no-timing`, ignoring inherited intra-assignment delays like synthesis;
it is not the delay-aware timing reference. Compare functional diagnostics
and native boot evidence against `headless` before relying on fast results.
`make -C verilator test-fast` covers snapshots and the SDL adapter;
`test-game` checks CROSS Chase movement from a native-booted local state.
See `docs/PLAYING.md` for `boot-game` and `play`. Regenerate snapshots after
RTL changes; they contain ROM/game bytes and must not be bundled or committed.
The disk's non-commercial use grant is not binary redistribution permission.
`lint-wrapper` uses a PLL interface stand-in, not Intel PLL simulation or a
Quartus/hardware validation. The narrow `sys/hps_io.sv` edits move shared PS/2
registers out of generate scope and correct an initialized ROM's variable
declaration; avoid unrelated framework changes.

For functional changes, choose checks that demonstrate the affected behavior:
CPU/bus traces for ROM mapping and wait states, memory readback for RAM banking,
frame timing and images for video, and waveforms for audio. Record the active
machine configuration, clock frequencies, reset sequence, asset hashes, and
simulation duration. Do not mark a TODO complete solely because it compiles.

Keep new simulation interfaces deterministic. Check memory address/data widths,
write enables, inactive input values, reset polarity, clock domains, and delayed
events. Replace implicit nets with explicit declarations when touching relevant
wiring. Review warnings before adding suppressions; the inherited broad
suppressions are build accommodations, not correctness guarantees.

For FPGA changes, use the main Quartus 17.0 project as the baseline:

```sh
quartus_sh --flow compile sharpx1
```

Report unavailable tools and unverified synthesis or hardware behavior clearly.
The historical Q13 project is not evidence of current build compatibility.

## Generated files and cleanup

`verilator/obj_dir_headless/` is ignored build output. `make -C verilator clean`
removes that directory only. `verilator/obj_dir/` contains tracked historical
generated sources despite its ignore entry. Do not remove or regenerate those
tracked artifacts as routine cleanup. Inspect tracked files before deleting
any build directory. Keep new build outputs outside source and firmware trees.
`obj_dir_interactive/` and `obj_dir_fast/` are also ignored, separate outputs;
the existing clean target intentionally does not remove them.

## Local references

Use the existing MAME checkout at `../FM-7_MiSTer_alanswx/refs/mame`, especially
`src/mame/sharp/x1.cpp` and related X1 files. The user requested reuse of local
MAME; do not download another checkout. Preserve unrelated changes there.
Reference emulators have limitations, so compare uncertain behavior with
hardware documentation or a second implementation when available.

`../SharpMZ_MiSTer/verilator/` is a useful example for headless runners and
regression artifacts. Its GHDL conversion is specific to its VHDL core and is
not required here. Treat sibling repositories as read-only references unless
the task explicitly includes changes to them.

Additional emulator links and retrieval status are in `references/README.md`.
Distinguish references actually inspected locally from candidates identified
through repository metadata. Do not claim an emulator was cloned, built, or
compared unless that work was done.

## Attribution and handoff

Preserve source-level copyright and license notices. The root GPLv2 file and
restrictive notices in inherited Nise X1 sources need reconciliation before
release distribution; do not remove notices to imply resolution. Record the
provenance of new code and firmware assets.

When handing off changes, state what changed, the active RTL path tested,
the verification result, and any remaining functional limits. Update the README
and bring-up checklist when status changes, while keeping proposed work
distinct from confirmed defects and completed behavior.
