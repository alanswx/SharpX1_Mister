# Turbo boot-switch readback (October 6/7)

The shared machine now has a static raw `TURBO_DSW` parameter, default decimal
241 (`F1`), read at `1FF0..1FFF` only with `TURBO=1`. Writes have no effect.
Base X1 retains unmapped `FF`. The read is gated by ordinary I/O read and DAM;
interrupt acknowledge is excluded by the parent machine's read decode.
This does not implement SASI or detect a mounted disk's density.

## Evidence and provenance

The existing local MAME `src/mame/sharp/x1.cpp` switch definition encodes bit 0
as interlace off when set; bits 3:1 select the boot device. Its default `F1`
selects 2D floppy, `F3` 2DD, `F5` 2HD and `FF` SASI. Upper bits are marked
unknown. These are emulator-defined configuration semantics, not a completed
physical-switch audit. Local X Millennium `io/dipsw.c` returns raw switches;
`io/iocore.c` mirrors the low nibble. Inherited `rtl/x1_adec.v` also selects
`1FFx`. The model-20/30 schematic's SW1/IC8 bus buffers were inspected, but
physical alias/polarity and model-specific strap qualification remain open.
New module and fixtures are original GPL-2.0-only code; no private bytes added.

Before this change, the actual supplied Turbo IPL read `1FF0=FF` at about
8.141 ms. Its eight-second final PC was in a loop reading SASI status `0FD1`.
This identifies a real missing configuration readback, not proof that it was
the only boot blocker. A fresh two-second F1 probe now reads `1FF0=F1`
twice. Both cold runs match all reports/dumps/actual frames and preserve input
hashes, but still execute **zero FDC transactions in the 0–1500 ms trace**.
888 host disk requests are scanner activity, not CPU game loads. No gameplay
acceptance follows from the switch fix.

Private evidence: `output_files/arcus-kanji-dsw-f1-init/`, collector log
`/tmp/x1-arcus-dsw-f1.log`. Same authorized IPL/ANK16/model-40 candidate and
exploratory Arcus Disk 1 A / Disk 2 B as the previous native probe; system
32 MHz, video nominal 42.954540 MHz, fast model, no DMA, two fresh cold runs,
two seconds each, zero writes.

The first eight-second follow-up completes with 14,388 CPU FDC data reads,
2,752 host requests, zero host writes and 469 actual frames. Its final
640×400 frame (`c532ccc7df38c9da`) displays a Japanese disk-read error,
not gameplay. The 6000–7500 ms trace contains 113,382 FDC transactions,
mostly status polling. This is progress beyond the old SASI loop, not
proof of successful Arcus boot. The independent repeat is still running;
do not promote the completed first run to repeatability. Private evidence
is `output_files/arcus-kanji-dsw-f1-eight/`; `cold-final.png` is a lossless
conversion of the terminal real PPM and was visually inspected. The earlier
`cold-inspection.png` is a blank in-progress frame, not the final result.

## Checks and remaining gates

`make -C verilator test-turbo-dsw` passes 266,240 exhaustive address/control
and raw-pin/mirror cases, including disabled base profile and DAM isolation.
The real-Z80 diagnostic reads all sixteen mirrors, attempts ignored writes,
checks unmapped neighboring ports and reboots from retained ROM/RAM. Fast
F1 cold/warm passes (`/tmp/x1-dsw-cpu-fast-recovered.log`), as does the
delay-aware F1 profile (`/tmp/x1-dsw-cpu-timing-recovered.log`). Base X1
cold/warm returns FF (`/tmp/x1-dsw-cpu-base.log`). The wrapper elaborates
with inherited warnings (`/tmp/x1-dsw-wrapper-lint.log`). The ten-case fast
Kanji RGB matrix still passes (`/tmp/x1-dsw-render-pixels-fast.log`).
Alternate F5 fast cold/warm checks pass (`/tmp/x1-dsw-cpu-f5.log`), using
a distinct build directory. Actual renderer snapshot continuation passes
(`/tmp/x1-dsw-render-snapshot.log`). The dedicated executing CPU DIP snapshot
test also passes exact F1/F5 report/dump continuation and bidirectional raw
configuration rejection (`/tmp/x1-dsw-config-snapshot.log`).
An initial CPU fixture
incorrectly expected FF at the end of a DAM-clearing read; its failure is
preserved in `/tmp/x1-dsw-cpu-fast-dam.log`. The machine clears DAM on the
I/O strobe before the CPU's final sample. The corrected fixture uses the
existing native PPI recovery read; it does not alter RTL to force that result.

Build with `TURBO_DSW=<decimal byte>` for an explicitly chosen boot profile.
Use a **new `KANJI_DIR`** when changing build configuration; make timestamps
do not track parameter changes. No runtime OSD switch selector is added yet.
F5 config alone does not establish 2HD controller/media support.
Turbo snapshot profiles include DIP revision/configuration so pre-DIP or
different-DIP states cannot silently resume. Current F1/F5 configuration
rejection/continuation passes; rejection of an actual preserved pre-DIP state
still needs an executed check. Base profile numbering is unchanged.
Native boot, hardware switch semantics, interlace, UI, current-source Quartus
fit and physical acceptance remain required. The recommended RBF predates
this change and does not contain this switch readback.
