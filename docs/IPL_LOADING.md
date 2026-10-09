# IPL loading and black-screen troubleshooting

Current builds expose **Load IPL** in the OSD (`F0,ROM,Load IPL`). The active
shared machine does not initialize its IPL RAM from a bundled ROM. Loading a
game D88 is not an IPL upload; launching an RBF alone without a separate ROM
can leave the machine with no usable boot program/video initialization.
Historical builds and older inherited machine paths may behave differently.

## Manual startup

1. Identify the exact RBF/revision being tested. Base X1 expects a **4,096-byte
   raw IPL**; a Turbo-foundation revision expects a **32,768-byte raw Turbo IPL**.
   Do not select a ROM merely because it belongs to some Sharp computer.
2. Place your matching IPL on the SD card as a `.rom` file. The current menu
   filters `.ROM`; MAME's `ipl.x1`, `ipl.x1t` or `ipl.bin` names will not appear
   under this filter. Rename/copy the matching **binary**, not its contents.
   A `.hex` text dump, ZIP/7z archive, ANK font or game disk is not a raw IPL.
3. Open the OSD and choose **Load IPL**. Then mount the game in **Drive A**.
   Use **Reset and close OSD** if needed. Do not use a font upload as a ROM
   upload; Turbo's **Load 16-row ANK** is a separate index-4 asset.
4. Record the visible IPL/search screen before treating a game failure as a
   disk or compatibility defect. Report the RBF and ROM hashes/sizes.

The local MAME driver distinguishes base `ipl.x1` (4 KiB), Turbo `ipl.x1t`
(32 KiB) and Turbo40 `ipl.bin` (32 KiB). Filename extension alone does not
prove machine compatibility. Existing hardware-qualified MGL tests explicitly
upload IPL at file index 0 and reset after their disk mount.

## Automatic startup

The inspected local MiSTer Main implementation tries `boot0.rom`/`boot.rom`
in the core's home directory and also supports explicit index-0 MGL file
uploads. For the normal `SharpX1` core home, place the matching raw IPL at
`/media/fat/games/SharpX1/boot.rom`, then reload the core. A custom MGL/setname
or customized games directory can change the effective home; do not assume
an unrelated folder or merely matching RBF basename guarantees autoload.
Use an explicit MGL upload or manual Load IPL to separate those cases.
Do not place incompatible multipart `boot*.rom` assets in this core's folder.

These paths are based on the inspected local Main source, not a new test on
the tester's installed Main/RBF. Private IPL bytes are not included here.

## Evidence and remaining diagnosis

The current wrapper forwards index-0 uploads to the shared machine, holds
reset during download and filters the base/Turbo address aperture. The focused
`make -C verilator test-loader` regression passes upload qualification, bounds,
no-wrap and RAM reset guards. This proves the shared loader's tested behavior,
**not** Main's file picker, HPS transport, this tester's RBF or their ROM.

For the reported black screen, obtain:

- Exact RBF filename/hash and whether **Load IPL** is visible in its OSD.
- Exact selected IPL filename, byte count/hash and raw-versus-text/archive form.
- Whether a boot ROM was uploaded before mounting the game; manual or MGL path.
- A screenshot after IPL upload/reset, before adding disks, and the installed
  Main version if file selection/upload still has no effect.

If Load IPL is absent, first establish that the tester is using the intended
RBF. If a correct raw IPL was actually uploaded and it remains black, the
missing-asset explanation is insufficient: investigate upload dispatch, reset
release, CPU boot and physical video on that exact build. No such tester
hardware success or confirmed root cause is claimed yet.
