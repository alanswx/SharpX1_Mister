# X1 Turbo implementation plan

October 4, 2026. The coordinating implementation now provides the opt-in T1
foundation and 32 KiB IPL aperture; see [confirmed tests/limits](TURBO_STATUS.md).
Remaining stages below are a plan, not completed Turbo support.
The active machine is `rtl/sharpx1.v`, shared by `verilator/sim.v` and the
MiSTer wrapper. `rtl/sharpx1_legacy.v` is a reference, not the current machine.

## Target and evidence

Implement an **experimental Turbo foundation parameter** first. This parameter
enables selected extensions to the base machine, not a complete model, an
authentic Turbo IPL profile, or a compatibility promise. Keep the
base-X1 default and its port mirroring intact. Treat Turbo II, optional boards,
and Turbo Z as separate profiles/capabilities. In particular, FM, 1 MiB bank
RAM, 4096-color palettes and video capture must not be advertised merely
because the Turbo address map has been added. The initial slice can be tested
with original CPU diagnostics and the current IPL; an authentic Turbo IPL,
ANK and Kanji asset set needs its own provenance and loader contract before
claiming native Turbo firmware acceptance.

Confirmed first increment: machine/simulator default to `TURBO=0`;
experimental targets pass `-GTURBO=1`. CPU page/KVRAM/DAM/reset and synthetic
32 KiB IPL tests pass in both clock models; actual RGB page/clip fixtures
also pass. These checks do not complete T2 or establish a full Turbo model.
A supplied 32 KiB Turbo IPL has now been staged unchanged and executed in a
bounded native probe; it displays an IPL search message, not the Arcus game.
See [firmware provenance and limits](NATIVE_TURBO_FIRMWARE_STATUS.md).
The shared machine explicitly selects
`PS2_RECEIVE_ONLY=1`, while standalone/legacy defaults remain 0. X Millennium
is now cloned and inspected locally, not built/run; existing sibling MAME
remains the main reference. See `TURBO_STATUS.md` for exact scopes.

References actually inspected locally:

- MAME `src/mame/sharp/x1.cpp` and `x1_v.cpp`, checkout
  `../FM-7_MiSTer_alanswx/refs/mame`, revision
  `f4bfc5a423f48d48e809c01fc70a47c0c00d40a2`.
  Relevant functions are linked below to the corresponding upstream sources;
  the local checkout was read, not cloned or run for this work.
- `rtl/legacy/x1t_mode.v`, `rtl/sharpx1_legacy.v` and the active machine.
  Legacy mode latches establish a useful bit-by-bit comparison, but SIO is
  stubbed, Kanji detection is fake, and DMA is mediated by MR16 firmware.
  Do not inherit those shortcuts as a Turbo contract. Preserve Satoh's notices;
  the inherited redistribution restrictions still need reconciliation.
- The downloaded [CZ-851/852 schematic](../references/manuals/CZ851_2C_Schematic.pdf)
  was rendered and visually inspected at PDF pages 1 through 6. Page 1 shows
  Z80A SIO/CTC, 8255, PSG, interrupt/wait nets and named screen-control lines;
  page 2 shows HD46505, graphic RAM, separate character/attribute/Kanji RAM
  paths and video wait logic. Page 4 shows the 8049 sub-CPU, mailbox 8255 and
  blink/keyboard interrupt connections. Page 5 shows the real Z80A CPU/DMA,
  BUSRQ/BUSACK and interrupt-enable-chain nets. Page 3 has the X3 42.95454 MHz
  oscillator, divider/multiplexer chain and `200/400` / `40/80` control nets;
  page 6 has the MB8877A and disk interface. This is a limited sheet inspection,
  not a complete timing/netlist audit. The original scan is available from
  [the manuals archive](https://eaw.app/Downloads/Manuals/Sharp/CZ851_2C_Schematic.pdf).
- The local Turbo II user/BASIC manuals are image scans without usable
  extracted text. Selected user-manual pages were subsequently inspected
  visually; the software-visible display contract below records the scope.
  The Turbo Z service
  manual pages 1–6, 9, 30 and 43–48 were subsequently visually audited for the
  separate [Turbo Z roadmap](TURBO_Z_PLAN.md). This is a feature/component
  survey, not a complete ASIC/register/netlist audit. See
  [manual inventory and hashes](../references/manuals/README.md). Do not cite
  these scans as proof of unreviewed register details.

MAME is an implementation reference with explicit TODOs, not silicon proof.
Further SCRN audit: CP932-decoded X Millennium `io/crtc.h` describes bit 2
as vertical text expansion and bit 6 as CPU 8/16-raster font selection;
`io/pcg.c::pcg_i` applies bit 6 in high-speed CPU ANK reads independently of
display scan mode. That agrees with inherited `O_TEXT12`/`O_CG16` names but
differs from MAME's display `ank_sel` usage. Treat the port table below as a
reference inventory, not a settled hardware contract for those two bits.
Verify mode/CPU-read/display combinations from the circuit/manual before
adding independent font selection; high-scan-only ANK does not close it.
Its screen-mode comments contain a bank-bit typo, while `scrn_w` unambiguously
uses bit 3 for display and bit 4 for access. Its Turbo interrupt order is marked
unverified and disagrees with the legacy chain. These are explicit review gates.

The parent also cloned and inspected X Millennium at ignored
`references/emulators/xmil-libretro`, revision
`b07506c0cae31d260db28cb079148857d6ca2e93`. Its access/display bits agree with
MAME, but SCRN readback/mirroring and high-resolution timing estimates differ;
see `TURBO_STATUS.md`. It was not built/run and no code was imported from it.

## Primary Turbo II text/video acceptance contract

October 5 visual audit of the existing CZ-856C user manual, SHA-256
`ae2f807aaeefcf9993cc705b7ea24015b121d976048ed9f65e2f0f15b37228ac`.
PDF pages 69–70 are printed pages 58–59; PDF pages 86–91 are printed
pages 75–80. These describe **Turbo II user-facing software behavior**, not
a complete ASIC register specification or proof that earlier Turbo models
have identical bit encodings. [Original Sharp manual scan](https://eaw.app/Downloads/Manuals/Sharp/CZ-856C_UsersManual.pdf).
Only these selected pages and introductory/contents pages were read, not
the whole manual; Japanese OCR was not performed.

| Documented behavior | Required implementation/acceptance |
|---|---|
| Standard scan supports 40/80 columns with 25, 12, 20 or 10 text rows; high scan supports 40/80 with 25, 12 or 20 rows. BASIC defaults to 80×12 standard / 80×25 high. | CPU-programmed CRTC/SCRN mode matrix at both widths; independently predicted active pixels, glyph/raster addresses and HS/VS. Do not invent a general 50-row mode from a 400-line frame. |
| Graphics variants are 200/192 rasters in standard scan and 400/384 in high scan; 40-column graphics is 320 pixels wide, 80-column is 640. Two 48-KiB graphics memories are specified. | Test both active-height variants, each display/access page and raster boundaries. Frame height alone does not establish text rows or glyph choice. |
| Underline is available in 10/20-row text modes, which disable graphics display. `KSEN` controls underline in the reserved interline area. | Define raster reservation, underline position/color/attributes, graphics suppression and mode exit/reset. A line drawn over otherwise unchanged graphics is not this contract. Read the remaining KSEN syntax/register circuit before assigning SCRN bits. |
| `CSIZE` selects normal 8×8, doubled height, doubled width or both. Double-height placement has row/pair restrictions; double-width odd columns map to the next even column. | Test row/column parity, neighboring cells, clipping, reverse/blink/color/ROM-vs-PCG and width transitions, not only a centered enlarged character. Reconcile BASIC software placement with hardware attribute semantics rather than changing CPU addresses by assumption. |
| `CFLASH` alternates normal/reverse; text and graphics are independent overlapping displays with a console window. | Verify native blink phase and mixed priority/transparency, blanking, console boundaries and retained attributes. |
| ROM CG is fixed ANK/kana/semigraphics; RAM CG has 256 programmable 8×8 patterns with three color planes and is volatile across power-off. Kanji KMODE has text-mode restrictions. | Preserve ordinary PCG access and warm-reset retention; test plane independence and CPU/display addressing. Add authentic Kanji read/glyph halves and mode restrictions separately; an allocated KVRAM is not Kanji support. |

The WIDTH scan selector can follow the physical display switch or request
standard/high explicitly. Wrong-scan output is not supported by an ordinary
single-scan monitor; the manual names dual-scan Sharp displays separately.
MiSTer scaler output must therefore not hide an incorrect native raster.

This narrows T2's tests but does **not** resolve SCRN b2/b6: X Millennium and
legacy identify vertical expansion and CPU 8/16-row selection, while MAME
uses a display ANK selector. The current high-scan font16 increment remains
partial. Complete circuit/CPU-read/display combinations before changing it.

## Register and memory contract

Addresses below are Z80 **16-bit I/O** addresses. Decode ordinary I/O only,
excluding M1 interrupt acknowledge and the base DAM plane-write mode. Preserve
base read-to-clear DAM behavior: new ports must not steal graphics transactions.
All reset values in the first slice must be deterministic. Reset mode latches
to zero; reset must not erase VRAM or reload media.

| Port/range | Turbo implementation | Tests / source |
|---|---|---|
| `1FD0..1FDF` write | SCRN; low-nibble mirror. b0 high-resolution scan; b1 raster expansion; b2 8/16-raster ANK selection; b3 GRAM display page; b4 CPU GRAM access page; b5 high-speed PCG; b6 graphics-character raster control; b7 underline/display interaction. | Decode all mirrors, reset, held strobe, ordinary I/O vs ACK/DAM. Implement b3/b4 first. Other bits require the video gates below. [MAME `scrn_w`](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1.cpp#L1044), legacy `x1t_mode.v`. |
| `1FE0` write | Black clip: b2:0 text color selector, b3 enable text clipping, b4/b5 clip graphic color indices 0/1, b6 blanking black. b7 reserved in the legacy implementation. | Exhaust each selector, reverse/blink interactions and priority before RGB comparison. Readback is model-specific: MAME says Turbo Z only. Do not add Turbo readback just to make detection pass. [MAME black clip](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1.cpp#L1078). |
| `1FF0` read | Model/DIP switch input, with explicitly documented profile values. | Establish polarity/defaults from schematic/manual audit; software title guesses are insufficient. [MAME input definition](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1.cpp#L1885). |
| `3000..37FF` / `3800..3FFF` | 2 KiB text / 2 KiB Kanji attribute RAM. Turbo splits the base's mirrored text aperture. Existing 2 KiB ordinary attributes at `2000..27FF` retain their own path. | Independent writes, address wrap, base mirroring unchanged, reset retention. Kanji attrs: b7 enable, b6 left/right half, b5 underline, b3:0 glyph bank; b4 level-2 behavior unresolved. [MAME map](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1.cpp#L1378), [`draw_text`](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1_v.cpp#L143). |
| `4000..7FFF`, `8000..BFFF`, `C000..FFFF` | B/R/G GRAM planes, 16 KiB each, **two pages** (96 KiB total). CPU page from SCRN b4; display page from b3. DAM writes use the CPU page for all selected planes. | Every plane/address boundary on both pages; no aliasing; mixed display/access pages; page changes through actual CPU writes; base regression. [MAME GRAM renderer](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1_v.cpp#L339). |
| `1400..17FF` | Existing beam-access ANK/PCG mode plus Turbo high-speed PCG selected by SCRN b5. | Derive high-speed glyph/raster address from the local `pcg_r/pcg_w`, then reconcile hardware wait logic; retain bundled-data handshake and one-write semantics. Exercise both modes, 40/80 columns, page changes, asynchronous clocks and reset. [MAME PCG](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1.cpp#L777). |
| `0E80..0E83` | Kanji low/high address latches, ROM byte reads, and rising-edge EKSEL latch. | CPU read/write sequence, EKSEL repeated-high vs rising-edge, glyph halves, bounds and authenticity. MAME's JIS conversion is marked FIXME; do not duplicate it as an authoritative encoding table. [MAME `kanji_r/w`](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1.cpp#L1173). |
| `1F80..1F8F` | Z80 DMA register stream mirrored over low nibble; real bus ownership and FDC DRQ pacing. | Register parser, memory/I/O transfer, ready polarity, count/address modes, WAIT, BUSRQ/BUSACK, reset/abort, interrupt and disk continuity. [MAME map/config](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1.cpp#L2264). |
| `1F90..1F93` | Z80 SIO BA/CD mapping. | Reset/status, pointer register writes, internal loopback RX/TX, framing, empty FIFO, IRQ/RETI before physical serial integration. No always-zero detection stub. [MAME map](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1.cpp#L1403). |
| `1FA0..1FA3`, `1FA8..1FAB` | Z80 CTC aliases from common map; 4 MHz device clock/reference CE, external triggers with explicit phase. | Vector/control/time-constant sequences, /16 and /256 timers, counter edges, zero-constant handling, channel-0 → channel-3 cascade, channel-1/2 triggers, IRQ in-service priority, RETI. [MAME CTC wiring](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1.cpp#L2193); local `rtl/legacy/z80/z80ctc*.v` are candidates requiring license/function audit. |
| `0B00` optional bank RAM | b3:0 bank number, b4 active-low bank enable, b5 latched but no mapping effect in MAME; reads masked to `3F`; reset `10`. 64 KiB bank aperture overrides IPL while enabled. | Only expose with a real allocated capacity; test banks, underlying IPL writes, DMA addressing and reset. MAME explicitly associates this with expansion boards/later models, so it is not the minimum Turbo feature. [MAME banking](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1.cpp#L1258). |
| `0700/0701`, `0704..0707` optional FM | YM2151 address/data/status plus FM-board CTC. Candidate local JT51 source; board detect only when implemented. | Busy/status, timers/IRQ, stereo routing and CPU-programmed note waveform; PSG mixing and clipping; 4 MHz CTC / 2 MHz YM reference clocks. [MAME FM config](https://github.com/mamedev/mame/blob/f4bfc5a423f48d48e809c01fc70a47c0c00d40a2/src/mame/sharp/x1.cpp#L2287). |

Defer Turbo Z `1FB0`, `1FB8..1FBF`, `1FC0..1FC5` and analog palette
interpretation of `1000..12FF`. Those cover analog enable, text/graphic palette,
capture/mosaic/chroma-key/scroll features with substantial MAME TODOs. Optional
EMM (`0Dxx`), SASI (`0FD0..3`), external SIO/CTC (`1F98..9F`) and extra disk
interfaces also require separate storage/peripheral scope. MAME's combined
Turbo/Z map is not permission to report all of them as base Turbo hardware.

## First implementable slice: experimental video foundation

After the D88/keyboard changes settle, add an opt-in experimental parameter
to the active shared machine and implement **SCRN b3/b4 plus two GRAM pages**,
**separate KVRAM at `3800..3FFF`**, and **black clip**. The main agent selected
this foundation on October 4; the paragraph describes intended behavior,
not a claim that this sidecar implemented or verified it.
This yields observable memory/video behavior without claiming 400-line mode,
new firmware, interrupts or Kanji glyph rendering. KVRAM storage/readback is
separate from authentic glyph display. A latch alone or fake Turbo signature
is not the feature. Keep unimplemented SCRN functions explicitly documented;
do not expose a UI label claiming complete Turbo compatibility.

The proposed implementation expands each `x1_video_ram #(14)` to 15 address
bits only for the Turbo profile. CPU address becomes `{access_page,a[13:0]}`;
video address becomes `{display_page,vaddr}`. Qualify SCRN writes with the
existing ordinary-I/O, reset and DAM guards. Apply CPU page selection to both
reads and all ordinary/DAM plane writes. The label `GRAM_RP` in legacy is not
a separate CPU read-page register: follow the actual MAME display/access paths.
Check Quartus BRAM cost before committing to on-chip allocation; the extra
48 KiB is a resource estimate, not a fit result.

Allocate independent 2 KiB KVRAM and split the text decode in the experimental
parameter only; test base `3800` text mirroring separately. Apply black clip in
the actual mixer with pixel-level fixtures for text color/reverse/blink,
graphic indices 0/1, priority and blanking. Retain the write-only Turbo contract
until primary evidence establishes readback; MAME's Turbo Z read function must
not be used as an experimental Turbo identification shortcut.

Carry display-page changes through a stable video-domain control transaction
or an explicitly specified synchronization scheme; avoid an unsynchronized
mode bus. Do not silently substitute a frame-boundary latch for immediate
register behavior. The initial diagnostic can change pages during blanking;
mid-scan changes require their own timing acceptance. Define and test reset
while a crossing is pending so the page returns to zero without a stale update.

Acceptance for this slice:

1. Original CPU program fills each of six page/plane combinations with a
   different pattern, reads them back, exercises `3FFF/4000` plane boundaries
   and all SCRN mirrors. RAM/page data survive warm reset, selectors return zero.
2. Actual RGB shows page 0 while CPU reads/writes page 1 and vice versa;
   compare every active pixel at both 320 and 640 widths. Verify DAM masks
   alter only selected planes on the selected access page. Restore page 0.
3. Read/write text and KVRAM independently at boundaries and through reset;
   confirm the base mirror remains. Exhaust black-clip selectors/enable bits
   against independently predicted RGB, including priority/blanking cases.
4. Test ACK, unmapped ports, reset and held strobes for accidental mode writes;
   test asynchronous system/video frequencies and repeated identical results.
5. Existing base RAM, PCG, video matrix, floppy, reset and keyboard checks pass.
   Baseline headless is the delay-aware reference; compare fast and opt-in
   single at both master frequencies. Add dependencies through `rtl/machine.qip`.
6. Build the main Quartus 17 project and record resource/timing outcomes before
   claiming FPGA feasibility. Native software/hardware evidence is a later gate.

## Follow-on dependency order and acceptance

| Stage | Implementation and dependency | Required acceptance |
|---|---|---|
| T0 | Finish current D88 safety/media cases and keyboard command/IRQ work; freeze base diagnostics and special-title negative probes. | Native base regression, unchanged media, reproducible failures/screens; do not hold Turbo synthetic diagnostics hostage to an unimplemented title. |
| T1 | Experimental foundation: two GRAM pages / SCRN b3/b4, KVRAM decode isolation and black clip. | CPU page/KVRAM readback, base text mirror, independently selected actual RGB and exhaustive clip pixels. |
| T2 | Remaining digital video: 15/24 kHz timing, raster repeat, 8/16-raster text/ANK, black clip, underline and high-speed PCG; add KVRAM/glyph ROMs. | CPU programs explicit CRTC values; measure line/frame periods and active dimensions, check every pixel, glyph halves, reverse/blink/width/height and each priority bit. Four SCRN b1:b0 combinations must be investigated separately: MAME enables its `v400_mode` only for `11`; `01` is explicitly not complete. Never implement all 400-line modes by just scaling PPM output. |
| T3 | CTC and shared interrupt arbitration before SIO/DMA IRQs. | Original IM2 vector fixture with simultaneous requests, masked requests, in-service blocking, nested priority, ACK and RETI; keyboard must still recover. Resolve physical priority from schematic/second source because MAME and legacy disagree. Clock CTC from enables, not a new fabric clock. |
| T4 | DMA register engine, CPU wrapper BUSRQ/BUSACK exposure, shared memory/I/O arbiter, FDC DRQ ready. | Memory copy then read-only native disk DMA; stalled WAIT/host ACK, stopped CPU enables, warm reset during bus ownership and pending SD ACK; exact byte/count/CRC assertions. FDC DRQ enters DMA ready, not an invented base CPU IRQ. |
| T5 | SIO then optional YM2151/CTC board; optional bank RAM only with capacity/provenance. | Serial loopback and interrupt sequence; FM WAV/timer tests; RAM bank isolation and overlay tests. Serial connectors/audio hardware remain separate. |
| T6 | Authentic Turbo IPL + fonts, disk-set support and commercial acceptance. | Native cold boot, visible title, actual control response and repeatability, disk changes/protection as required. Validate delay-aware baseline, chosen clock profile, main Quartus build and coordinated MiSTer test separately. |

### Authentic 400-line clock gate

The locally inspected MAME board inventory lists X3 at **42.9545 MHz**, and
its `VDP_CLOCK` is `42.954545 MHz` (`x1.cpp:185,208`); it is not the current
28.636 MHz-intended / 28.571428 MHz-actual core clock. This oscillator is also
visible on **PDF page 3, lower edge**, of the original Turbo schematic,
beside the mode-dependent divider/multiplexer chain. Legacy
`rtl/legacy/x1_vid.v:185..188` even annotates both divider chains:
28.63636/2 = 14.31818 versus 42.95454/2 = 21.47727 MHz, down through
1.7897725 versus 2.68465875 MHz. This is evidence to investigate the oscillator
and divider/mode multiplexing, not proof that replacing the PLL with 42.9545 MHz
globally produces correct Turbo timing. MAME itself labels its CRTC divider
unknown (`x1.cpp:2222`) and changes clock via the width-control port, so do not
copy its clock setup uncritically.

Before enabling SCRN b0/b1, trace the remaining clock-generator/video schematic
sheets, establish low/high-resolution divisors and mode-switch phase/reset,
and specify CPU/PSG/sub-CPU rates separately. Then produce native 400-active-line
RGB with CPU-programmed CRTC values and measured HS/VS periods; independently
check repeated-raster and true high-resolution addressing. Doubling captured
rows, changing only CRTC totals, or running the existing renderer faster is
insufficient. Prefer a validated clock/enable architecture with Quartus clock
constraints and a source-bound build; preserve the existing base frequency and
single-clock timer contract until the new profile is explicitly selected.

Concrete next clock architecture: retain baseline `clk_sys=32 MHz` for CPU,
PSG, sub-CPU and SD transport; provide a separately constrained Turbo video
master from a reviewed PLL output near 42.954545 MHz. Extend the simulator
scheduler to drive that master independently and record its actual frequency.
Derive pixel/character strobes from that master, with the schematic's
mode/40-column selection explicitly modeled. As arithmetic candidates to
validate against the divider netlist, master/3 gives 14.318182 MHz low-resolution
dots and master/2 gives 21.477273 MHz high-resolution dots; /24 and /16 give
the corresponding 8-dot character rates, with a further /2 in 40-column mode.
These ratios are inferred design candidates, not a completed schematic audit.
Specify fractional/phase behavior explicitly if any enable is synthesized;
average frequency alone cannot validate line-edge timing.

Keep the CPU-to-video RAM/control/PCG bridge and review all timing constraints
for the new ratio. The existing single-clock experiment cannot silently inherit
42.954545 MHz: its CPU/PSG fractional enables, MR16 timer/instruction rate,
reset counters and host transport must be requalified with that master first.
Use an original CRTC program to measure HS/VS, pixel/character strobes and
address sequences through all b1:b0 modes and width switches. Scope native
24 kHz outputs separately from MiSTer scandoubling/scaler output. A revised
PLL and positive constrained timing still need coordinated physical output
acceptance; neither a boot screenshot nor resampled rows closes this gate.

### Follow-up video audit: T2 contracts, graphics addressing now implemented

The October 4 read-only audit visually examined enlarged schematic pages 2/3
and inspected local MAME/X Millennium. Page 3's X3 is 42.95454 MHz, feeding
IC17 inversion, coupled IC6 JK stages, IC9 width-dependent preset/clear,
IC22/IC1 gating, IC33 mode selection and the IC7/IC8/IC18-to-IC19 divider path.
MIX1/MIX3 enter this network. This supports a shared video oscillator rather
than independently selected low/high PLLs, but the complete gate truth table,
edge sequence and live-switch/reset phase are **not** yet transcribed.

Exact nominal arithmetic from the printed crystal value:

| Proposed steady mode | Dot rate | 80-column character rate | 40-column character rate |
|---|---:|---:|---:|
| Low scan | X3/3 = 14.318180 MHz | X3/24 = 1.7897725 MHz | X3/48 = 0.89488625 MHz |
| High scan | X3/2 = 21.477270 MHz | X3/16 = 2.68465875 MHz | X3/32 = 1.342329375 MHz |

These agree with inherited annotations, not measured oscillator tolerance or
electrical equivalence. Preserve the earlier independently constrained Turbo
video-master proposal and use enables *inside* that domain. A later unified
machine master needs CPU/CTC/PSG/MR16/transport requalification; it is not a
silent replacement of the current single profile.

Arcus's stored CRTC table is `6B 50 59 88 1B 00 19 1A 00 0F 00 00 00 00`:
108 characters/line, 448 total rasters, 80x25 characters with 16 rasters each.
At the proposed high-scan 80-column rate it predicts **40.2285765 us HS period**
and **18.0224023 ms VS period** (about 24.858 kHz / 55.4865 Hz). Its eight-character
horizontal sync is 2.9798946 us. The observed 60.468750 us / 27.095031250 ms
capture is consistent with the existing low-rate master, not correct high scan.
The CRTC's exact vertical-width/HD46505 behavior remains independently testable.

Separate GRAM raster, text MA and glyph-row paths before T2. At the audit,
graphics wiring always used `{SCRN[3], RA[2:0], MA[10:0]}` and repeated RA0 at
RA8. X Millennium provides this **proposed**, ASIC-review-gated display mapping:

| SCRN b1:b0 | Display page | Plane offset |
|---|---|---|
| 00 | b3 | `{RA[2:0], MA[10:0]}` |
| 10 | b3 | Same low-scan mapping in X Millennium; distinct b1 hardware effect unresolved |
| 11 | b3 | `{RA[3:1], MA[10:0]}`: adjacent graphics lines repeat |
| 01 | RA0 | `{RA[3:1], MA[10:0]}`: even/odd physical lines alternate pages |

The subsequent graphics-only increment implements this mapping; see
`TURBO_RASTER_STATUS.md`. Further inspection of `width80x25_400h` resolves
X Millennium's mode-01 precedence: it directly uses fixed BANK0/BANK1 rather
than b3-swapped `disp1/disp2`. Clock/font and hardware gates remain open.

Page 2 supports investigating raster-controlled banking, not the complete
ASIC selection truth table. Hardware b3 precedence in mode 01 still needs
confirmation independently of the inspected emulator. CPU/DAM access remains
`{SCRN[4], port[13:0]}` in every mode.
MAME does not correctly model the independent-page 01 path. See local
`references/emulators/xmil-libretro/vram/make24.c` for the even/odd page reads.

Font-control disagreement must be settled separately: MAME labels b2 as an
8/16 ANK selection; X Millennium and inherited `x1t_mode.v` instead identify
b2 with text-height expansion and b6 with CPU font selection. Do not turn b2
into a ROM-bank selector just from MAME's comment. X Millennium's high-scan
path uses distinct 16-row ANK, repeated ordinary eight-row PCG, and paired
even/adjacent PCG glyphs when KVRAM `&90` is nonzero. Stored KVRAM is currently
tied out of the renderer, and the active glyph address has only three row bits.
Kanji half/bank ROM mapping also differs between references. High-speed PCG's
selector fallback is 3FF in MAME versus 7FF in X Millennium; neither is yet a
hardware-approved shortcut for the existing bundled transaction.

Acceptance must cover all four SCRN modes and both widths: exact enable
intervals/phase; coherent live mode/width switches; plane/page/raster patterns
at RA7/8/15/16 and MA wrap; independent CPU bank/DAM; unique 8/16 ANK/PCG/Kanji
rows; paired-glyph bounds; frozen PCG selection/single writes with asynchronous
clocks and pending reset. Check Arcus totals within quantization/one observation
clock, preserve base video and CTC acceptance, then bind Quartus constraints/CDC
and physical native video measurements. Scaler output cannot close native timing.

### DMA / CTC / SIO architecture

The first CTC/IRQ increment is now implemented and simulation-tested; see
[source, schematic decisions and acceptance](CTC_STATUS.md). Schematic pages
1/5 support CTC above keyboard (after future SIO/DMA), not MAME's keyboard-first
order. The new bridge has no keyboard service latch. ASIC alias decode and
exact physical phase remain unresolved. T3 has focused unit/CPU acceptance,
not complete hardware/native-software acceptance; T2/T4/T5/T6 remain open.

The [CPU ownership seam](CPU_BUSREQ_AUDIT.md) now exports active-low
BUSRQ/BUSACK through `rtl/cpu.v`; its real-wrapper unit passes WAIT, sparse/
stopped enables, release, continuation and reset. The shared machine still
ties BUSRQ inactive. Introduce a shared ordinary memory/I/O bus owner mux
and actual DMA engine before DMA can drive a transaction.
The active machine currently ties MR16 DMA inactive; the inherited refresh
hack is not the proposed implementation. Keep arbitration in `clk_sys` with
qualified enables, hold address/data/strobes through WAIT and complete only
one transaction per request. DMA must use the same IPL/banked-memory and
GRAM/DAM decode as CPU cycles, while interrupt ACK is a distinct cycle.
First prove a diagnostic memory copy; then pace `0FFB` data-register transfers
with FDC DRQ. Local MAME inverts FDC DRQ in `fdc_drq_w`, so ready polarity must
be tested together with the chosen DMA engine's programmable polarity.
Cover final count, restart, search/match if supported, bus release, pending
interrupt and resets with outstanding SD transport. Never stop host ACK draining
just because CPU/DMA/FDC enables stopped.

Additional [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf)
audit: printed pages 75–78 and 89–92 make programmed block length a terminal
count, not a byte count: sequential transfer length N transfers N+1 bytes.
Source/destination terminal address counters differ. Add tests for N=0/1/65535,
fixed/increment/decrement ports and readback after stop. Bus request requires
enable plus Ready (or Force Ready); byte/burst/continuous release conditions
are distinct. Test Ready loss during each bus phase and programmable WAIT
before native FDC transfers. These details are not yet implemented in this core.

Make CTC channel state and interrupt pending/in-service state explicit. A
shared daisy arbiter must provide the selected IM2 vector only during M1/IORQ,
block lower-priority requests while a device is in service, and release on a
decoded RETI. Audit physical IEI/IEO wiring across PDF pages 1 and 5 before
choosing inter-chip priority; preserve sub-CPU keyboard behavior as a mandatory
regression. Run the CTC clock with a 4 MHz enable independently of video mode;
derive external counter triggers/phase from the audited schematic. Compare
candidate local legacy CTC source variants before reuse and preserve notices.

Add SIO register/FIFO/serial timing and IRQ state behind the same arbiter after
CTC works. Establish BA/CD address order from `1F90..93`, independently program
both channels, and use an internal serial loopback fixture before promising
RS-232 hardware. Test RX/TX interrupt coexistence with CTC, keyboard and DMA.
Idle input levels, CTS/DCD behavior, FIFO overrun and reset values must be
specified; an inert port that passes software detection is not SIO support.
Consult original chip manuals for register-stream details before coding each
engine; the machine schematic and MAME integration establish wiring only.

### Drive B / disk-set dependency

The experimental Arcus cold checkpoint reaches a driver routine at `F9B0`
that reads `0FF8` and loops while status `81` bits are set. Its saved script
pointer/stack identify an earlier `0FFC=81` selection (drive B, motor on).
At that checkpoint only drive A had media support. Bounded traces subsequently
confirmed the initialization dependency, not a reason to report an empty drive
as ready. The October 5 [two-image increment](DUAL_DISK_STATUS.md) implements
serialized A/B rescans, separate head/motor state and ACK-drained ownership;
generated tests pass, but the acceptance steps below remain wider than that
increment's software/mechanical/hardware coverage.
The resulting black 640x400 capture is not title or video-mode acceptance.

Next storage increment, before claiming Arcus/disk-set compatibility:

1. Confirm selected drive, motor and effective ready together with repeated
   status reads. The runner now exposes these in bounded event CSVs; retain
   native RAM/CPU dumps and unchanged-media hashes alongside the trace.
2. Add two independently mounted image descriptors and host channels to the
   wrapper/runner, including per-drive size/read-only/mount generations. Keep
   **one controller register/IRQ/DRQ state machine**, not two pretend FDCs.
   `disk_index` selects concatenated volumes and is not a physical-drive ID.
3. Specify per-drive head position, motor hold and index behavior. Preserve
   the shared WD track register separately from physical heads; selecting a
   drive must not manufacture a seek or erase the other head's position.
4. Make scanner/index metadata drive-specific, or serialize rescans with a
   documented not-ready interval. Latch host-request drive/generation through
   ACK drain so a pending A request cannot read or write B. Accepted writes
   remain associated with their original image; no speculative cancellation.
5. Test A/B with deliberately different original sector patterns and head
   positions: read/write protection, alternating seeks, empty/ejected B,
   malformed B, replacement during pending A/B I/O, CE-stopped ACK/reset and
   retention. No two-drive support claim until these pass through the shared
   CPU/FDC/transport path. Review selection-during-command behavior against
   the original controller before calling its timing hardware-equivalent.
6. Mount the staged Arcus disks explicitly in their documented A/B order,
   start fresh native IPL, inspect actual title/controls and required disk
   changes, then repeat with unchanged originals. Do not patch the game or
   mirror Disk 1 into both drives merely to pass a ready check. Authentic
   Turbo IPL, 400-line/glyph rendering and DMA may still be independent gates.

### High-speed PCG remains a separate increment

SCRN b5 needs more than direct low-port addressing. Local MAME
`check_pcg_addr/check_chr_addr` inspect attribute bit 5 at `7FF`, `3FF`, `5FF`,
then `1FF`, using PCG/non-PCG selection respectively and a `3FF` fallback.
High-speed PCG writes select the text glyph there and raster `(port & 0E) >> 1`;
high-speed `1400` reads select Kanji using text/KVRAM, glyph bank and half.
MAME's PCG read/write handling is not symmetric and has known timing issues.
Before implementation, validate the selection order/fallback, frozen selected
glyph during a transaction, read behavior and wait timing from hardware
documentation. Test competing selector attributes, all four candidate cells,
fallback, port raster bits and reset with a pending crossing. Preserve the
current beam transaction's data stability and single-write behavior. The first
foundation must leave b5 unimplemented rather than claim high-speed PCG support.

Before T2, inspect the remaining Turbo schematic sheets at usable resolution
and OCR/translate the relevant manual pages; obtain register-level primary
evidence for mode timing/readback and chip interrupt/clock wiring. The scan
inspection here establishes chip presence and signal names, not all bit timing.
In particular the inherited 28.571428 MHz PLL differs from intended 28.636 MHz;
record actual frequencies. The single model's MR16 instruction clock remains
slower even with timer compensation. Neither issue is solved by Turbo decode.

## Private title probes and evidence gates

The user supplied `software/Sharp X1/Arcus (Wolf Team)/Arcus (X1turbo) [FD].7z`
(five disks) and `software/Sharp X1/Bastard Special (Xain Soft)/Bastard Special [FD].7z`
(one disk). `scripts/stage_special_titles.py` preserves source/member bytes in
ignored `software/special-unpacked/`, with hashes and safe names following
`stage_top32.py`. No commercial downloads or media patches are required.

Run from the repository root, then from `verilator/`:

```sh
python3 scripts/stage_special_titles.py
cd verilator
python3 tests/probe_special_titles.py ./obj_dir_fast/Vtop arcus \
  --seconds 16 --output obj_dir_fast/special-probes/arcus-new-build
python3 tests/probe_special_titles.py ./obj_dir_fast/Vtop bastard-special \
  --seconds 16 --output obj_dir_fast/special-probes/bastard-new-build
```

Each invocation creates a new directory, freezes/hashes its executable, and
runs two cold native IPL loads with the same disk and PS/2 script. It records
commands, clock/reset counters, disk request/write counters, actual PPM,
main/text/attribute/sub-CPU RAM and CPU registers. An optional I/O trace can
identify attempted Turbo ports. Raw traces contain repeated clock samples;
`--bus-events` instead retains the final sample of each contiguous held
transaction. Use `--bus-start-ms`/`--bus-end-ms` with `--io-trace` for a bounded
half-open observation window and manageable CSV sizes.
Inputs must match the staging manifest and remain
unchanged. `--cycles` is always 32 MHz reference duration, including for single.
Runner errors/media preflight rejection are retained and reported as failures.
PASS establishes probe determinism, not title boot or compatibility.

Use `--keys tests/commercial_enter.keys` or another recorded script only as a
separate trial with a new output directory. A shipped F/Space probe is a common
boot attempt, not a confirmed control scheme for either title. Stage all Arcus
disks but initially mount only Disk 1; no disk-change/drive-B claim is implied.
Do not count either title as playable until native title/gameplay and actual
input effects have been inspected and their release-specific checks added.
Observed current results belong in [the compatibility matrix](COMMERCIAL_COMPATIBILITY.md).

## Local Turbo BIOS inventory (no loader changes)

Read-only inventory on October 4, 2026 of six user-supplied archives under
`software/Sharp X1/`. Only archive/member names, byte sizes and SHA-256 were
examined; no ROM was installed, booted, converted, committed or downloaded.
Archive names identify candidates, not verified model identities or permission
to redistribute. The generic Turbo Z label sharing the generic Turbo IPL is
especially not independent evidence of a Turbo Z firmware dump.

Reproduce the complete archive-to-member mapping and full hashes:

```sh
python3 scripts/inventory_turbo_bios.py
```

The script uses the bounded `stage_top32.members` reader, verifies archives
remain unchanged, and prints JSON without writing firmware or staging ROMs.
The archive-size values include any trailer bytes. Each member is decompressed
in memory and hashed as supplied, with no normalization.

| Archive under `software/Sharp X1/` | Archive bytes | Archive SHA-256 |
|---|---:|---|
| `[BIOS] X1turbo (Sharp)/[BIOS] X1turbo [ROM] [Set 1].7z` | 80081 | `80508a466ca76d6e825e8c90d5623a77c1a0588fd9790a7b10880e3ed34db17a` |
| `[BIOS] X1turbo (Sharp)/[BIOS] X1turbo [ROM] [Set 2].7z` | 85876 | `cab67c8e20c9539114dbb98a2d66810e3a72c0d4342d97463e55679f254ed096` |
| `[BIOS] X1turbo (Sharp)/[BIOS] X1turbo [ROM].7z` | 86555 | `320319a7f0c506f57350203d3cd6aa6ebfcc0c3705f4fd3bd1fc2b0f97c84451` |
| `[BIOS] X1turbo model40 (CZ-862C) (Sharp)/[BIOS] X1turbo model40 (CZ-862C) [ROM].7z` | 79834 | `c2449695642e0a914fdabc834a4feb8af90ac2d7a04a163db31432ad8176ec78` |
| `[BIOS] X1turboZ (CZ-880C) (Sharp)/[BIOS] X1turboZ (CZ-880C) [ROM].7z` | 149090 | `01d426ecbdc5f0b48e075d586564b9d3c588f7c66f3b9626b30eca1fd3e0f9d1` |
| `[BIOS] X1turboZ (CZ-880C) (Sharp)/[BIOS] X1turboZ (CZ-880C) [extras].7z` | 542 | `accca228dc548431b74936064a037e34a9f3758ee8f86599a6a95bbfffa8c1cd` |

Repeated identical member bytes are grouped below. “ROM” means the generic
Turbo archive without a set suffix; “Z” means the Turbo Z ROM archive.

| Exact member names / archives containing them | Bytes | Member SHA-256 |
|---|---:|---|
| `ipl.bin` / model40 | 32768 | `f781919f05a119976d6b8b73ca797052f06034631624d8328da46e38be103841` |
| `ipl.x1t` / Set 1; `IPLROM.x1t` / Set 2, ROM, Z | 32768 | `212895703175665be8544daa55b65da1aebcf1e9a2db65bcc1622e564b802b71` |
| `IPLROM.x1` / ROM | 4096 | `e6295a523008688421991b651ab61de392b28c67bec9efbf040b0004e4b70a2a` |
| `kanji1.rom` / Set 1, model40 | 32768 | `c66097b57050e8811e08c4a8ce065677155d55d7d9a21c34190c7c1952a5aec4` |
| `kanji2.rom` / Set 1, model40 | 32768 | `301dcafd242e7bd53a6e8d0ad3bd742685a7161a74877cb3ee62374bea75a977` |
| `kanji3.rom` / Set 1, model40 | 32768 | `90bdcb5f1fa08afcec47229b85932f7aa344018f67aba35268abc6d4a89bb362` |
| `kanji4.rom` / Set 1, model40 | 32768 | `9b8794db08a82fb0be7091db69a7869e7b06ce8e1c59a4725c7af491cce94205` |
| `fnt0808_turbo.x1` / Set 1, model40; `FNT0808.x1` / Set 2, ROM, Z | 2048 | `2ce875255d64002589831e68825fbb36b7827be538dd030ffabb907b3c07610b` |
| `FNT0816.x1` / Set 2 | 4096 | `e356dd1992708d2bdf03d4029ba07a8177158e1cb0eac145f881ed8dcdae35d8` |
| `FNT0816.x1` / ROM, Z | 4096 | `1030eb93743a7b7a5c1fce3d6effde7772d408ca5ade99e8fa1a77af1178030c` |
| `FNT1616.x1` / Set 2, Z | 306176 | `40c080b7ad381050fe9f8d8063985a2648785ef470e397fbeb3d606a9774fc48` |
| `FNT1616.x1` / ROM | 306176 | `bb40a2bf549d73946d1c53050daee4e8c27f9cd8486890568064a3633ba7e953` |
| `KANJI2.rom` / Z | 306176 | `56e4318a9ac99aca52022222b41119712e05877b1b65ed369abec431b92e7aa1` |
| `[BIOS] X1turboZ (CZ-880C) (readme).txt` / Z extras | 572 | `a8e74823425408cc001842446f92e4da3684888f3a6f4c36b971213e92bbde93` |

The 32 KiB model40 IPL is a candidate for authentic Turbo firmware acceptance.
The earlier active 4 KiB IPL bound required separate machine/loader work; the
main agent now reports a synthetic 32 KiB mapping/protection test, which does
not establish a native boot of this supplied image. Large font-container layouts also require an independently
specified mapping; size/name alone does not establish the glyph address order.
