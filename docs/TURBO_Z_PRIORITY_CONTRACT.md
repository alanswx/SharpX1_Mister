# Turbo Z priority/composition implementation contract

October 9, 2026: research and remaining integration requirements, **not an
implemented renderer or register**. This follows the completed bounded
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

This contract fleshes out Z4 and the missing portion of Z3. No implementation
or hardware completion box is checked by this research checkpoint.
