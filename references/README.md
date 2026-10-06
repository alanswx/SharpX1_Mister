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
its source/asset licensing was not reconciled. Neetan has not been cloned.

ROMs, BIOS images, fonts, disks, and tapes are not redistributed here.

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
