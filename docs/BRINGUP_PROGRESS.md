# Implementation progress

## 2026-10-03 — beam-addressed PCG readback and transaction WAIT

Added original `rtl/x1_pcg_access.v` to the shared machine manifest. The
previous machine never returned CG/PCG reads and drove PCG writes continuously
from the CPU clock using a changing video-domain address. The replacement
captures one beam character/row in the video domain, performs one access,
and acknowledges stable data. CPU WAIT is now connected through `cpu.v` to
TV80. All three 2 KiB PCG planes have synchronous video-clock access ports;
ANK reads use a second instance of the unchanged inherited font ROM.

The original Z80 fixture explicitly initializes text/attributes and programs a
constant glyph/raster row, writes three distinct plane bytes, reads them back
through mirrored PCG ports, and checks ANK row 0 of 'A' remains 18 hex after
an attempted write. It passes in delay-aware and clocked simulation. The
asynchronous transaction bench checks plane/boundary access, single writes
despite held bus strobes and subsequent beam movement, read-only ROM, pending
request reset cancellation and WAIT at three independent clock ratios.
CPU bus traces additionally prove real WAIT extension with a deliberately
slowed 4 MHz video clock: ordinary reads hold RD for 16 system edges, PCG
reads for 40. At the default video clock, 16-edge PCG reads fit inside the
CPU's mandatory I/O wait. Both clock configurations return the expected data.

Configuration: base shared machine, 32 MHz system/4 MHz CPU enables,
28,571,428 Hz video; CPU diagnostic runs 2,000,000 system cycles including
fixture download/reset. Fixtures are original, require no BIOS/game assets,
and are run by both `make test` and `make test-fast`. Existing game snapshots
are invalidated by this RTL change and must be regenerated via `boot-game`.

Final verification: headless/fast suites, the three-ratio transaction bench,
wrapper lint (with inherited warnings), and native boot/gameplay pass.
`boot-game` regenerated the local 13-second snapshot: 763 disk-block requests,
803 frames, frame hash `d9190e75a2854a35`, unchanged from the preceding build.
The movement regression still reaches (21,13) from idle (22,14), with the
same pair of RGB hashes. Both default/slow-video CPU trace checks pass;
`git diff --check` passes. No Quartus synthesis or hardware test was performed.

This is a functional integration increment, not exact PCG timing certification.
Local MAME `pcg_r`/`pcg_w` and the legacy CG mux agree on beam-derived addressing.
The legacy AUTO_WAIT trap is optional and not enabled. Service-time beam lag,
soft-sync timing, raster/attribute tests, Turbo addressing and Quartus
bundled-data CDC constraints/placement remain open. See the updated contract.

## 2026-10-03 — system ports, joystick mapping and PSG modes

Corrected a confirmed MiSTer wrapper bug: direct inversion of bits 0–5
misordered X1 directions, drove reserved bit 4 as button A and placed button B
at bit 5 instead of 6. The new original board-only adapter maps directions
and two buttons according to the local MAME P1/P2 definitions and sibling
FM-7's documented MiSTer ordering. It is tracked in `files.qip`, separate from
the unchanged shared machine manifest. All 64 button/direction combinations
and ignored higher bits are checked by `tests/joystick_tb.sv`.

Original CPU fixtures now verify PPI mode-0 reset, input/output directions,
output latches, split port-C direction and bit set/reset; PSG register masks,
mirrored addresses, and both independent active-low joystick inputs.
`--joya`/`--joyb` provide deterministic simulator pins, with width validation
and saved-state persistence/explicit override coverage.

`tests/test_psg_modes.py` checks actual exported WAV signals, not synthetic
audio: each channel independently produces 1 kHz, volume zero mutes it,
noise repeats exactly and transition counts scale with period, all 16
envelope shapes reach the appropriate held/repeating states, and envelope
ramps repeat at 4.096/8.192 ms for periods 32/64 at 2 MHz. Single-channel
unsigned samples are recovered by exactly inverting the runner's unclipped
integer DC blocker. Fixtures are original and need no game or BIOS assets.

Configuration: shared base-X1 RTL unchanged, 32 MHz system, 4 MHz CPU enables,
2 MHz PSG, 28,571,428 Hz video, deterministic reset including fixture download.
Audio cases run 960,000 system cycles (30 ms); PPI/joystick cases run 100,000.
The new tests pass in both `make test` and `make test-fast`; native game movement
also passes, and board-wrapper lint completes with inherited warnings.
`git diff --check` passes. Existing native-game snapshots remain
compatible because no shared machine RTL changed.

Still open: PSG output-port direction behavior, zero-period edge cases,
music/reference fidelity, PPI handshake/printer/cassette, live SDL audio,
hardware joystick and Quartus/PLL validation. These tests are integration
evidence, not a full AY/YM or 8255 compatibility certificate.

## 2026-10-02 — playable native game checkpoint

CROSS Chase boots through native IPL and the WD1793-family read-only D88 path
on the shared `rtl/sharpx1.v`, displays a populated 320×200 level, and responds
to real PS/2 input through MR16 firmware. No RAM injection or direct video
patching is used. The earlier pending-gameplay notes below are chronological
records superseded by this checkpoint.

An original gameplay regression resumes native-booted RTL state and verifies
player coordinates (22,14) idle versus (21,13) after I/J input, changed RGB
frame hashes (`2917b1d92124ea6c` / `16f792d1d2c74a8c`), and byte-exact repeated
controlled runs over 200 simulated ms. Eleven-second delay-aware and clocked
native runs match full main RAM and PPM bytes, with RGB hash
`e1d6010e6bbbe483`. A sixteen-second scripted run reaches score 00025.
The 13-second checkpoint services 763 SD blocks and captures 803 frames.
Configuration, asset hashes, controls and reproduction are in [PLAYING.md](PLAYING.md).

The new SDL frontend was exercised with actual IPL and game windows. Its
dummy-driver test checks make/break, extended arrows and Caps Lock. Savable
clocked execution has a continuous-versus-restored memory/phase regression;
snapshots require matching model, clock and disk. A deterministic 48 kHz WAV
regression verifies the PSG produces 1000 Hz and repeats byte-for-byte.
Live SDL audio playback is not implemented. Simulation runs roughly ten times
slower than real time on this host.

Verification commands:

```sh
make -C verilator test
make -C verilator test-fast
make -C verilator test-game
make -C verilator lint-wrapper
git diff --check
```

MiSTer wrapper elaboration is not synthesis/hardware verification. Quartus is
unavailable here. Full FDC/PCG/keyboard behavior, cassette, expansion chips,
Turbo, PLL timing, warning cleanup and inherited licensing remain open.
Software was acquired by the requested subagent with provenance and notices;
the non-commercial CROSS Chase disk/state remain ignored local assets.

## 2026-10-02 — CPU, IPL raster and native firmware protocol

The shared `rtl/sharpx1.v` now uses correct active-low CPU bus strobes,
qualified 4 KiB IPL/64 KiB RAM downloads, read-overlay switching, and RAM
writes beneath IPL. The MR16 mailbox/work RAM is repaired to 1024 16-bit
words with correct write data and qualification. Original self-checking Z80
diagnostics pass instruction fetch, address patterns/boundaries, overlay
transitions and debug bootstrap. Loader tests reject inactive/out-of-range
writes and RAM downloads while running.

Connected the inherited base renderer/CRTC/font, separate text/attribute,
PCG and RGB-plane RAM, palette/DAM logic, Sorgelig i8255 and JT49 PSG.
The WD1793-family candidate and index RAM are adapted in `rtl/vendor/`,
retaining upstream notices. A read-only SD-block host can supply D88 images.
The runner supports ROM/RAM loading, raw PS/2 scripts, actual RGB frame
capture, bus traces and memory dumps. These integrations are not full device
compatibility claims; see [the contract](BASE_X1_CONTRACT.md).

Observed a **real 320×200 native IPL raster** with “IPL is under preparing”.
The initial 64,000,000-cycle (2 simulated seconds) trial scanned 682 disk
blocks and completed 123 frames, but did **not** load the game. That is not a
successful machine/game boot. The installed IPL hex contains 4095 bytes;
converted binary SHA256 is
`db612eaee19dd2b46d70f8fb96a64b744f0fc3e8f494cc6d015aa1b03d653ec7`.
Configuration: base X1, system 32 MHz, CPU enable 4 MHz, video 28,571,428 Hz,
reset 4159 system cycles including download, read-only CROSS Chase D88.

Focused firmware tests pass E7 + parameter / E8 reply via the Z80/PPI and
PS/2 set-2 make-to-ASCII translation via the MR16 interrupt handler. Keyboard
input does not use an HLE bypass. Full startup, IRQ acknowledgement/RETI,
game controls, audio and floppy-sector behavior remain under investigation.
Software acquisition/provenance is in `references/software/README.md`;
the CROSS Chase binary is an ignored local non-commercial testing asset.

An optional SDL frontend is being added separately from the headless target;
both delay-aware SDL and clocked (`--no-timing`) SDL builds compile, and a
dummy-video-driver smoke test passes. Actual window/input gameplay remains
unverified. CPU/memory, mailbox, keyboard and graphics-bus diagnostics also
pass in the clocked build. The old GUI artifacts remain untouched.

A four-second delay-aware native trial loads the game payload through the
floppy controller and reaches its graphics-clear routine. That exposed DAM
writes incorrectly hitting ordinary IPL and sub-CPU ports: the CPU returned
to IPL during the game clear. These selects now exclude DAM, and an original
Z80 regression verifies individual planes, all four simultaneous-write masks,
read-clear behavior and isolation at 1D00/1900 aliases. Gameplay is not yet
claimed; the fixed longer trial is ongoing.

MiSTer now routes actual RGB, video-domain clock/pixel enable, PSG audio,
read-only drive-A SD blocks and HPS raw PS/2/joystick inputs. Template OSD
options were replaced by IPL and D88 entries. IPL downloads hold reset and
use qualified full-width bounds. Wrapper lint elaborates with an interface
PLL stand-in, with warnings still present; this is not board verification.
Enabling raw PS/2 exposed inherited framework variables incorrectly scoped
inside generate blocks while used by the module-level command process.
They were moved to module scope, initialized, and the initialized config-ROM
array changed from wire to reg. No unrelated framework behavior was changed.
Quartus/hardware validation remains unavailable.

The section below records the earlier timing-only increment; its former
“next increment” items are historical, not the current implementation status.

## 2026-10-02 — shared machine and deterministic simulation

Completed the first implementation increment of milestone 1, not its full gate:

- MiSTer and Verilator instantiate `rtl/sharpx1.v`; both consume the machine
  dependency list in `rtl/machine.qip`. Added board PLL dependency to `files.qip`.
- Removed the legacy SRAM simulation wrapper from the active headless path;
  retained all legacy machine sources and tracked GUI build artifacts.
- Replaced the zero-time runner with a picosecond event scheduler, independent
  clocks, deterministic reset, cycle limits, JSON results, and optional FST.
- Removed the simulation-only clock-divider branch, reset its phase, and
  corrected the CPU/sub-CPU reset polarity. Tests count the resulting 4 MHz
  CPU enables; they do not yet prove correct instruction execution.
- Connected MiSTer secondary clock and pixel-enable pins. Removed decoder-local
  Turbo/TurboZ/FM defines that made interfaces depend on compilation order.
- Replaced broad warning-category suppressions with visible warnings and
  `-Wno-fatal`. Existing defects remain; this is not a clean-lint result.

Verified with Verilator 5.044 on macOS:

```sh
make -C verilator headless
make -C verilator test
make -C verilator run CYCLES=200000
make -C verilator lint
git diff --check
```

Tests pass at 256, 4,096, and 200,000 system cycles, including different reset
durations, repeated runs, alternate video frequency, delayed-event completion,
FST creation, and rejection of invalid CLI arguments. The 200,000-cycle baseline
is 6.25 ms, 200,000 system edges, 178,571 video edges, 64 reset edges, and 24,992
CPU enables. HS/VS remain static because the shared machine lacks a renderer.

The default video clock follows the actual checked-in PLL parameter:
`rtl/pll/pll_0002.v` specifies 28.571428 MHz. This disagrees with the wrapper
comment and intended X1 crystal frequency. The simulator can test 28.636360 MHz
with `--video-hz 28636360`; the FPGA PLL has not been regenerated or verified.

## Next increment

1. Finish the base-model contract and sub-CPU firmware/protocol audit from
   milestone 0. Neither is complete merely because the harness now works.
2. Fix active-low bus use, decoder control inputs, IPL overlay/loader
   qualification, memory write strobes, and sub-CPU work RAM; add focused tests.
   Removing forced Turbo defines also exposes a base decoder typo: `text_cs`
   is assigned instead of output `O_TEXT_CS`.
3. Add an original diagnostic ROM and verify reset-vector fetch and RAM
   patterns before claiming IPL execution. Implement video separately.

Milestone 1 remains open for clean relevant lint, loader tests, and floating/
conflicting machine wiring. No ROM has been loaded by the new runner, no IPL
boot has been verified, and no Quartus/hardware validation was performed.
`quartus_sh` was not found in PATH on this machine.
