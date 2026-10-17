# CROSS Chase matched hardware controls

October 15, 2026. Native CROSS Chase shows a populated playfield on both the
historical single-clock RBF and the external-font c6 RBF, with either base or
Turbo IPL. No renderer change was needed. The earlier score/Press-key capture
was incomplete input evidence.

The local game source has separate waits after the initial screen, hints,
high score and per-level prompt (`main.c` lines 149–160, 242 onwards, 381).
This source inspection does not establish an exact binary/source build match.
Three Space taps produced no field in any of four controls; six taps at
0/5/10/15/20/25 seconds after a 25-second cold wait traversed the prompts.
Raw screenshots were requested every 0.4 seconds; timestamp coalescing means
70 requests yielded 32–33 distinct PNGs per case.

| Core / IPL | Exact border matching frames | Inspected populated frame |
|---|---:|---|
| Historical single / base | 8 | `01_Single_BaseIPL_26.png` |
| Historical single / Turbo | 14 | `02_Single_TurboIPL_21.png` |
| External-font / base | 14 | `03_External_BaseIPL_22.png` |
| External-font / Turbo | 14 | `04_External_TurboIPL_21.png` |

The historical RBF SHA-256 is
`eaca279a7c137dd6b9cef50a3da2fbb793b558eced3c3177ebb5b454352a3e1d`:
it uses the historical 28.571428-MHz single-clock experiment. The external
RBF is `c6a2ac021173a18fa1f45ac2ea0d9ed8b2a44db1979db1d18de549125afc3880`,
SYS 32 MHz / fitted VID 42.954545 MHz, with the original synthetic full font.
No native Kanji font is involved.

All four use the same protected disposable disk content, SHA-256
`2fb70389737a7d54bff5a746b581343385ebde115cefb77ded32c473dcde97ec`.
Private originals, deployed assets, RBFs, MGLs and PNGs are hash-recorded in
[the successful manifest](../output_files/X1Cross4_20261015T145438Z/manifest.json).
[Border review](../output_files/X1Cross4_20261015T145438Z/border-review.json)
checks all 531 yellow pixels at the known side/bottom-border positions of a
previous accepted native 320×200 frame. This is a partial exact signature
plus visual inspection of white circles, red crosses and the bounded playfield;
it is not whole-frame equivalence, directional-input displacement or clock
accuracy acceptance. The successful fourth inspected frame is already at
“You lost”; that still establishes its populated playfield, not sustained play.

The insufficient-input matrix remains in
`output_files/X1Cross_20261015T144642Z/`; the successful matrix is in
`output_files/X1Cross4_20261015T145438Z/`. Neither replaces the earlier frozen
manifest. Physical timing closure, native Z font conversion and broader
software/reset/coexistence gates remain open.

The subsequent [fd9a0850 upload-recovery RBF](Z_FONT_HPS_UPLOAD_STATUS.md)
also reaches an inspected native playfield through Turbo IPL with the changed
synthetic full font. Fourteen raw frames match the same 531 border pixels;
its separate gallery/manifest preserve that profile independently.
