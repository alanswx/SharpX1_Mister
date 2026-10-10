# Connected Turbo D88 capacity matching

October 10, 2026. `turbo-hd-media` is a separate non-savable, delay-aware
experiment enabling Turbo foundation, wide D88 storage, `TURBO_HD_SELECT`
and `TURBO_HD_MEDIA`. All ordinary/board defaults remain disabled. It is not
native 2HD byte-rate, drive-mechanical, format or software acceptance.

## Implemented functional matching

The real CPU's IN `0FFE/0FFF` selection now reaches the strict D88 indexed
controller. Optional metadata captures byte `1B` relative to the selected
volume's base on the exact accepted scanner strobe. It is not captured from
an arbitrary absolute file offset or gated with CPU CE. The selected type
is retained through controller reset like the index/write-protect metadata;
new mounts already quarantine access until a complete valid scan.

Low selection accepts D88 types `00` (2D) and `10` (2DD); high selection
accepts `20` (2HD). Other byte values do not match this explicit prototype.
Medium matching follows the local Common Source X1 capacity-class distinction;
it is not a manufacturer-derived interpretation of all unusual dump flags.
Wrong class rejects sector read/write and READ ADDRESS with RNF, without
turning a present spinning drive into NOT READY. Type-I head movement remains
independent. Search/rotation delay is not native: rejection currently uses
the inherited functional search path, not five measured index revolutions.

The new vendor input is inactive in ordinary integration. Its added top-level
vendor port can change a standalone controller serializer interface, even
when defaults are unchanged. Default internal-state checks therefore require
an identical legacy-port wrapper, while whole-machine snapshot v17 identity
must be checked separately. Do not normalize or patch saved state bytes.

The first build failed because an optional generate block was inserted among
the inherited parser's procedural local declarations. The correction captures
the class inside the actual parser and leaves all existing scopes/order intact.
Final controller source under test:
`2affa0bd8a6bf504247dd917a86902508c1efb8f5e6143f2e90706f438a6b75a`.
The inactive metadata register is constant/dead in default profiles; generated
state identity is an acceptance gate, not assumed from this observation.

## Executed and running gates

Three original real-CPU fixtures run against the frozen delay-aware executable
`fcb350da3ce459f5905717c6398b71dded47ad32f2d713279fe7f1d5a1e9a645`:
types `00`, `10` and `20`. Every case first selects the wrong class, requires
RNF without NOT READY for read/write/READ ADDRESS, then selects correctly
and requires exact read/write/readback beyond 1 MiB. The `10` case uses the
4,004-sector geometry, physically seeks to cylinder 76 and side 1, and accesses
index 4,003. All media/neighbor bytes and originals must remain unchanged
except the exact permitted output payload/metadata. Actual selection INs must
return `FF`. All three runs now finish **exit zero**, with unchanged original
inputs and exact expected output copies. The `00/20` cases each perform
2,048 actual CPU reads/1,024 payload writes; the `10` geometry case performs
512 reads/256 payload writes plus its real SEEK target write. Wrong-class
commands add no payload transfer. Evidence directories in `obj_dir_v17_hd_media`:
`cpu-wide-3c55fsiy` (00), `cpu-wide-4_it4q63` (10), `cpu-wide-tkn7yw_4` (20).

Logs: `/tmp/x1-hd-media-cpu-hd20.log`, `/tmp/x1-hd-media-cpu-low00.log`,
`/tmp/x1-hd-media-cpu-dd10.log`. The standalone selected-volume/class/reset
and default-state gates now pass independently. Ordinary fast regression
subsequently completes exit zero at `/tmp/x1-hd-media-default-fast.log`,
including executed ordinary snapshot, CPU/video/disk/reset and transport cases.
It is the no-timing fast profile, not delay-aware or hardware timing acceptance.
Build isolation already passes across all 31 shared C++ recipes with actual
parent-object rejection; `/tmp/x1-hd-media-isolation.log`. No new suppression
or blanket timing exception is added.

The frozen standalone suite passes 35 cases in each of four runs: matching
enabled/disabled and CE dividers 1/8. It verifies concatenated selected-volume
headers, drive rescans, retained reset, payload/writeback, READ ADDRESS CRC,
unknown types 30/FF, wrong-class RNF without DRQ/SD traffic, and independent
SEEK/RESTORE. Main checks all four current source hashes against the frozen
manifest and reads all four completion logs. Evidence:
`x1-fdc-capacity-class-h9uqbreq/sources.json` in the local temporary directory.
Reproduction: `test-fdc-capacity-class` uses the explicit qualified vendor hash.

Default internal-state comparison against `3c34dd0` passes four profiles
through the identical original-port wrapper, SHA-256
`f68f38807c355825ce382c057003578dc40b1736ddb77e95d2a5a74e71d4bea4`.
The wrapper does not edit either vendor or saved states. Main's final helper
rerun also passes at `/tmp/x1-hd-media-default-state-final-fixed.log`.
An independent ordinary whole-machine audit uses identical 104-source lists
and finds all five headers and three serializers/checksums byte-identical.
Main independently compares these eight generated files directly; evidence
`/tmp/x1-hd-class-state-HnNXo6/comparison.json`. These are default state-identity
gates, not enabled-profile snapshot or native chip acceptance.

## Remaining native work

Commands that change density/class during BUSY,
native FDCCLK routing, byte/DRQ/deadline pacing, FM decoding, RPM/low-current,
format/WRITE TRACK, authorized native HD software and source-bound board tests
remain open. No guessed BUSY deferral or native clock divider is introduced.
The earlier claimed MB4107A pin-assignment mismatch is withdrawn: the
original MB4107 manufacturer scan has now been retrieved and the relevant
MIN/CK/DW pin table visually read. Use the original chip source rather than
assuming suffix equivalence. Its documented MIN-to-CK selection does not yet
prove the Sharp ASIC's capacity-to-MIN logic; see `FDC_VFO_CLOCK_STATUS.md`.
See [the full HD plan](TURBO_HD_DISK_PLAN.md),
[CPU selector scope](HD_CAPACITY_CPU_STATUS.md) and
[wide-storage qualification](WIDE_D88_STATUS.md).
