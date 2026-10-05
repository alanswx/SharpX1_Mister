# Sharp X1 core bring-up TODO

This list is based on the current RTL, the existing Verilator harness, and
cross-checking against the local MAME Sharp X1 driver. X Millennium is now
downloaded and its Turbo control code inspected, not built or run.
See `CORE_STATUS.md` for confirmed device and wiring gaps.
See [the implementation and test plan](IMPLEMENTATION_PLAN.md) for dependency
ordering, test coverage, and acceptance gates. These checklist phases are broad
work buckets; the plan gives the execution order, including base-X1 floppy
support before optional Turbo extensions.

## Current priorities 1–4 (October 5 checkpoint)

These are acceptance gates, not four completed checkboxes.

| Priority | Confirmed increment | Still required |
|---|---|---|
| 1. Turbo video | X3 enable cadence, synthetic graphics raster mapping, 16-row ANK pixels/reset; font maps as 32K RAM bits; opt-in HPS measurement snapshot seam tests pass | Route/timing/CDC/reset signoff and refit; text expansion/CPU font selection/underline, high-speed PCG, Kanji CPU/glyph paths and native/hardware acceptance |
| 2. Native games | All five baseline games requalified on deleted-data/v04 RTL, including Galaga firing and Shanghai pair removal | Native Arcus/Bastard playability, Turbo firmware/video and multi-disk continuity; delay-aware and hardware gameplay (Arcus A1/B2 remains exploratory) |
| 3. CTC/DMA/SIO | Enable-driven CTC and focused IM2/ACK/keyboard arbitration tests pass | DMA/BUSRQ/BUSACK engine, shared bus ownership/FDC DRQ transfers; SIO serial/FIFO/IRQ implementation; exact CTC pin/phase and physical daisy-chain timing |
| 4. D88 robustness | Malformed-image bounds, A/B ACK ownership/eject, protected/cross-block writes, new deleted-read record type/status isolation pass | Separate ID/data CRC semantics, deleted-write/CRC metadata updates, bounded format/write-track, density/HD mechanics, physical HPS media epochs and native disk-change acceptance |

Turbo Z is a separate planned profile, not implied by these increments. Its
manual-based feature/acceptance breakdown is in [TURBO_Z_PLAN.md](TURBO_Z_PLAN.md)
and Phase 5 below. New X3 hardware artifacts currently fail timing; do not
replace the previous timing-positive experimental RBF without a reviewed fit.
The [Turbo II manual acceptance matrix](TURBO_IMPLEMENTATION_PLAN.md#primary-turbo-ii-textvideo-acceptance-contract)
adds the documented row/scan combinations, underline graphics suppression
and expansion placement gates; these are not yet completed behavior.

## Phase 0 — make simulation trustworthy

- [x] Repair the Verilator Makefile continuation and clean rules.
- [x] Add a headless Verilator target that does not require SDL/OpenGL.
- [x] Advance simulation time and independently schedule the checked-in board clocks.
- [ ] Correct/verify the board PLL video frequency (currently 28.571428 MHz).
- [x] Add opt-in one-clock simulation, fractional enables and enabled CRTC;
  prove CRTC 40/80 phase equivalence and focused diagnostics.
- [x] Resolve single-clock short gameplay-input regression by preserving the
  MR16 timer's 32 MHz virtual tick rate; retain the original movement test.
- [ ] Audit slower MR16 instruction timing, broaden software compatibility and
  obtain timing/hardware signoff before changing the default configuration.
- [x] Investigate and fix cold-start PS/2 receive/firmware turnaround: F make at 25 ms,
  break at 45/47 ms, I at 60 ms and break at 80/82 ms, then J at 100 ms and
  break at 120/122 ms gives only F/J responses in both baseline and single.
  Firmware LED transmit on disconnected output pins consumed I. Explicit
  receive-only firmware profile now passes all six cold and steady responses,
  overlapping keys and Caps/Shift polling in both clock models; original
  bidirectional failure remains reproduced. See `KEYBOARD_STATUS.md`.
- [x] Build opt-in single revision with positive analyzed setup/hold/recovery
  and no unconstrained clocks; external I/O constraints/hardware remain open.
- [x] Make the simulator load `bios/ipl_x1.hex` through the shared ioctl path.
- [ ] Add deterministic reset, clock, and frame-count command-line options.
- [x] Add cycle/reset-duration/video-frequency options and a timing/reset regression.
- [x] Add deterministic warm-reset pulses and repeated IPL-overlay/HALT recovery
  tests with retained ROM/RAM; keep physical Main/OSD dispatch validation separate.
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
- [x] Correct one-master-edge HBlank/RGB mismatch and compare every pixel of
  CPU-programmed 40/80 text, 320/640 graphics and palette/priority mixtures in
  baseline and single-clock models. See `VIDEO_STATUS.md`; attributes, PCG,
  mode transitions and hardware acceptance remain separate gates.
- [x] Add CPU-programmed color/reverse/address-wrap, double-width/height and
  three-plane PCG pixel fixtures at both widths; delay-aware baseline/single
  and fast runs pass. Both live width switches and firmware-driven blink
  phases pass in baseline/single and fast; exact scanline timing, character
  ROM authenticity and hardware acceptance remain open. See `VIDEO_STATUS.md`.
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
- [x] Add two independently mounted A/B D88 images through one controller,
  retained physical heads/shared registers, per-drive motor hold/protection,
  serialized rescans and ACK-drained request ownership. Generated CPU A/B
  reads/writes and connected pending-write/reset/malformed/eject tests pass.
  Exact index/mechanics, selection latency, HPS replacement and hardware remain
  open. See `DUAL_DISK_STATUS.md`; no complete Arcus/disk-set claim.
- [x] Verify generated D88 variable/multi-sector reads, seek/side/RNF/not-ready,
  sticky lost-data, write protection and byte-exact cross-block write/readback.
- [x] Add drive/density decode, motor hold and 300 rpm index/head-load tests.
- [ ] Validate deleted-data/format/force-interrupt/metadata/CRC edge cases,
  including conditional force-interrupt sources, abort during host SD I/O,
  malformed/eject/reset transfers, drive B and applicable 2HD/2DD media.
- [x] Preserve D88 byte-7 deleted marks in the sector index and report Read
  Sector record type; generated CPU payload/status-clearing, READ ADDRESS,
  mixed multi-sector and byte-8 isolation checks pass. Deleted writes and
  metadata/CRC/density behavior remain open; snapshots now require v04.
- [x] Fix busy `$D0` falsely raising completion INTRQ; add idle/busy `$D0/$D8`,
  subsequent normal completion, status acknowledgement and reset regression.
- [x] Cross-check Fujitsu MB8877A Type IV bits and status acknowledgement;
  implement `$D1/$D2` ready edges, `$D4` index edges and `$D8` persistence,
  with mask cancellation/re-arming and reset tests. Exact pin timing remains open.
- [x] Drain pending sector SD reads/writes across `$D0` and controller reset;
  test before/during ACK, stable LBA/write-buffer samples and fresh commands.
  Already accepted writes can commit; stalled-host/eject/remount/scanner reset
  and hardware fault injection remain open.
- [x] Correct ACK draining when CPU/FDC enables stop during reset; reproduce
  the missed-handshake regression with CE stopped in the transport fixture.
- [x] Add simulator D88 structural preflight and original malformed-media CLI
  tests; reject unsupported scanner layouts separately from corrupt images.
- [x] Add strict D88-only bounds/rejection to shared RTL; bypass host preflight
  in direct scanner tests covering header/table/count/payload errors, index
  overflow, selected-volume bounds, eject/replacement and scanner/controller
  pending-read reset/ACK draining. Invalid media stay not-ready, no raw fallback.
- [ ] Verify malformed direct MiSTer mounts and physical media changes; extend
  replacement during writes and all parser phases. Permanently stalled hosts
  remain safely quarantined; safe cancellation/timeouts need a transport contract.
- [x] Extend connected FDC tests to active A eject before write ACK and during
  ACK-high, including CE-stopped reset and unchanged B. Accepted writes drain
  to the test host's retained old media. Real HPS replacement epochs, physical
  mounts, rollback and exhaustive scanner-phase coverage remain open.
- [ ] Implement DMA bus arbitration and verify Z80 DMA transfers.
- [ ] Add CTC/SIO behavior and interrupt priority/acknowledgement tests.
- [x] Add opt-in Turbo CTC with enable-driven timers/counters, schematic-based
  CTC-before-keyboard arbitration, stable vectors/single mailbox consumption,
  nested channel IRQs and decoded RETI. Unit, connected bridge, real MR16
  stretched ACK and CPU IM2/cold-input tests pass in both clock profiles.
  ASIC alias decode, exact pin/phase timing and hardware remain open; SIO is
  still absent. See `CTC_STATUS.md`.
- [ ] Implement X1 Turbo high-resolution/400-line behavior.
  Graphics raster/page addressing is implemented separately from text MA;
  nominal X3 enable timing and 16-row ANK now have focused simulation coverage.
  Exact clock/switching hardware, Kanji, text expansion, CPU font selection,
  underline and high-speed PCG remain open. See `TURBO_VIDEO_CLOCK_STATUS.md`;
  this does not close the 400-line milestone.
- [x] Add separate opt-in 42.954540 MHz X3 video profile with enabled CRTC,
  2/3-edge high/low dot cadence, phase/reset/width tests, sixteen-row ANK
  loader and synthetic pixel tests. Exhaust ordinary/paired PCG addresses.
  Native Arcus high-scan periods now match nominal geometry; its screen remains
  garbled, not playable. FPGA fitted frequency/hardware need separate evidence.
- [x] Separate graphics RA from text MA; implement low/repeated/even-odd GRAM
  page/raster addresses. Exhaustive address unit and sixteen CPU-written RGB
  cases pass in fast baseline Turbo, with focused delay-aware single coverage.
  Clock/font/hardware gates remain separate; latest RBF predates this change.
- [x] Add explicit experimental Turbo foundation: independent GRAM access/display
  pages, 96 KiB GRAM, separate KVRAM, blackclip and 32 KiB IPL. CPU/boundary/DAM/
  warm-reset and actual RGB tests pass; no complete Turbo model claim.
  See `TURBO_STATUS.md` and `TURBO_IMPLEMENTATION_PLAN.md`.
- [ ] Implement Kanji ROM readback and the Turbo/TurboZ extended video paths.
- [ ] Add optional EMM/expanded RAM and SASI/HDD support if the target core
  promises Turbo/TurboZ compatibility.

## Phase 4 — MiSTer integration and validation

- [x] Produce an initial main-project Quartus 17 RBF; record failed timing,
  utilization and source hashes. This is not timing closure or hardware proof.
- [x] Load the source-bound single-clock timer checkpoint on MiSTer, observe
  native CROSS Chase title/playfield and remote-key start; retain hardware PNGs
  and unchanged disposable disk hashes. This is not full hardware validation.
- [x] Observe directional remote-input response on the latest hardware build:
  live cyan player moves (23,17) to (21,14) with unchanged life/level display.
- [ ] Verify exact single-event two-direction movement, unshifted Caps Lock
  behavior, physical inputs and audio on hardware, beyond rapid remote bursts.

- [x] Wire MiSTer HPS keyboard, joystick, read-only floppy and IPL/reset OSD;
  route actual RGB/audio and elaborate the wrapper with lint.
- [ ] Reproduce/close the reported Reset/Reset-and-close needing core reload
  on hardware; test both actions from title, gameplay and disk loading. See
  `RESET_STATUS.md`; MiSTer is unavailable while travelling.
- [ ] Verify SDRAM/GRAM bandwidth and video timing on hardware.
- [ ] Review PCG bundled-data CDC placement/max-delay constraints and reset
  release with Quartus timing tools; simulation does not verify metastability.
- [ ] Add keyboard, joystick, cassette, floppy, and reset OSD controls.
- [x] Add new SDL gameplay frontend and native-booted checkpoint regression.
- [x] Warm-reboot a running native game without ROM reload or disk remount in
  baseline and single-clock simulation; retain the original movement regression.
- [ ] Build a reference test matrix: IPL, BASIC, text, graphics, PSG, tape,
  floppy, and representative commercial software.
- [x] Establish release-bound repeatable player-control checks for Druaga,
  Xevious, Mappy and Galaga, plus Shanghai cursor/selection/legal-pair removal, after
  native IPL/D88 boot in fast baseline simulation.
  See `COMMERCIAL_COMPATIBILITY.md`; 5/5 bounded commercial control gate, not full
  compatibility, delay-aware gameplay or hardware validation.
- [ ] Record known deviations from MAME/X Millennium and gate regressions on
  stable screenshots, bus traces, and audio hashes.

## Phase 5 — Turbo Z (researched roadmap, not implemented)

See [Turbo Z specification, sources and acceptance plan](TURBO_Z_PLAN.md).
Finish base Turbo first; keep Z-specific detection/ports behind a separate
capability profile. The existing `TURBO=1` build is not Turbo Z support.

- [ ] Define CZ-880 model/BIOS/font/DIP/readback contracts; distinguish ZII/ZIII.
- [ ] Widen simulator and FPGA RGB paths for true 12-bit analog color.
- [ ] Implement analog enable, text/graphics palettes and palette readback.
- [ ] Implement/test 640x400/8, 640x200/64, 320x400/64,
  320x200/64 (two screens) and 320x200/4096 (one screen) multi-modes.
- [ ] Implement Z text priority, transparency, blackclip and output rules.
- [ ] Integrate standard stereo YM2151 FM, CTC/IRQ and PSG mixing.
- [ ] Qualify switchable dual 2HD/2D drives and native HD software.
- [ ] Add second-level Kanji, mouse/serial and RTC/control-processor behavior.
- [ ] Research/implement capture quantization/inversion, mosaic, chroma key,
  extra scroll and superimpose/telopper, with a deterministic test video source.
- [ ] Validate native Z software, pending-operation resets, Quartus/CDC and
  physical video/input/audio. EMM/SASI remain separately scoped expansions.
