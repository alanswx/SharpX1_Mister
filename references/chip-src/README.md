# Chip source snapshots

Collected 2026-10-02 for Sharp X1 integration research. Source files are
preserved with attribution and LF line endings. This directory is a staging
area; it is not automatically included in the X1 build.

| Directory | Source | Revision used |
| --- | --- | --- |
| `jt49/` | [jotego/jt49](https://github.com/jotego/jt49) | `47301ed51374d6d41db4db846b7643fecf75e417` |
| `jt51/` | [jotego/jt51](https://github.com/jotego/jt51) | `985a573dcfc1ff135553a39f7eae21d18ba57cbe` |
| `amstrad/` | [MiSTer-devel/Amstrad_MiSTer](https://github.com/MiSTer-devel/Amstrad_MiSTer), `rtl/i8255.v`, `rtl/UM6845R.v` | `6c2c39b6607fc870f5b60ca893c40fb9c873c81f` |
| `zxnext/` | [MiSTer-devel/ZXNext_MISTer](https://github.com/MiSTer-devel/ZXNext_MISTer), `rtl/device/{dma,ctc,ctc_chan}.vhd` | `7daebd1983ec4d04f4d22541d2f52d92badbbe5f` |
| `fm7/` | Local `../FM-7_MiSTer_alanswx/rtl/{wd1793.sv,wd1793_dpram.v}` | `57a82100b3997c9dd6c8ea2a3126cfbdf54e18cb` |
| `sharpmz/` | Local `../SharpMZ_MiSTer/rtl/i8255/i8255.vhd` | `611c4f8a9772c51c055d0dda45231c28633097cc` |
| `t48/` | Local `/Users/alans/Documents/development/newstart/MacLC_MiSTer/jtcores/modules/jtframe/hdl/cpu/t48/`, plus `cfg/cpu/t48.yaml` | `c0f7df4b1dceb73b2af9a1be96e29d579bf92455` |

Selected local files had no reported modifications relative to their source
checkout. JT49/JT51 snapshots include RTL, Quartus source lists, root README
and LICENSE; testbench/measurement assets are available in the local upstream
clones under ignored `../chips/`. T48 includes VHDL and system wrappers; the
upstream YAML's generated-Verilog branch is retained for provenance, but its
`t48_core.v` is not in this VHDL snapshot. The supplied Makefile uses the VHDL
branch's source order explicitly.

`zxnext/LICENSE.repository` is the original root license. Device headers use
GPL-3.0-or-later; `COPYING.GPL-3.0` supplies that license text from JT49's copy.
Use file-level terms, not the root license alone, when assessing reuse.

`SHA256.json` records hashes of imported files and the initial validation
Makefile. The hash index itself and this index are excluded from that manifest.

Run `make lint` here for isolated Verilator/GHDL source checks. See
[CHIP_REUSE.md](../../docs/CHIP_REUSE.md) for compatibility caveats, local
search results and the integration plan.
