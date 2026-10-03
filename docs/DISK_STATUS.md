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
aborting an outstanding host SD request or conditional `$D1/$D2/$D4` semantics.
The inherited controller also clears INTRQ on every status read, whereas local
MAME retains it when the immediate force-interrupt mask is active; verify that
distinction against MB8877 documentation before claiming exact `$D8` behavior.
The local MAME `src/devices/machine/wd_fdc.cpp` `interrupt_start()` provides the
cross-check for a zero force-interrupt mask. Imported source notices and sibling
reference snapshots remain unchanged.

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
conditional force interrupts, deleted-data marks, metadata updates after writes,
per-sector density, format/write-track, malformed-image rejection, eject/reset
during transfers, drive B and Turbo 2HD/2DD remain unvalidated or incomplete.
Image addressing is limited to less than 1 MiB. Synthetic CRC flags do not
establish exact MB8877 behavior on bad ID/data fields. Do not mark the broad
storage milestone complete from these tests or a successful FPGA compile.

Both baseline delay-aware simulation and the optional single-clock simulation
passed the generated-media suite. FPGA validation is separate; see
[Quartus build evidence](QUARTUS_BUILD.md).
