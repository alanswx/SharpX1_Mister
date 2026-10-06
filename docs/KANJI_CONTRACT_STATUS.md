# Kanji electrical address and CPU protocol audit

October 6, 2026. Work group 3 and Turbo Z Z7 dependency. The new physical
first-level address decoder and dual-clock 128 KiB ROM storage/loader are
implemented/tested separately; there is **no new shared-machine Kanji CPU port,
loader dispatch, glyph renderer or native support claim**. Neither
`rtl/x1_kanji_address.sv` nor `rtl/x1_kanji_rom.sv` is yet a shared-machine
dependency. The physical-address CPU read port below is not the native
`0E80..83` register interface.

## Primary first-level ROM wiring

Reused the hashed [CZ-851/852 model-20/30 schematic](https://eaw.app/Downloads/Manuals/Sharp/CZ851_2C_Schematic.pdf),
SHA-256 `8784414a3aaa25e15b4afb3662967c395c3abd6b4204ab818c7b18ed07c33f5c`.
PDF pages 2/3 were rendered/read; page 3 ROM and decoder details were rendered
again directly from the PDF and visually inspected. Temporary renders:
`/tmp/x1-kanji-model20-page{2,3}.png`,
`/tmp/x1-kanji-model20-{rom,decode}-detail.png`.

| Visible wiring | Implemented electrical relationship |
|---|---|
| IC106/105/104/103 are four MB83256 ROMs | Four 32 KiB chips, total 128 KiB first-level storage. This model is not the Turbo Z 256 KiB set. |
| ROM A14/A13/A12 receive DKAN2/DKAN1/DKAN0 | Low three glyph-bank bits occupy local address bits 14:12. |
| ROM A11..A4 receive DCHA7..DCHA0 | Eight-bit character code occupies address bits 11:4. |
| ROM A3..A0 receive K4Y..K1Y | Four-bit raster row occupies address bits 3:0. The preceding row mux must still be integrated/qualified. |
| IC92 LS139 (2/2) A=DKAN3, B=DKAN6; active-low KAY0..3 drive ROM OE | Bank high bit and left/right half select one of four chips: IC106, IC105, IC104, IC103. |

Thus local ROM address is `(bank & 7)*4096 + character*16 + row`; physical
chip is `half*2 + bank/8`. Flattened storage in the declared chip order is
`half*65536 + bank*4096 + character*16 + row`. This is a wiring-derived
mapping, **not** MAME's converted glyph layout or an assertion that archive
files named `kanji1..4.rom` follow those physical labels.

The decoder accepts caller-qualified `level1_enable` (KACE policy), exposes
active-low chip OE and local/flattened address, and does not invent PCG/ANK,
DKAN4 level-2, DKAN5 underline or DKAN7 selection semantics. These signals
must be resolved at the parent mux/ASIC, not guessed inside an address helper.
No raster clock, reset latch, ROM bytes or capability signature is added.

Strict-warning `make test-kanji-address` passes all **131,072 physical bytes**,
all 16 banks/256 characters/two halves/16 rows, with integer-formula readback,
no alias, full address visitation, unaffected non-address attribute pins and
all chip selects inactive when disabled. The first test used a giant packed
initialization rejected by Verilator's width warning; an unpacked visitation
array removes that warning without suppressing it or reducing coverage.
Log `/tmp/x1-kanji-address-unit-qualified.log`; Verilator 5.044, original
synthetic fixture, no fonts/firmware. This is address qualification, not
display pixels, synthesis resource or hardware acceptance.

## Standalone first-level storage qualification

Original GPL-2.0-only `rtl/x1_kanji_rom.sv` implements byte-wide dual-clock
storage with address width 17. Physical chip concatenation is
IC106, IC105, IC104, IC103, each 32 KiB. This defines a synthetic/physical loader
contract; native dump filenames and emulator-converted layouts are not assumed
equivalent. No ROM/font bytes are embedded or redistributed.

Uploads require both CPU and video resets held, exactly 131,072 ordered byte
strobes, and a falling upload edge without a byte strobe while resets remain
asserted. Readiness is published only on that commit edge, not the last byte.
The first byte may coincide with upload start. Empty/short, missing-zero,
gap/duplicate, out-of-range/trailing, live and orphan streams fail closed until
a fresh valid upload. An upload start invalidates the preceding image; failed
loads do not roll back a partial rewrite. Unsupported writes never touch RAM.

Warm reset retains ROM and loaded status but asynchronously flushes local read
validity. CPU reads have one local clock-edge latency; video availability crosses
two metadata stages, followed by the local select stage. Once available, video
reads have one video-edge latency. These are true clocks, not gated clocks.
The CPU port has one physical address and forwards written data to its masked
output during upload writes; the video port reads every edge. Same-address
cross-clock read/write values are never used. Supported upload/reset sequencing
prevents display access during rewriting; live invalidation may take metadata
pipeline latency to reach video, and is not a live font-update interface.

`make -C verilator test-kanji-address test-kanji-rom
HEADLESS_DIR=obj_dir_v12_kanji_storage` passes with Verilator 5.044, strict RTL
warnings and no suppressions. The ROM fixture connects the physical decoder,
checks every byte on both ports with complementary addresses, retains/rechecks
all bytes after warm reset, reloads a different synthetic pattern, and checks
inactive selects, short between-edge reset, malformed streams, exact write
counts, coincident first byte and commit-edge errors. Independent CPU/video
reset tests stop each clock in turn, require asynchronous valid flushing, keep
the other reader active, and require a fresh read after clock restart.
CPU is 32 MHz; video half-periods are 17,500, 11,640 and 25,000 ps (synthetic ratios, not an exact
nominal X3 or fitted PLL claim). Log:
`/tmp/x1-kanji-storage-final-qualified.log`. This target is added to hosted CI;
local success does not establish hosted success.

Two pre-fix failures were preserved: short reset allowed an old CPU read-valid
flag to return before a fresh edge; an orphan byte on the falling upload edge
was overridden by the later commit assignment. Async read-valid reset and
commit qualification using current inputs correct these behaviors. The latter
failed with `upload commit status` before the fix; neither failure was waived
or worked around by editing state bytes.

### Source-bound Quartus inference audit

The cached Apple-container runtime was actually queried and used locally,
with installed Quartus 17.0 and Cyclone V 5CSEBA6U23I7; no new installation or
license acceptance was performed. Initial frozen sources at
`output_files/kanji-storage-map-AJ8TADcE/` synthesized successfully, but the
inherited unconditional CPU read/write template inferred **two** 131,072×8
memories: 2,097,152 block-memory bits and 256 RAM segments, not the intended
single 128 KiB store. Source hash
`f95d37a00ee2dcff42621e53af6d6e503e07040798977026553d4f4c19f8fd4e`.
Log `/tmp/x1-kanji-storage-quartus-map.log`; resource evidence is its
`output_files/kanji.map.rpt` RAM/hierarchy summary. Warnings were one-processor
selection, unsupported `async_reg` attribute and undefined dual-clock collision
behavior. The last is explicitly excluded by the loader/reset contract;
synchronizer identification/constraints still require integration review.

The intermediate exclusive CPU read/write template is frozen separately at
`output_files/kanji-storage-map-ILSstLoc/`, source SHA-256
`6fa73b58c622a668ee7429ba5ab4fda13d0d590d8237d7307ad43eb1ef595b4d`.
It also mapped successfully but still used 256 RAM segments: separate read and
write addresses did not establish a single physical CPU port. That change was
therefore not accepted as a resource fix.

The current two-address/new-data template is frozen at
`output_files/kanji-storage-map-3jh0e6qj/`, source SHA-256
`bef106df7e17f285e8322652ea809dad8f5264a2ae6f9496eba65ad958d8e9ae`.
It muxes upload/read addresses before the CPU RAM port and forwards written
data, while externally masking read validity during writes. This conforms to
two-unique-address/new-data inference contract described by the
[Intel Quartus handbook](https://cdrdv2-public.intel.com/653794/quartusii_handbook_121.pdf).
The actual Quartus map exits zero: **one 131,072×8 bidirectional dual-port
memory, 1,048,576 block-memory bits and 128 RAM segments**. The final synthetic
fixture passes unchanged for reads/reset/commit checks after this storage
correction. Log `/tmp/x1-kanji-storage-two-address-quartus-map.log`, RAM summary
`output_files/kanji-storage-map-3jh0e6qj/output_files/kanji.map.rpt`.
The same three warning categories remain and were not suppressed. This is an
observed synthesis saving, not an estimate from the RTL. Standalone mapping is not a
shared-machine fit, constrained timing result, RBF or hardware acceptance.

Shared-machine loader index/signature, source ordering, CPU register protocol,
KACE/PCG/ANK and raster selection, glyph/pixel latency, WAIT/concurrency and
native fonts still need implementation and acceptance. Standalone physical
storage is not full Kanji or Turbo Z support.

## CPU-port conflicts actually inspected

Local MAME revision `f4bfc5a423f48d48e809c01fc70a47c0c00d40a2`,
`src/mame/sharp/x1.cpp` functions `kanji_r/w`, `jis_convert`,
`init_x1_kanji`, ROM declarations; and `x1_v.cpp::draw_text`.
Local X Millennium `io/cgrom.c/.h`, `vram/makechr.c`,
`font/font.c/.h`, inspected, not built/run. No second MAME checkout.
Also read the original [Common Source/eX1 display implementation](https://github.com/Artanejp/common_source_project-fm7/blob/2f350e59869ad52293c768e08dd1e6137001486b/source/src/vm/x1/display.cpp)
at pinned revision `2f350e59869ad52293c768e08dd1e6137001486b`, through
GitHub API without cloning/building it. Its header attributes Kanji to X1EMU
by KM and ANK16 patches to X-millennium by Yui; this is not three independent
silicon observations. No emulator implementation was copied into RTL.

| Contract | MAME | X Millennium / inspected eX1 source |
|---|---|---|
| `0E80/0E81` writes | Low/high staging address | Low/high staging address |
| `0E82` writes | Bit-0 rising edge copies staged address to active address | Xmil latches on every write; eX1 explicitly marks bit-0 rising-edge behavior TODO |
| Glyph row progression | Right-port read increments staging address, not active glyph address; fresh edge relatch is needed to expose that change | Both half reads set flags; row advances only when both have been read, wrapping modulo 16 |
| Address-low nibble | Used as active row in MAME reads | Face pointer masks low nibble; separate row counter survives ordinary latch writes |
| Staged high byte zero | Partial `jis_convert` cases marked FIXME | Special code/address conversion path; not ordinary font byte access |
| Font storage | `init_x1_kanji` interleaves sixteen-byte halves; raw dump order is 4/2/3/1 in inspected ROM declarations | Split-half arrays; Xmil allocates 256 KiB and uses `FONTX1T_LR=0x20000`, including extra bank/mirror conversion |
| PCG + Kanji selection | Kanji enable takes precedence in inspected renderer; second-level bit is TODO | PCG attribute chooses separate paired-PCG behavior, not the same Kanji path |

These differences prevent treating an emulator's allocation/JIS table as the
hardware ROM pin order or advertising native CPU access merely by returning
font-looking data. The model-20/30 video schematic does not settle CPU EKSEL,
read advancement, special conversion or Turbo Z ASIC behavior. MAME's FIXME
conversion and eX1's TODO are explicit gaps, not acceptance oracles.

## Implementation sequence still required

1. Connect the now-tested physical decoder/storage to the shared loader and
   video row/character pipeline. Specify native source chip identities/file order;
   standalone synthetic bank/half/row reads pass before private fonts. Verify
   latency, beam boundaries, blanking and CPU/DMA concurrency, not just address
   equality. No native archive reordering/conversion was performed here.
2. Trace the remaining KACE/PCG/ANK/underline/row mux and Z level-2 nets from
   the primary sheets. Define supported model-specific behavior without
   silently replacing a missing glyph with ANK or a working-device signature.
3. Resolve CPU `0E80..83` semantics with programming documentation or an
   authorized hardware transaction trace. Test staged versus active address,
   repeated-high EKSEL, read order/repeats/wrap, code conversion, WAIT and
   held strobes. Implement actual CPU diagnostics and deterministic ROM service.
4. Resolve Z storage budget before wiring 256 KiB ROM into FPGA BRAM. The
   measured X3 fit has only 164 M10Ks left; a naive 256-block addition does
   not fit. First-level capacity here does not shrink the user's Z requirement.
   Plan external-memory/cache arbitration for simultaneous video and CPU ROM
   requests, DMA/capture and loader access, then qualify timing/resources.
5. Run native fonts/software with recorded asset hashes, mode/attribute matrix,
   source-bound Quartus fit and real MiSTer video/reset checks. None is complete
   from this decoder or the research alone.
