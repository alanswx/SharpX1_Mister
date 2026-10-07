# Kanji electrical address and CPU protocol audit

October 6, 2026. Work group 3 and Turbo Z Z7 dependency. The new physical
first-level address decoder and dual-clock 128 KiB ROM storage/loader are
implemented/tested separately. The subsequent [opt-in CG profile](KANJI_CG_ACCESS_STATUS.md#shared-machine-physical-rom-profile)
connects the ROM loader and CPU `1400..140F` backend to the shared machine;
the separate [render experiment](KANJI_RENDER_STATUS.md) now checks actual
pixels under an explicit provisional row policy, not full native font support.
The ROM is now a
shared-machine manifest dependency; the standalone electrical decoder remains
a reference/verification component. The physical-address CPU port is not the native
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

### Executed first-level glyph-source decoder

`rtl/x1_kanji_decode.sv` now models the visible IC92/IC91 selection gates,
separately from ASIC timing and the renderer. The page-3 detail was inspected
again (`/tmp/x1-kanji-kace-detail.png`): IC92 (1/2) has A=DATT5, B=DKAN7;
its active-low Y2 is KACE. IC91's input/output-bubbled NAND implements
`KACE_n | DKAN4` at IC92 (2/2)'s active-low enable. The upstream first
decoder enable remains caller-qualified; tracing that phase is still required.

| DATT5 (PCG) | DKAN7 | Active IC92 first-half output, when enabled |
|---|---|---|
| 0 | 0 | Y0 / ANK |
| 1 | 0 | Y1, not KACE |
| 0 | 1 | Y2 / KACE; DKAN4 chooses first/second level |
| 1 | 1 | Y3, not KACE |

Thus the electrical decoder does **not** select Kanji when PCG is selected.
Local X Millennium `vram/makechr.c` (`makechr8` and `makechr16`) agrees:
its PCG branch is outside the Kanji branch, including paired-PCG selection.
Local MAME `x1_v.cpp:draw_fgtilemap` instead replaces `gfx_data` when Kanji
is enabled even after selecting PCG; its Kanji double-height treatment is
explicitly a guess. Neither emulator has been newly built/run here. Use the
schematic relationship, not MAME's conflicting priority, for this component.

`make -C verilator test-kanji-decode` passes **4,194,304** combinations of
decoder enable, PCG, all Kanji attributes, all characters and all 16 supplied
rows. It covers every first-level physical byte, both underline values,
disabled/ANK/PCG/absent-level-2 chip isolation and all 256 ordinary attributes.
The independent expected-value calculation uses integer decoder truth tables
and physical-address formulas. No warning suppressions were added. Log:
`/tmp/x1-kanji-display-decode.log`, exit zero, Verilator 5.044.
A temporary negative control ignores DATT5; the unchanged fixture fails its
LS139 assertion (exit one), log `/tmp/x1-kanji-display-decode-negative.log`.
Existing physical-address, CPU-selector and conversion regressions also pass,
log `/tmp/x1-kanji-display-decode-regression.log`.

This decoder's standalone acceptance does not change any default or the
recommended RBF. It is now a shared-machine manifest dependency for the separate
render experiment, which has its own opt-in model identity.
K4Y..K1Y row generation, upstream enable phase, attribute/glyph latency,
underline/mixing, level-2 storage and actual pixel/native/hardware acceptance
remain open. The CPU-only profile's ROM display port stays disconnected;
gate truth table coverage is not renderer acceptance. The target is added to hosted CI,
but this new target's hosted result is not yet available.

### Supplied native-asset inventory and conversion boundary

The user-supplied model-40 archive
`software/Sharp X1/[BIOS] X1turbo model40 (CZ-862C) (Sharp)/[BIOS] X1turbo model40 (CZ-862C) [ROM].7z`
has SHA-256 `c2449695642e0a914fdabc834a4feb8af90ac2d7a04a163db31432ad8176ec78`.
`7z l` lists four 32,768-byte Kanji members. Streaming each member directly to
SHA-1 (no binary output/redistribution) matches the local pinned MAME model-40
ROM declarations exactly:

| Member | SHA-1 |
|---|---|
| `kanji1.rom` | `dad7ada1b70c45f1e9db11db273ef7b385ef4f17` |
| `kanji2.rom` | `103bbe459dc8da27a9400aa45b385255c18fcc75` |
| `kanji3.rom` | `273f3329c70b332f6a49a3a95e906bbfe3e9f0a1` |
| `kanji4.rom` | `d3fd24892bb1948c4697dedf5ff065ff3eaf7562` |

These hashes identify a MAME candidate set, not independently verified chip
labels. MAME `init_x1_kanji` and `x1_v.cpp` were inspected together: the display
address is `((bank*256 + character)*2 + half)*16 + row`; the initialization
interleave maps that to raw offset
`(bank>>3)*65536 + half*32768 + (bank&7)*4096 + character*16 + row`.
Its raw region is loaded in member order 4,2,3,1. Thus **inferred** conversion
to our half-major electrical layout would concatenate **4,3,2,1**, not copy
MAME's raw region unchanged. The subsequent explicit converter below now
qualifies this software mapping and a bounded private CPU-read candidate;
native glyph/physical-chip acceptance remains required.

The supplied Turbo Z ROM archive has SHA-256
`01d426ecbdc5f0b48e075d586564b9d3c588f7c66f3b9626b30eca1fd3e0f9d1`.
Its `FNT1616.x1` and `KANJI2.rom` are **306,176 bytes each**, not 128 KiB raw
first-level chips or a 256 KiB raw Z set. The corresponding extras archive
SHA-256 is `accca228dc548431b74936064a037e34a9f3758ee8f86599a6a95bbfffa8c1cd`.
Its 572-byte CP932 readme was streamed/decoded: it identifies extraction tool
`x1fnt3.zip` and says the second-level filename was chosen arbitrarily because
the tool documentation did not specify its name/use. The contents are glyph
exports, not proof of physical ROM layout. Exact-size rejection must remain
in `--kanji-physical`; do not truncate these files or relabel their bytes.

Both archives report 38 trailing bytes in `7z l`; listings/member hashes were
read successfully. Originals remain unchanged. The native files were not
downloaded, installed in the core, booted, converted or committed in this
inventory step. The subsequent conversion below is a separate executed
increment. Emulator source inspection and matching hashes do not settle
physical priority/raster/level-2 selection or replace hardware evidence.

### Executed explicit model-40 conversion and CPU-read candidate

Original `scripts/prepare_kanji.py` requires the explicit source format
`audited-model40-raw`, the audited archive SHA-256 and all four member SHA-1s.
Unknown/repacked archives need another audit, not automatic filename-based
acceptance. It reads at most 1 MiB, snapshots the hashed archive bytes privately
before `7z` extraction, and uses only fixed member names with stdout extraction.
Archive path entries are never extracted to the filesystem. The original is
unchanged. Destination directories and files use exclusive creation; existing
targets/symlinks are not overwritten. No font bytes are embedded in source.

Executed command (local user-supplied assets only):

```sh
python3 scripts/prepare_kanji.py \
  'software/Sharp X1/[BIOS] X1turbo model40 (CZ-862C) (Sharp)/[BIOS] X1turbo model40 (CZ-862C) [ROM].7z' \
  --source-format audited-model40-raw \
  --output-dir software/turbo-kanji/model40-frozen-candidate
```

Private output is 131,072 bytes, SHA-256
`b32559f5d5b9014d5ba316c41293e1336532eb0c66a01d5ac7e1304dabdaa91c`.
Ignored `provenance.json` retains archive/member identities, physical order,
layout, pinned MAME revision and the explicit inferred/not-hardware-qualified
label. An earlier identical output lives in `software/turbo-kanji/model40-candidate/`;
the frozen-source extraction reproduces its exact hash. An attempted overwrite
exits 1, leaving that output unchanged, log `/tmp/x1-kanji-conversion-existing.log`.

`make -C verilator test-kanji-conversion` passes **131,072** address comparisons
with original synthetic members. The oracle independently forward-interleaves
the MAME raw order 4,2,3,1 into character/half/row display space, then compares
every electrical half-major byte. It requires a bijection, exact member shape,
synthetic/native hash rejection, explicit CLI format and rejection of an
unqualified archive without creating output. This asset-free target is added
to hosted CI; its pending hosted run is separate from local success.

The actual shared-machine X3 fast and delay-aware runners both execute the
unchanged 1,024-byte INI matrix with `--physical-rom` pointing to the earlier
private candidate. All halves/banks/rows at glyph codes 0/255 pass cold/warm,
along with absent ROM, ignored writes, level-2 rejection, ANK exit and CLI
length rejection. Expected comparisons are original emitted CPU instructions;
private temporary programs are not committed. Logs
`/tmp/x1-kanji-model40-x3-{fast,timing}.log`. Output asset hashes are recorded
in each test report. This demonstrates bounded CPU read/coherence of the
supplied candidate, not every native glyph, JIS registers, rendered pixels,
Turbo IPL/software compatibility or verified board chip identity. Those remain
open, as does the larger Z first/second-level export conversion.
The original synthetic X3 snapshot regression also exits zero after the test
fixture extension, log `/tmp/x1-kanji-converter-snapshot-regression.log`.

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

### Hardware monitor establishes a separate high-speed CG access sequence

Read the author's [X1turbo Remote Monitor description](https://x1turbo-agency.hatenablog.jp/entry/2018/05/22/080623)
and downloaded published v1.2.2 through its Dropbox link, not an emulator or
a new MAME checkout. ZIP SHA-256
`7e40690f5ea65e92c8051095e66edae0863db39c26557c8b4198676e0568f9cf`.
Only `x1_mon.bin` was extracted for static inspection, SHA-256
`09d116df5260b764831df1a82e7b954e29f374cdae9e47e5381b7e0f22236e8c`.
Temporary reference `/private/tmp/x1-monitor-reference-TAucHfou/`; binaries,
bundled D88 media and disassembly are not committed or redistributed. The
bundled readme retains the author's copyright and asks for contact before
republication. The Windows executable and monitor were not executed.

The binary has a four-byte LOADM start/end header; static disassembly at
origin `D4FC` aligns the payload entry with documented `D500`. Using `D500`
for the entire file initially displaced instruction addresses by four bytes;
that initial disassembly was not used as a transaction oracle. Installed
`z80dasm 1.2.0` was used, not newly installed tooling. Its linear-disassembly
self-modifying/8080 warnings mean data must not be treated as executed code.

The inspected ROM command dispatch and call target show this sequence:

- Kanji: set SCRN high-speed/16-row bits, select each half using K b6, and
  traverse 256 character values for the requested bank.
- At `DBFB..DC1D`: write K to `3FFF`, character to `37FF`, and attribute 7
  to `27FF`; read sixteen bytes via `1400..140F` using INI with its B decrement
  compensated, so the high port byte remains 14.
- ANK uses the same helper with eight rows/stride two or sixteen rows/stride
  one. The monitor does not use `0E80..82` in this inspected ROM routine.

This is a hardware-tool author's software sequence, not a captured pin trace
or execution here. It establishes a useful native **high-speed CG** test target;
it does not settle the separate `0E80..83` latch/read-order disagreements below.
The author explicitly says the exported font is reordered into Shift-JIS,
not physical ROM order; those exports cannot silently become the physical
chip-concatenated loader input. The author reports tested Turbo/II/ZIII models;
we have not repeated that acceptance.

An original `KANJI_SUPPORT=1` option in `x1_pcg_selector.sv` now exposes a
first-level physical address for that bounded CPU selector path:
`half*65536 + bank*4096 + character*16 + row`. K b5 does not alter address;
K b4 (absent level 2) fails closed rather than aliasing first-level bytes.
PCG planes remain PCG and ANK exit clears the Kanji backend selection/address.
Defaults retain `KANJI_SUPPORT=0`. The subsequent explicit `TURBO_KANJI`
profile enables it with a physical-ROM loader/backend and distinct snapshot
signature; ordinary machine/FPGA profiles still disable it.

Strict-warning `test-kanji-cg-selector` passes **524,352** physical/attribute
cases: every physical byte at both underline-bit/font-mode settings, default
profile isolation, partial metadata, level-2 rejection, all sixteen existing
candidate masks/plane choices, ANK exit and noncandidate writes. The original
`test-turbo-pcg-access` regression also exits zero: 49,216 original selector
cases, all 4,096 ANK16 bytes, three base-PCG clock profiles and six high-speed
transaction profiles (16,395 transactions each). The inherited four-cell
priority/7FF fallback remains bounded/provisional, not a full ASIC selector
claim. Log `/tmp/x1-kanji-cg-selector-qualified.log`.
Base and X3 wrapper lint both exit zero using the PLL interface stand-in,
with inherited framework/RTL warnings and no new suppressions. This is not
Quartus, PLL behavior or physical acceptance. Log:
`/tmp/x1-kanji-cg-wrapper-lint.log`. Selector SHA-256
`bd1a54b0cf87a806dc1859270b4870eb067c3ac24c0c08f102d2125e75304946`;
new original fixture SHA-256
`12cf4cd7a472ce8c057e7a8eeae61c855aede7d0538e61f616a009d5b65f59a3`.

The subsequent [connected Kanji CG backend](KANJI_CG_ACCESS_STATUS.md) now
freezes its address/read selection and samples ROM bytes only on the CPU
clock. Exhaustive ROM/WAIT and actual-CPU IN/INI fixtures preceded the subsequent
opt-in shared-machine loader/profile and CPU execution. See the linked status
for snapshot and exact shared-machine acceptance. Glyph/display selection and
the larger Z storage remain separate gates.

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
   equality. The explicit model-40 conversion above is a CPU-read candidate,
   not acceptance of native rendering or physical chip labels.
2. The first-level KACE/PCG/ANK gate truth table is tested above. Trace its
   upstream enable phase and the remaining underline/row mux and Z level-2 nets from
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
