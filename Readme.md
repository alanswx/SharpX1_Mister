# Sharp X1 for MiSTer

An experimental Sharp X1 FPGA core for MiSTer, with machine RTL, inherited
Nise X1 hardware, firmware sources, and a Verilator simulation harness.
The project is in bring-up. CROSS Chase now boots from D88 through the native
IPL and is playable in Verilator. This does not establish full X1 compatibility
or a release-ready FPGA core. An optional single-clock checkpoint also boots
the game on MiSTer and responds to remote start/directional input; see
[hardware bring-up evidence](docs/HARDWARE_BRINGUP.md) for the limited scope.

## Current status

See the [chip-by-chip implementation survey](docs/CORE_STATUS.md) for the
current wiring audit and [downloaded hardware manuals](references/manuals/README.md)
for schematics and machine documentation.
The [summary table](docs/CHIP_IMPLEMENTATION_TABLE.md) and
[chip reuse survey](docs/CHIP_REUSE.md) describe available replacement sources
and the remaining integration work.
The [implementation and test plan](docs/IMPLEMENTATION_PLAN.md) defines the
base-X1 milestones, architecture decisions, and acceptance gates.

There are two machine implementations in this tree:

| Path | Role today |
| --- | --- |
| `rtl/sharpx1.v` | Shared machine instantiated by MiSTer and the headless simulator. |
| `rtl/sharpx1_legacy.v` | Inherited Nise X1 implementation retained as a reference. |

Both builds now use the machine sources in `rtl/machine.qip`.
The legacy implementation enables an X1 Turbo subset and FZ80 CPU through
source macros; its presence does not imply complete Turbo compatibility.
An explicit, opt-in `TURBO=1` foundation now adds two graphics pages, separate
Kanji attribute RAM, blackclip controls and a 32 KiB IPL aperture to the shared
machine. CPU diagnostics and actual RGB tests cover these extensions. It is
**not full Turbo support**: Kanji, full DMA, SIO and native Turbo
firmware acceptance remain open. An
experimental [graphics raster increment](docs/TURBO_RASTER_STATUS.md) separates
text/graphics addresses and adds repeated/alternating-page raster mapping;
the new opt-in [X3 clock/font increment](docs/TURBO_VIDEO_CLOCK_STATUS.md)
adds enable-driven nominal high/low-scan timing and a validated 16-row ANK
loader. Synthetic pixel tests pass; native Arcus remains garbled/not playable.
Exact hardware timing, remaining text/PCG/Kanji functions and FPGA acceptance
remain open. The previous published RBF predates these increments. The earlier
opt-in [CTC increment](docs/CTC_STATUS.md) adds enable-driven timers/counters,
IM2 vectors, CTC-before-keyboard arbitration and stable stretched ACKs;
focused unit/CPU/real-MR16 tests pass, not exact hardware timing. See the
[Turbo status](docs/TURBO_STATUS.md) and [implementation plan](docs/TURBO_IMPLEMENTATION_PLAN.md).
An unchanged user-supplied 32 KiB Turbo IPL now executes to an IPL disk-search
screen; see [native firmware evidence](docs/NATIVE_TURBO_FIRMWARE_STATUS.md).
This does not establish native Turbo game or complete firmware compatibility.
An original [standalone DMA subset](docs/DMA_STATUS.md) now passes register,
transfer, count/readback and ownership tests. That standalone checkpoint did
not connect the shared machine or establish native DMA compatibility.
The [real CPU/DMA unit diagnostic](docs/DMA_CPU_BUS_STATUS.md) passes
18 ownership/register/reset cases. A subsequent separate, opt-in
[shared-machine DMA increment](docs/DMA_MACHINE_STATUS.md) connects real CPU
ownership and FDC DRQ pacing. Generated A/B reads, writes, CRC repair,
protection and owned-pair reset tests pass; native firmware and full DMA
functions remain open. Ordinary Turbo/X3 and board defaults do not enable it.
Further [pending-SD reset and video-target checks](docs/DMA_MACHINE_STATUS.md#october-6-pending-sd-reset-and-video-target-qualification)
pass eight held-reset A/B read/write cases, including stopped-enable ACK drain
and native diagnostic reboot. Fast/delay-aware GRAM/selected PCG transfers pass
CPU count/readback and isolation checks. Broader reset/metadata/DAM/native timing
and hardware gates remain open.
The [reset extension](docs/DMA_MACHINE_STATUS.md#october-6-reset-extension-checkpoint)
passes 64 held/pulsed payload/single-block/split-header metadata cases and five PCG-owned
reset profiles, including a stopped-video WAIT and exact one-write drain.
The full delay-aware baseline regression also completes successfully.
Partial CPU payload/Ready loss and native firmware remain open; no hardware
signoff is implied.
The [DMA automatic-restart increment](docs/DMA_AUTO_RESTART_STATUS.md) passes
40 standalone groups through 65,537-byte boundaries, real shared-CPU buffer
updates without LOAD in both directions, and fast/delay-aware machine tests.
IRQ, pure search, non-Byte Stop on Match and variable timing remain unsupported;
default profiles keep DMA off.
A [sequential comparison increment](docs/DMA_COMPARE_STATUS.md) now reports
real masked/sticky match status: 6,144 unit cases and 12 actual shared-CPU
profiles pass, including delay-aware/fast agreement. A subsequent
[Byte-mode stop increment](docs/DMA_BYTE_STOP_STATUS.md) completes the matching
write and stops without another read; 10,240 standalone comparison/stop cases
pass. The subsequent [pure Byte search increment](docs/DMA_PURE_SEARCH_STATUS.md)
performs no destination writes and passes 10,240 additional cases, including
memory/I/O, WAIT/reset and long-count rollover. Read-only
[Byte search automatic restart](docs/DMA_SEARCH_RESTART_STATUS.md) also passes
unit and actual-CPU fast/delay-aware buffer/count/status tests, with zero
destination writes. [Non-stopping Burst/continuous pure search](docs/DMA_NONBYTE_SEARCH_STATUS.md)
now passes distinct counts/Ready ownership and twenty real-CPU profiles on
fast and delay-aware builds; total search mask cases are 14,336.
An actual [pure-search match-stop pipeline](docs/DMA_SEARCH_STOP_STATUS.md)
adds real extra-read and Ready-loss behavior; 24,576 search cases and twenty
actual-CPU fast/delay-aware stop profiles pass.
Sequential non-Byte Stop on Match
and IRQ/service remain open. DMA serialized state has a distinct revision;
ordinary non-DMA v12 snapshots and defaults remain unchanged.
The separate [DMA service foundation](docs/DMA_SERVICE_STATUS.md) passes
4,096 arbitration cases, 2,048 status-vector cases and twelve connected real-CPU/DMA
IM2/HALT/handler/RETI profiles, including stopped-enable held ACKs. It is not
yet wired into machine DMA or native interrupt programming.
The subsequent [completion-IRQ command path](docs/DMA_COMMAND_IRQ_STATUS.md)
adds an explicit device-only `COMPLETION_IRQ=1` profile: 36,864 register/vector
cases and twelve real-CPU WR4/IM2/RR0/RETI cases pass. Machine/board defaults
still disable it; Ready/restart interrupts and shared-machine IRQ remain open.
The subsequent [shared-machine completion IRQ increment](docs/DMA_IRQ_MACHINE_STATUS.md)
adds an explicit `TURBO_DMA_IRQ=1` profile with schematic-qualified DMA/CTC
ownership and isolated nested RETI. Four generated CPU/IM2/HALT/RR0/RETI
profiles pass on fast and delay-aware runners. Defaults remain disabled;
native firmware, broader reset/concurrent-service and hardware gates remain open.
Its subsequent reset guard prevents an old held ACK from selecting a new
device after reset. Real-CPU nested DMA/CTC tests and native-handler snapshot
continuity/cross-profile rejection pass; this still does not establish full
DMA/Turbo compatibility or hardware reset acceptance.
The directed three-device DMA/CTC/real-MR16 pending profile also passes on both
timing models, with ordered keyboard make/break and cold repeat checks.
The [Kanji contract audit](docs/KANJI_CONTRACT_STATUS.md) adds an exhaustive
schematic-derived first-level address component and a separately tested 128 KiB
dual-clock ROM loader. Synthetic byte/read/reset checks pass; the opt-in shared
CPU/loader path is now connected, but glyph rendering remains incomplete and
Turbo Z requires its separate larger ROM path. No private font data is included.
An optional, default-disabled high-speed CG Kanji selector now passes exhaustive
physical addressing/isolation tests, informed by static inspection of a
published hardware monitor. Its [ROM/WAIT backend](docs/KANJI_CG_ACCESS_STATUS.md)
now passes connected synthetic tests and six cold/warm actual-CPU profiles.
The separate opt-in `turbo-kanji` shared-machine profile adds physical-ROM
loading and native CPU CG/INI checks; it is not a native glyph renderer or
an enabled FPGA capability. X3 fast/delay-aware CPU checks, executing snapshots
and five pending-read reset cases also pass. Default profiles stay unchanged.
A bounded [high-speed PCG increment](docs/TURBO_HIGH_SPEED_PCG_STATUS.md)
adds selector shadows, frozen HSYNC-window access and CPU ANK8/16 selection.
Original unit/CPU tests pass; ASIC fallback/WAIT phase, Kanji and hardware
timing remain open, not full 400-line compatibility.
The [X3 PPI crossing](docs/TURBO_PPI_CDC_STATUS.md) adds two-stage VSYNC/VDISP
level sampling only in the X3 profile; asynchronous and real-CPU cold/warm
tests pass. It has not been refitted and does not establish timing closure.
A further [digital text-raster increment](docs/TURBO_TEXT_RASTER_STATUS.md)
implements provisional global vertical expansion and reserved underline/gap
mixing. Focused units, standard-scan 80×20 / expanded 40×10 CPU pixels,
expanded high-scan 80×12 (640×384), and delay-aware high-scan 40×20
underline pixels pass. All 16 documented row/width/mode-exit cases now pass
on the frozen v09 checkpoint, not complete Turbo text/Kanji compatibility.
The subsequent [X3 reset-release increment](docs/X3_RESET_RELEASE_STATUS.md)
keeps CPU phase intact and releases video reset on its own clock. Unit/PCG,
CPU polling, expanded pixels and retained-font warm-reset checks pass; refit
and physical reset remain open. It advances the model to v10.
The optional `turbo-video-savable` simulator target now supports fast X3
single-drive diagnostic continuations with model-profile rejection; it does
not enable dual-drive snapshots or replace delay-aware/hardware checks.
Turbo Z is a separate capability target with a
[manual-based roadmap](docs/TURBO_Z_PLAN.md), including analog multi-color
video, stereo FM, HD disks and capture effects. Its first
[RGB12 output foundation](docs/TURBO_Z_RGB_STATUS.md) connects full-color
capture and wrapper interfaces while preserving digital colors. Palette,
multi-mode rendering and the other Z devices are not implemented in the
shared machine. A separate [FM foundation](docs/TURBO_Z_FM_STATUS.md) passes
JT51 busy/timers, stereo notes, fractional enables and signed mixing at three
master frequencies; CPU decode/IRQ, native sound and hardware remain open.

The headless simulator has been compiled with Verilator 5.044 on macOS.
The timing/reset regression passes. A 200,000-system-cycle run reports:

```text
time_ps=6250000000 sys_edges=200000 video_edges=178571
reset_edges=64 cpu_enables=24992 delayed_sys_edges=200000
```

This verifies clock scheduling, reset/divider phase, delayed events, and
repeatability. Additional diagnostics now verify Z80 fetch, RAM patterns,
writes beneath IPL, overlay switching and loader bounds. The shared renderer
produces native IPL and game rasters. Native floppy boot, keyboard interrupts,
repeatable player movement, and a deterministic PSG tone are verified.
Focused regressions also cover PPI mode-0 behavior, both joystick inputs,
all three PSG tones, noise and all 16 envelope shapes. MiSTer joystick bit
order is corrected; physical controller behavior is still untested.
ANK/PCG readback and single-write transactions now have CPU and asynchronous
clock tests. CPU WAIT covers the synchronized transaction; exact native
scanline waits and PCG raster compatibility remain unverified.
See [bring-up progress](docs/BRINGUP_PROGRESS.md) for changes and remaining gates.

Private commercial-game test preparation and the top-32 shortlist are documented
in [test media](docs/TEST_MEDIA.md). Locally extracted disks remain ignored
assets; their presence is not proof of compatibility or gameplay.
The deleted-data/v04 checkpoint requalified repeatable native gameplay-control
evidence for five commercial titles in fast baseline simulation: Druaga,
Xevious, Mappy, Shanghai and Galaga, including legal tile-pair removal and
native firing/projectile travel. See the
[commercial compatibility matrix](docs/COMMERCIAL_COMPATIBILITY.md) for the
bounded checks and remaining compatibility gates; this is not hardware signoff.
The subsequent [ID/data CRC increment](docs/D88_CRC_STATUS.md) passes direct
controller and fast/delay-aware machine regressions and requires snapshot v05.
Fresh CRC/v05 Xevious, Druaga, Mappy and Galaga native/control qualifications
pass, including Galaga firing. Shanghai's native pair check failed and its
evidence is retained; it is not a fifth v05 pass. The five-game v04 evidence
is historical. Subsequent
[D88 metadata publication](docs/D88_WRITE_METADATA_STATUS.md) and PCG changes
require v07 and separate acceptance. The subsequent X3 PPI increment requires
v08, text-raster work v09, and X3 reset release v10. Current CPU/DMA integration
requires v11; the subsequent RGB12 output boundary requires v12. Do not
convert or patch old snapshots; v11 gameplay evidence below is historical.
The v11 baseline qualification now passes all five titles. Shanghai's timed
replay missed its fixed pair coordinates; [native cursor feedback](docs/SHANGHAI_FEEDBACK_STATUS.md)
prepares the same pair and passes the unchanged removal/repeatability checks.
The original failure is preserved. This does not establish Turbo/hardware play.
An original [standalone SIO slice](docs/SIO_ASYNC_STATUS.md) now passes
two-channel polled 5–8-bit N/E/O pin, FIFO/error and buffering tests at CE=1/4/7:
108 formats cover x16/x32/x64 and 1/1½/2 TX stops, plus simultaneous accesses.
A separate [SIO IRQ wrapper](docs/SIO_IRQ_STATUS.md) passes nested service,
held ACK/vector and actual-CPU IM2/RETI tests at the same enable rates, now
including explicitly armed first-character/error locking and CTS/DCD snapshots.
A separate opt-in [functional WAIT/Ready experiment](docs/SIO_FLOW_STATUS.md)
passes pin tests and actual-CPU stalled IN/OUT tests at those rates; it does
not establish exact pin timing. A subsequent [standalone SIO/DMA fixture](docs/SIO_DMA_STATUS.md)
passes A/B RX/TX Ready-paced transfers, count readback and stopped-enable recovery;
it fixes repeated copies of a locked error character in the opt-in flow model.
A further [actual CPU/SIO/DMA diagnostic](docs/SIO_DMA_CPU_STATUS.md) passes
real grants, continuous RX/TX, CPU count/data checks and CPU-driven burst
error inspection/reset on both channels at CE=1/4/7. Its new IM2 profile
passes one genuine SIO error ACK/handler/RETI after burst release, including
80 stopped-enable ACK edges. Broader IRQ/reset/multi-device service and
exact pin handshakes remain open; DMA's own IRQ engine is still absent.
Its warm-reset extension also passes twelve owned serial read/write cases:
retained short request, stopped enables, one-pair drain, reboot without reload
and fresh byte/count checks. IRQ-service reset and machine integration remain open.
A bounded [idle Send Break increment](docs/SIO_ASYNC_STATUS.md#october-6-idle-send-break-increment)
now passes A/B pin/register/reset tests at CE=1/4/7 with serial ticks stopped.
Queued/busy break and receive-break detection remain unsupported.
The SIO wrappers are not connected to the machine; native reset arming,
remaining external sources, x1/full break/exact WAIT/Ready and full
multi-device arbitration remain open.
A separate [CPU/SIO interrupt-reset profile](docs/SIO_IRQ_STATUS.md#october-6-actual-cpu-interrupt-service-reset-checkpoint)
passes 12 stopped-enable held-ACK/handler/FIFO/RETI reset cases, retained-program
reboot and fresh interrupts/TX pins. Concurrent multi-device and short-pulse
service reset remain open.
Asset-free [diagnostic CI](.github/workflows/diagnostics.yml) is configured
for the standalone SIO/DMA, D88, reset, bus-ownership and joystick fixtures.
[Hosted run 37479171527](https://github.com/alanswx/SharpX1_Mister/actions/runs/37479171527)
passes all 16 targets on commit `0e4e021`. It does not run private media,
native firmware, Quartus or hardware acceptance.
The expanded workflow adds idle Send Break, original DMA register/CPU units
and exhaustive RGB12 capture. The 19-target GCC run timed out compiling DMA
even at host `-O0`; it did not execute that simulator. Clang/C++20 with Ubuntu's
Verilator 5.020 also exceeds that compile limit. The successful 21-target retry pins
Verilator 5.044, selects Clang explicitly and adds standalone FM. It keeps
per-target limits and all original assertions/simulated durations.
[Hosted run 37497785084](https://github.com/alanswx/SharpX1_Mister/actions/runs/37497785084)
passes all 21 targets on `abda8ee`, including full DMA and FM waveform checks.
This remains asset-free diagnostic acceptance, not complete machine support.
[The 22-target follow-up](https://github.com/alanswx/SharpX1_Mister/actions/runs/37515820620)
passes on `421f5c9`, adding actual CPU/FM. SIO interrupt-reset is the next
added target: [the 23-target run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37522951169)
passes on `c621133`, including all twelve SIO service-reset cases. The newer
automatic-restart DMA matrix still needs its own hosted result.
The simulator window now offers optional [live joystick keys](docs/PLAYING.md):
arrows, Space (button 1) and Ctrl (button 2), through `--joystick-keys`.
Independent CPU-programmed 40/80-column text and 320/640 graphics rasters now
pass after correcting a one-edge HBlank/RGB qualification offset; see
[video coverage and remaining gates](docs/VIDEO_STATUS.md).
The previous video-alignment single-clock RBF is locally available at
`output_files/quartus-IwtYVtRu/source/output_files/sharpx1_single.rbf`.
It predates the new disk/keyboard/Turbo work and has not been tested on MiSTer;
see [source-bound build evidence](docs/QUARTUS_BUILD.md).
The new experimental foundation RBF is
`output_files/quartus-t7wQxGHo/source/output_files/sharpx1_turbo_single.rbf`.
It fits with positive constrained-path timing at eight analyzed corners;
external I/O, CDC and hardware acceptance remain open. See the
[Turbo build report](docs/TURBO_QUARTUS_BUILD.md); it is not full Turbo support.
This RBF predates the subsequent CTC/IRQ increment; do not attribute the new
CTC tests to that artifact.
The CTC-only experimental checkpoint RBF is
`output_files/quartus-CEhveaur/source/output_files/sharpx1_turbo_single.rbf`.
All 333 FPGA inputs match implementation commit `0115a38`; constrained paths
pass all eight analyzed corners. It has not been tested on MiSTer. See the
[CTC build report](docs/CTC_QUARTUS_BUILD.md) for hashes and remaining signoff gaps.
The latest two-image/CTC experimental RBF is
`output_files/quartus-JC4BFj9f/source/output_files/sharpx1_turbo_single.rbf`.
All 334 FPGA inputs match `ffc1c1c`; constrained paths pass all eight analyzed
corners at 48% ALM usage. It has not been tested on MiSTer. See the
[two-image build report](docs/DUAL_DISK_QUARTUS_BUILD.md).
The [current-source October 6 retry](docs/CURRENT_SOURCE_QUARTUS_STATUS.md)
records a Quartus parse failure, explicit-generate correction and a new frozen
build in progress; it is not yet a replacement RBF.
The newer X3 video/font candidate assembled but **fails timing at all eight
corners**; it is not a replacement timing-closed hardware candidate. See the
[X3 build audit](docs/TURBO_VIDEO_QUARTUS_BUILD.md) and
[font RAM correction status](docs/TURBO_VIDEO_CLOCK_STATUS.md).
The [font-BRAM refit](docs/TURBO_VIDEO_BRAM_QUARTUS_BUILD.md) confirms 49% ALMs
and true font RAM, but still fails setup/recovery at every corner. It binds
`f7875af`, not the later deleted-data storage changes; no hardware deployment
has occurred.
The later [coherent-snapshot refit](docs/TURBO_VIDEO_CDC_QUARTUS_BUILD.md)
binds `c0d1042`, retains the new measurement registers and still uses four
font M10Ks at 49% ALMs. It also fails setup/recovery at all eight corners
and hold at three; it is not hardware signoff or a build of current HEAD.
The completed [PCG/metadata fit audit](docs/TURBO_PCG_METADATA_QUARTUS_BUILD.md)
binds `15a0655`: 49% ALMs, 393 M10Ks, eight M10Ks for the dual-read font.
Same-clock machine paths pass all eight corners, but setup/recovery fail
all eight and hold fails five. It excludes newer PPI/text/reset/DMA changes;
the timing-failed RBF is not a deployment-ready replacement.

MiSTer now wires keyboard, joystick, disk, RGB and audio paths and
offers IPL/D88 OSD entries. Disk writes default to protected; enabling them
does not override read-only media. Generated D88 tests cover reads, safe writes,
protection, variable sector sizes, seeking, sides and error/status cases.
The new [two-image disk increment](docs/DUAL_DISK_STATUS.md) adds separate A/B
mount slots, independent head/motor state and owner-stable host transfers.
Generated A/B read/write tests pass in both clock profiles; selecting media
requires a not-ready rescan interval. This increment is in the latest
experimental RBF, but has not been tested on MiSTer or accepted as complete
disk-set compatibility.
See [disk verification and limits](docs/DISK_STATUS.md).
Focused tests cover pending SD read/write abort/reset and stable request
addresses. Shared RTL now rejects unsafe D88 header/table/sector layouts and
quarantines replacement/ejection until outstanding host ACK drains. Direct RTL
tests bypass simulator preflight and verify not-ready/recovery. A host that
never completes still remains quarantined; physical mounts/writes are unverified.
The initial Quartus 17 build produced an RBF, but **timing does not close**;
The optional single-clock checkpoint has positive analyzed timing and a native
hardware game boot. See [build evidence](docs/QUARTUS_BUILD.md) and
[hardware observations](docs/HARDWARE_BRINGUP.md); neither is full signoff.
The checked-in PLL specifies 28.571428 MHz,
not the 28.636 MHz in comments; correcting and verifying that clock remains
open. Hardware boot is separately observed, not inferred from simulation.

An opt-in [single-clock experiment](docs/CLOCK_EXPERIMENT.md) replaces the
CRTC fabric clock with an enable and derives average CPU/PSG rates from one
video-rate master. It boots the game and passes focused diagnostics and the
original two-direction gameplay regression after compensating the MR16 timer.
The MR16 instruction rate is still slower. The baseline remains
the default; do not advertise the experiment as fully compatible.
The frozen single-clock timer checkpoint builds an RBF with positive analyzed
core timing and no
unconstrained clocks; incomplete external I/O constraints and hardware testing
still prevent full signoff. A source-bound build including the silent-abort fix
has the same RBF because INTRQ has no board-visible fanout. The later conditional
interrupt revision has its own successful fit and native hardware boot. Check
the source-bound report before testing an RBF.
The later SD-transport abort/reset checkpoint also builds with positive analyzed
core timing; its hardware retest is pending because `mister.local` stopped
resolving. Earlier hardware observations do not validate this new RBF.
The cold-start F/I/J keyboard loss is fixed with an explicit receive-only MR16
firmware profile matching the one-way HPS input path; see
[cause, original reproducer and tests](docs/KEYBOARD_STATUS.md).
The reported OSD reset/reload-only issue is tracked in
[reset recovery](docs/RESET_STATUS.md). A current stopped-enable SD handshake
reset bug is reproduced and fixed; physical OSD reset acceptance remains open.

## Play CROSS Chase locally

The acquired game disk and a native-booted checkpoint are present locally,
but are ignored testing assets, not bundled redistributable files. With SDL2
installed:

```sh
make -C verilator play
```

Use **I/K/J/L** to move up/down/left/right and **Space** to fire. Close the
window to quit. The checkpoint has Caps Lock off, as the game expects lowercase
letters. Simulation runs roughly ten times slower than real time on this host.
The new SDL frontend displays real core RGB; live audio playback is not provided
(WAV capture is available). See [play and verification instructions](docs/PLAYING.md)
for checkpoint regeneration, asset permissions, and the gameplay regression.

## Build and run the headless simulator

Install Verilator 5.x, GNU Make, and a C++ compiler supporting the timing runtime
(C++20). The tested build uses the installed Verilator runtime; SDL and OpenGL
are not required for the headless target.

Run these commands from the repository root:

```sh
verilator --version
make -C verilator headless
make -C verilator run CYCLES=200000
make -C verilator test
```

The executable is `verilator/obj_dir_headless/Vtop`. `make -C verilator` builds
the same target. `CYCLES` counts 32 MHz system-clock cycles; omitting
it runs 2,000,000 cycles. Run from the `verilator` directory if invoking the
executable directly, since existing RTL asset paths may be relative.

The event scheduler advances time in picoseconds and drives independent system
and video clocks. Reset lasts 64 system cycles by default. The final JSON result
reports clock/reset/CPU-enable counts, sync transitions, and a provisional video
hash. Examples:

```sh
cd verilator
./obj_dir_headless/Vtop --cycles 4096 --reset-cycles 17 --trace /tmp/x1.fst
./obj_dir_headless/Vtop --cycles 4096 --video-hz 28636360
```

The default video frequency matches the current board PLL (28,571,428 Hz).
FST tracing is optional. `--rom` loads raw binary or whitespace-separated hex
through ioctl; `--ram`, `--load-address` and `--entry` offer explicit debug
execution. `--disk` attaches protected D88 media; `--disk-output NEW_COPY`
explicitly enables simulator writes and exports a new file without modifying
the input. Existing output paths are rejected. `--keys` supplies timestamped
PS/2 set-2 bytes, `--frame` captures actual RGB pixels to PPM, `--bus-trace`
writes CSV and `--dump` saves main/text/attribute RAM. `--audio` captures mono
48 kHz WAV. `--joya`/`--joyb` set raw active-low X1 joystick pin bytes (default
`0xff`); explicit values override saved inputs when restoring a snapshot.
Repeated `--reset-at MS` with `--reset-for-us US` inject warm machine resets,
relative to this run/restore, without reloading the core or assets.
Key scripts contain `milliseconds hex-byte` lines and now support `#` full-line
and inline comments; malformed non-comment lines are rejected. JSON
`ps2_bytes_sent` counts completed simulated serial bytes during this invocation,
not game-accepted keys. The old parser silently stopped at comments, invalidating
several commented-script probes; this was a runner bug, not a proven firmware bug.
`make interactive` builds the delay-aware SDL frontend; `make fast`
builds a clocked, savable SDL model. Example early native boot capture:

```sh
./obj_dir_headless/Vtop --cycles 64000000 --rom ../bios/ipl_x1.hex \
  --disk ../references/software/private-downloads/cross-chase/Xchase_x1.d88 \
  --keys tests/cross_boot.keys --frame obj_dir_headless/native.ppm
```

The game image is an ignored local testing asset, not a bundled release;
see [software provenance](references/software/README.md). A raster of
“IPL is under preparing” is not a successful disk/game boot.
`make -C verilator lint` exposes inherited warnings;
`-Wno-fatal` allows bring-up but does not certify correct wiring.

```sh
make -C verilator clean
```

This removes only the headless build directory. The old `verilator/obj_dir`
contains tracked generated sources and must be preserved.

The old GUI sources and Visual Studio project remain for reference. Their
Makefile path references missing SDL/OpenGL ImGui backends and requires further
repair before it is usable.

## FPGA project

The target is MiSTer's DE10-Nano Cyclone V. The main project records Quartus
17.0/17.0.2; `sharpx1_Q13.qpf` is a historical Quartus 13.1 project.
With the appropriate Quartus tools installed, the main compile invocation is:

```sh
quartus_sh --flow compile sharpx1
```

The installed Apple-container build is available through
`bash scripts/build_quartus.sh`; the initial main-project build completed
synthesis/fitting/assembly but failed timing. Optional single-clock checkpoints
have positive constrained-path timing and a separately observed native hardware
game boot; full timing/hardware signoff remains open. The FPGA top is
`sys_top`; core integration is in `sharpx1.sv`. Add machine dependencies to
`rtl/machine.qip`, shared with simulation; board dependencies belong in `files.qip`.
Quartus output goes into `output_files/`.

Development checkpoints are pushed to
[alanswx/SharpX1_Mister](https://github.com/alanswx/SharpX1_Mister).
The local `alanswx` remote is the default push destination; `origin` retains
the original upstream repository. Private test disks and snapshots are not pushed.

## Repository layout

| Location | Contents |
| --- | --- |
| `sharpx1.sv` | MiSTer HPS, reset, clock, OSD, and video integration. |
| `rtl/` | Machine, CPU, memory, address decode, and sub-CPU RTL. |
| `rtl/legacy/` | Inherited Nise X1 peripherals and original platform code. |
| `rtl/tv80/` | TV80 Z80 implementation used by the newer machine path. |
| `sys/` | MiSTer framework and board support. |
| `bios/` | Existing ROM assets and firmware/reference assembly sources. |
| `verilator/` | Simulation wrapper, headless runner, and historical GUI sources. |
| `docs/SHARP_X1_TODO.md` | Phased bring-up and compatibility checklist. |
| `references/README.md` | Emulator reference locations and retrieval status. |

## Bring-up priorities and references

The simulator timing, memory, loader, graphics bus, firmware keyboard/IRQ and
PSG paths have focused coverage; one native game boots and responds to input.
Next broaden compatibility, verify exact PCG raster/wait timing and floppy edge cases,
and synthesize/test on MiSTer. The
[base machine contract](docs/BASE_X1_CONTRACT.md) records connected interfaces
and current limits.
Turbo features need separate coverage. See the [bring-up checklist](docs/SHARP_X1_TODO.md)
for the remaining work and [AGENTS.md](AGENTS.md) for development guidance.

The existing local MAME checkout is at
`../FM-7_MiSTer_alanswx/refs/mame`; its X1 driver is
`src/mame/sharp/x1.cpp`. It provides a useful behavior reference, with its own
known limitations. X Millennium is now cloned locally under ignored
`references/emulators/` and its Turbo control code inspected, not built or run.
Neetan remains a candidate reference. See
[reference notes](references/README.md) for links and status.

The sibling `../SharpMZ_MiSTer/verilator/` demonstrates a headless simulation
workflow. Its machine RTL is VHDL and uses GHDL synthesis before Verilator;
this X1 project's Verilog/SystemVerilog sources do not need that conversion.

## Attribution and licensing

The root [LICENSE](LICENSE) contains GPL version 2. Individual inherited files
also carry their own notices. In particular, `rtl/sharpx1_legacy.v` credits
Tatsuyuki Satoh and includes non-commercial and redistribution restrictions.
The root license alone does not resolve those conflicting inherited notices;
their status needs clarification before distributing derived releases.
Preserve file-level attribution and notices when changing source.

Existing BIOS and firmware assets require their own provenance review. Use
appropriately authorized machine images for bring-up and record their origin
and hashes when creating reproducible tests.
