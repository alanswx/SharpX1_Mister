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
the corresponding exported copy's fingerprint on restore. A bounded dual
writable checkpoint now passes below; interrupted-write/rollback qualification
remains open. Read-only acceptance below
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
new host snapshot acceptance. The full new fast baseline suite also completes
exit zero (`/tmp/x1-dual-base-test-fast.log`), including existing snapshots and
the SDL adapter. No FPGA RTL, fitted artifact or machine ports are changed here.

### Committed writable-media checkpoint

`test_dual_write_snapshot.py` passes both A-first/B-second and B-first/A-second
profiles. Original CPU programs fill distinct RAM patterns, perform real
1024-byte DMA writes and DMA readback, and compare every payload byte.
At 175 ms the first drive's payload/metadata ACKs have fully committed and
the CPU publishes a marker and delays. The quiescent snapshot includes that
drive's **new** fingerprint. Restore uses the exported disposable copies,
then writes/readbacks the other drive; the final 500 ms reports, five RAM/CPU
dumps, all 4096 DMA reads/writes/grants and both entire exported images match
uninterrupted execution. Host requests/writes/sync edges match exact additive
counts. Both originals and checkpoint copies stay unchanged.

The original pre-write media are rejected as stale on restore, including
the extra B fingerprint when B commits first. Restoring without output-copy
authorization overrides both saved writable pins: the original CPU takes its
expected error branch on the second drive's protected write, with zero new
host writes and unchanged copies. This qualifies both A and B protection
overrides, not rollback or host cancellation. Logs:
`/tmp/x1-dual-write-snapshot-a-final.log`,
`/tmp/x1-dual-write-snapshot-b-first.log`; the Make target retains both full
profiles in `/tmp/x1-dual-write-snapshot-target.log`. All exit zero.

## Native provenance and remaining gates

`continue_native_probe.py` now forwards the original B path on every restore
and rejects a parent continuation dropping/changing B. Asset/runner/state
SHA-256 checks remain. The asset-free collector mock passes forwarding,
no-ROM/font/RAM-reload and dropped-B-parent rejection before output/runner
creation (`/tmp/x1-continue-native-dual-mock.log`); this is plumbing, not
RTL/native game acceptance.

A fresh protected two-drive sixteen-second Arcus savable probe completes
with the unchanged Turbo IPL/ANK16, original exploratory A1/B2 assignment,
32 MHz system / nominal X3 video, DMA on and Kanji off. Outputs are ignored
`output_files/arcus-dsw-f1-dma-x3-dual-state-sixteen/`, log
`/tmp/x1-arcus-dual-state-sixteen.log`, exit zero. Both independent cold
reports/dumps/frames/**state hashes** match, and all original inputs are
unchanged. Each completes 57,344 DMA pairs, 2,914 host requests, zero host
writes and 913 actual 640×400 frames; black frame `03702d99714c4325` is not
gameplay. The sixteen-second native save/repeat gate passes; continuation
to 32 seconds succeeds via the frozen runner and original A/B media,
without ROM/font/RAM reload. All five RAM/CPU dumps match the independent
fresh 32-second non-savable run byte-for-byte. DMA totals, CPU address and
actual final frame agree; host counters remain invocation-relative and are
not compared as if they were cumulative. The 48-second continuation also
completes exit zero with unchanged inputs, 76,800 cumulative DMA pairs,
zero new host requests/writes during that chunk, and the same black final
frame. This is native continuation acceptance, not gameplay. See the
[read-only graphics observation](VIDEO_OBSERVATION_STATUS.md) for the
separate storage/palette inspection. Private outputs:
`output_files/arcus-dma-dual-continuation-32-48/`; log
`/tmp/x1-arcus-dual-continuation.log`. The earlier old-runner dual-state
refusal remains preserved. The separate non-savable sixteen-second probe
now repeats exact reports/dumps/trace/frame hashes with unchanged inputs;
its black final frame is not gameplay. The 32-second non-savable probe
completes both independent cold runs with identical reports/dumps/trace/frame
hashes and unchanged original inputs. Each completes 76,800 DMA pairs and 2,971 host
requests with zero writes; the final real 640×400 frame is still black, not
gameplay. CPU/GRAM activity continues in the 30–31.5 second trace, including
SCRN `63`; do not label it a CPU HALT or fix a video mapping without stronger
evidence. Further owned-transfer/ACK/interrupted-write/B-only snapshots and native game
input/continuation still require acceptance; this does not close disk or
Turbo/Turbo Z work groups.

Hosted CI run `37559760439` (`944b57e`) fails its first machine DMA IRQ
execution: the log shows `-GTURBO=1` in the C++ compiler flags, consistent
with the already-corrected empty `-CFLAGS` parsing bug. Linux compiled the
wrong profile instead of the macOS compile-time rejection; no failing
assertion was removed. IRQ fixture failure messages now include return code
and stdout as well as stderr. The later corrected CI runs remain live, not
claimed green. Mixed-pixel run `37557293544` ends cancelled after about 45
minutes, not completed acceptance; the expanded job now has its previously
documented 90-minute limit with unchanged test durations/assertions.
