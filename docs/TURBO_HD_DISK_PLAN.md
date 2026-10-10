# Turbo 2HD disk implementation and acceptance

October 10, 2026. This is a hardware-documentation-derived plan, not a claim
that current Turbo runners or boards support native 2HD operation.

## Inspected sources and limits

Local ignored references (preserve originals and distribution restrictions):

- `references/manuals/CZ-880_Service_Manual.pdf`, SHA-256
  `70a5f8da327ed25710e76d60117c4f82a655e6a7b29a34cb3239c75f0bd65a81`.
  Pages 3/6 describe built-in 5.25-inch 2HD/2D drives and selection before
  power-on. Page 27 distinguishes 5-inch 1-MB X1-format 2HD from standard
  2HD. It does not provide their sector geometry. Sheets 47/48 identify
  MB8877A, MB4107 and separate MFM/MIN/1.6M controls.
- `references/manuals/X1_Techknow_Appendix_A_IO_Map.pdf`, SHA-256
  `720c79f24169ad33ea91d5b4e2c32b98fab41c91430f226462eb254ac9e5505c`.
  PDF page 3, printed page 275: **IN** `0FFC` selects FM, `0FFD` MFM,
  `0FFE` the 1.6M/2HD class and `0FFF` the 500K/1M 2D/2DD class.
  **OUT** `0FFC` instead controls drive bits 1:0, side bit 4 and motor bit 7.
  The capacity labels must not be interpreted as bit rates.
- `references/manuals/MB8876A_MB8877A_Datasheet.pdf`, SHA-256
  `3358e0cefabb858261177d3f658c63db3f4142f9bfb826339135d5c19ab1b91b`.
  Page 2 specifies 2-MHz FDCCLK or 1 MHz for mini-floppies; DDEN low means
  MFM, high means FM, and must remain fixed during BUSY. The write-timing
  table gives 16-us MFM bytes at 2 MHz, 32-us FM bytes; 1 MHz doubles these.
  This is a chip contract, not proof of each X1 board's clock routing.

The local X Millennium `references/emulators/xmil-libretro/fdd/fdd_2d.c`
provides a **candidate**, not manufacturer-confirmed geometry:
154 tracks, 26 sectors, N=1 (77 cylinders, two heads, 256-byte sectors).
That is 4,004 sectors and 1,089,776 bytes including a 688-byte D88 header
and sixteen bytes per sector. Thus both a larger address space and a larger
sector index are necessary; changing only the 20-bit byte address cannot work.
The existing local MAME is a cross-check, not an authoritative resolution of
the selector labels: its driver logs the capacity-selection reads and does not
establish native density switching. Do not download another MAME checkout.

## Ordered work and proving evidence

1. Expand storage without changing ordinary defaults. The in-progress,
   opt-in `turbo-wide-d88` profile uses 24-bit addresses and 4,095 usable
   sector entries with a 12-bit index. Default remains 20-bit/1,992 entries.
   Preserve all metadata fields, ACK-owned LBAs and scanner bounds. Qualify
   high-address split-block metadata read/modify/write, high index 4,003,
   capacity/overflow rejection and ordinary snapshot layout. This profile
   is non-savable and is **not yet qualified**; no board enables it.
2. Implement the distinct IN capacity-selection latch alongside existing
   FM/MFM and OUT drive control. Test exact aliases, neighboring ports,
   reset policy and reads during BUSY. Resolve provisional behavior against
   another implementation and board documentation before claiming native
   selector timing. Do not substitute a boot-DIP write for the I/O latch.
3. Map the controller's enable-timebase to actual board FDCCLK. Keep clocks
   as enables where appropriate; independently count DRQ byte intervals,
   command timing and busy behavior in both density classes. An enlarged
   D88 mount at the existing fixed rate is not this gate.
4. Resolve drive RPM/index and low-current/mechanical selection separately.
   The present 800,000-enable index period at 4 MHz is 300 RPM. A generic
   emulator's 360-RPM HD policy is not proof of the installed Sharp drive.
   Obtain the exact drive specification or trace the documented route.
5. Verify original CPU-generated multi-track, both-head read/write/reset/
   abort cases, plus default and media-protection negatives. Preserve all
   other sectors and concatenated volumes byte-for-byte. Actual FM decoding,
   WRITE TRACK/format, unusual CHRN and density mismatch need explicit gates;
   they are not supplied by address/index widening.
6. Boot authorized native 2HD software with documented selector/drive order;
   record ROM/media/executable hashes, real output and input response.
   Only then qualify the source-bound board build, timing, actual disk mode
   and warm/cold operation on an available MiSTer. Preserve private originals
   and use disposable protected copies for hardware tests.

Track executed results in [DISK_STATUS.md](DISK_STATUS.md). None of the steps
above is complete merely because a diagnostic compiles or a D88 file mounts.
