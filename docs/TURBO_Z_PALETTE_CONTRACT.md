# Turbo Z palette contract audit

October 6, 2026. Research gate for Z2/Z3, **not implemented registers**.

The later [standalone physical storage foundation](TURBO_Z_PALETTE_STORAGE_STATUS.md)
passes exhaustive component/address/nibble and retained-reset checks. It does
not resolve this audit's ASIC/register gates or connect a Z palette device.

## Primary circuit evidence

The existing hashed CZ-880 service manual was rendered again at PDF/printed
page 46 and visually inspected. No new scan was downloaded. The palette ASIC
IC60 is IX0868CE. Three uPD4314-45 memories IC68/69/70 share PA0–PA11 address
signals and EPMCS/EPMWE control. Each contributes four data signals to the
EPD0–EPD11 bundle. These twelve visible address wires support a 4096-entry
physical palette, not merely a 64-entry allocation. This is a circuit-derived
storage-capacity inference, not a traced CPU index-formation truth table.

Three MB40776H converters IC71–73 consume DA0–DA11 as four bits/component.
The adjacent MB40576 converters IC74–76 are the separate video-input A/D path;
they must not be substituted for palette output. Palette RAM has no reset
pin shown on this sheet: zeroing all entries on warm reset is not established
by the circuit. The ASIC's RESET2 input does not by itself prove RAM clearing.

This page still exposes only the ASIC's pins, not its internal register or
address mux logic. Derive CPU access, active-display wait and retention
contracts separately. Digital eight-color output and analog four-bit output
are distinct board paths; MiSTer's full-color boundary must not quantize the
analog path down to the digital connector's capabilities.

Source: [Sharp CZ-880 manual scan](https://eaw.app/Downloads/Manuals/Sharp/CZ-880_Service_Manual.pdf),
[local inventory/hash](../references/manuals/README.md). Temporary render:
`/tmp/x1-z-palette-page46.png`. This audit does not claim the rest of sheets
43–46 or the capture/connector/IC-block pages have been fully traced.

## Emulator cross-check, inspected but not executed

Local MAME revision `f4bfc5a423f48d48e809c01fc70a47c0c00d40a2`,
`src/mame/sharp/x1.cpp` functions `x1turboz_4096_palette_w`,
`x1turbo_*pal_*`; local X Millennium/libretro revision
`b07506c0cae31d260db28cb079148857d6ca2e93`, `io/crtc.c` functions
`palette_o`, `palette_i`, `extpal_*`, `extgrphpal_*`, `exttextpal_*`
and mode selection in `crtc_dispupdate`. These source inspections are not
emulator comparison runs or proof of silicon behavior. No code was copied.

| Transaction | Agreement / unresolved difference |
|---|---|
| AEN | Both identify `1FB0` bit 7 as analog enable; bit 4 participates in color-mode selection. Exact model masks/reset and remaining bits need primary programming evidence. |
| Graphics access | Both use `1FC5` bit 7 for APEN and bit 3 for APRD. Ordinary palette writes require APEN with APRD clear. |
| Full 4096 index | Both combine the low port byte as index bits 11–4 and data high nibble as index bits 3–0. Component selection follows palette-port high-byte B/R/G order, not RGB12 output packing. |
| APRD selector | X Millennium updates a remembered high nibble on palette writes even when no palette RAM write occurs, then combines it with the read port and returns it with the selected component. MAME explicitly leaves APRD incomplete. Selector lifetime/reset and ignored-access effects remain unresolved. |
| Reduced index | MAME masks with `0xCCC` and replicates selected bits. X Millennium distinguishes native eight/64-color arrays and reduced 4096-bank access, masks with `0xCCC`, optionally shifts by two, and selects CPU/display banks separately. These are not interchangeable contracts. |
| Text palette / graphics-control gate | X Millennium ignores writes/returns `FF` while AEN is clear. MAME stores/readbacks registers more freely (text color update itself is AEN gated). Do not silently choose either implementation. |
| Text component precision | MAME selects B/R/G two-bit fields from the text register, expanding them to display color; this is not evidence that all four-bit graphics component fields share that encoding. |
| Active display | MAME explicitly notes missing bus-request behavior for palette accesses outside blanking. X Millennium's palette software bookkeeping does not qualify real WAIT, RAM arbitration or beam timing. |

## Required original diagnostic matrix before integration

1. Establish model-specific decode and the reset/retention values, including
   unknown bits, inactive AEN/APEN and ignored access side effects. Keep base
   and Turbo profiles unchanged; do not expose a Z detection signature first.
2. Exhaust all 4096 addresses, three components and sixteen nibble values;
   verify component isolation, address high-nibble latch, read selectors and
   the independent RGB12 PPM expectation. Use synthetic patterns, not fonts.
3. Exhaust reduced-mode indices and both CPU/display page selections after
   resolving their physical mapping. Include the manual's 640x200/64 mode.
4. CPU strobes held over several enables must produce one accepted operation.
   Qualify DMA ownership, DAM exclusion and reads/writes during blank/active
   display. No fake Ready or synthetic BUSACK may establish machine acceptance.
5. Cold/warm/short reset between selector and data accesses; mode exits without
   reset; retained palette RAM vs reset ASIC latches. Specify read-during-write
   behavior and any CPU/video crossing before choosing FPGA RAM ports.
6. Refit and test full-color scaler/physical output and unchanged native
   software. Synthetic capture alone does not prove the Z palette works.

At the original October 6 audit, an online search for a specific CZ-880 palette programming manual did not
locate an additional usable primary register specification in this follow-up.
The existing scan and local sources remain the actual evidence; unrelated
modern Sharp download/manual results were not used to assign bits.

## October 9: primary technical-book programming evidence

Retrieved [X1-Techknow Appendix A I/O Map](https://github.com/UnsatisfactoryResult/Sharp-X1-Fun/blob/main/Documents/X1-Techknow/15%20X1-Techknow%20Appendix%20A%20IO%20Map.pdf),
not another emulator. Its published-book diagrams are primary programming
evidence, not a factory ASIC truth table or hardware measurement. The image-only
scan was visually read at PDF pages 4–12 (printed 276–284); pages 1–3 remain
uninspected. Hashes/provenance are in the [manual inventory](../references/manuals/README.md).

| Diagram | New corroboration / unresolved gate |
|---|---|
| Printed 276 | Full palette index packs G/R in the low port byte and B in data bits 7–4; component value uses bits 3–0 at B/R/G ports `10/11/12`. |
| Printed 280 | `1FB0` bit 7 selects compatibility/multicolor; bit 4's 4096/64-two-screen choice is qualified for 320×200. `1FB8` is labelled control, unlike a simple eighth color entry; reconcile its role. |
| Printed 282 | `1FC5` bit 3 selects write/read, but bit-7 access-mode labels make bit 3 valid with access OFF and invalid with access ON. This conflicts with both emulators' APEN/APRD gating; do not silently invert the implementation. |

These pages do not establish reset values, selector lifetime or active-display
WAIT. Seek independent Sharp programming documentation and native register
sequences before committing the conflicting gate policy. The audit remains open.

## Screen-display chapter: normal access and power-on contract

The subsequently retrieved [screen-display chapter](https://github.com/UnsatisfactoryResult/Sharp-X1-Fun/blob/main/Documents/X1-Techknow/09%20X1-Techknow%20Part%202%20Chapter%204%20Screen%20Display.pdf)
provides published programming sequences, not just the appendix's bit labels.
PDF pages 51–60 (printed 155–164) were visually inspected; its full provenance,
hash and inspected scope are in the manual inventory. This changes the next
implementation decision: the normal explicit write/read sequence is supported
by primary programming evidence, rather than chosen by emulator agreement alone.

- Printed 157 flow diagrams and listings on 158–159 enable multi-color with
  `1FB0=80h`, use `1FC5=80h` for writes and `1FC5=88h` for reads. Reading first
  performs an OUT to select the address high nibble, then an IN at the component
  port. This supports APEN=1/APRD=0 writes and APEN=1/APRD=1 selector/read
  operations in the documented normal sequence. The appendix's access-mode
  labels do not justify inverting that sequence. APEN=0 side effects and
  undocumented combinations are still unqualified.
- Printed 156–157 corroborate low-port-byte plus data-high-nibble addressing
  and B/R/G component ports. The physical PA-bit table lists pin permutations;
  logical palette indices must not be equated to PA pin order without tracing
  that permutation. CPU and display must use the same representation.
- Printed 156 expressly distinguishes power-on initialization from the front
  IPL switch: internal and external palettes initialize at power-on, not at
  IPL reset. Printed 159–160 give default external colors and a software
  initialization loop; logically, each index starts with its corresponding
  B/R/G nibble values. Internal eight-color defaults and text defaults are
  separately tabulated. The original storage primitive's unspecified unwritten
  power-up values therefore could not establish native cold-start acceptance.
  The subsequent storage extension now supplies a tested configuration-time
  external identity image, preserving warm-reset retention; see its status
  report for the fresh synthesis gate. Internal/text palette initialization,
  real power-on timing and machine cold/warm dispatch remain open.
- Printed 162 states text entry zero at `1FB8` cannot be accessed and is fixed
  zero; entries 1–7 use two bits/component, replicated to four-bit output.
  This is stronger evidence than treating `1FB8` as an ordinary programmable
  eighth color. Readback of the inaccessible entry, inactive-AEN effects and
  any separate control decode still need qualification.
- Printed 161 identifies the internal palette for 640×400 and external RAM
  for other multi-modes. It explicitly requires expansion of effective reduced
  color bits for external indexing. The CPU/display bank and exact replication
  contract must still be reconciled with the physical diagrams and both
  emulators before implementing all modes.

Do not copy the listings verbatim into diagnostics: printed 158's write heading
and stated colors disagree with its port/data literals; its read heading on
158 likewise disagrees with the continuation's selector literals on 159.
The flow diagram's final control-port label also differs from the setup port.
Use independently authored tests with explicit expected indices and values.
These inconsistencies do not erase repeated `80h/88h` setup agreement, but
prevent treating every printed literal as an exact hardware oracle. No listing
or register sequence was executed in this research checkpoint.

Next integration gates are now concrete: cold defaults versus retained IPL
reset; the supported explicit selector/write/read path with deduplicated held
strobes; internal/external mode selection and fixed-zero text entry; independent
CPU/display index oracles; then real ownership/WAIT and RGB12 renderer tests.
Active-display contention, selector lifetime across control changes, default
ASIC latches and inactive-mode behavior remain open. Z2 is not complete.

## Multi-mode fetch requirements from the same chapter

PDF pages 16–22 (printed 120–126) were also visually inspected. Diagrams
4-8 through 4-14 and accompanying prose describe component-bit significance
and bank/offset use. Here `q` means the base display byte position **within a
component plane**, not the absolute B/R/G I/O address. Book bank 0/1 corresponds
to the two physical 16 KiB component stores; do not confuse a bank with the
additional `+400h` byte position inside that bank.

| Native display | Component bits / required source bytes |
|---|---|
| 320×200/4096 | Bit 0: bank 0 at q; bit 1: bank 0 at q+400h; bit 2: bank 1 at q; bit 3: bank 1 at q+400h. |
| 320×200/64, two screens | Per screen, bit 0 at q and bit 1 at q+400h. Bank 0 and bank 1 hold the separate screens. |
| 640×200/64 | Bit 0: bank 0 at q; bit 1: bank 1 at q. |
| 320×400/64 | On the bank selected by raster parity, bit 0 at q and bit 1 at q+400h; successive raster lines alternate banks. |
| 640×400/8 | One bit/component from the bank selected by raster parity; use the internal eight-entry analog palette, not the external 4096 store. |

Component order is B/R/G, while the final RGB12 interface remains R:G:B.
Here bit numbers name **source channels**, not logical CPU-address significance.
The earlier claim that channel zero is the least-significant logical nibble bit
was incorrect. Printed 156 table 4-22 permutes CPU pins against display pins;
the display index must reverse each source nibble before a logical CPU-indexed
RAM lookup. See the explicit pin reconciliation below. Synthetic agreement
with an identically mistaken oracle was not native-significance acceptance.
Reduced-color replication and the palette-bank selector remain distinct from
the GRAM source-bank selection in this table.

There are scan-label/dimension inconsistencies in the prose and diagram 4-13:
its width annotation conflicts with the named 320×400 mode. Retain native
dimensions from the machine manual; derive character/raster addressing from
the actual CRTC and byte positions, not that conflicting annotation. The
chapter also distinguishes low-scan two-screen priority from high-scan use;
the register truth table for simultaneous composition still needs qualification.

The current `rtl/sharpx1.v` gives each component RAM only one display address,
passes one byte/component into the digital renderer and derives RGB12 by
replicating final digital bits. `x1_gram_address.sv` already handles ordinary
Turbo raster bank interleave but does not fetch these extra Z bytes. Therefore
neither connecting the external palette nor changing RGB12 alone implements
Z3. Add a video-domain fetch schedule/buffer that obtains every needed source
byte without corrupting the CPU port, and prove synchronous-read latency,
bank/offset boundaries, CRTC phase and CPU/DMA contention. Do not assume extra
GRAM ports or RAM replication fits without synthesis evidence.

Acceptance must initialize distinct patterns through genuine CPU writes at
each bank/offset, independently predict component indices and final RGB12,
check every pixel in all five modes and both low-scan screens, then exercise
live exits, retained reset and unchanged base/Turbo rendering. This is a
documented integration contract, not executed Z-mode acceptance.

## CPU/display pin reconciliation (table 4-22)

Re-read printed 121/122 source diagrams and printed 156 table 4-22 while
extending the renderer. CPU external access is still logical
`{AB[7:0], DB[7:4]}`; the physical memory PA pins have a different order:

| Source channel order | Physical PA order | CPU pin order | Logical component bits |
|---|---|---|---|
| QHA0,1,2,3 (blue) | 0,1,2,3 | DB7,6,5,4 | B3,2,1,0 |
| QHB0,1,2,3 (red) | 4,5,6,7 | AB3,2,1,0 | R3,2,1,0 |
| QHC0,1,2,3 (green) | 8,9,10,11 | AB7,6,5,4 | G3,2,1,0 |

First GRAM source is BD0/RD0/GD0, then the other three bank/offset sources.
Thus the first fetched byte supplies logical component bit **3**, not bit 0.
This is a physical-to-logical representation correction, not an aesthetic
image adjustment. CPU selector/write packing and palette storage identity
stay unchanged. The old renderer/oracle at `533961a` used unreversed logical
nibbles; its pixel passes establish internal agreement, not this pin contract.
The correction updates both independently derived pin and CPU-pixel oracles.
Full native software and physical pin timing remain separate gates.

Reduced modes still require interpreting the effective-source expansion and
page policy, not blindly copying emulator tables: local X Millennium selects
only `CCC`/`333` positions for its two 64-color banks, while local MAME expands
masked `CCC` bits by OR with a two-bit right shift under a different C64
condition marked TODO. Those implementations do not agree on the contract;
neither executes a complete Z multicolor renderer. Preserve this discrepancy
until the book/ASIC controls and native pixel sequences resolve it.
