# Turbo Z capture/effect control contract

October 9, 2026. Z8 prerequisite, not implemented video capture or effects.
The new original `rtl/x1_z_effect_control.sv` decodes supplied control bytes;
it has no CPU storage, input-video clock, line buffer, GRAM ownership, pixel
composition or capability signature. No machine manifest or board/runner
profile enables it. Existing frozen pixel matrices are unchanged.

## Primary programming evidence

Visually inspected X1-Techknow Appendix A PDF pages 8–10, printed pages
280–282, rendered locally from the existing image-only scan. SHA-256:
`720c79f24169ad33ea91d5b4e2c32b98fab41c91430f226462eb254ac9e5505c`.
See [manual inventory](../references/manuals/README.md) and the
[source archive](https://github.com/UnsatisfactoryResult/Sharp-X1-Fun/tree/main/Documents/X1-Techknow).
No new PDF or emulator was downloaded for this audit.

| Register | Documented meaning | Decoder boundary |
|---|---|---|
| `1FB0` bits 7/3/2 | Multi-color mode admits capture; bit 3 enables capture; bit 2 inverts captured levels only when capture is enabled. | Capture enable requires caller enable and bits 7/3. Inversion requires that enable and bit 2. No input quantizer is implemented. |
| `1FC1` | Capture-position correction count 0–255 dots; valid only in 200-line scan. | Exposes the byte/count in low scan. Origin, direction, sync phase and application to external samples remain unresolved. |
| `1FC2` bits 2:0 | Horizontal mosaic 1/2/4/8/16/32/64 dots for encodings 0–6; encoding 7 is a dash. | Returns dimensions only for defined combinations, with a separate validity output. Undefined does not mean wrap, clamp or a native black pixel. |
| `1FC2` bits 5:3 | Vertical mosaic 1/2/4/8/16/32 lines for encodings 0–5; encodings 6/7 are dashes. | Same validity policy; no spatial sample/hold engine yet. |
| `1FC2` bits 7:6 | Capture uses 4/3/2/1 bits per component for encodings 00/01/10/11 (4096/512/64/8 colors). In 64-color mode, bit 7 is treated as 1. | Reports component width, forcing the high selector bit when the caller qualifies a 64-color format. This is not limited to two-screen 320x200; bit 4 of `1FB0` alone is not a complete format decode. |
| `1FC3` | Bit 7 enables chroma key; bit 6 enables inverse key and is valid only with bit 7. Key color G/R/B uses bits 5/3/1; bits 4/2/0 are unused. | Decodes enable/inverse and three-bit key code, not an RGB12 comparator or inferred ADC threshold. |
| `1FC4` | Bit 3 makes bits 0–2 effective. Bit 0 selects scroll-in/out; bit 1 requests repeating in/out; bit 2 disables CRT output. Bits 4–7 are unused. | Exposes qualified controls, not scroll movement or immediate global video blanking. The text explicitly requires superimpose, CRTC and second-8255 setup. |

`enabled` is a caller-qualified permission, not a native readback/reset/ASIC
decode claim. The pure decoder keeps programmed dimensions and quantization
available independently of the capture trigger; a future consumer must still
honor `capture_enabled`, `mosaic_defined` and its own valid sample/ownership.
The helper returns zero dimensions with validity false for undefined settings;
it does not choose what the real ASIC displays for those settings.

## Emulator cross-check, inspected not executed

The existing local MAME `x1.cpp` has logging-only `z_img_cap_w`, `z_mosaic_w`,
`z_chroma_key_w` and `z_extra_scroll_w`; these cannot validate effects.
Current inspected file SHA-256:
`daff0118d09c7f8e5e9fcf1edfd2d474ff3faae48e0cf75752ec5dbe76e5e079`.
The local Common Source X1 `display.cpp` stores/reads these four registers when
AEN is set and saves their state, but its only references to those fields
are initialization, register access and state serialization, not rendering.
File SHA-256:
`2bd722cb871a90d92adc20a52f09ea3d8ad61be81b486d6915add19b4dd6cc87`.
Neither storage/readback agreement nor MAME's labels prove digitizer behavior.

## Executed decoder acceptance

`make -C verilator test-z-effect-control` terminates zero with Verilator 5.044,
without warning suppressions. The original arithmetic/table oracle exhausts
**264,192** configurations: all mode/mosaic bytes crossed with enabled and
qualified 64-color capture mode, all position bytes in both scan modes,
all chroma controls and all scroll controls including disabled/unused bits.
Two matched negative controls fail the unchanged oracle: omission of forced
64-color quantization and ignoring the scroll activation bit. Log:
`/tmp/x1-z-effect-control-final.log`. Current decoder SHA-256:
`94f0fc068e26aa0d174a6dc7efdfaf04870e015edde04abf9af4ac27c6f20f21`;
fixture SHA-256:
`b6cec587ee8ff6cf701a59e27407401d1e8d01cc9aa7c8bd369f94a740a90ee4`.
Adjacent priority-order/negative and 120-case matrix-plan tests also pass
(`/tmp/x1-z-effect-control-adjacent.log`). CI now schedules this asset-free target;
hosted results are separate from this local pass.

## Implementation still required

### Capture sequencing follow-up (printed 171–174)

The existing local `X1_Techknow_Screen_Display.pdf` (SHA-256
`70b6f88f7d775ab5ee7a9c289958eb7ef09e4b86e4ca0a02eed3e231b0804a78`)
was visually read at PDF 63/67–70 by the reviewer, with Main independently
reading 63/67–70. This is a published programming reference, not a Sharp-authored
ASIC timing specification. It settles additional functional sequencing:

- Capture is low-resolution/200-line only, requiring multicolor/capture bits
  and superimpose setup. Shared graphics VRAM needs actual capture ownership.
- Quantization/mosaic precede the 910-word FIFO. Horizontal mosaic controls
  the input dot clock; vertical mosaic controls line-memory write permission
  using `CHsync`. FIFO read/write controls are independent.
- Digitization is synchronized with the display dot clock; this does not
  specify a rising sampling edge or QA's divider. Superimpose may periodically
  pause the CRTC clock for phase correction.
- Buffering displaces capture downward one line. Recommended `1FC1` corrections
  are **40 decimal** for 40 columns and **48 decimal** for 80 columns, not hex.
- Capture inversion is bitwise after FIFO read, immediately before GRAM write.
- Chroma key acts on each component's **bit0**, ignoring its other bits.
  This rules out guessing a full-nibble RGB comparator, but does not yet bind
  that component bit to a particular core source/physical palette pin or settle
  normal/inverse-key placement relative to capture and superimpose output.

Printed 172 also gives a concrete quantization table in its own `D3..D0`
symbols. Preserve those labels; do not silently substitute a numeric MSB/LSB
policy or truncate a core RGB nibble. The published three-bit entry repeats
`D1`, not an inferred generic rounding bit:

| Output symbol | 4-bit | 3-bit | 2-bit | 1-bit |
| --- | --- | --- | --- | --- |
| D3 | D3 | D1 | D1 | D0 |
| D2 | D2 | D2 | D0 | D0 |
| D1 | D1 | D1 | D1 | D0 |
| D0 | D0 | D0 | D0 | D0 |

Binding these symbols to MB40576 D1..D4, IC58 stage-1/stage-2 nets, line-buffer
DIN/DOUT indices and logical/physical GRAM/palette components remains a separate
pin audit. The table is now retrieved; a missing symbol binding must not be
presented as a missing table or filled in from an emulator with no capture.

Ignored renders: `/tmp/x1-techknow-capture-review.t1WegK/`. No private asset,
new chip clock, capture consumer, GRAM write or keyed pixel is implemented by
this audit. Still resolve QA/ADC/WCK/RCK phases, position origin/direction,
reduced-bit packing, key source and line-buffer retention during vertical
mosaic before claiming connected capture acceptance.

The [manufacturer line-buffer follow-up](TURBO_Z_LINE_BUFFER_STATUS.md) now
retains the NEC device reference and exact chip-model acceptance sequence.
This changes the future buffer contract, not the current machine: no capture
or effect renderer is implemented by that research.

The subsequent [CPU-storage experiment](TURBO_Z_EFFECT_CPU_STATUS.md) now
qualifies actual Z80 `1FC1..1FC4` transactions, AEN/DAM/neighbor isolation and
retained-IPL reset under explicit provisional policies. It connects no
capture/effect renderer, native read/reset contract or board capability.

1. Resolve native CPU write/read/reset policies and capture/CRTC/PPI gating;
   add opt-in real-CPU register tests without exposing a false Z capability.
2. Trace input sync, dot-position correction direction/origin, ADC bit order,
   quantization threshold/retained-bit policy and capture inversion through
   CZ-880 sheets. Define a deterministic RGB/sync input source with validity;
   absent input must never masquerade as a functioning digitizer.
3. Implement bounded line-buffer/sample-hold behavior and capture GRAM writes
   through actual ownership, including both pages/planes and all formats.
   Exercise stopped clocks, reset, DMA contention and uncompleted writes.
4. Apply mosaic/key/scroll/telopper at their documented pipeline stages; verify
   all pixels, source-presence/key decisions, timing and mode exits. Do not
   guess a full-color chroma comparison from the three-bit key selector.
5. Qualify native Z software, fitted resources/CDC/timing and physical video
   input/output separately. Decoder success does not complete Z8 or the goal.

## Physical digital-input boundary audit

Re-rendered/read CZ-880 service-manual sheet 46, including ADC, IC58 and
line-buffer details, and adjoining sheet 45. Source SHA-256:
`70a5f8da327ed25710e76d60117c4f82a655e6a7b29a34cb3239c75f0bd65a81`.
The existing Fujitsu 1990 Linear Products Data Book MB40576 sheets were also
read: PDF pages 588–590/592/594, printed 7-77–79/81/83. Book SHA-256:
`8360ba1bd0e9fc408f385daee32faa12cf52e35aad843b5561bd5f73e6c34268`.
This changes the input-boundary plan; it does not resolve the custom ASIC.

- IC74/75/76 are six-bit MB40576 ADCs for B/R/G. Their D1/D2/D3/D4 pins
  (6/5/4/3) connect to `BD11..BD41`, `RD11..RD41`, `GD11..GD41`.
  D5/D6 (pins 2/1) are explicitly NC. The manufacturer's pin/block drawings
  identify D1 as MSB and D6 as LSB; thus the connected nibble is the upper
  four bits of a six-bit conversion code, not the lower four bits or a
  reversed nibble. Its example output-code table is increasing unsigned binary.
- These twelve nets reach IC58 IX0871CE, alongside ADCCLK and capture/mode/
  sync controls. IC58 internals, further 1/2/3-bit packing, inversion and
  timing are not shown; do not equate these pins with already formatted GRAM.
- IC57 uPD41101C takes `BD12..BD42` and `RD12..RD42`, not the direct ADC
  `...11/21/31/41` nets. IC56 takes `GD12..GD42` in its low four inputs.
  They return `BDO0..3`/`RDO0..3`/`GDO0..3`, with shared clock/reset/control
  wiring and IC58 line-memory controls. This rules out simply wiring the
  ADC nibble into a guessed generic capture FIFO. The complete ASIC/FIFO/
  GRAM sequencing and direction still require qualification.
- The MB40576 timing diagram shows a sampled conversion appearing at the
  following rising clock edge plus output delay (5/18/40 ns min/typ/max in
  its specified conditions). Minimum high/low clock widths are 25 ns each.
  The actual board ADCCLK generation/phase is not yet established; do not
  sample on every X3 edge or assume the datasheet's typical delay is measured
  on this machine. RGB front-end gain/clamp/reference controls also remain
  outside the current digital model.

The original stateless `rtl/x1_z_adc_pinmap.sv` now implements only the
settled **digital code** to connected-nibble relationship. Its `rgb12` uses
the core's R:G:B nibble order, not an inferred palette address. Caller-owned
`source_connected && sample_valid` produces `pixel_valid`; invalid samples
return zero as an interface convention, **not a valid captured black dot**.
Future consumers must gate writes and buffer advancement on validity. There
is no analog quantizer, simulated input clock, ADC pipeline, CPU integration,
GRAM write or board pin in this helper. It is not in `machine.qip` and does
not change any existing machine or frozen qualification runner.

`make -C verilator test-z-adc-pinmap` terminates zero without suppressions:
**1,048,576** cases exhaust all 64×64×64 input codes under all four
connection/validity combinations, covering every discarded-bit alias.
Three matched negatives fail the unchanged arithmetic oracle: swapped R/B,
using low rather than high bits, and ignoring sample validity. Log:
`/tmp/x1-z-adc-pinmap.log`. CI now schedules this asset-free test; hosted
acceptance remains separate. This qualifies wiring and absent-source policy,
not native capture or physical conversion.
Adapter SHA-256:
`96fcf18ad2790545f37395bda458f18cce8171c854d283d2add82fc60f03f565`;
fixture SHA-256:
`331bc68dc9cafc58f87a2c70d58a1597edb45a26975518397c6a7cf90d25cabc`.
The adjacent exhaustive control/negative target also repeats successfully
(`/tmp/x1-z-adc-adjacent-controls.log`).

A web follow-up also inspected the [eX1 developer's own WIP page](https://takeda-toshiya.my.coocan.jp/x1twin/index.html).
Its 2017-05-15 entry explicitly describes mosaic-related functions as
unimplemented and asks for 64-/4096-color verification. Do not use its
register retention as an executed reference for these effects. No independent
capture algorithm or native timing trace was recovered from that page.
