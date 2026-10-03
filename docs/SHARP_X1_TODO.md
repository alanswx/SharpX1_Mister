# Sharp X1 core bring-up TODO

This list is based on the current RTL, the existing Verilator harness, and
cross-checking against the local MAME Sharp X1 driver. X Millennium is a
candidate reference; it has not yet been downloaded or compared locally.
See `CORE_STATUS.md` for confirmed device and wiring gaps.
See [the implementation and test plan](IMPLEMENTATION_PLAN.md) for dependency
ordering, test coverage, and acceptance gates. These checklist phases are broad
work buckets; the plan gives the execution order, including base-X1 floppy
support before optional Turbo extensions.

## Phase 0 — make simulation trustworthy

- [x] Repair the Verilator Makefile continuation and clean rules.
- [x] Add a headless Verilator target that does not require SDL/OpenGL.
- [x] Advance simulation time and independently schedule the checked-in board clocks.
- [ ] Correct/verify the board PLL video frequency (currently 28.571428 MHz).
- [x] Make the simulator load `bios/ipl_x1.hex` through the shared ioctl path.
- [ ] Add deterministic reset, clock, and frame-count command-line options.
- [x] Add cycle/reset-duration/video-frequency options and a timing/reset regression.
- [x] Add optional FST traces and JSON results.
- [ ] Add VCD/FST trace selection and a small smoke-test script.
- [x] Establish nonzero HS/VS with an actual renderer and IPL-programmed CRTC.
- [ ] Resolve all Verilator warnings instead of relying on broad suppression.
- [x] Document Verilator 5.x headless and new SDL builds/play commands.
- [ ] Add CI for the freely redistributable diagnostic fixtures.

## Phase 1 — prove the existing machine boots

- [x] Verify the active top-level is the intended X1 model, not the stale
  legacy wrapper accidentally selected by the simulator.
- [x] Confirm reset fetch, IPL overlay and RAM through a self-checking Z80 diagnostic.
- [ ] Validate wait states and cycle timing against hardware/reference traces.
- [x] Confirm allocated 64 KiB main RAM, 2 KiB text/attribute banks,
  2 KiB per PCG plane and 16 KiB per GRAM plane; RAM/GRAM diagnostics pass.
- [x] Boot the checked-in IPL and capture native IPL/game frames.
- [ ] Resolve IPL/BASIC licensing/provenance and verify BASIC compatibility.
- [x] Boot one native D88 game (CROSS Chase) and verify repeatable PS/2 movement.
- [ ] Add memory/I/O bus assertions for unmapped accesses and contention.
- [ ] Compare CPU-visible behavior against MAME traces for a short boot window.

## Phase 2 — complete the base X1 peripherals

- [ ] Finish the 8255/PPI port map and joystick/parallel-port behavior.
- [x] Verify PPI mode-0 reset, direction, output latches, split port-C input
  direction and BSR; verify both PSG joystick inputs and mirrored/register-mask reads.
- [x] Correct MiSTer-to-X1 joystick direction/button order; exhaust all 64
  combinations in a board-adapter regression. Hardware input remains untested.
- [ ] Finish the MR16 keyboard/sub-CPU command set and verify repeat,
  modifiers, reset/device-command behavior and full interrupt interactions.
- [x] Retain repaired MR16 firmware execution; test mailbox E7/E8, PS/2 ASCII,
  IM1 make/break IRQs and native-game controls.
- [ ] Validate the CRTC timing, 40/80-column text, attributes, and character ROM.
- [ ] Validate 320/640 graphics modes, palette behavior, and GRAM banking.
- [x] Test individual GRAM planes, all DAM write masks, read-clear and ordinary
  port isolation; observe native 320×200 game colors.
- [ ] Validate PCG writes/readback and the documented PCG wait behavior.
- [x] Implement beam-addressed ANK/three-plane PCG reads and single-byte
  writes through a synchronized video-domain transaction, with CPU WAIT.
- [x] Test PCG readback via Z80, plane independence, low-port mirrors,
  ROM write protection, held-bus single writes, reset and three clock ratios.
- [ ] Validate exact soft-sync/scanline timing and optional AUTO_WAIT trap
  against hardware; test PCG raster images and Turbo high-speed addressing.
- [ ] Complete cassette transport and baud/timing behavior.
- [x] Connect PSG audio output and verify deterministic 1 kHz WAV waveform.
- [ ] Verify noise, envelopes, full music and hardware audio/clock behavior.
- [x] Verify all three tone channels, volume mute, repeatable noise with period
  scaling, all 16 envelope shapes and 4.096/8.192 ms envelope periods in simulation.
- [ ] Compare game music/noise/envelope fidelity to a reference or hardware,
  including zero-period quirks and output-port direction semantics.

## Phase 3 — storage and X1 Turbo support

- [ ] Implement the floppy controller and disk-image adapter (D88/2D/2HD as
  applicable), including write protection and drive status.
- [x] Integrate WD1793-family replacement and read-only base 2D D88 adapter;
  verify native IPL loads CROSS Chase byte-exactly through the controller.
- [ ] Verify exact MB8877 errors/status/timing, density/motor behavior and writes.
- [ ] Implement DMA bus arbitration and verify Z80 DMA transfers.
- [ ] Add CTC/SIO behavior and interrupt priority/acknowledgement tests.
- [ ] Implement X1 Turbo high-resolution/400-line behavior.
- [ ] Implement Kanji ROM readback and the Turbo/TurboZ extended video paths.
- [ ] Add optional EMM/expanded RAM and SASI/HDD support if the target core
  promises Turbo/TurboZ compatibility.

## Phase 4 — MiSTer integration and validation

- [x] Wire MiSTer HPS keyboard, joystick, read-only floppy and IPL/reset OSD;
  route actual RGB/audio and elaborate the wrapper with lint.
- [ ] Verify SDRAM/GRAM bandwidth and video timing on hardware.
- [ ] Review PCG bundled-data CDC placement/max-delay constraints and reset
  release with Quartus timing tools; simulation does not verify metastability.
- [ ] Add keyboard, joystick, cassette, floppy, and reset OSD controls.
- [x] Add new SDL gameplay frontend and native-booted checkpoint regression.
- [ ] Build a reference test matrix: IPL, BASIC, text, graphics, PSG, tape,
  floppy, and representative commercial software.
- [ ] Record known deviations from MAME/X Millennium and gate regressions on
  stable screenshots, bus traces, and audio hashes.
