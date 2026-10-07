# Two-drive simulator snapshots (October 6/7)

The runner now supports quiescent two-drive snapshots under its explicit
savable build. The single-drive v12 header remains byte-for-byte unchanged.
Dual-media headers use a separate bit-42 identity and an extra ordered
B fingerprint after the existing A fingerprint; the model and clock checks
are unchanged. Both supplied media must match before deserialization.
No old snapshot is converted or patched to bypass compatibility checks.
Media stay external: ROM/game bytes inside private states must not be shared.

This does **not** serialize a pending host SD request. Save still requires
a falling reference edge, released reset, idle ACK/cooldown/request host,
and quiescent keyboard/download interfaces. The RTL may still have work to
do, but the host must be drained. Both restored write-protect inputs follow
their explicit disposable-output choices. Changed writable media require
the corresponding exported copy's fingerprint on restore; dual writable
snapshot/rollback qualification remains open. Read-only acceptance below
does not imply rollback of an accepted write or hardware-state save support.

## Executed checks

`test_dual_snapshot.py` uses original generated distinct A/B N=3 sectors
and a real CPU program loaded as IPL. It reads/checks 1024 bytes from A,
publishes a RAM marker and delays using CPU instructions. At 175 ms, the
quiescent snapshot has 1024 real DMA pairs and an executing CPU, not HALT.
Restoring it selects B and reads/checks another 1024 bytes. The 500 ms result
exactly matches uninterrupted execution: all non-host report fields, 2048
DMA reads/writes/grants, both complete destination payloads and five RAM/CPU
dumps. Host requests/writes/sync edges match exact additive totals.

Missing B, changed A, changed B, swapped distinct media, and loading a
single-drive state as dual all fail closed before model deserialization.
Both original media remain unchanged; zero host writes. Log:
`/tmp/x1-dual-snapshot.log`, exit zero. The full existing A/B disk fixture
also passes on the new X3 savable runner, including head/register retention,
protected B, disposable A/B writes, B-only mounts and cold repeats:
`/tmp/x1-dual-disk-savable.log`. These tests do not imply dual writable
snapshot acceptance. The old universal dual-snapshot rejection case is
replaced by this positive/negative actual-snapshot fixture, not merely removed
to claim support.

The existing base single-drive snapshot/clock/joystick diagnostic passes
(`/tmp/x1-dual-single-snapshot-regression.log`). The full delay-aware baseline
suite also finishes exit zero (`/tmp/x1-dsw-baseline-suite.log`), on its frozen
pre-dual host runner; that proves the preceding DIP machine checkpoint, not
new host snapshot acceptance. The full new fast baseline suite is still
running. No FPGA RTL, fitted artifact or machine ports are changed here.

## Native provenance and remaining gates

`continue_native_probe.py` now forwards the original B path on every restore
and rejects a parent continuation dropping/changing B. Asset/runner/state
SHA-256 checks remain. The asset-free collector mock passes forwarding,
no-ROM/font/RAM-reload and dropped-B-parent rejection before output/runner
creation (`/tmp/x1-continue-native-dual-mock.log`); this is plumbing, not
RTL/native game acceptance.

A fresh protected two-drive sixteen-second Arcus savable probe is running
with the unchanged Turbo IPL/ANK16, original exploratory A1/B2 assignment,
32 MHz system / nominal X3 video, DMA on and Kanji off. Outputs are ignored
`output_files/arcus-dsw-f1-dma-x3-dual-state-sixteen/`, log
`/tmp/x1-arcus-dual-state-sixteen.log`. Native save, repeated cold state hashes
and continuation have not been accepted yet. The earlier old-runner dual-state
refusal remains preserved. The separate non-savable sixteen-second probe
now repeats exact reports/dumps/trace/frame hashes with unchanged inputs;
its black final frame is not gameplay. The 32-second non-savable probe remains
live. Further owned-transfer/ACK/writable/B-only snapshots and native game
input/continuation still require acceptance; this does not close disk or
Turbo/Turbo Z work groups.
