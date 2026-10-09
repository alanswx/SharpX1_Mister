# Experimental paired-screen analog text composition

October 9, 2026. Default-disabled follow-up to
[paired graphics composition](TURBO_Z_PAIRED_VIDEO_STATUS.md), not native Z4
completion or a new hardware capability.

The combined palette/video/multi-mode/text-CPU experiment now exposes the
existing post-attribute, pre-mixer glyph color from `x1_vid`. It selects the
retained six-bit text palette by that raw color, not the legacy mixed RGB.
The primary ordering decoder now receives actual text presence, so paired
fields `00/01/10` can place text above/below/between the graphics screens.
Nonzero raw text/graphics codes remain present when programmed black.
Undefined paired `11` remains black, not a guessed ordering.

Text RGB is registered one video edge after selection, matching external
graphics lookup and display qualification. The explicit provisional policy is
G:R:B two-bit fields expanded `00/01/10/11 -> 0/5/A/F`. This matches inspected
emulator arithmetic, not resolved physical DAC pin significance. Single-screen,
other graphics formats, blackclip/underline/global expansion and complete
ANK/PCG/Kanji attribute acceptance remain separate work. No board revision
enables this experiment, and its simulator profile remains non-savable.

## Executed and pending tests

- Build, three-clock actual-CPU priority/capture/reset/disabled controls and
  ordinary/X3/DMA wrapper lint exit zero in
  `/tmp/x1-z-paired-text-build-cdc-final.log`. The first build exposed the
  read-only C++ observer's old `display.cg_col` name after signal aliasing;
  it was updated to the actual shared raw-glyph wire. The failed initial log
  `/tmp/x1-z-paired-text-build-cdc.log` is retained.
- Fresh ordinary fast snapshot execution/continuation/clock mismatch,
  joystick persistence/override and old-version rejection exit zero in
  `/tmp/x1-v14-qualification-build.log`. Default delay-aware timing/FST,
  graphics-bus and PPI/DAM CPU checks exit zero in
  `/tmp/x1-v14-default-focused.log`. These are focused checks, not a new full
  baseline, private-game or fitted-hardware result.
- Actual CPU-written custom text-between-screens cold pixel test **exits zero**:
  all 64,000 pixels, line/frame periods and actual CPU completion in
  `/tmp/x1-z-text-middle-pixels.log`, frozen runner/oracle/emitter
  and checked-in ANK source under
  `verilator/obj_dir_v13_z_paired/text-middle-nkwTd2/`. Runner SHA-256
  `52f6c189e67c37b5553b5be7b9f9b3a4473a91d0664d8347beb0ca212659f693`;
  program `356f9510722c5331c8ff08e638286a1918f578c4ec4745c54a7eb0df0a5ea666`.
  It uses ANK A from the existing checked-in source, cell colors 0–7,
  all four experimental component levels, raw text color 7 programmed black
  and nonzero graphics index `A:5:F` programmed black. No new private font or
  copied emulator code is included.
  A read-only comparison of this unchanged actual frame with the same scene
  under a text-on-top counterfactual differs at 15,377 pixels; this is not
  merely a case whose image is independent of priority.

`test-machine-z-paired-text` now defines twelve frozen custom cold/warm cases
for both front banks and all three defined orderings. That full recipe is
now running in `/tmp/x1-z-paired-text-matrix.log`; it is not completed. It
requires 64,000 exact pixels/periods per case, real reboot
CRTC/PPI/priority writes and no text/graphics palette or VRAM refill.
Native intensity/opacity, complete attributes/live/reset seams, native software
and current-source Quartus/physical output remain open.

The [subsequent visibility audit](TURBO_Z_TEXT_OPACITY_COVERAGE.md) finds that
the original graphics-on-top scenes never selected any text. Their exact-frame
passes must not be described as beneath-graphics text acceptance. Between-screen
cases do select text. Corrected CPU-written transparent windows and all-color
visibility assertions are now being executed on independently frozen tests;
the earlier running matrix retains its original fixture and limitation.

## Snapshot boundary

Exposing raw glyph color changes elaborated observation/state layout; current
snapshots are conservatively advanced to **v14** (`X1SNAP14`). Reject v13 and
earlier rather than trying to reuse or convert state bytes. The version test
changes only a negative fixture's header to verify rejection before model
deserialization; it does not create a compatible converted state. Historical
v13 game and graphics evidence stays source-bound. The old paired graphics
matrix still executes its frozen v13 runner, not this new text implementation.
