# Quartus revisions

October 20, 2026: the bring-up revisions were merged into one release core.

| Revision | Role |
|---|---|
| `sharpx1_turbo_z_font_single` | **Release core.** X1 Turbo on one X3 master clock, with a runtime X1 / X1 Turbo / X1 Turbo Z model (OSD `Model`), DMA, FM board + CTC, Turbo Z video, physical Kanji font, cassette, D88 and raw 2D. See [DMA board status](DMA_BOARD_BUILD_STATUS.md) and [model select](MODEL_SELECT_STATUS.md). |
| `sharpx1` | Base X1, original two-clock design. Kept as the main-project baseline and a fallback until X1 mode in the release core has the same hardware coverage. |

## Retired

These were removed in the merge commits. Their last versions are in
`fd9405f` (or `2111ebd` for `sharpx1_turbo_z_video_single`); restore one with
`git show fd9405f:<name>.qsf > <name>.qsf` if a historical result must be
reproduced. Dated documents that cite them remain as records.

| Revision | Was | Replaced by |
|---|---|---|
| `sharpx1_Q13` (+ `.qpf`, `.srf`) | Historical Quartus 13.1 project | Quartus 17 main project |
| `sharpx1_single` | Base X1 on one 28.57-MHz master | Release core, X1 mode |
| `sharpx1_cassette` | Base X1 + TAP | Release core, X1 mode (tape included) |
| `sharpx1_turbo_single` | Turbo foundation, single clock | Release core |
| `sharpx1_turbo_video` | Two-clock X3 video | Release core (single X3 master) |
| `sharpx1_turbo_fm` | FM board alone | Release core |
| `sharpx1_turbo_dma_single` | DMA/IRQ qualification | Release core |
| `sharpx1_turbo_z_font` (+ `.sdc`, `_reset.sdc`) | Two-clock font board (failed timing) | Release core |
| `sharpx1_turbo_z_video` (+ `.sdc`) | Two-clock Z video | Release core, X1 Turbo Z model |
| `sharpx1_turbo_z_video_single` | Single-clock Turbo Z video (removed October 20, after `2111ebd`) | Release core, X1 Turbo Z model |
| `sharpx1_turbo_z_handoff` | HDMI clock-handoff experiment on two-clock Z | — (audit scripts kept; tests use synthetic reports) |

Their `lint-wrapper-*` targets went with them; the wrapper still contains
the corresponding `ifdef` paths. Probe scripts under `scripts/` that name
retired revisions are historical tooling.
