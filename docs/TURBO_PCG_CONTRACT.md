# Turbo high-speed PCG contract and hardware evidence

October 5, 2026. A bounded read-only schematic/manual/source audit, followed
by creation of this document only. No RTL changes, native probes, emulator
execution, tool installation, synthesis or hardware measurements were made.
This is an implementable **proposed functional contract with open hardware
gates**, not proof of the ASIC truth table or silicon timing.

## Sources and scope

- Primary: local [CZ851/852 model 20/30 schematic](../references/manuals/CZ851_2C_Schematic.pdf),
  SHA-256 `8784414a3aaa25e15b4afb3662967c395c3abd6b4204ab818c7b18ed07c33f5c`.
  PDF pages 1, 2, 3, 4 and 5 were rendered. Pages 2/3 and the page-5 WAIT
  merge were inspected with enlarged crops. The numbering below is PDF
  **1-based**, not circuit-sheet numbering: PDF 2 is MAIN board 2/3,
  PDF 3 MAIN board 3/3, PDF 5 SUB board 2/2.
- Primary feature description: local [Turbo II user manual](../references/manuals/CZ-856C_UsersManual.pdf),
  SHA-256 `ae2f807aaeefcf9993cc705b7ea24015b121d976048ed9f65e2f0f15b37228ac`.
  PDF 89–91 (printed 78–80) were visually read. These describe text
  expansion, ROM/RAM CG, definition of 256 eight-by-eight RAM characters and
  underline. They do **not** establish high-speed selector addresses or WAIT
  phases. This is a later model's user manual, not a Turbo ASIC specification.
- Local MAME, commit `f4bfc5a423f48d48e809c01fc70a47c0c00d40a2`:
  `../FM-7_MiSTer_alanswx/refs/mame/src/mame/sharp/x1.cpp`,
  `check_pcg_addr`, `check_chr_addr`, `pcg_r`, `pcg_w`, near lines 813–921.
- Local X Millennium libretro checkout, commit
  `b07506c0cae31d260db28cb079148857d6ca2e93`:
  `references/emulators/xmil-libretro/io/pcg.c` (read through CP932-to-UTF-8
  conversion), `io/crtc.h`, `font/font.h`. No emulator was run.
- Active shared machine: [bridge](../rtl/x1_pcg_access.v),
  [font storage](../rtl/x1_font16.sv), [dual-clock RAM](../rtl/x1_video_ram.v),
  [integration](../rtl/sharpx1.v). Inherited reference:
  `rtl/sharpx1_legacy.v` and `rtl/legacy/x1_vid.v`.

No font, firmware or game bytes are copied into this document. RAM/ROM byte
address formulas describe the interface, not a redistributable asset layout.

## Primary net trace: what is actually visible

| Path | Traced connectivity | What it establishes / does not establish |
|---|---|---|
| Text address, PDF 2 | CRTC IC52 MA outputs feed the video-address side of MB74LS257 muxes IC66/IC53/IC67. CPU AB0–AB10 feed the other side. AMA0–AMA10 outputs feed attribute IC82, Kanji attribute IC84 and character IC83 RAM address pins. | Shared physical cell addressing, with CPU/video multiplexing. No external four-entry priority encoder is shown. This trace does not establish a forced blanking address or fallback. |
| Text/attribute capture, PDF 2 | Character RAM feeds IC109 LS373; character data is also buffered/latching through IC95/IC107 to DCHA0–DCHA7. Attribute RAM passes through IC108 and IC94/IC93 to DATT signals; Kanji RAM passes through IC85 and IC96/IC81 to DKAN signals. | Registered character/attribute/Kanji information is available to downstream video logic. Metadata must not be treated as asynchronous live RAM outputs in the FPGA bridge. |
| CG address ASIC, PDF 3 | IC30 IX0522CE receives RA0–RA4, AM0–AM3, MA10, AB0–AB3, DISP timing, H/V sync, 8/16, 200/400, DATT3, DATT6, DKAN7 and compatibility/high-speed control FPCG.CE. It outputs C1Y–C4Y, K1Y–K4Y, PCG WAIT, and FPCG-related controls. | CPU low-nibble and raster/attribute inputs reach the real address-selection logic. **IC30 is opaque**: selector order, fallback, paired condition and exact address/wait truth tables are not exposed. |
| PCG plane addresses, PDF 3 | IC80/IC79/IC78 MB8416A RAM A4–A10 receive DCHA1–DCHA7; A0–A3 receive C1Y–C4Y. RAMs have separate CWA/CWB/CWC write controls and data paths through IC65/IC64/IC63. | Exactly 11 address bits per plane. The physical form is `{DCHA[7:1], C4Y,C3Y,C2Y,C1Y}`: eight-row glyph addressing and even/adjacent sixteen-row pairing fit the same 2 KiB plane. The ASIC determines C4Y's role; wiring alone does not prove KVRAM `&90` selects it. |
| Character ROM, PDF 3 | IC177 HN61364 receives DCHA character bits and a distinct four-bit row path; its ROM enable/data path is separate from PCG RAM writes. | ROM and RAM are distinct resources; CPU FONT16 selection is not permission to write ROM. The extra ROM selection/address logic and asset normalization are not fully resolved here. |
| Kanji ROM, PDF 3 | IC103–IC106 MB83256 receive DCHA0–DCHA7 and DKAN0–DKAN2 plus K1Y–K4Y. External IC92/IC91 and DKAN control lines participate in ROM/half selection. | Real bank/half decoding exists outside the basic ANK path. This is more than substituting an ANK array. The full chip-select/normalized-font mapping was not transcribed; do not claim either emulator layout is silicon-proven. |
| PCG write strobes, PDF 3 | CHAR RAM A/B/C selects, IOWE, FPCG/timing control and external IC47/IC60/IC91 gates feed the individual RAM WE nets. | Per-plane writes are physically qualified. A single held CPU write must not become repeated writes as raster/selector changes. The complete gate timing equation was not derived. |
| CPU WAIT return, PDFs 3/5 | IC30 PCG WAIT, pin 14, goes to connector T-26. PDF 5 calls the T-26 input PLG WAIT (net 87); it enters IC47 LS21 pin 13, with V WAIT and EXWAIT/other local wait inputs at the remaining pins. The combined output returns to CPU IC18 WAIT pin 24. | There is a real hardware WAIT route, distinct from transport latency. Connector identity links PCG WAIT to the CPU wait combiner despite the label variation. ASIC assertion/release polarity and edge phase are still unresolved. |

This is a partial **net-connectivity audit**, not merely a list of sampled
chip labels. It does not include a complete gate-level netlist, propagation
delay calculation, ASIC reverse engineering, or oscilloscope proof.
Temporary enlarged evidence crops were rendered under `/tmp/x1-pcg-*`;
they are not tracked documentation assets.

## Secondary behavior: agreements and disagreements

Both emulators prioritize candidate text cells in this order:
`7FF`, `3FF`, `5FF`, `1FF`. PCG selects the first candidate whose attribute
bit 5 is **set**; ROM/character reads select the first whose bit 5 is
**clear**. These selectors are distinct and can choose different cells.
MAME falls back to `3FF`; X Millennium falls back to `7FF`. For PCG fallback
all four bits are clear; for character fallback all four are set. Neither
fallback is resolved by the visible schematic. Preserve this as a named,
tested policy rather than burying a magic address in the bridge.

| Operation in high-speed mode | MAME | X Millennium | Proposed bounded policy |
|---|---|---|---|
| PCG writes | Selected PCG glyph, row `(port & 0E)>>1`. | Selected PCG glyph; ordinary row `nibble>>1`; if KVRAM `&90` is nonzero, even glyph plus full nibble. | X Millennium paired/ordinary rule; mark paired-condition hardware gate open. |
| PCG reads | Still beam-addressed, not symmetric with high-speed writes. | Same high-speed selected glyph/row logic as writes. | Symmetric read/write selected address; do not claim MAME equivalence. |
| `14xx` ROM reads | Always Kanji in high-speed mode, regardless of KVRAM Kanji enable. | KVRAM b7: Kanji; otherwise SCRN b6: 16-row ANK; otherwise 8-row ANK with nibble divided by two. | Explicit Kanji/ANK16/ANK8 dispatch; without Kanji assets/backend, report that branch unimplemented. |
| Wait | No equivalent explicit scanline stall in these handlers. | `waithsync()` charges time to the raster-display end before high-speed access. | Safe synchronized horizontal-access window plus transaction completion; exact phase must remain provisional. |

The inherited reference is not a third primary proof: it forces text address
`7FF` while high-speed mode and display timing is inactive, then switches
glyph row to CPU A3:A1 around `crtc_hsync | hsync_d`. Its WAIT equation stalls
when high-speed CG is selected and HSYNC is not asserted. It neither models
the four-entry attribute priority nor resolves fallback. The active renderer
does not acquire Turbo behavior merely because this legacy code exists.

SCRN b5=high-speed and b6=CPU font selection are supported by X Millennium
and inherited mode decoding; physical control labels fit that division but
the exact latch encoding is not proven by this net trace. MAME's separate b2
ANK-selection field must not silently replace CPU b6. Scan rate b0 and CPU
font selection b6 are independent: **CPU FONT16 must not depend on high scan**.

## Implementable byte-address contract

This section defines a proposed, explicitly gated functional increment.
Let `p=port[9:8]`, `n=port[3:0]`, `T` be the selected text byte,
`K` its KVRAM byte, and `paired=((K & 90h)!=0)`. CPU access decode is
`1400..17FF`; do not confuse candidate text-cell address with glyph-byte
address. PCG has three separate 2 KiB planes, not a 16-row array per plane.

| Access | Selected cell | Byte address / action |
|---|---|---|
| Compatible mode read/write | Existing frozen beam glyph/row | Retain baseline behavior and current CDC semantics. Low port bits do not become direct glyph addressing in this mode. |
| High-speed PCG, p=1/2/3, ordinary | First PCG-marked candidate | Per-plane offset `(T<<3) + (n>>1)`. Port bit 0 aliases the same row; bits 7:4 alias. |
| High-speed PCG, p=1/2/3, paired | First PCG-marked candidate | Per-plane offset `((T & FEh)<<3) + n`. Row 8 selects the adjacent odd glyph; row 15 stays within 7FF even when T=FF. Same address for even/odd T in a pair. |
| High-speed ROM, p=0, K b7 clear, SCRN b6 clear | First non-PCG candidate | ANK8 offset `(T<<3) + (n>>1)`. |
| High-speed ROM, p=0, K b7 clear, SCRN b6 set | First non-PCG candidate | ANK16 offset `(T<<4) + n`, all 4096 bytes accessible. |
| High-speed ROM, p=0, K b7 set | First non-PCG candidate | Kanji half/bank read only; logical layout must be explicitly declared, as below. |
| Any p=0 write | No writable font target | Ignore write with normal bounded completion; do not mutate ANK8, uploaded ANK16, Kanji or PCG. |

For a contiguous diagnostic array, a combined PCG offset adds `(p-1)*800h`;
the actual RTL's independent RAMs use the 11-bit per-plane address only.
Test K=00,10,80,90 separately: `&90 != 0` means **either bit**, not both.
For p=0 Kanji dispatch tests b7 only; b4 alone does not select Kanji.
K b6 is half selection for Kanji, not CPU FONT16 selection.

Do not normalize Kanji assets by guessing. MAME uses
`(((T + (K<<8)) & FFFh)<<5) + n + ((K & 40h)>>2)`, with halves interleaved
in 32-byte glyphs and four bank bits. X Millennium uses
`((((K & 1Fh)<<8) + T)<<4) + n`, plus `20000h` for K b6, with separated
halves and five bank bits. These formulas disagree in both capacity and
layout. Synthetic ROMs can test a chosen backend without claiming real-font
correctness; a real Kanji loader needs documented provenance, size, ordering
and full primary bank/chip-select reconciliation.

### Selector acceptance independent of fallback

Use four distinct text codes/KVRAM values at the candidate cells, with all
other cells containing unrelated sentinels. Exhaust all sixteen patterns of
attribute b5: PCG selector picks the first set bit; character selector picks
the first clear bit. Assert the two selectors independently, including
patterns where they intentionally choose different cells. Vary other
attribute bits without changing the result. Separately test the two
no-eligible-candidate cases against the explicitly selected provisional
fallback. Priority agreement between emulators is useful implementation
evidence, **not primary hardware resolution**.

## Resource-safe integration and CPU font read

The current bridge accepts plane/write/data only, then freezes `beam_addr`
in the video domain. It has no low port nibble, SCRN mode or selected
text/KVRAM metadata. `x1_font16` only connects its video read output; its
CPU port is used for upload and leaves `cpu_q` unused. No current CPU
FONT16 read path exists. Existing KVRAM storage alone does not implement one.

Recommended architecture, without adding full memory replicas:

1. Keep the existing display RAM read ports. Maintain a CPU-domain shadow of
   the four candidate cells' text/attribute/KVRAM bytes (12 bytes total),
   updated from **the same accepted writes/address aliases** as the real RAM.
   Alternatively arbitrate an existing read port with bounded latency;
   do not infer a third port on each 2 KiB RAM just to inspect selectors.
   Shadow reset/uninitialized values must agree with real RAM semantics:
   resetting only the shadow while warm reset retains RAM is incorrect.
2. Capture mode, p, n, selected cell, T/K, computed byte address, data and
   read/write type as one transaction. Hold the bundle until acknowledgement;
   live beam, selector writes, SCRN changes or future DMA ownership must not
   retarget an accepted access. Specify whether metadata is captured at CPU
   request acceptance or at the synchronized access window; test that choice.
3. Preserve video-domain PCG access staging and one-edge write pulses. Qualify
   high-speed servicing with a video-domain horizontal-access window; latch
   a window opportunity rather than requiring a long CDC roundtrip to fit
   within one short pulse. Return WAIT until both the chosen window and the
   memory response are satisfied. Compatibility mode keeps existing behavior.
4. Reuse `x1_font16`'s existing CPU RAM port: mux its address between upload
   address and the frozen CPU-font address; only the upload path asserts WE.
   Connect its already available `cpu_q` to a registered read response.
   Display remains on the independent video port. There is no need for a
   second 4096-byte font or combinational ROM read mux across all bytes.
5. Keep unconditional registered reads in `x1_video_ram`; gate availability
   **after** RAM. Font readiness already has a CPU-domain `loaded` flag;
   qualify the CPU response after its one-cycle read latency. Upload takes
   priority and holds the machine reset in the existing loader workflow;
   define collision behavior if that assumption is ever relaxed. Incomplete,
   out-of-order, missing font loads remain blank, never substitute private
   embedded font bytes. Warm reset retains storage/readiness.
6. Do not feed a sys-clock font result directly into a video-clock response
   latch without a return handshake or stable bundled response. A CPU-side
   font completion path can share request ownership while avoiding a third
   font port. Once any valid response is acknowledged, hold it for the
   stretched CPU read and prevent duplicate requests.

Previous font read gating mapped 32K storage bits into flip-flops in Quartus
17; preserving the unconditional registered-read pattern is a resource
requirement, not a coding preference. Any future fit must verify memory
inference/resource counts; no such fit is part of this audit.

## Original fixture matrix and timing limits

Use generated font/PCG patterns with distinct character/row/plane bytes;
never copyrighted font or game bytes. These are proposed tests, not executed
acceptance results from this document.

| Gate | Cases and exact observable requirement |
|---|---|
| Address/planes | All three planes, glyph 00/01/FE/FF, nibble 0..15, ordinary and paired K values; exhaustive 2048-byte per-plane access, plane isolation and no cross-plane spill. Verify n=0/1 aliases in ordinary mode but differs in paired mode. |
| Selectors | All sixteen b5 patterns, distinct four candidate metadata sets; independent ROM/PCG selection; high port-bit aliases; no-candidate fallback policy separately asserted. Beam/CRTC start address must not accidentally replace a high-speed selector. |
| CPU font | Unique ANK8 versus ANK16 bytes, all T/row boundaries, SCRN b6 on/off in both scan rates; K b7 overrides b6 into the declared Kanji backend, K b4 alone does not. Plane-zero writes change no storage. |
| Kanji diagnostics | Synthetic bank/half patterns, upper-code boundaries, K b6 half and K b7 enable. Test the declared normalized layout, not two incompatible emulator formulas simultaneously; real-font mapping remains a separate gate. |
| Frozen transaction | Change live beam, p/n/mode and selector metadata after acceptance; only the captured address/data can be used. Held select/write produces one write; next deasserted/reasserted request remains usable. |
| WAIT/phase | Requests before, during and after the chosen horizontal window; 40/80 columns, low/high scan, multiple clock ratios, CE stopped/restarted and HSYNC-width changes. Assert no early acknowledgement, bounded eventual completion when windows recur, and one write even if a window is missed. |
| Reset | Reset each handshake stage/window wait; no unserviced stale write after reset. Already completed writes are not rolled back. Preserve font and selector-shadow agreement across retained-RAM warm reset. |
| Loader/BRAM | Missing, partial, complete and out-of-order ANK16 loads; read/display latency alignment and warm-reset retention. Verify no new third RAM port, no 4096-byte FF font replica, and no font writes from CPU plane zero. |
| Integration | Existing beam/PCG and pixel regressions unchanged in base/compatible mode; original CPU I/O checks for high-speed addresses/fonts; eventual DMA accesses must use the same selection and WAIT contract. |

Exact timing remains open: X Millennium waits to raster-display end,
legacy waits for asserted HSYNC, and the schematic routes timing through
IC30 plus external latches/gates. These are **not identical events**.
Neither a fixed number of sys cycles nor the current CDC latency may be
advertised as the native high-speed WAIT duration. Horizontal blanking,
display-end and HSYNC must be tested separately before choosing a hardware
claim; an original functional fixture only verifies the chosen policy.

## Next implementation boundary

An implementable first increment is selected-cell ordinary/paired PCG,
explicit ANK8/ANK16 CPU read dispatch, ROM write protection, frozen bundles,
single writes and a separately labelled synchronized access window. Keep
selector fallback, exact window phase, ASIC paired condition and Kanji
bank/asset mapping as explicit unresolved gates. Do not resolve them by
silently forcing `7FF`, copying MAME's always-Kanji branch, or assuming that
successful display pixels validate CPU font access. Native firmware, physical
timing, CDC placement and Quartus resource/timing qualification remain
independent follow-up work.
