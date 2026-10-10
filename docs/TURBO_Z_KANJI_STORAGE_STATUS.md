# Turbo Z Kanji physical storage contract

October 10, 2026. The standalone physical decoder is implemented/tested;
second-level machine storage, native font loading and glyph rendering remain
unimplemented. This does not complete work group 3 or Z7.

## Primary pin trace

Re-rendered and visually read existing CZ-880 service-manual PDF/printed sheet
46, IC65/66 and their labeled address/CE pins. Source SHA-256:
`70a5f8da327ed25710e76d60117c4f82a655e6a7b29a34cb3239c75f0bd65a81`.
The local render is `/tmp/x1-z-line-sheet46.png`; original reference:
[Sharp service manual](https://eaw.app/Downloads/Manuals/Sharp/CZ-880_Service_Manual.pdf).

| ROM input | Board net |
|---|---|
| A16..A13 | DKAN3..DKAN0 |
| A12..A5 | DCHA7..DCHA0 |
| A4..A1 | K4Y..K1Y |
| A0 | L/R |
| IC65 CE | KACE1, first level |
| IC66 CE | KACE2, second level |

Each chip has a 17-bit address. Its local byte is
`bank*8192 + character*32 + row*2 + half`. Declared flattened storage is
IC65 followed by IC66, 131,072 bytes each. This is **not** the earlier Turbo
four-chip half-major physical loader layout. Native archive member names,
the user-supplied 306,176-byte glyph exports and ASIC select/row timing are
not qualified by these pin labels. No private bytes are embedded or converted.

## Executed standalone decoder acceptance

Original GPL-2.0-only `rtl/x1_z_kanji_address.sv` takes caller-qualified level
enables and explicit bank/character/row/half. It preserves both raw active-low
CE outputs; its flattened consumer validity requires exactly one selected
chip. It does not manufacture KACE1/2 from DKAN4 or infer a missing ASIC.

`make -C verilator test-z-kanji-address` completes zero using Verilator 5.044,
strict warnings without suppressions. The independent integer/pin oracle
visits all **262,144** physical bytes exactly once, plus all disabled and
dual-selected cases. A matched earlier-model half-major negative fails the
unchanged pin assertion. Log `/tmp/x1-z-kanji-physical-address-first.log`;
negative log `verilator/obj_dir_headless/z-kanji-address/negative.log`.
CI now schedules the asset-free target; its hosted result is not yet known.
The adjacent earlier-model 131,072-byte decoder repeats successfully with
the new target in `/tmp/x1-z-kanji-physical-adjacent.log`, without warnings.
New decoder SHA-256:
`38a61f776e3a8d91920853815be7fb7456d9dfa7b1d641de13eb566ea4f5d104`;
original fixture SHA-256:
`1323a9f2ba11f3d57cfbbd1dd9e540ad5e2c82c2c98c42f12377aaf493b6f68a`.

## Remaining integration gates

The decoder is not in `machine.qip`, instantiated by a board/runner or connected
to a font memory. Existing first-level profiles, snapshots and manifests stay
unchanged. Do not claim level-2 machine support from this combinational check.

1. Trace ASIC KACE/row/half generation and qualify CPU/display source selection.
2. Resolve storage architecture: the earlier X3 fit has only 164 spare M10Ks;
   a naive 256-block ROM addition cannot satisfy the full Z requirement.
   Plan external memory/cache arbitration for concurrent glyph/CPU/DMA/capture
   requests rather than dropping second level to fit current BRAM.
3. Define explicit model-bound native conversion with complete original hashes;
   do not truncate exports or reuse the earlier physical format silently.
4. Qualify ordered loader, actual CPU/WAIT, pixels/attributes, pending-operation
   reset and source-bound Quartus resources/timing before physical acceptance.
