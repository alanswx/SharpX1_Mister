# Experimental 320x200 single-screen analog text ordering

October 9, 2026: follow-up to
[paired analog text](TURBO_Z_TEXT_COMPOSITION_STATUS.md). No board revision
enables this combined experiment and native intensity/opacity remains open.

The combined palette/video/multi-mode/text-CPU profile now applies analog text
composition to captured fetch layouts 0 (320x200/4096), 1 (selected-screen
320x200/64) and 5 (simultaneous-screen 320x200/64). Eligibility is captured at
character request/load alongside priority. Other 640/400-line formats keep
their previous behavior; do not apply the low-scan priority port globally.

In a single-screen character, the ordering decoder forces priority bit 1
effectively zero and ignores front-bank selection. Bit 0 chooses text above
or below the one fetched graphics source. The unselected screen cannot become
a fallback source. In mode `90h`, bit 4 still genuinely enables simultaneous
display, so single-screen diagnostics must clear it. The fixture rejects a
`dual64 --text` setup that accidentally requests both screens rather than
silently treating bit 4 as unused. In full-color mode, paired bank controls
have no effect on the four-source single-screen index.

Raw glyph/index presence and experimental 0/5/A/F text intensities retain the
explicit policy and unresolved native contracts from the paired increment.
All-zero text-on-top falls through to programmable graphics entry zero;
graphics-on-top ends at fixed black text zero. Blackclip/underline/expanded
attributes, live/reset races, native firmware and physical gates remain open.

## Executed checks and running pixels

- Combined runner build, three actual-CPU control/capture/reset clocks,
  disabled negative, exhaustive ordering and ordinary/X3/DMA wrapper lint
  exit zero in `/tmp/x1-z-single-text-build-cdc.log`. Lint is not Quartus.
- Original standalone text/fetch/shifter/pin regression exits zero in
  `/tmp/x1-z-single-text-units.log`.
- Enhanced actual-CPU mode-exit/captured-eligibility tests exit zero at all
  three clocks, including the disabled negative, in
  `/tmp/x1-z-single-text-mode-exit.log`. The synthetic IPL sweeps priority,
  enters an actual 640x200/64 fetch layout and returns on each cold/warm
  execution. The checker requires excluded-layout samples and verifies
  eligibility cannot change except at character load/reset.
- Independent pixel oracle checks all 64,000 selected-screen pixels have
  identical expected output for single-screen priority `01h` versus `EBh`:
  bit 4 is clear, while between/front/unused bits differ. This oracle check
  is not an executed-machine pixel acceptance result.
- Actual CPU-written full-color `FBh` graphics-on-top cold probe exits zero
  in `/tmp/x1-z-single-full-text.log`: all 64,000 pixels and periods, with
  16,118 actual pixels rejecting the alternate text order.
- Actual CPU-written selected-bank-1 `EAh` text-on-top cold probe exits zero
  in `/tmp/x1-z-single-64-text.log`: all 64,000 pixels and periods, with
  17,432 pixels rejecting the alternate order. Frozen directories are
  `single-full-LRZlDj` and `single-64-V3BXbW` under the paired runner tree.
  Both executables hash to
  `6420d29945b4958ee8509334fb8e774f7191ab490babd2172f00b65e0ed634e0`.

`test-machine-z-single-text` defines sixteen custom cold/warm cases: full and
selected-bank-1 64-color, controls `00/01/EA/EB`, real CPU completion and
64,000 exact pixels plus periods per case. Warm cases require real control
reinitialization without text/graphics palette or VRAM refill. The recipe has
now running in `/tmp/x1-z-single-text-matrix.log`, not completed. It deliberately
programs nonzero graphics/text codes black and includes an alternate-order
oracle whose image must differ from the actual frame. Existing experiments
remain non-savable; ordinary v14 snapshot behavior is unchanged by the new
default-disabled composition registers.

The old graphics-only and paired-text matrices still use their own frozen
executables. Their passes remain source-bound and cannot qualify this extension.
The subsequent [visibility audit](TURBO_Z_TEXT_OPACITY_COVERAGE.md) also finds
the original full-color graphics-on-top scene selected no text: its 64,000-pixel
pass is graphics/order acceptance, not proof of beneath-graphics text output.
Corrected real-CPU window/warm tests are running; do not erase the older record.
