# Sharp X1 for MiSTer

An experimental Sharp X1 FPGA core for MiSTer, with machine RTL, inherited
Nise X1 hardware, firmware sources, and a Verilator simulation harness.
The project is in bring-up. CROSS Chase now boots from D88 through the native
IPL and is playable in Verilator. This does not establish full X1 compatibility
or a working FPGA release.

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

MiSTer now wires keyboard, joystick, disk, RGB and audio paths and
offers IPL/D88 OSD entries. Disk writes default to protected; enabling them
does not override read-only media. Generated D88 tests cover reads, safe writes,
protection, variable sector sizes, seeking, sides and error/status cases.
See [disk verification and limits](docs/DISK_STATUS.md).
The initial Quartus 17 build produced an RBF, but **timing does not close**;
hardware operation remains unverified. See [build evidence](docs/QUARTUS_BUILD.md).
The checked-in PLL specifies 28.571428 MHz,
not the 28.636 MHz in comments; correcting and verifying that clock remains
open. No FPGA release or hardware boot is established by simulation results.

An opt-in [single-clock experiment](docs/CLOCK_EXPERIMENT.md) replaces the
CRTC fabric clock with an enable and derives average CPU/PSG rates from one
video-rate master. It boots the game and passes focused diagnostics, but the
short two-direction gameplay regression currently fails. The baseline remains
the default; do not advertise the experiment as fully compatible.
The single revision builds an RBF with positive analyzed core timing and no
unconstrained clocks; incomplete external I/O constraints and hardware testing
still prevent full signoff.

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
synthesis/fitting/assembly but failed timing. Timing closure and hardware boot
have not been established. The FPGA top is
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
known limitations. X Millennium and neetan are additional candidate references;
their sources have not been cloned into this repository. See
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
