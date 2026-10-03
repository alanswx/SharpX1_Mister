# Reusable chips for Sharp X1

Survey and imports: 2026-10-02. The implementation summary is saved separately
in [CHIP_IMPLEMENTATION_TABLE.md](CHIP_IMPLEMENTATION_TABLE.md). Source evidence
for the existing core remains in [CORE_STATUS.md](CORE_STATUS.md).

## Sources pulled into this repository

Candidate source snapshots are in `references/chip-src/`. They are not in the
active Quartus or machine simulation source lists. Original attribution is
retained; imports normalize line endings to LF. Source revisions are recorded
in that directory's README, with snapshot hashes in `SHA256.json`.

| X1 part | Candidate and saved location | Recommendation / integration work |
| --- | --- | --- |
| AY-3-8910 / YM2149 PSG | Jotego JT49, `jt49/hdl/` | First sound-chip choice. Use `jt49_bus` BDIR/BC1 interface or an explicit register latch around `jt49`. Map X1 PSG ports, supply the model-correct clock enable, wire both joystick I/O ports, scale/mix output and verify tone/noise/envelopes. |
| Optional YM2151 FM board | Jotego JT51, `jt51/hdl/` | Suitable optional FM candidate. Requires full-rate and half-rate enables, address/data port decode, status reads, timer IRQ handling and signed stereo output. Separate from base-X1 bring-up. |
| System 8255 PPI | Amstrad `amstrad/i8255.v`; SharpMZ `sharpmz/i8255.vhd` | Amstrad is convenient Verilog but has an explicit CPC tape-motor quirk and snapshot inputs. SharpMZ contains mode-1/mode-2 handshake logic and is the better candidate when complete PPI handshakes matter. Adapt pin maps and test mode changes/BSR/handshakes. |
| HD46505 / 6845-family CRTC | Amstrad `amstrad/UM6845R.v` | GPL-2.0-or-later candidate. Implements CPC type-0/type-1 behavior: compare X1 HD46505 register masks, readback, sync widths, interlace, start address and scanline behavior before selecting. CRTC alone does not implement text/graphics rendering. |
| MB8877A FDC and disk-image backend | FM-7 `fm7/wd1793.sv`, `fm7/wd1793_dpram.v` | Best local storage candidate: WD179x-style commands, write support, D77/D88 handling, image write-protect state and container disk selection. Adapt X1 ports/drive select/side/density, DRQ/IRQ, HPS image handshake and SD arbitration. MB8877 differences and exact timing need comparison. |
| Z80 DMA | ZXNext `zxnext/dma.vhd` | Candidate transfer engine, not a faithful drop-in Z80 DMA. Source explicitly warns of differences and exposes a compatibility mode. Review RDY behavior, command/readback support, cycle timing and daisy-chain/interrupt handling against X1 Turbo software. |
| Z80 CTC | ZXNext `zxnext/ctc.vhd`, `ctc_chan.vhd` | Counter/timer engine is available. Its header explicitly omits IM2 vector/interrupt implementation in the device and requires surrounding logic. Preserve X1 trigger wiring and implement interrupt acknowledge/priority/RETI. Existing X1 CTC and local MCR implementation remain comparison candidates. |
| 80C49 / MCS-48 MCU | T48 VHDL snapshot, `t48/` | Found in local Jotego JTFRAME sources. Offers an MCS-48 core and system wrappers as an alternative to MR16 firmware emulation. Need an 8049-appropriate ROM/RAM configuration, original MCU firmware or compatible replacement, pin-level host/RTC/cassette/keyboard wiring and timing tests. A CPU core alone does not supply the original firmware. |

All paths in this table are relative to `references/chip-src/`.

## Where else we searched

- `../FM-7_MiSTer` and `../FM-7_MiSTer_alanswx`: JT12/JT49 and WD1793.
  Selected FM-7_alanswx FDC files are clean relative to source commit.
- `../SharpMZ_MiSTer`: 8255, WD1793 and its RAM model; selected 8255 file is
  clean relative to source commit. Its FDC is closely related to the FM-7
  candidate, so it was not duplicated.
- `../CoCo3_MiSTer` and `../CoCo3_MiSTer_sys`: further WD1793 variants.
- `../Vectrex-development`: local JT49 implementation and QIP; also found
  copies in SegaG80V and Pandora's Palace trees under
  `/Users/alans/Documents/development` and `/Users/alans/Downloads`.
  Pulled upstream JT49 rather than selecting an older local revision.
- `/Users/alans/Documents/development/TangPrimer-25K-example/Arcade-MCR2_MiSTer/rtl/Z80CTC`:
  `z80ctc_top.vhd`, `ctc_counter.vhd`, `ctc_controler.vhd`. Top-level includes
  CPU interrupt acknowledge and RETI detection. No device-level license header
  was apparent in the inspected top; keep as a comparison candidate pending
  attribution/license review rather than silently relicense it.
- `/Users/alans/Documents/development/newstart/MacLC_MiSTer/jtcores/modules/jtframe`:
  T48 source and build-order configuration. Snapshot uses original VHDL with
  file-level notices rather than the generated Verilog translation.
- LisaFPGA's `t400_sio.sv` is COP400 serial logic, not Z80 SIO. Atari FujiNet
  SIO and Z8530/SCC implementations likewise do not establish Z80 SIO
  register/interrupt compatibility. They should not be substituted by name.

The source search covered RTL file names and relevant module declarations
under the sibling workspace and the other development trees. It is not a
claim that every file in every core has been audited.

## Gaps that remain after collecting chip RTL

| Part | Result / next work |
| --- | --- |
| Exact Z80 SIO | No suitable exact RTL implementation found in the inspected local trees or targeted online search. Use local MAME `src/devices/machine/z80sio.cpp` as a behavior reference and the chip manual to guide an implementation or continued search. |
| uPD1990 RTC | No matching RTL candidate found. Decide whether original serial pins are needed or host-synchronized RTC behavior through sub-CPU commands suffices. Generic MSX/PC RTC chips are not interchangeable. |
| Text/attribute/PCG/GRAM renderer and palette | X1-specific glue must be implemented or recovered from the inherited path. Reusing a 6845 gives addresses and timing, not rendering, wait states or multi-plane writes. |
| Keyboard/sub-CPU behavior | T48 does not replace missing ROM contents or keyboard protocol. MR16 route still needs its work-RAM and disconnected interfaces repaired. |
| Tape transport, APSS and signal decoder | No connected X1 implementation found. Existing CPC tape handling may inform buffering, but CPC CDT encoding is not an X1 tape decoder. |
| Kanji/font ROMs | A storage/presentation interface and appropriately sourced font assets are still needed. The fake Kanji register is not a solution. |
| HPS storage, SDRAM, audio/video delivery | Framework parts exist; machine-specific adapters and clock/enable/reset wiring remain necessary. |

JT12/YM2203 was found in FM-7, but it is not the X1's base PSG or optional
YM2151 board and was not imported as a replacement for either. JT89/SN76489,
6821 PIA and arbitrary DMA blocks are similarly different devices.

## Verification and integration order

```sh
make -C references/chip-src lint
```

Verilator 5.044 lint passed for JT49/JT51, Amstrad PPI/CRTC and the FM-7 FDC in
both RAM and SD backend modes. GHDL analysis passed for ZXNext DMA/CTC,
SharpMZ 8255 and the T48 core in source order. Amstrad PPI has CASEX warnings;
FDC has width warnings; ZXNext CTC has a name-hiding warning. Warnings are
visible and nonfatal for the Verilog checks. T48 system wrappers were saved
but are not all analyzed by this target.

These are syntax/dependency checks, not functional tests or FPGA resource and
timing measurements. No candidate has been connected to the X1 machine yet.
The active implementation summary therefore remains unchanged.

Repair the existing CPU, IPL and memory wiring first. Then integrate JT49,
system PPI, CRTC plus X1 rendering, and floppy/media support. Add Turbo CTC/DMA
after the base machine boots; keep FM and Turbo Z work behind separate feature
choices. Use isolated wrappers when candidates reuse module names such as
`dpram`; do not add all imported RTL to a single compilation indiscriminately.

## Source licensing

JT49/JT51 and ZXNext DMA/CTC carry GPL-3.0-or-later notices. Amstrad candidates
and FM-7 WD1793 carry GPL-2.0-or-later notices. SharpMZ 8255 and inspected T48
core files carry BSD-style attribution/redistribution terms; preserve all
file-specific notices. ZXNext's root license is GPLv2 while these device files
specify GPLv3-or-later: the snapshot retains both and records that distinction.
Importing candidates does not resolve the restrictive notices in existing
Nise X1 code or determine a combined release license.
