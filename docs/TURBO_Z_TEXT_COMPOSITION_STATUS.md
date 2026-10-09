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

`test-machine-z-paired-text` defines twelve frozen custom cold/warm cases
for both front banks and all three defined orderings. The original full recipe
now terminates with exit zero in `/tmp/x1-z-paired-text-matrix.log`: 12/12
cases pass on runner `52f6c189e67c37b5553b5be7b9f9b3a4473a91d0664d8347beb0ca212659f693`
and fixture `e961dcfebab0dce590e57105a27888bc3edd45f3bafc29c17d996aa3983457cc`.
It
requires 64,000 exact pixels/periods per case, real reboot
CRTC/PPI/priority writes and no text/graphics palette or VRAM refill.
Native intensity/opacity, complete attributes/live/reset seams, native software
and current-source Quartus/physical output remain open.

The [subsequent visibility audit](TURBO_Z_TEXT_OPACITY_COVERAGE.md) finds that
the original graphics-on-top scenes never selected any text. Their exact-frame
passes must not be described as beneath-graphics text acceptance. Between-screen
cases do select text. Corrected CPU-written transparent windows and all-color
visibility assertions are now being executed on independently frozen tests;
the earlier completed matrix retains its original fixture and limitation.
That fixture also aliases text palette entries 1/5 and 2/6; its passes do
not prove those indices are distinguished. After confirming the old handle
terminated, a fresh separate twelve-case recipe starts in
`/tmp/x1-z-strengthened-paired-text-matrix.log`. It freezes the corrected
windows, seven distinct writable text RGB entries and all-color visibility
assertions. This strengthened recipe now terminates with exit zero: 12/12 cases,
both front banks and all three defined orderings, cold and retained warm reset.
Frozen root: `verilator/obj_dir_v13_z_paired/text-matrix-aWWkN5/`;
runner `6420d29945b4958ee8509334fb8e774f7191ab490babd2172f00b65e0ed634e0`,
fixture `31f5ab3fe223f753948d9e984a553bf4b7aad399c6fbe1a142cf530ab87f7188`,
ANK source `68aa689abd81c1a620980b5318b669b292a72d4877916ec43dc2461d713c831b`.
Final independent hash checks match those captured at each invocation, and
all twelve actual PPMs byte-compare exactly with their expected PPMs.
Every nonzero text color is selected in every case: 2,250 samples each for
text-on-top, 36 each for graphics-on-top, and 85–87 each for text-between.
This closes this experimental strengthened paired-text matrix, not the live
single/graphics matrices, native opacity/intensity or physical Z acceptance.
Its auxiliary paired raw-code coverage metadata still omits the cleared
window; do not quote that metadata as the corrected source distribution.
The exact-frame and selected-text checks include the window correctly.

## Snapshot boundary

Exposing raw glyph color changes elaborated observation/state layout; current
snapshots are conservatively advanced to **v14** (`X1SNAP14`). Reject v13 and
earlier rather than trying to reuse or convert state bytes. The version test
changes only a negative fixture's header to verify rejection before model
deserialization; it does not create a compatible converted state. Historical
v13 game and graphics evidence stays source-bound. The old paired graphics
matrix still executes its frozen v13 runner, not this new text implementation.
