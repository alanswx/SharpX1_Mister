# Base-X1 disk verification

The [Turbo 2HD plan](TURBO_HD_DISK_PLAN.md) separates address/index expansion
from native selector, density clock, RPM and format acceptance. The new
wide-D88 implementation and its original high-index CPU fixture are in progress,
not qualified 2HD support; ordinary runners and board defaults are unchanged.

The shared `rtl/sharpx1.v` instantiates a WD1793-family replacement with the
D88 image adapter, not a fully validated MB8877 implementation. Native IPL
read-only CROSS Chase boot remains one software compatibility example.
The newer [two-image increment](DUAL_DISK_STATUS.md) adds A/B mount slots,
independent head/motor state, selection rescans and owner-stable SD routing.
The historical single-image test description below is not a claim that B is
still unimplemented; an **unmounted** B remains not-ready. Hardware and exact
mechanical/controller timing remain unverified.

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

The stopped-enable reset regression is detailed in `RESET_STATUS.md`. ACK
history/completion now runs on every system-clock edge, not the emulated FDC
enable. The fixture stops CE during reset to match the shared machine; all
twelve cases still pass. Earlier constant-CE fixture results did not cover
that integration condition.
The generated-media machine suite now checks a 1 ms reset during scanning at
1 ms, then another at 50 ms after scanning: the mounted image is retained and
the original register-driven read/seek test still completes with byte-exact
data. All three simulator modes pass. This is scan continuation, not a proof
of safe eject/replacement or every scanner/host timing phase.

## Simulator media preflight

### Concatenated-container admission repair

The runner and strict RTL mount gate previously rejected the **total file**
at 1 MiB, even when its selected first volume was reachable. Both now separate
container size from selected-volume extent. Host preflight validates every
volume structurally; selected volume zero must remain below 1 MiB and the
whole file below the machine's 24-bit size-interface limit (16 MiB). Oversized
selected volumes remain unsupported, not silently masked into smaller disks.
This does not widen the sector index or implement 2HD density/timing.

`test_d88_bounds.py` passes 27 original/generated CLI cases, including exact
20-/24-bit boundaries, a larger reachable container, an unselected large
trailing volume and malformed oversized media. Rejected images leave sources
unchanged and create no requested disk copy, frame or dump. Passing log:
`/tmp/x1-d88-container-protected-cli.log`. The first extension failed at the
old caller's total-file check; `/tmp/x1-d88-capacity-cli.log` preserves that
failure, rather than claiming the helper alone fixed admission.

`test-d88-scanner` passes the existing direct-host matrix plus a 1,200,000-byte
container with a reachable 976-byte first volume: two index entries and the
exact selected end are required. An oversized selected header still rejects.
Log: `/tmp/x1-d88-container-scanner-build.log`. Rebuilding the **same current
fixture** against unchanged pre-fix RTL fails its large-container assertion,
log `/tmp/x1-d88-old-container-gate-negative.log`; old source SHA-256
`cfb85c62f69a1378f99d53d6dc84049be985ceb525e76da31d4d3e6561a48de6`.

From `verilator/`,
`python3 tests/test_disk.py obj_dir_headless/Vtop --large-container-only`
also completes zero. Its unchanged actual Z80 basic/read/write programs run
on a 1,049,568-byte container of 58 generated volumes, selecting the first
18,096-byte volume. Six payload reads and a 256-byte write/readback are required;
every byte of the exported whole container is compared, including all trailing
volumes and headers. Original media hashes remain unchanged. SYS 32 MHz / VID
28.571428 MHz, delay-aware, 8,000,000 reference cycles per case. Log:
`/tmp/x1-d88-large-container-machine.log`; frozen runner SHA-256
`0772cf0ef66675efc8abfc6c1b602617d934067bd195845e66ce3f5c4ecf206c`.
The ordinary full suite now completes zero in
`/tmp/x1-d88-container-baseline-suite.log`, including both CPU-programmed video
matrices, protected preflight, keyboard/reset, CPU/memory/CTC, generated A/B,
native FDC reads/writes/CRC/metadata and final disk-control/index checks. This
is the shared default RTL at the container repair, not a Turbo/Z hardware gate.
Native game, new-RBF and physical
large-container acceptance remain open; earlier frozen RTC/X3 game probes
predate this RTL repair and are not current-source qualification.

The subsequent [partial CPU-sector reset qualification](CPU_PARTIAL_DISK_RESET_STATUS.md)
passes 24 A/B read/write held/short cases at 1/64/255 bytes with live FM and the opt-in DMA
reset guard, but zero DMA transfers. Both whole images remain unchanged before
retry; the retained IPL completes 256 fresh CPU bytes. These are three
interruption points, not bare-base short-pulse, Ready-loss or physical acceptance.

### Structural preflight

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
These preflight checks cover every concatenated volume. Direct RTL validation
below covers the selected volume only. The simulator accepts D88 only for
`--disk`, not the vendor controller's reference EDSK/raw formats.

## Direct shared-RTL validation and media changes

The active machine now selects `wd1793.D88_ONLY=1`; inherited raw/EDSK fixture
profiles retain their original default. Invalid/unsupported containers never
fall back to raw geometry. Controller READY/status remain not-ready until the
selected volume passes the scanner. Guards cover declared volume bounds,
20-bit address overflow, full-width strictly increasing track offsets outside
the header, sector counts 1..255 with consistent per-track headers, N=0..3
matching payload lengths, track/volume payload extents, complete records and
the 1992-entry index limit. Tracks above the inherited 32-sector cap are no
longer silently truncated in strict mode. Concatenated trailing volumes are
not inspected by RTL when selecting disk zero; host preflight still checks all.

Replacement/ejection invalidates READY and cancels controller work, but keeps
an already published host request and its LBA until ACK drains. Only then may
the next image scan begin. A rejected image can be followed by a valid remount;
a stale scanner error cannot kill the new scan. Machine reset pauses scanner
work while ACK sampling continues every system clock. Mounted media and video/
main RAM are not reloaded to recover these tests.

`make -C verilator test-d88-scanner` deliberately bypasses C++ preflight. It
tests seventeen ordinary valid/malformed/oversize mounts, a concatenated first
volume, valid 33-sector track, index overflow, stalled pre-ACK replacement,
reset during scanner ACK, nine replay points across volume header/table/sector
header/payload (including held `scan_wr` without duplicate indexed records),
eject/remount, and replacement during a pending
controller read with CE stopped during reset. Requests never write media or
index beyond capacity; rejected images report not-ready. Existing Type IV and
twelve read/write reset/abort transport cases also pass. Generated machine
disk tests pass in delay-aware baseline and single-clock configurations.

This is RTL simulation, not malformed-image testing on MiSTer. Permanently
missing ACK remains quarantined: without an epoch/cancel contract, timing out
and reusing its request could alias a late completion or corrupt an accepted
write. Replacement during writes, exhaustive parser-phase resets, and physical
host fault injection remain open. Accepted host writes cannot be rolled back.

## Write safety

The simulator opens input images for reading only. `--disk-output NEW_COPY`
permits writes to an in-memory copy and exports it at the end; existing paths,
the original path and missing input are rejected. Export uses exclusive creation
to reject a path/symlink introduced while simulation was running. Pending writes prevent
export. Tests compare SHA-256 of the original and every byte of the output.
Snapshot restore re-applies explicit host protection; writable snapshots need
the corresponding exported media fingerprint. This is a development copy flow,
not filesystem crash consistency or concurrent-writer protection.

October 5 follow-up: `make -C verilator test-write-eject` passes two connected
FDC/descriptor variants for active A eject before ACK and during ACK-high of
an accepted sector write, with CPU/FDC CE stopped by reset. Owner/LBA and
buffer stay stable; the synthetic host drains the accepted write to retained
old-media storage, leaves B unchanged and rescans/recoveries pass. This is not
a physical HPS image-generation contract: a mount that changes the underlying
host file before the old write completes still requires host coordination.
No timeout cancels an accepted write, and no automatic rollback is promised.

MiSTer OSD defaults to **Disk writes: Protected**. **Enabled** only allows
writes when mounted media are not read-only. Board writes are wired but have
not been verified on hardware; use disposable media copies for bring-up.

## Remaining limits

The original suite covers drive A and base MFM/2D; the subsequent
[two-image increment](DUAL_DISK_STATUS.md) separately covers generated A/B
reads/writes and ownership/ACK draining. Exact command/byte/seek timing,
exact force-interrupt pin timing, deleted-write marks/metadata updates after writes,
per-sector density, format/write-track, hardware malformed-image rejection,
replacement during writes/all parser phases, permanent stalled-host recovery,
native multi-disk continuity and Turbo 2HD/2DD remain unvalidated or incomplete. Pending-sector SD
abort/reset is covered by the focused synthetic fixture, not hardware fault injection.
Selected-volume addressing is limited to less than 1 MiB; larger concatenated
containers do not widen it. Synthetic CRC flags do not
establish exact MB8877 behavior on bad ID/data fields. Do not mark the broad
storage milestone complete from these tests or a successful FPGA compile.

### Concrete remaining command contracts

Fujitsu's MB8876A/MB8877A datasheet, printed page 4-33, distinguishes
Read Sector bit 5 (deleted-data record type) from Write Sector bit 5 (write
fault), and distinguishes bad ID fields from bad data fields using CRC/RNF
status. The scanner now retains header byte 7's deleted mark separately from
the two CRC flags; local MAME's D88 format reader treats any nonzero byte 7
as deleted. The 57-bit sector index reports the selected record type through
Read Sector bit 5; every matched sector replaces that bit, and command setup
clears it. Generated CPU tests pass for byte-7 marks `10` and `01`, payload
readback, a subsequent normal sector, READ ADDRESS isolation, mixed
deleted/normal multi-sector reads and byte-8 `10` without a deleted mark.
No game media were used or modified. This does **not** implement deleted
writes, metadata updates or exact multi-sector CRC-stop behavior.
At the deleted-read checkpoint, generated tests demonstrated sticky CRC
reporting for A0/B0, not complete command semantics, and READ ADDRESS always
emitted a computed good ID CRC. The subsequent
[CRC increment](D88_CRC_STATUS.md) separates bad-ID search from data completion,
returns deterministic synthesized damaged ID CRC and copies C into SCR.
Its direct fixtures pass; final-source machine/game qualification and exact
physical command timing remain separate gates. Snapshots now require v05.

Deleted-read increment verification (October 5): expanded generated-media
suite passes with delay-aware baseline and single-clock models. Logs:
`/tmp/x1-d88-deleted-tests.log` and `/tmp/x1-d88-deleted-single-tests.log`.
Frozen baseline acceptance executable SHA-256:
`22c963187e028266bed212229b9a6a53d34adee8fe6ec34e670ea6f79db97d5d`;
single-clock executable:
`549e06cbffc563e1a7f5a51fbf31d4c493499e698b7bdd38c2fe88a8f6686268`.
Base runs retain 32 MHz system / 28.571428 MHz video; single-clock runs use
28.636364 MHz with compensated MR16 timer enables. Generated fixtures use
8,000,000 reference cycles, native ioctl diagnostics and read-only input
hash checks; writable cases use separate disposable output images.
Expanded controller/owner/eject/index unit regression and wrapper lint pass.
New index layout requires snapshot v04; the fast snapshot regression passes
continuity, input persistence, incompatible-version/time and truncated-header
rejection. Early header checks precede Verilator deserialization, avoiding
its trailer-check abort on exception unwinding. No older state is converted.
Fresh five-title v04 native requalification passes bounded baseline controls,
Shanghai pair removal and Galaga firing; see [source-bound evidence](COMMERCIAL_COMPATIBILITY.md).
The complete base diagnostic set now passes across retained logs: original
`/tmp/x1-d88-deleted-full-regression.log` stops at a 180-second mixed-video
host timeout; the same frozen executable passes that unchanged case with
900 seconds allowed in `/tmp/x1-d88-deleted-video-retry.log`, and every remaining
peripheral check passes in `/tmp/x1-d88-deleted-peripherals.log` (exit 0).
This is a completed set with one wall-time retry, not a single unbroken
`make test` success. No simulation durations/assertions were reduced.
This storage increment's FPGA audit is in progress; it has not been tested on
MiSTer.

Finish in this order, retaining default-profile and disposable-write checks:

1. Complete density/error metadata beyond the implemented deleted-read bit;
   retain normal/deleted/status-clearing/multi-sector tests.
2. Qualify the implemented bounded bad-ID search/READ ADDRESS and post-data
   CRC completion in the final machine and native software; direct fixtures
   now verify DRQ counts, CRC/RNF, INTRQ and subsequent recovery independently.
   Fujitsu's Type-II/III status table (datasheet PDF page 7) distinguishes
   bad-ID CRC with RNF from data CRC without RNF. Local MAME
   `wd_fdc.cpp::read_sector_continue()` skips a matching bad-CRC ID but
   continues multi-sector transfer after data CRC when RNF is clear; its
   READ ADDRESS path returns six bytes and records ID CRC failure. This
   conflicted with the inherited RTL comment saying real WD179x necessarily
   aborts a multi-sector read at CRC. That comment is removed; the increment
   follows bounded duplicate-ID recovery and sticky data-CRC continuation.
   Exact rotational timeout and pin timing are still unverified.
3. Update D88 mark/CRC metadata after successful normal/deleted sector writes,
   with protected/no-op, abort and cross-SD-block cases. Accepted writes may
   commit even when the controller aborts; never promise atomic rollback.
4. Specify supported WRITE TRACK tokens and bounded D88 reindex/reallocation;
   unsupported layouts must fail safely, not corrupt adjacent tracks/volumes.
5. Derive per-sector FM/MFM, 2D/2HD rates/index/seek/motor behavior from the
   selected model, not just the image header. Validate HD software and physical
   HPS same-slot replacement/ACK ownership separately.

Both baseline delay-aware simulation and the optional single-clock simulation
passed the generated-media suite. FPGA validation is separate; see
[Quartus build evidence](QUARTUS_BUILD.md).
Native read-only CROSS Chase boot and remote-key start are now observed on
MiSTer; see [hardware scope](HARDWARE_BRINGUP.md). INTRQ is not exposed by the
base machine, so hardware game boot cannot validate the force-interrupt output.
