# Base-X1 disk verification

The shared `rtl/sharpx1.v` instantiates a WD1793-family replacement with the
D88 image adapter, not a fully validated MB8877 implementation. Native IPL
read-only CROSS Chase boot remains one software compatibility example.

Original generated D88 media and original Z80 fixtures in
`verilator/tests/test_disk.py` verify the actual machine bus/controller/SD path:

- CHRN data matching, physical seek/restore/step-out, both sides, track mismatch,
  missing-sector RNF, and multi-sector reads through the end of a track.
- 128/256/512/1024-byte reads and 256/1024-byte write/readback. Cross-512-byte
  host-block writes preserve every neighboring header and data byte.
- Computed READ ADDRESS ID CRC; D88 ID/data CRC status flags; sticky lost-data
  after deliberately missing DRQ, and clearing stale errors on a new command.
- Default host protection and D88-header protection prevent SD writes.
- Drive-A selection, other-drive not-ready, and FM selection rejection followed
  by MFM recovery. Global FM rejection is not support for actual FM media.

`disk_control_tb.sv` verifies side/drive/density decode, motor hold/restart/reset.
The 1.2-second hold is accelerated to 12 cycles in that bench, not simulated
as a full real-time mechanical motor. `fdc_index_tb.sv` measures a 200 ms index
period and 2 ms pulse in 4 MHz enable ticks, plus Type-I head-load status.
The inherited controller previously cleared lost-data on later bytes and used
an unrelated short index period; this integration now preserves the error and
selects the X1 index/head-load configuration without changing upstream snapshots.

`fdc_abort_tb.sv` reproduces and fixes a busy `$D0` abort that incorrectly raised
the ordinary completion interrupt. Idle/busy `$D0` now clears BUSY/DRQ silently;
`$D8` still interrupts. The register-level fixture also verifies a subsequent
normal completion, status-read acknowledgement and reset. This does not cover
aborting an outstanding host SD request by itself. The fixture now also verifies
`$D1/$D2` only trigger on the selected READY transition, `$D4` waits for an index
rising edge, conditional sources stay armed after acknowledgement, and a normal
command or `$D0` cancels the mask. `$D8` remains asserted across status reads,
following Fujitsu's Type IV exception and local MAME's immediate-mask handling.
The test's index period is accelerated to 1000 enables; the separate index bench
still checks the actual 800,000-enable period. Pin-level command timing and
simultaneous event/read edge priorities are not established by these fixtures.
The local MAME `src/devices/machine/wd_fdc.cpp` `interrupt_start()` provides the
cross-check for a zero force-interrupt mask. Imported source notices and sibling
reference snapshots remain unchanged.

`fdc_sd_abort_tb.sv` adds twelve original raw-media transport cases: reads and
writes, `$D0` and reset, before ACK and while ACK stays high, including reset
held through completion. It reproduced
premature abort completion before the fix. Requests now latch their LBA,
continue draining through reset, and cannot be reused by an ordinary command
until the old acknowledgement has fully cleared. The fixture checks stable
pending-write buffer samples, quiet DRQ/INTRQ, and a subsequent fresh-address
read. `$D0` holds BUSY while draining; this adapter safety policy is not a claim
of exact MB8877 pin timing. Reset clears controller BUSY but temporarily rejects
ordinary commands while transport drains. An already accepted host write can
still commit; abort/reset cannot roll it back. No ACK timeout or media-change
recovery is implemented by this change.

## Simulator media preflight

The headless/SDL runner validates D88 before constructing the machine or opening
an output disk. `d88_image.h` checks volume sizes, track offsets, sector headers,
counts and payload bounds for every concatenated volume. It distinguishes
structural corruption from layouts unsupported by the forward-only scanner:
non-increasing offsets, counts above 255, more than 1992 indexed sectors, or
lengths inconsistent with supported N=0..3 sectors. Original generated CLI tests
cover mixed sizes, concatenated volumes and truncated/out-of-range records,
checking that source bytes remain unchanged. Successful preflight is not a boot
or compatibility test. Copy-protected irregular layouts may be valid D88 but
unsupported here. CRC/deleted-data/density flags are not certified by preflight.
These are **host checks only**: direct MiSTer mounts still need equivalent RTL
validation and error/not-ready recovery. The simulator now accepts D88 only for
`--disk`, not the vendor controller's reference EDSK/raw formats.

## Write safety

The simulator opens input images for reading only. `--disk-output NEW_COPY`
permits writes to an in-memory copy and exports it at the end; existing paths,
the original path and missing input are rejected. Export uses exclusive creation
to reject a path/symlink introduced while simulation was running. Pending writes prevent
export. Tests compare SHA-256 of the original and every byte of the output.
Snapshot restore re-applies explicit host protection; writable snapshots need
the corresponding exported media fingerprint. This is a development copy flow,
not filesystem crash consistency or concurrent-writer protection.

MiSTer OSD defaults to **Disk writes: Protected**. **Enabled** only allows
writes when mounted media are not read-only. Board writes are wired but have
not been verified on hardware; use disposable media copies for bring-up.

## Remaining limits

Only drive A and the base MFM/2D path are covered. Exact command/byte/seek timing,
exact force-interrupt pin timing, deleted-data marks, metadata updates after writes,
per-sector density, format/write-track, board malformed-image rejection,
eject/remount during transfers, reset during scanning, stalled-host recovery,
drive B and Turbo 2HD/2DD remain unvalidated or incomplete. Pending-sector SD
abort/reset is covered by the focused synthetic fixture, not hardware fault injection.
Image addressing is limited to less than 1 MiB. Synthetic CRC flags do not
establish exact MB8877 behavior on bad ID/data fields. Do not mark the broad
storage milestone complete from these tests or a successful FPGA compile.

Both baseline delay-aware simulation and the optional single-clock simulation
passed the generated-media suite. FPGA validation is separate; see
[Quartus build evidence](QUARTUS_BUILD.md).
Native read-only CROSS Chase boot and remote-key start are now observed on
MiSTer; see [hardware scope](HARDWARE_BRINGUP.md). INTRQ is not exposed by the
base machine, so hardware game boot cannot validate the force-interrupt output.
