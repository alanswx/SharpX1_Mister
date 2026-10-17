# Sharp X1 software references

Reusable HDL snapshots from Jotego, other MiSTer cores and sibling repositories
are indexed in [chip-src/README.md](chip-src/README.md). Hardware documentation
is indexed in [manuals/README.md](manuals/README.md).

The local MAME checkout used for comparison is:

`../FM-7_MiSTer_alanswx/refs/mame`

Its Sharp X1 driver is `src/mame/sharp/x1.cpp`. It is intentionally not
duplicated in this repository. The checkout currently has unrelated local
changes; do not modify or reset it as part of X1 work.

Additional open-source references selected for this project:

- [MAME Sharp X1 driver](https://github.com/mamedev/mame/blob/master/src/mame/sharp/x1.cpp)
- [X Millennium libretro port](https://github.com/r-type/xmil-libretro)
- [neetan X1 documentation/emulation code](https://github.com/neetandev/neetan)

October 4 update: X Millennium was cloned to ignored
`references/emulators/xmil-libretro`, revision
`b07506c0cae31d260db28cb079148857d6ca2e93`. Its `io/crtc.c`, `io/crtc.h`,
`io/iocore.c` and palette paths were inspected for Turbo access/display banks,
blackclip, mode decoding and clock estimates. It agrees on SCRN bits 3/4 but
differs from MAME on SCRN readback/mirroring, and uses approximate high-resolution
timing. Those disagreements remain documentation/hardware review gates, not
permission to advertise full compatibility. It has not been built or run;
its source/asset licensing was not reconciled. At that checkpoint Neetan had
not been cloned; see the subsequent retrieval below.

October 9: Neetan is now shallow-cloned into ignored `references/emulators/neetan`,
revision `605452881bc725de6cffc7bf70ea5c9a7d783c5d`. Its X1 bus/interrupt,
FM decode/clock wrapper and sound tests were statically inspected, not built or
executed. The root BSD three-clause license was read; no code/assets are copied
into RTL. [FM IRQ/reference audit](../docs/FM_REFERENCE_IRQ_AUDIT.md) records
agreement on 4 MHz and differences in detection/optional CTC behavior, without
claiming native built-in IRQ wiring is resolved.

ROMs, BIOS images, fonts, disks, and tapes are not redistributed here.

October 15 macOS execution: the user supplied the existing sibling
`../common_source_code`, base commit `c0b9bccb972af2157da823fe28903c9f6e4af958`
with extensive existing local macOS/CPU work, and authorized adding an X1 CLI.
X1/Turbo/Z/MZ800/Twin now build in a separate output directory. X1/Turbo/Z
execute original CPU/RAM/PSG fixtures; the frozen CSP/RTL gate and real-mailbox
keyboard controls pass. Native CROSS/Arcus cold-repeat actual PNGs, traces and
memory; CROSS passes matched I/J movement. Arcus reaches an ARCUS-labelled
interface with synthetic virtual Kanji and PSG-only sound, not accepted native
gameplay. This working tree is distinct from the earlier sparse fork below.
[Builds, hashes, host-adapter fixes and scope](../docs/CSP_MAC_REFERENCE_STATUS.md)
include the observed IPL M1 wait-policy difference. No reference machine code
or private assets were copied into FPGA RTL.

The subsequent [HuBASIC reference/reset gate](../docs/BASIC_REFERENCE_RESET_STATUS.md)
executes eight fresh CSP cases with exact native arithmetic/LIST/RUN pixels,
retained reset, rejecting no-reset/no-Enter controls and cold repeats. CSP's
existing ANK and Caps defaults differ from the FPGA profile and are recorded
explicitly. Native SAVE/LOAD, graphics and broader BASIC releases remain open.
The separate [Turbo host-input observation](../docs/BASIC_IPL_MATRIX_STATUS.md)
preserves missing `7`/native Missing operand at 4/4 frames; 8/8 cold/repeat
gives exact `42` and missing Enter rejects. Real mailbox I/O supports the
delivery difference; no reference VM/FPGA timing change is made.

October 15: the user supplied an existing `~/Downloads/xmil026s` source tree
and archive. Thirteen Windows-source/reference files were inspected read-only
and matched to the archive, not built or executed. PCG fallback, high-speed
font rows/halves, SCRN and sub-CPU command paths are recorded in the
[local 0.26 audit](../docs/XMIL026_REFERENCE_AUDIT.md). This is source history
related to the existing X Millennium port, not an independent hardware oracle;
its virtual fonts are not relabeled as physical Z ROMs. No code/assets copied.

October 6 Kanji follow-up: inspected local Xmil `io/cgrom.c/.h`,
`vram/makechr.c`, `font/font.c/.h` and the existing local MAME Kanji CPU/video/
ROM conversion paths. Read the original [eX1/Common Source display source](https://github.com/Artanejp/common_source_project-fm7/blob/2f350e59869ad52293c768e08dd1e6137001486b/source/src/vm/x1/display.cpp)
through GitHub API at the linked revision, without cloning, building or
executing it. Its header attributes Kanji to X1EMU by KM and ANK16 to
X-millennium by Yui; these are not independent hardware measurements.
The [contract audit](../docs/KANJI_CONTRACT_STATUS.md) preserves CPU latch,
advancement, selection and font-format conflicts. No code or assets from
those implementations were copied into the original address-decoder RTL.

October 6 hardware-tool follow-up: downloaded Akira Amano's published
[X1turbo Remote Monitor v1.2.2](https://x1turbo-agency.hatenablog.jp/entry/2018/05/22/080623)
to a temporary reference folder and statically inspected only its monitor
binary/ROM dump routine with the existing `z80dasm`. It uses selector-cell
writes followed by high-speed CG reads; its author says exported fonts are
Shift-JIS ordered, not raw chip order. This is not an open-source emulator
addition, executed hardware acceptance or a resolved `0E80` contract. Package
hash, header/disassembly correction, instruction addresses and limits are in
the [Kanji audit](../docs/KANJI_CONTRACT_STATUS.md). The bundled copyright/
republication conditions were inspected; no binary, disassembly, disks or
third-party code are included in the repository.

October 6/7 native follow-up: actually executed the existing local MAME 0.283
binary with the user's matching IPL/ANK and supplied Kanji/font members,
protected disposable Arcus A/B copies, an original read-only Lua probe and
fresh private configuration paths. Two cold runs repeat exact CTC/CPU records
and actual PNGs, but reach the same black interrupt-handler state, not gameplay.
Binary/source distinction, failed attempts, hashes, font differences and limits
are in [the interrupt status](../docs/ARCUS_INTERRUPT_STATUS.md). No sibling
checkout, installed configuration or original asset was changed. X Millennium
now also executes from an isolated macOS libretro build with declaration-only
accommodations: two cold runs repeat actual frames/state records and progress
to garbled scenes, not gameplay. A separate original pending-retention adapter
repeats the same black handler state twice, isolating the phase-coalescing
policy's effect within that reference. No FPGA policy changed; see the interrupt
status for build/run/counterfactual provenance and the unresolved chip contract.

October 9: sparse-cloned [Common Source Project/eX1](https://github.com/Artanejp/common_source_project-fm7)
into ignored `references/emulators/common-source-x1`, revision
`2f350e59869ad52293c768e08dd1e6137001486b`, with X1 source and VM documentation.
This supersedes the earlier online-only retrieval status, not an execution
claim. Inspected X1 display control/palette-index/composition branches and the
X1 VM notes; did not build/run it or audit the entire repository. Its display
header credits Takeda.Toshiya and attributes Kanji/ANK origins to X1EMU and
X Millennium; `source/LICENSE.txt` identifies GPLv2, not a cleared ROM/font
redistribution license. No reference code or assets were copied into the core.
The [priority contract](../docs/TURBO_Z_PRIORITY_CONTRACT.md#additional-local-reference-ex1-composition)
records raw-code opacity, backdrop and reduced-index disagreements.
