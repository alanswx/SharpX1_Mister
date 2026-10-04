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
