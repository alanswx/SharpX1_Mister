# Turbo Z priority/composition implementation contract

October 9, 2026: research and remaining integration requirements, **not a
completed priority renderer or register**. This follows the completed bounded
graphics matrices and [CPU text-palette path](TURBO_Z_TEXT_PALETTE_STATUS.md).

## Primary register evidence

Re-rendered and visually inspected X1-Techknow Appendix A PDF page 8,
printed 280, especially the `1FC0` Z-priority table and its qualifications.
The [local inventory](../references/manuals/README.md) records the scan hash;
[published scan](https://github.com/UnsatisfactoryResult/Sharp-X1-Fun/blob/main/Documents/X1-Techknow/15%20X1-Techknow%20Appendix%20A%20IO%20Map.pdf).
Temporary render: `/tmp/x1-z-priority-appendix8.png`.

| Bit | Documented meaning / scope |
|---|---|
| 1:0 | `00`: text above graphics; `01`: graphics above text; `10`: text between the two graphics screens; `11`: undefined |
| 2 | Invalid/unused |
| 3 | 0: bank 0 above bank 1; 1: bank 1 above bank 0 |
| 4 | 0: display only one of banks 0/1; 1: display both simultaneously |
| 5–7 | Invalid/unused |

Bits 3/4 are qualified to two-screen mode (`1FB0` bit 4). The note limits this
port's meaningful effect to multi-color 320x200. With bit 4 set, SCRN `1FD0`
bit 3 is invalid: the ordinary selected-bank display control must not disable
one of the simultaneously requested screens. The table also says bit 4=0
makes bit 1 effectively zero; do not invent a between-screens effect when only
one screen is displayed. Bits 1:0 are a combined field, not independent
text/graphics and enable switches.
Cold/reset readback and unused-bit electrical values are not supplied here.

This table determines ordering, **not pixel opacity**. It does not establish
whether an all-zero source index, a palette-programmed black RGB value, a
text glyph's absent dot or blackclip causes transparency. Those distinctions
must be resolved from the screen/blackclip descriptions or hardware before
an overlap oracle is called native. The `11` undefined combination must not
silently acquire an invented layer order. The `10` between-screen order is
expressly documented and must be included in the implemented acceptance scope.

## Local reference inspection, not execution

Existing local MAME `src/mame/sharp/x1.cpp` implements `x1turbo_txdisp_r/w`
as stored-byte read/write. The inspected local X Millennium/libretro
`io/crtc.c` implements `exttextdisp_o/i` and uses `ZPRY` bits 3/4 in
`crtc_dispupdate` to select paired-screen display paths. Its writes are
unconditionally stored, but reads are AEN-gated. MAME's stored reads are not
similarly gated. These do not resolve inactive-AEN/native readback behavior.
Neither was executed with a priority diagnostic in this audit; no code copied.

## Concrete integration sequence

1. Add explicit opt-in `1FC0` transaction storage/read-tail semantics, DAM
   exclusion and a complete coherent video-control crossing. Keep default
   X1/Turbo profiles and existing RBF revisions unchanged; do not fabricate
   a Z identification signature.
2. Extend the real GRAM fetch/shifter to capture **both** two-bit component
   sources in **both** banks for simultaneous 320x200/64. The current mode-1
   path reads only the selected bank's base/+400h pair; it cannot compose two
   screens. Four source reads must finish before the existing character load,
   with captured control/page metadata and no change to CPU RAM ownership.
3. Preserve two distinct logical palette indices and the reduced-mode bank
   addressing contract. A second lookup/composition stage must not alias
   both screens' colors or silently select the full-color bank expansion.
   Resolve the documented/emulator reduced-index disagreement first.
4. Resolve opacity/blackclip and text intensity significance independently;
   combine actual ANK/PCG/Kanji color and glyph coverage with ordered graphics
   layers, including text between the front and back graphics screens for
   field `10`. Never infer coverage merely from the final palette RGB value.
5. Use original CPU-programmed per-screen patterns with different colors,
   transparent regions and overlap. Exercise bits 0/3/4, both SCRN selections,
   all four text component levels, zero versus programmed-black indices,
   blackclip, reverse/blink/underline and bank/address boundaries. Compare
   every active pixel and native periods, cold/warm retention without refill,
   pending-fetch live changes and disabled-profile negative controls.
6. Qualify actual native Z firmware/software and fit/CDC/physical output.
   Existing selected-screen captures do not close the simultaneous-screen or
   text-priority gates, even though all sixteen reduced-mode cases pass.

## Executed paired-screen fetch/shifter increment

The shared fetch/shifter components now accept internal layout ID 5: bank 0
base/+400h followed by bank 1 base/+400h, wrapping offsets within each 16 KiB
component bank. Both source pairs are captured in the existing four lanes.
The shifter emits two distinct indices and a captured `paired_screens` tag.
SCRN/parity inputs cannot redirect this layout. Index expansion deliberately
uses the existing provisional effective-pair policy; it does not resolve
native reduced palette addressing or introduce a new brightness policy.

The machine still admits only existing layouts 0–4 and leaves the second
index/tag unconnected. Simultaneous-screen lookup/composition,
opacity and the priority renderer remain unconnected. The subsequent
[CPU register/ordering increment](TURBO_Z_PRIORITY_CPU_STATUS.md) adds opt-in
`1FC0` reads/writes and separately qualifies the full layer-order truth table;
its follow-up connects stored priority to the coherent video-control payload,
not rendered composition. Ordinary board profiles remain
unchanged. This is infrastructure for step 2 above, not completed Z3/Z4.
The later [paired graphics experiment](TURBO_Z_PAIRED_VIDEO_STATUS.md) now
admits layout 5 in its combined opt-in profile and connects captured priority
to a selected palette lookup. Its actual-pixel acceptance is running; opaque
analog text, native opacity and reduced-bank policy remain open.

```sh
make -C verilator test-z-gram-fetch test-z-graphics test-z-palette-pins
```

Final matrix exits zero: nine passes, log
`/tmp/x1-z-dual-fetch-final-matrix.log`. Video half-periods are 17,500,
11,640 and 25,000 ps. The real-RAM fetch fixture covers all 16,384 bases,
six layouts, both selected/ignored page inputs, exact four-read paired
responses, live-input mutation, reset at each pipeline seam and phase-14
deadlines at all scan/width settings. CPU RAM writes initialize the sources;
no private assets are used. The shifter checks all bases/eight pixels and all
64x64 independent screen-color pairs against both address and direct-color
oracles, including held enables and captured control mutation. Existing
all-4096 full-color GRAM/palette pin checks also pass at the three clocks.

Unit executable SHA-256 values after this terminal run (not a frozen
native-game qualification):

- Fetch: `519c200f782e29fc4a078acd5aeffcc9257c3c336581025f1574644974502ba2`
- Shifter: `9a1db015838df76e9c8652b6de4432be748d6fb2fc03dd534e9f61e84c983a43`
- Full-color pins: `60ac07287fb1fbbcb7d68b5a90f03264cd48113778e6a41f5e704734cf6b1bb6`

Ordinary/X3/DMA wrapper lint also exits zero in
`/tmp/x1-z-dual-fetch-current-suite.log`, with inherited warnings and a PLL
stand-in, not fitted timing. The paired-fetch checkpoint's actual-CPU
full-color matrix finishes with exit zero in
`/tmp/x1-z-dual-fetch-machine-regression.log`: four identity/custom cold/warm
cases, each checking all 64,000 active pixels and measured periods. Warm
traces require CRTC/PPI reinitialization without palette/GRAM/text refill.
It uses the hash-checked original executable
`c6f5e379baa27278b46dd8f25a8952981ef935a124dffd4146b4a0bfbf3a8ceb`
and copied oracle/emitter under `pixel-matrix-F0CIRT`. The runner stays
unchanged throughout all four cases. This profile disables the subsequent
text/priority CPU capability; its result does not qualify priority rendering.
The Make target subsequently also copies the
executable for future invocations, like the reduced/internal/text matrices.
Its updated recipe has been dry-run inspected, not yet executed as a new run.

This contract fleshes out Z4 and the missing portion of Z3. No native or
hardware completion box is checked by this increment.

## Additional local reference: eX1 composition

The sparse Common Source Project checkout is now local at
`references/emulators/common-source-x1`, pinned to
`2f350e59869ad52293c768e08dd1e6137001486b`. Inspected `display.cpp`
`get_zpriority`, `get_zpal_num`, control access and drawing branches; not built
or executed, and no code/assets copied. Unlike the inspected X Millennium
candidate composition branch behind `#if 0`, eX1 supplies active two-screen
composition. This is implementation evidence, not independent pin measurement.

Its ordering uses raw text/graphics code nonzero, not palette RGB brightness:
a nonzero code programmed black remains present. Crucially, a zero-code
backdrop is not uniformly fixed black: text-on-top can fall through to
programmable graphics entry zero, whereas graphics-on-top can end at fixed
text entry zero. The standalone ordering decoder currently returns an abstract
backdrop, so it has not settled this RGB/opacity policy. Add these distinct
all-zero and programmed-black cases to the actual-pixel acceptance oracle.

eX1 gates both `1FC0` reads/writes by AEN; X Millennium's inspected write path
does not. Its reduced-index masks `CCC/333` and text intensity mapping still do
not resolve the primary pin-contract uncertainties. The service sheet's
multi-mode transparent-only background/blackclip descriptions do not specify
raw-code versus RGB-zero testing or the exact clip stage. The Techknow screen
chapter (printed 122) also requires palette setup after a mode switch: existing
CPU reduced-pixel fixtures that program in full-color before switching are
experimental coverage, not that native programming-sequence acceptance.
