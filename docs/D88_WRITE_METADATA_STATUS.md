# D88 sector-write metadata increment

October 5, 2026. Active machine path: `rtl/sharpx1.v` →
`rtl/vendor/wd1793.sv`. This implements sector-container semantics, not
flux reconstruction, raw-track formatting or exact MB8877 pin timing.

## Publication and ownership contract

Type-II writes retain the selected index entry, index address, sector-header
offset and command a0 deleted/normal choice. A usable ID is still mandatory;
C/S comparison and damaged-ID duplicate selection are unchanged.

All payload block writes must finish their host ACK drains before a separate
header read/modify/write begins. Byte 7 is canonicalized to `00` for normal
or `10` for deleted data. Byte 8 is repaired only from data CRC `B0` to `00`;
other dump-status values and all neighboring bytes remain unchanged. No
metadata is published for a protected or rejected sector, incomplete CPU
collection, or a payload transfer aborted before publication.

The header may be in the preceding payload block; bytes 7 and 8 can also
straddle two 512-byte host blocks. Each metadata block is read afresh, edited
and written independently. The corresponding cached deleted/data-CRC field
changes only on that block's actual ACK drain. Thus an interrupted split
header can have a committed deleted mark and still retain its old data CRC;
the live index and a subsequent remount must agree. It is not an atomic
filesystem transaction.

Metadata ownership covers gaps between host requests, preventing a drive
rescan/new command from reusing the shared buffer or index. Host LBA and
buffer bank remain stable through accepted ACKs. Reset and D0 cannot retract
an already published write: it may commit while the FDC enable is stopped.
Eject suppresses stale index publication and further writes; the test host
retains the old medium for the outstanding request. Real HPS replacement
epochs and rollback are not implemented by this policy.

## Lost data and unsupported commands

The [FD179X manufacturer datasheet](https://bitsavers.trailing-edge.com/components/westernDigital/FD179X-01_Data_Sheet_Oct1979.pdf),
PDF pages 12–13, distinguishes missing the first write byte from later
underruns. The strict D88 adapter aborts an initial timeout without flushing
any payload or metadata. Later missing bytes are explicitly zero-filled and
lost-data remains sticky. A CPU byte already accepted before watchdog expiry
wins over zero fill; held WR must finish rather than silently replacing it.
Only a completely collected/flushed deterministic sector can repair CRC.
This is a bounded functional policy, not proof of exact Fujitsu timing.

READ TRACK remains rejected with RNF. WRITE TRACK previously completed as a
successful no-op; an original fixture reproduces status `00` where rejection
was required in `/tmp/x1-d88-track-before.log`. Strict D88 now reports
write-fault with no DRQ or host write. This is an explicit unsupported-adapter
policy, not an implemented formatter or claimed silicon response to a track
stream. Implementing safe bounded format still requires a reviewed track
token/geometry/container-update contract.

## Original tests and qualification

`make -C verilator test-d88-metadata` builds an original generated-media unit.
It drives actual registers, scanner and synchronous SD buffer; no private
game/firmware, forced index entry or debug RAM stimulus is used. Read-only
hierarchical observations assert that complete index entries change only at
their owned metadata ACK commits.

The first 60 groups pass at CE=1 and CE=1/8; parent independently reproduced
them in `/tmp/x1-v06-other-units.log`. Coverage includes 128/256/512/1024-byte
sectors, unaligned payloads, preceding/split header blocks, canonical and
noncanonical marks, preserved non-B0 status, protected host/container,
bad-ID duplicates, multi-sector writes, same-mount and remounted readback,
first/later lost data, watchdog/accepted-byte race, and D0/held-reset/eject
before/during payload and metadata ACKs and header reads. The later track
rejection cases bring this to 62 groups. Parent then reproduced a short reset
pulse ending before metadata ACK drain leaving `metadata_busy` stuck;
`/tmp/x1-metadata-reset-pulse-reproduce.log`. Cancellation is now retained
independently of controller state until the host ownership drains. Expanded
75-group tests pass at both CE rates in
`/tmp/x1-metadata-reset-pulse-after.log`, including short pulses during
payload/header reads and writes before/during ACK. Accepted writes may still
commit; the fix releases ownership without publishing another block.

Existing CRC, force-interrupt, twelve SD abort/reset, scanner-boundary and
active-A eject tests also pass with the first metadata implementation; log
`/tmp/x1-v06-storage-final.log`. The new actual CPU metadata and remount
fixtures in `test_disk.py` await final-source fast/delay-aware execution.
An isolated final v07 fast-machine CPU case already passes a 1024-byte
cross-block deleted write, B0 repair, FDC readback and byte-exact disposable
image preservation in `/tmp/x1-metadata-cpu-large-fast.log`: 8,000,000
reference cycles, 32 MHz system / 28,571,428 Hz video, 205 original diagnostic
download bytes, 269 reset edges, four host writes. Its CRTC is unprogrammed,
so zero frames are expected. This focused case is not the complete matrix.
The matrix fixtures retain 8,000,000 reference cycles and disposable output
images; they do not modify original media.

The next savable machine uses v07, rejecting v06 and older states rather than
converting them. Frozen source `76d87a2`/v05 native game tests do not qualify
this subsequent metadata or high-speed PCG change. No current-source Quartus
fit or physical MiSTer test is claimed.

The initial combined diagnostic binaries/log directories were labelled v06
during development. Because commit `473a5fe` had already published v06 for
the smaller side-compare state layout, the final guard advances to v07.
Initial diagnostic snapshots must be regenerated, never converted. This
header-only guard change does not alter controller command behavior.

Final controller SHA-256:
`cfb85c62f69a1378f99d53d6dc84049be985ceb525e76da31d4d3e6561a48de6`.
Final v07 baseline fast/SDL runner SHA-256:
`c87b79ae39b36b1954cd8e8b5f249e87a063e3ddecc0bdf11d70ef251886bac4`.
V07 snapshot continuity, rejected v06 header, clocks and SDL joystick
tests pass in `/tmp/x1-v07-snapshot-final.log`; base timing/FST and both
base/X3 wrapper lint also pass, with inherited warnings visible. These checks
are not Quartus/CDC or hardware acceptance.

## Remaining storage gates

Raw track/format, density/FM and HD mechanics, physical index/rotational and
DRQ timing, native disk-change/copy-protection behavior and HPS file epochs
remain open. The primary FD179X multi-record CRC termination policy differs
from the adapter's currently tested sticky continuation; resolve that
chip-specific discrepancy separately, not by changing this write path.
