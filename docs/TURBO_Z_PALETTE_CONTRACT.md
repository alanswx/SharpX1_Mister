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

An online search for a specific CZ-880 palette programming manual did not
locate an additional usable primary register specification in this follow-up.
The existing scan and local sources remain the actual evidence; unrelated
modern Sharp download/manual results were not used to assign bits.
