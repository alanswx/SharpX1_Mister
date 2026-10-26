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

October 26: the same xmil-libretro revision now builds outside the checkout
(`git archive`, `SUPPORT_TURBOZ`/`SUPPORT_BANKMEM` via a forced-include overlay,
no source patches) and runs headless through our own frontend
`tools/xmil-cli`. X1, X1 turbo (15/24 kHz) and Turbo Z boot real disks to
title/menu screens with verified real ROM fonts. It is a secondary
reference; its font/text rendering is not hardware evidence. See the
[X Millennium runner status](../docs/XMIL_REFERENCE_STATUS.md).

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

October 18 compatibility follow-up: `scripts/mame_x1_headless.sh` runs the same
local MAME 0.283 binary headless (`x1` with the MAME `x1.zip` set; `x1turbo`
with the matching local `ipl.x1t` and placeholder turbo font/Kanji files). It
reproduced the Othello IPL reload loop while HuBASIC and Alien Egg controls
booted; see `docs/COMPATIBILITY_SWEEP_20261018.md`.

## October 20 CSP-audit reference retrieval

For the verification of [the CSP X1 audit](../docs/CSP_X1_AUDIT.md), retrieved
2026-10-20 into ignored `references/local/docs_20261020/` (checked with
`git check-ignore`). Nothing was executed; PDFs were only hashed, page-counted
with `pdfinfo` and rendered with `pdftoppm`. Which pages were actually read is
recorded in the verified audit report, not implied by retrieval. No scan is
committed or licensed for redistribution.

| Local file | Pages | SHA-256 | Source |
|---|---:|---|---|
| `01 X1-Techknow Table of Contents.pdf` | 5 | `569cc146d319f191f192288e864909c0a3d90dfebd0679bcde8e88d0d99a9931` | [Sharp-X1-Fun X1-Techknow](https://github.com/UnsatisfactoryResult/Sharp-X1-Fun/tree/main/Documents/X1-Techknow) (raw.githubusercontent.com, main) |
| `06 X1-Techknow Part 2 Chapter 1 System Overview.pdf` | 8 | `d0f996aa8c4b850891e02026f30d6598076966113194f2d03c08fecd14a53ef2` | same archive |
| `07 X1-Techknow Part 2 Chapter 2 Memory Configuration.pdf` | 8 | `b7dff54ff55327516080f66cadb7d8d700c145af5395f438994d4db56972ba42` | same archive |
| `08 X1-Techknow Part 2 Chapter 3 HuBASIC Structure.pdf` | 12 | `31c87bd3f08ac5cc372687cab52b116f15a27ded1dd846964f8c46512792cd63` | same archive |
| `14 X1-Techknow Part 2 Chapter 9 Various Interfaces.pdf` | 10 | `b1ce3f264987cc9f7d5e8eac78f84f271fbad06d24d12c8ee6985850b2fc915e` | same archive |
| `17 X1-Techknow Index.pdf` | 6 | `fe5fd6d2baa9b9b101a0c2c4a3e3dac0ab377796c989bdbee8077aed407161ff` | same archive |
| `CZ-856C_InstructionManual.pdf` | 80 | `dae0a988dde7ebbc970a9b40a6201a679211ffadf31231233625ac1c85207e56` | [eaw.app](https://eaw.app/Downloads/Manuals/Sharp/CZ-856C_InstructionManual.pdf) |
| `HLN014_HD46505R_CRT_Controller_Users_Manual.pdf` | 66 | `b665740ee59c71d51c01514ba882a0c11f0c3611f2baf66dbb1087586803f0ff` | [Bitsavers mirror](https://ftpmirror.your.org/pub/misc/bitsavers/components/hitachi/_dataSheets/HLN014_HD46505R_CRT_Controller_Users_Manual.pdf) |
| `Motorola_6845.pdf` | 23 | `84ae68617c23e3b3057dce86f4a04a5be5d890d108bce8e9bb928bfdd2759dcf` | [Bitsavers mirror](https://ftpmirror.your.org/pub/misc/bitsavers/components/motorola/_dataSheets/6845.pdf) |
| `x1center_sdx1_0_IO_map.html` | web page | `68a4a796ff39b0db39d10515ed92486d99524d15a021157739226c47512fa625` | [x1center.org "試験に出ないX1" chapter 0 I/O map, Ver.2018.7.18](http://x1center.org/sdx1/sdx1_0.html) (HTTPS failed with a TLS error; fetched over HTTP, 320,952 bytes, saved as data, not rendered with scripts) |

The x1center page is Mr. Sato's schematic-referenced I/O map (its header says signal
names follow the circuit diagrams and that undecoded-address details are incomplete).
CSP's wait tables also credit Mr. Sato, so it is not independent of CSP on those points.
The Techknow file sizes match the GitHub contents listing. Together with the
chapters already in `references/manuals/` and `references/local/research_20261018/techknow/`,
the local set now holds every file in that archive except Part 1 chapters 1-4
(graphics theory, graphics creation, stereographics, FM music). Web searches
for a Turbo Z ASIC register manual, an Oh!X/Oh!MZ register article and a
CZ-8KR (0E80) port description found nothing retrievable; none is claimed.
