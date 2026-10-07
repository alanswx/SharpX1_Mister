# Experimental Sharp X1 hardware test handoff

Recommended candidate: the October 6 local build, source-bound to FPGA inputs
of `889f23c`. No hardware testing has occurred on this artifact yet.

[sharpx1_turbo_single.rbf](../output_files/quartus-L7gRiDWX/source/output_files/sharpx1_turbo_single.rbf)
is 3,860,876 bytes. SHA-256:
`0a996f49c67e585fe63351659db068260fbb779e3be67c51ba7f6d6d571a632e`.

This is the partial Turbo foundation, **single 28.571428 MHz board master with
clock enables**. It is not the X3/400-line candidate or full Turbo/Turbo Z.
DMA and its completion IRQ, Kanji glyph rendering, SIO and FM are not enabled
by this revision; the existing Turbo CTC/sub-CPU interrupt path is distinct.
All eight analyzed corners pass constrained timing; external I/O, PLL startup/
loss-of-lock, CDC and physical acceptance remain open. Full build evidence is
in [the source-bound report](CURRENT_SOURCE_QUARTUS_STATUS.md).

## Test safely

Use a uniquely named core copy. Preserve installed cores/configuration and
original media. Use disposable disk copies, initially write-protected in OSD;
FAT permission bits alone do not enforce write protection. Use the usual
authorized IPL/BIOS and a known base-X1 disk; do not bundle ROMs or games with
the RBF. Record the BIOS and disk hashes/configuration. Hardware availability
must be coordinated before loading; the travelling owner has not released a
remote MiSTer again.

1. Cold-load the core and boot a known disk. Record the visible screen and how
   long boot took; black/garbled output is a failure to investigate, not success.
2. Check physical keyboard input immediately after cold boot, without first
   opening OSD or resetting. Record keyboard model and Caps Lock/Shift state.
3. Enter actual gameplay and verify controls. CROSS Chase is a known earlier
   checkpoint reference, not proof that this artifact boots it. Commercial
   games need their own result; Arcus/Bastard are not accepted gameplay yet.
4. Use OSD **Reset** while gameplay is running. The core should restart and
   accept input without reloading the RBF, IPL or disks. Repeat from a halted/
   waiting screen, and during an active disk load if safe with disposable media.
5. Repeat with **Reset and close OSD**. Distinguish Main's command delivery
   from machine restart. If either fails, capture the screen/LED/activity and
   exact menu action before reloading the core as recovery.
6. Check both disk slots independently and a two-drive title/configuration
   whose disk order is known. Arcus Disk 1 A / Disk 2 B is exploratory, not an
   established required arrangement. Keep original media untouched.
7. Record HDMI/VGA mode, audio output, unusual glitches and repeatability over
   several warm resets. Actual sound/video measurements remain separate gates.

Report the RBF/BIOS/media hashes, MiSTer Main version, cold/warm sequence,
keyboard/configuration, disk assignments and actual screenshots. A screenshot
filename is not proof of its contents. Do not summarize an OSD-reset failure
as fixed just because a direct simulated reset passes.

Existing scripted deployment/capture instructions are in
[hardware bring-up](HARDWARE_BRINGUP.md). They use unique names and protected
disposable copies and do not replace installed user assets.
