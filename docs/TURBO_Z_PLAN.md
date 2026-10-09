# X1 Turbo Z roadmap (output foundation only)

October 6, 2026. Turbo Z is now explicitly part of the user's active goal,
alongside work groups 1–6. Base Turbo device/video gates remain dependencies.
`TURBO=1` is not a Turbo Z identification flag. Introduce a separate capability
profile only when its observable behavior exists; do not make software detect
missing devices by returning invented status values.

## Evidence actually inspected

- Sharp CZ-880CB/CE service manual No. CZ-72, printed/PDF pages 1–6, 9, 30,
  43–48, read
  visually from the existing local scan. Page numbers coincide for these
  sheets. [Original scan](https://eaw.app/Downloads/Manuals/Sharp/CZ-880_Service_Manual.pdf),
  [local inventory/hash](../references/manuals/README.md).
  The manual is image-only; text extraction did not provide searchable prose.
  No new copy was downloaded. Pages 43/45 are partial foldout sheets: only
  visible chip/control labels were surveyed, not a complete netlist/register
  timing audit. Adjoining pages 44/46 were also surveyed for component labels;
  custom ASIC behavior remains unresolved. The web viewer could not fetch this PDF; the local
  scan was used successfully.
- Existing local MAME `x1.cpp` / `x1_v.cpp`, revision recorded in
  `TURBO_IMPLEMENTATION_PLAN.md`. [Upstream implementation](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1.cpp).
  Z palette/control code and logging-only capture/mosaic/key/scroll handlers
  were inspected, not executed. These stubs are not reference acceptance.
- Existing X Millennium `io/crtc.h`, `io/crtc.c`, `vram/makescrn.c`, inspected
  locally, not built/run. Its mode selection and palette readback provide a
  second implementation, with disagreements listed below.

## Model and feature boundaries

The CZ-880 manual specifies a 4 MHz Z80A, two 80C49 control processors, 64 KiB
main RAM, 96 KiB GRAM, 6 KiB PCG, 6 KiB total text/attributes, 8 KiB character
ROM and 256 KiB Kanji ROM. Its 32 KiB BIOS contains a 4 KiB IPL (page 4): a
32 KiB read aperture alone does not prove the reset/BIOS bank contract.
Page 2 describes first/second-level Kanji and a standard mouse. Page 3 describes
FM/PSG mixing and two switchable 2HD/2D drives; page 6 includes RS-232C,
parallel printer, two joystick ports and battery-backed clock functionality.

Do not assume ZII/ZIII RAM or cassette differences from the CZ-880 manual.
MAME's model inventory associates additional 64 KiB RAM with ZII and cassette
removal with ZIII; verify their manuals before exposing those variants.
EMM, SASI/HDD and expansion-board interfaces remain optional capabilities,
not requirements inferred from MAME's combined port map.

## Graphics acceptance matrix

Manual page 4 lists these multi-mode configurations, all with 12-bit analog
RGB color selection. Active dimensions and actual address/plane use need
independent pixel tests; no row resampling or oversized framebuffer claim.

| Native mode | Simultaneous colors | Screen capacity |
|---|---:|---:|
| 640x400 | 8 selected from 4096 | 1 |
| 640x200 | 64 selected from 4096 | 1 |
| 320x400 | 64 selected from 4096 | 1 |
| 320x200 | 64 selected from 4096 | 2 |
| 320x200 | 4096 | 1 |

The 640x200/64-color entry is absent from MAME's introductory list; retain
the manual's entry and derive its packing from schematics/second reference.
Compatibility mode also has 192/384-raster variants. Screen counts in the
manual include monochrome/plane-use configurations; do not allocate imaginary
extra GRAM. The digital RGB output reduces analog multi-mode colors to eight
(page 4); model that separately from the full-color MiSTer/scaler output.

## Ordered TODO and tests

- [ ] Z0: explicit CZ-880 profile, authentic BIOS/ANK/Kanji loader layout and
  hashes, real device/DIP/readback behavior. Verify base/Turbo decode isolation,
  DAM and ACK exclusion, cold reset and retained storage. Resolve BIOS bank
  layout before native boot, without patching firmware detection.
- [ ] Z1: widen the shared RGB pipeline to at least 4 bits/component and carry
  full color through simulator PPM capture, wrapper/scandoubler/scaler and
  screenshots. Preserve exact base eight-color pixels and audio interfaces.
  The [RGB12 foundation](TURBO_Z_RGB_STATUS.md) now connects shared-machine,
  simulator/PPM/SDL and eight-bit wrapper outputs; exhaustive capture and
  wrapper lint tests pass. Real palettes, fitted/scaler/physical full-color
  acceptance remain open, so this milestone is not checked complete.
- [ ] Z2: analog enable/palette mode `1FB0`, eight text palette entries
  `1FB8..1FBF`, graphics palette control `1FC5`, and palette programming/read
  transactions at `1000..12FF`. Establish AEN/APEN/APRD/C64 gating, address
  formation, masks, reset and palette RAM retention from hardware diagrams.
  The [October 6 palette contract audit](TURBO_Z_PALETTE_CONTRACT.md) records
  the visible 12-address-bit/three-component RAM wiring, precise emulator
  disagreements and the original diagnostic matrix. ASIC index/read/WAIT
  behavior remains unresolved beyond the explicit CPU-only subset below.
  The standalone storage probe now fits in six M10Ks/39 ALMs, and the new
  technical-book I/O-map audit corroborates full index packing while exposing
  a conflicting `1FC5` access-mode label. The screen-display chapter now
  corroborates normal `80h` write / `88h` selector/read programming, requires
  cold initialization distinct from retained IPL reset, and fixes text entry
  zero as inaccessible black. External RAM now has a tested configuration-time
  identity image with retained warm reset; this does not implement internal/text
  palette defaults or machine reset dispatch. Use those integration requirements;
  inactive-mode side effects and exact reduced bank mapping remain open.
  Combined integration and arbitration
  remain required; do not treat the resource probe as completion of Z2.
  The [external transaction adapter](TURBO_Z_PALETTE_ACCESS_STATUS.md) now
  connects selector/write/read requests to storage in a separate diagnostic;
  An opt-in [shared-Z80 CPU experiment](TURBO_Z_PALETTE_CPU_STATUS.md) now
  latches `1FB0/1FC5` and tests the explicit low-scan/40-column `80h/88h`
  sequence, real CPU WAIT and retained palette reset. Upper input bits,
  general native decode and DMA/beam ownership remain open. The separate
  [full-color renderer experiment](TURBO_Z_VIDEO_STATUS.md) now connects an
  external-palette display consumer and passes identity/custom 320x200/4096
  pixels and retained reset; Z2/Z3 remain incomplete beyond that explicit subset.
  The [functional ownership follow-up](TURBO_Z_PALETTE_OWNER_STATUS.md) now
  corrects C6=1 for 40 columns, connects a blank-window lease/drain and passes
  real-CRTC CPU waits and the unchanged original late-read failure after a
  narrowly scoped retained-response fix. Native ASIC pin timing, display
  general display deadlines and DMA ownership still need qualification.
  Exhaust palette entries/components and read-selector transactions; verify
  address/data latch and held-strobe behavior, WAIT/bus ownership, live changes
  during blanking/active display and mode switches without reset.
- [ ] Z3: all five multi-mode pixel formats above, using real CPU-programmed
  GRAM, distinct pages/planes, horizontal pixel packing and raster boundaries.
  The [screen-chapter fetch audit](TURBO_Z_PALETTE_CONTRACT.md#multi-mode-fetch-requirements-from-the-same-chapter)
  now identifies the required bank/+400h source bytes and component significance
  for every mode, including 640×200/64. The current one-byte-per-component
  renderer is insufficient; qualify a synchronous video fetch/buffer schedule
  and arbitration rather than attaching a palette to quantized digital pixels.
  A [sequential GRAM buffer](TURBO_Z_GRAM_FETCH_STATUS.md) now passes the full
  within-bank address/five-layout/page/parity matrix through the real RAM
  primitive at three clock ratios, with exact response latency and reset seams.
  The full-color experiment connects it to CRTC/pixel/palette stages for
  320x200/4096, with all 64,000 pixels checked under identity/custom palettes
  and retained reset. A separate
  [multi-mode extension](TURBO_Z_MULTIMODE_STATUS.md) now passes generated
  640x200/64, 320x400/64 and both selected 320x200/64 screen captures after
  retained reset under an explicit provisional effective-pair expansion.
  Its sixteen-case cold/warm palette matrix is running. Internal 640x400/8,
  simultaneous screen composition and native ASIC/priority gates remain open;
  this does not close Z3.
  A separate [internal8 extension](TURBO_Z_INTERNAL8_STATUS.md) now connects
  programmable 640x400/8 with all-pixel identity/custom retained-reset checks
  and custom cold cross-store isolation. Exhaustive aliases/nibbles and
  captured palette-store tags pass. Full cold/warm isolation, native/composition
  and hardware gates remain; diagnostic formats alone do not complete Z3.
  Verify MA wrap, screen-page capacity, priority/transparency and blackclip
  before/after palette stages; compare every active pixel and native HS/VS.
- [ ] Z4: text-display/priority control `1FC0`, analog text colors, background
  transparency and model-specific SCRN/blackclip readback. Manual pages 4–5
  distinguish compatibility/multi-mode border/black rules. Test text/graphics
  overlap with underline, blink/reverse, Kanji halves and all color controls.
- [ ] Z5: standard stereo FM (YM2151), board CTC/interrupts and PSG mixing.
  The [standalone FM foundation](TURBO_Z_FM_STATUS.md) now executes genuine
  JT51 bus/timer/stereo notes and original signed mixer tests at all three
  master frequencies. Actual CPU busy/timer/status, stopped-enable WAIT and
  HALT/timer-flag reset tests pass nine clock combinations separately.
  Shared-machine decode/IRQ, signed PSG conversion,
  native/hardware fidelity remain open; Z5 is not completed.
  Reuse audited JT51 sources, preserve licenses, verify busy/status/timers,
  stereo panning, clipping and deterministic note WAVs. Manual page 3 routes
  PSG equally to L/R and combines FM channels for the internal mono speaker;
  MiSTer stereo and optional mono output need distinct tests.
  The page-30 diagram's 4 MHz label is now corroborated by the adjoining
  sub-board sheets 47/48: T-2 is labelled 4 MHz, and the visible YM2151
  IC404 clock pin 24 is on that labelled net, with no intervening divider
  drawn on these sheets. Use 4 MHz as the documented provisional input,
  rather than silently copying local MAME's `MAIN_CLOCK/8` (2 MHz).
  Trace the main-board clock source and measure the physical pin before
  claiming oscillator/phase accuracy; the reference emulator discrepancy
  remains explicit. Validate note pitch, busy duration and both timers
  against that input frequency and preserve base PSG clock behavior.
- [ ] Z6: dual 2HD/2D operation, mode-switch/DIP reset behavior, rates/index,
  media type and supported D88 track/sector layouts. Protect source images;
  validate native HD boot/reads/writes using disposable output copies.
- [ ] Z7: second-level Kanji/ANK ROM authenticity and addressing, mouse/serial
  behavior, calendar/RTC persistence and control-processor commands. Verify
  CPU-level device transactions, not static capability signatures.
  Resolve storage budget before adding the ROM: the font-BRAM X3 fit uses
  389 of 553 M10Ks, leaving 164. Extrapolating its four-block/4-KiB byte-wide
  font layout, a further 256-KiB Kanji ROM would need about 256 blocks, beyond
  that remaining capacity. This is an estimate, not a Kanji synthesis result.
  Plan external-memory/cache service or a verified alternative packing/port
  architecture, then refit. Include simultaneous video/CPU glyph requests,
  deterministic WAIT/prefetch latency and DMA/capture contention in tests.
  [Measured memory budget](TURBO_VIDEO_BRAM_QUARTUS_BUILD.md).
- [ ] Z8: image capture `1FC1`, mosaic `1FC2`, chroma key `1FC3`, extra-scroll
  `1FC4`, superimpose/telopper output and video-source ownership. First derive
  register encodings, capture clocks and DMA/GRAM arbitration from manual
  schematics; specify a deterministic simulated input source. Verify capture
  at 1/2/3/4-bit component quantization (8/64/512/4096 colors), inversion,
  normal/inverse chroma key and horizontal/vertical mosaic dimensions listed
  on page 5. Test physical video input separately; an absent input must not
  masquerade as a working digitizer.
- [ ] Z9: native software acceptance, analog/multi-mode test programs and
  diagnostic input patterns; cold/warm reset during palette/capture/SD/DMA,
  unchanged assets and repeatable input/audio/screens. Record source-bound
  Quartus resource/timing/CDC reports and physical output measurements.

MAME's palette implementation marks APRD and active-display bus behavior
incomplete. X Millennium gates text/graphics palette readback/writes on AEN
where MAME is less restrictive, and forms reduced-color palette indices
differently. These are explicit research/acceptance gates, not choices to
settle by making one game's boot pass. MAME's four video-effect handlers only
log accesses; they cannot validate capture or mosaic output.

## Next primary-document audit

Page 9 shows optional external drives/RAM/color-image board, not a chip-level
system block diagram. Its right-hand foldout continues beyond that scan page;
do not infer full built-in capture hardware from the accessories alone.
Page 30 is the internal system diagram: separate 48 KiB GRAM banks, A/D and
D/A paths, RGB decoder, mosaic/capture positioning, telopper, automatic
synchronization control and 32.768 kHz NiCd-backed clock. It independently
shows the CPU/DMA/SIO/CTC, two 8255s and two 80C49s. The keyboard processor
and main sub-CPU are distinct; the MR16 replacement is not automatically an
implementation of both controllers.

The visible part of page 43 identifies Z80A CPU IC9, DMA IC10, SIO IC11,
decode ASIC IX0861CE (IC17) and wait/bus ASIC IX0724CE (IC3). Page 45 shows
address/video ASICs IX0862CE/IX0866CE, graphics ASIC IX0867CE, character/IRQ
ASIC IX0864CE, MB8416 graphics RAM, 2 KiB text/Kanji/attribute RAMs and
42.95454 MHz crystal. These labels give net-audit targets, not behavioral
models of custom ASIC internals. Chip acquisition alone cannot fill those gaps.

Page 44 adds the HD46505-2 CRTC, Z80A CTC, timing/PCG ASIC IX0863CE,
16 MHz CPU crystal and real FDC-ready/external-ready inputs. Page 46 shows
palette ASIC IX0868CE with three uPD4314 palette RAMs (12 output data bits),
three MB40776H D/A converters, three MB40576 A/D converters, two uPD4101C
line-buffer FIFOs and level-1/level-2 Kanji ROMs IX0730CE/IX0782CE. This
supports separate palette, capture/line-buffer and glyph-loader milestones.
The ROM address nets explicitly include glyph code, raster and left/right;
archive layouts must be reconciled with those pin orders before claiming
that concatenating downloaded font files reproduces silicon addressing.

Sub-board pages 47/48 show the 6 MHz 80C49 sub-CPU, uPD1990 serial calendar
and 32.768 kHz oscillator, YM2151/YM3012 FM path, YM2149 PSG, MB8877A plus
MB4107 data separator and disk-control ASIC IX0870CE. The existing main
CPU's DMA-ready path therefore depends on real FDC DRQ and wait/bus logic,
not a replacement always-ready status bit. Disk connectors explicitly carry
rate/mode, 48/96 TPI, index, ready and write-protect; add those relationships
to the HD-media timing contract before merely accepting an HD D88 header.
The October 5 clock follow-up visually rechecked both existing renders and
rendered sheet 48 again from the same hashed local PDF. It inspected T-2 and
YM2151 pin 24, not a complete main-board clock-generation trace. The original
scan's online viewer again failed; this evidence comes from the local primary
scan, not an emulator run or measured hardware.

Continue a full signal/ASIC functional audit of sheets 43–46, connectors
pages 11–29; capture adjustment page 40; sub-board page 47; telopper page 51; IC blocks
pages 67–71. Render and inspect those pages before assigning register bits
or importing FPGA chips. Record page-specific evidence and unresolved nets.
For now only the pages explicitly listed above and named emulator source paths
have been inspected.
