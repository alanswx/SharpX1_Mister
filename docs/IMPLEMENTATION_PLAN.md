# Sharp X1 implementation and test plan

## Goal and scope

Deliver a base Sharp X1 that boots, displays correct text and graphics, accepts
keyboard input, produces PSG audio, and loads software from supported media,
with reproducible Verilator tests and a verified MiSTer build. Base X1 comes
first; X1 Turbo, TurboZ, and optional expansion hardware are separate targets.
This ordering is a planning assumption, not a claim that Turbo is already
supported by the inherited RTL.

This plan is based on [the core audit](CORE_STATUS.md),
[the chip table](CHIP_IMPLEMENTATION_TABLE.md), and
[the reusable-chip survey](CHIP_REUSE.md). Downloaded candidates have passed
isolated compilation/lint checks, not functional compatibility tests.

Implementation checkpoint (2026-10-02): the shared machine now boots a native
D88 game and CROSS Chase is playable in simulation. CPU/memory, loader,
graphics-bus, MR16 keyboard/IRQ, PSG waveform and gameplay regressions pass.
See [runtime evidence](BRINGUP_PROGRESS.md) and [playing instructions](PLAYING.md).
This satisfies the first playable-game checkpoint, not all milestone gates:
full peripheral compatibility and Quartus/MiSTer hardware validation remain open.

October 4 simulation milestone: independent 40/80 text and 320/640 graphics
pixel/period checks, attributes/PCG/blink and live width switches pass in both
clock configurations. Five commercial titles have native gameplay-control
regressions; Shanghai removes a legal pair and Galaga also runs an enemy wave
and fires a moving projectile. See `VIDEO_STATUS.md` and
`COMMERCIAL_COMPATIBILITY.md`. The current single-clock RBF builds with positive
analyzed timing, but this does not close all display timing/CDC, full chip
compatibility, hardware acceptance or licensing/release gates below.

## Architecture and decisions

- Use one machine implementation beneath both MiSTer and Verilator. Start
  with `rtl/sharpx1.v`, repair its bus/memory infrastructure, and integrate
  individually tested peripherals. Keep the legacy machine as a reference;
  do not use successful legacy simulation as proof of the FPGA path.
- Keep host download, disk-image service, keyboard translation, and board PLL
  logic outside the reusable machine. Both wrappers must expose equivalent
  machine inputs, reset behavior, clocks, and clock enables.
- Use the existing TV80 first. Expose WAIT, interrupt acknowledge, RETI-related
  handling, refresh, and DMA arbitration signals as needed; document signal
  polarity at the wrapper boundary.
- Prefer JT49 for AY-compatible PSG sound and the collected WD1793 candidate
  for an MB8877A-compatible floppy controller, subject to behavior tests.
  JT51 is optional YM2151 hardware, not a base-X1 requirement.
- Evaluate the collected 8255 and 6845 candidates against X1 requirements
  before selecting them. CPC-specific behavior must not leak into the X1.
  A CRTC provides addresses/timing; it does not replace the X1 video renderer.
- Resolve the sub-CPU implementation at milestone 0: repair the MR16 approach
  only if its firmware and protocol can be verified; otherwise implement a
  documented command-level model for initial bring-up. Preserve the option
  of authentic MCS-48 execution when appropriate firmware is available.
  Incomplete commands must be tracked, not silently reported as working.
- Keep third-party candidates isolated until selected. Preserve notices and
  source hashes, and resolve inherited redistribution restrictions and the
  GPL-version compatibility of imports before a distributable release.

## Milestones and acceptance gates

### 0. Establish the exact machine contract

Tasks:

- Extract a base-X1 memory/I/O map, reset behavior, clock relationships,
  peripheral inventory, and relevant timing tables from the downloaded
  schematics/manuals. Record model and page citations beside each decision.
- Identify which capabilities are internal, optional expansion hardware, or
  Turbo-only. Define initial IPL size/mapping and permitted ROM fixtures.
- Compare the existing sub-CPU assembly with the embedded ROM, document the
  host command protocol, and choose the initial execution/model approach.
- Inventory licenses and firmware provenance. Reuse the existing local MAME
  checkout; do not download another copy.

Gate: a reviewed machine specification, explicit sub-CPU choice, fixture
provenance records, and no unexplained assumptions in the base address map.

### 1. Make simulation and synthesis exercise the same machine

Tasks:

- Replace the legacy-only simulation wrapper with the shared machine path.
  Repair missing source dependencies in both `files.qip` and the simulator.
- Advance Verilator time, schedule independent machine clocks faithfully,
  and apply deterministic reset. Avoid simulation-only machine behavior.
- Add ROM download through the production loader interface, optional FST/VCD
  tracing, assertions, a timeout, and machine-readable result reporting.
- Remove floating inputs, multiple drivers, implicit nets, incorrect widths,
  and unjustified warning suppression. Model external memories explicitly
  wherever the selected machine actually uses them.

Tests: clock/enable counts over simulated time, reset assertion/release,
repeat-run determinism, loader address/index qualification, and time advancement
through delayed RTL. Verify that the selected machine is identical in both
source manifests.

Gate: clean relevant lint, a repeatable headless run with functioning timed
events, and shared-machine elaboration. A static blank screen is not a failure
until video hardware has been implemented.

### 2. Prove CPU, decode, and memory without a proprietary BIOS

Tasks:

- Correct reset and active-low CPU strobes; wire decoder control inputs and
  give every bus transaction one unambiguous target.
- Fix IPL priority over RAM, bank switching, download qualification, idle
  write strobes, and memory sizing. Separate text, attributes, PCG, and three
  graphics planes according to the specification.
- Define synchronous memory latency and read-during-write behavior. Repair
  the shared sub-CPU memory width, addressing, and write-data path if retained.
- Add an independently written diagnostic ROM and a host-visible pass/fail
  mechanism that cannot accidentally overlap production device registers.

Tests: reset-vector fetch; RAM walking bits and address patterns; ROM write
protection; ROM/RAM overlay switching; every decode range and boundary; each
graphics bank; read/write pulse duration; WAIT; and unmapped reads. Assert
one-hot device selection and absence of unintended writes.

Gate: diagnostic ROM completes with deterministic bus signatures, no decoder
contention, and correct CPU frequency/clock-enable behavior.

### 3. Implement the display pipeline

Tasks:

- Integrate a compatible CRTC, character/font source, text and attribute
  fetches, PCG access, graphics-plane fetches, palette, and blanking.
- Implement base 40/80-column and 320/640-pixel behavior as specified, including
  mixed text/graphics priority and documented PCG access/wait timing.
- Connect pixel enable and secondary clock at the MiSTer boundary; explicitly
  review clock-domain crossings and memory bandwidth.

Tests: CRTC register/readback tests; diagnostic text, attributes, all palette
entries, single-plane/combined-plane patterns, PCG updates, borders, and
mode changes. Measure line/frame totals and blanking from signal traces.
Capture raw frames only at defined frame boundaries.

Gate: diagnostic screens match independently specified pixel patterns and
timing; frame capture is stable across repeated runs. Reference screenshots
supplement these tests, not replace them.

### 4. Complete the base control devices and boot the IPL

Tasks:

- Implement the selected 8255 port/control behavior and keyboard/sub-CPU
  protocol, including busy/ready transitions, resets, modifiers, and key repeat.
- Implement required RTC/time and cassette-control command semantics; keep
  host wall-clock input injectable so tests remain deterministic.
- Load an authorized, hashed IPL and trace boot until its expected ready or
  media prompt. Fix missing behavior from traces rather than bypassing checks.

Tests: PPI mode/control and bit-set/reset operations; all implemented sub-CPU
commands including invalid commands and timeouts; key press/release sequences;
reset while busy; RTC rollover. Compare selected CPU-visible boot transactions
with the existing MAME X1 driver.

Gate: the real IPL reaches its expected prompt with a correct captured frame,
and scripted input reliably changes machine state. A prompt alone does not
prove tape, floppy, or full sub-CPU compatibility.

### 5. Integrate and validate sound

Tasks:

- Integrate JT49 register access, clock enables, GPIO behavior, audio scaling,
  and MiSTer stereo/mono routing. Do not retain PSG-port RAM as a substitute.
- Add signed/unsigned conversion and saturation deliberately; define the
  simulator's sample rate and capture format.

Tests: register masks/readback, tone periods, noise activity, envelope shapes,
  mixer disables, GPIO direction/readback, reset silence, and clipping limits.
  Capture deterministic PCM and compare register-level behavior against MAME.

Gate: measured tone/envelope timing meets the specification, regression audio
is repeatable, and on-board output is audible without clipping or DC errors.

### 6. Make media usable, including interrupt and bus ownership

Tasks:

- Integrate the WD1793 candidate behind an X1-specific MB8877A adapter, resolving
  its generic `dpram` module-name collision without changing unrelated RAM.
- Separate controller behavior from image parsing and host-sector service.
  Start with one documented disk geometry/container and extend explicitly.
- Implement drive/side/density selection, write protection, DRQ/IRQ, command
  status, and transfer timing. Add CTC/daisy-chain and DMA support where the
  selected configuration/software requires it; do not substitute instant copies.
- Implement cassette playback/loading, transport/status, and required pulse
  timing. Recording and APSS are separately tested capabilities.

Tests: seek/restore, sector reads/writes, end-of-track, missing sector, CRC and
write-protect errors, interrupted transfers, reset, disk change, and multi-drive
selection. Test container bounds, including images crossing the candidate's
addressing limits. Prove WAIT/BUSRQ/BUSAK ownership, interrupt vector/priority,
RETI release, and CTC timing with small diagnostic programs. Tape tests cover
known encoded bytes, leader/silence, stop/resume, and malformed input.

Gate: an authorized BASIC or other known-good program loads from each supported
medium; disk writes survive remount and independently validate. Unsupported
formats/commands fail explicitly. Successful floppy loading does not mark
cassette support complete.

### 7. Verify MiSTer integration and a base-X1 release candidate

Tasks:

- Replace template OSD items with implemented model/media/input controls;
  exercise HPS download, reset, keyboard, joystick, disk, and audio routes.
- Run Quartus compilation and inspect timing, CDC, inferred memories, and
  resource usage. Fix clock/reset constraints rather than hiding failures.
- Test on DE10-Nano with the same ROM/media fixtures used in simulation.
  Document reproducible build/tool versions and every known limitation.

Gate: timing closes; cold boot, warm reset, mode changes, input, audio, and
media pass on hardware. Publish a compatibility matrix distinguishing
simulation-tested, hardware-tested, and unsupported features. Release also
requires resolved source/firmware redistribution permissions.

### 8. Extend to Turbo and optional hardware

Add only after the base regression suite is stable: Turbo memory/ROM mapping,
400-line display, Kanji ROM and timing, required CTC/DMA/SIO extensions,
optional JT51 YM2151, and later TurboZ video. EMM/SASI and other expansions
need explicit scope and their own tests; they are not prerequisites for base X1.

Gate per feature: documented hardware contract, unit/bus tests, applicable
reference comparison, real-software coverage, and hardware verification before
advertising compatibility. Missing SIO/RTC silicon models remain named tasks;
unrelated similarly named chips are not substitutes.

## Regression strategy and deliverables

Create the following as implementation progresses; these paths and targets are
proposed, not existing functionality:

| Layer | Proposed artifacts | Required result |
| --- | --- | --- |
| Static | Shared source manifest; lint and elaboration targets | No implicit nets, conflicting drivers, or unexplained width/polarity warnings |
| Device | `tests/unit/` bus-driving testbenches | Defined register, reset, timing, and error behavior |
| Machine | `tests/roms/` original diagnostic sources and build recipes | Self-checking memory/video/audio/interrupt tests |
| Reference | `tests/reference/` trace comparison scripts | Explained CPU-visible differences, not assumed cycle identity |
| Boot/media | Fixture manifest and scripted scenarios | Prompt, input response, loads, writes, and reset verified |
| Hardware | `docs/HARDWARE_TESTS.md` and compatibility matrix | Named board/build/fixtures and actual observations |

Use a fixture manifest containing model, ROM/media hashes and provenance,
tool versions, seed, clocks, simulated duration, expected outcome, and test
revision. Keep restricted ROMs/media out of the repository; allow local fixture
paths. Synthetic tests must run without those assets.

Capture bus traces, signal timing, frame hashes/images, and PCM samples on
failure. Hashes are useful only after sampling and expected behavior are
validated. Compare semantic bus events with MAME: its X1 driver has known
limitations and is not an exact timing oracle. Resolve disagreements against
the manuals and, where possible, hardware or a second independent emulator.

Run fast lint/unit/synthetic-ROM tests on each change. Run boot/video/audio/media
scenarios after relevant changes and as the complete regression suite before
release. Keep expensive hardware checks as documented release gates.

## Execution order and parallel work

Critical path: specification → shared simulator → CPU/memory → display and
control devices → IPL boot → media/software → hardware release gate.

After milestone 0, candidate-device tests, license/provenance review, and fixture
preparation can proceed alongside simulator repairs. Video and sub-CPU work can
proceed independently once the bus/memory contract passes milestone 2. PSG can
be unit-tested early and integrated once I/O access is reliable. DMA and CTC
interrupt work can run beside disk-image service development, but end-to-end
media acceptance requires their tested integration where used.

The first implementation change should establish the shared machine wrapper
and deterministic simulator clocks/time, accompanied by a small timing/reset
test. Do not start by enabling Turbo macros or wiring all imported chips at once.
