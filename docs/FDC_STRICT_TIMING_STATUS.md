# Default-off controller byte-timing integration

October 10, 2026. Original experimental bridge in `rtl/vendor/wd1793.sv`.
An opt-in shared-machine connection is under qualification; neither it nor
the standalone gates establish native MB8877A timing or board acceptance.

## Implemented experiment

`STRICT_D88_TIMING=1` requires the SD-backed indexed strict-D88 configuration.
The trailing `fdc_ce` input is an explicit nominal chip-clock event, separate
from the existing controller/bus `ce`; no capacity-derived rate is invented.
No ordinary board or runner enables this parameter. Disabled shared-machine
profiles tie the new input inactive while preserving the legacy controller enable.

The bridge connects the previously standalone byte scheduler, external-DR
stream, raw bus-event capture and held completion lease. The existing SYS
process remains the only physical data-register owner. Read arrivals update
it even when controller CE stops. Idle/non-DRQ DATA writes still store there;
write underrun zero belongs to DSR/staging, not physical DR. Captured bus
responses remain stable through held strobes and serial activity.

Caller address/DIN must remain stable through acceptance and raw release must
be observed on SYS. `transport_idle` is host-transport availability, not proof
that a cached stream has finished; future dual-drive/machine integration must
retain media-change cancellation rather than assuming BUSY and transport
availability are interchangeable. Independent review finds no blocking issue
under these explicit contracts.

The existing 2,048-byte sector staging RAM prefetches the entire payload before
starting the fixed stream. Unaligned 1,024-byte payloads may use three SD
blocks. Payload bytes retire on SYS independently of the slow state-machine
consumer. Its completion result waits for CE and cancellation must invalidate
the lease before it can advance the write/metadata state machine. Existing
ACK-owned SD requests still drain through SYS during reset or abort.

The initial write request has an explicit experimental deadline: 32 future
chip enables after prefetch/arm. Early service cannot rephase launch. Missing
first service aborts without payload/metadata writes. This is **not** the native
ID-CRC/write-gate gap. Reads and later writes use fixed 32-enable MFM slots;
last-service tails and arrival/store tie priorities are digital policies,
not measured native failure edges or guaranteed-service maxima.

## Verification state

The earlier frozen 98-case fixture produces four positive completion logs at
nominal 1/2 MHz and low/above-1-MiB media addresses:
`/var/folders/sv/859j7h856t5gzg1kv3nnqdj40000gn/T/x1-fdc-strict-timing-915_vzyw`.
Those logs are historical; the checker subsequently changed and they do not
qualify the current expanded test. The fresh 102-case run now completes zero:
four configurations, 408 counted cases and nine matched rejecting mutations.
Main reads all positive markers and each exact negative assertion, then checks
all eight frozen/current source hashes unchanged. Evidence:
`/var/folders/sv/859j7h856t5gzg1kv3nnqdj40000gn/T/x1-fdc-strict-timing-44x5qdrs`.
The earlier 915 and o2 attempts failed overall and are retained; the accepted
run reuses neither. Each low-address configuration reports 239 SD requests,
each high-address configuration 2,287; each reports 57 SD writes.
Both fixtures use original generated media and real host SD/register activity,
not forced controller state or private game images.

The expanded fixture checks six-byte READ ADDRESS against an independent CRC,
payloads 128/256/512/1024, unread replacement, later zero fill, missed initial
prefill with no writes, stopped-CE completion, held bus responses, CRC/deleted
metadata and reset/Type-IV cancellation in prefill/stream/pending-result and
SD payload/metadata ownership phases. Whole-medium comparisons include
neighboring bytes and already-published writes that cancellation cannot undo.
Negatives reject changed prefill, CE-gated staging, missing metadata stores,
zero mirrored into physical DR, stale cancelled completion, live/repeated held
reads, service-rephased slots and dropped stopped-CE initial-abort completion.
Build failure or timeout is not a qualifying rejection.

In `915_vzyw`, the held-read mutant correctly fails `held STATUS response
changed`, but its checker expects a different diagnostic string. In
`o2rfjasw`, service-paced scheduling escapes all 98 positive cases because
service happens before the first future chip edge. The expanded fixture adds
17-chip-edge-delayed service; the same mutant now fails the unchanged cadence
assertion. These are preserved checker/coverage failures, not hidden production
passes or a relaxed timing oracle.

Default-off CRC/metadata fixtures separately complete at CE dividers 1/8,
including 75 metadata groups per divider. Main reads their actual logs and
manifest under `x1-fdc-strict-legacy-hv4znxma` in the same temporary root.
Both new Make targets are scheduled in CI; no hosted success is claimed.
The current strict-disabled vendor also repeats all 140 standalone capacity-
class cases (check 0/1 × CE divider 1/8) in `x1-fdc-capacity-class-4tfemxe5`;
Main checks the real PASS markers and frozen/live hashes before updating the
Makefile's approved source pin. The standalone fixture still has an unused
trailing-input PINMISSING warning; generated-state compatibility is qualified
only through the explicitly tied actual machine/original-port wrapper.

| Frozen source | SHA-256 |
| --- | --- |
| WD controller | `e04791cce6887ef5c3981f0c9c1cf6b5efe083bbd43813845afaca3dc25ca820` |
| Expanded fixture | `ee286fb86aa4247bd9f75217d1c0eefa9215820d1bc94244a99df17f9e63b3bc` |
| Timing checker | `2d825b58a2abcfdf7337e5769f07881d9d6a47aa41e0861d939d55b6a1914fdd` |

Default-state review reproduces a real integration defect: an unconnected
`fdc_ce` becomes generated savable state. Explicit production `.fdc_ce(1'b0)`
removes that difference. Main independently compares all eight base/Turbo
generated headers/serializers against `c744767`, byte-identical, with snapshot
C++ unchanged and no new FDC PINMISSING warning. Evidence:
`/tmp/x1-fdc-actual-machine-audit.lD06TK/manifest.json`.
The original missing-port failure and scratch diagnostic remain under
`/tmp/x1-fdc-state-review.9qN4Bx`; no state-byte conversion is performed.

The four-profile vendor original-port check also passes with an internal
constant tie, not a new public savable input. Inherited warning messages remain;
these are generated-state checks, not runtime restore or enabled-profile proof.
The current default headless build and 200,000-reference-cycle smoke finish;
the full default fast/snapshot regression now completes zero with 144 PASS
markers in `/tmp/x1-fdc-strict-disabled-fast.log`. Its runner SHA-256 is
`cb3670e97f9a5f25d57510ccda8ef44fa4416d314ad6ba6e8b13e784851a1ec8`.
The broader ordinary delay-aware `make test` also finishes with exit zero and
149 PASS markers in `/tmp/x1-fdc-strict-disabled-timing.log`. Its runner SHA-256
is `b405612b16ee40e47c41fa95a8b865ef5c79ce1abc12e7ea86bb0de528dd5c00`.
These default-disabled regressions do not qualify the enabled bridge through
the actual CPU/DMA path or on hardware.

## Shared-machine candidate (not yet a transfer acceptance gate)

`TURBO_FDC_TIMING=1` now connects the bridge through `rtl/sharpx1.v` and
`verilator/sim.v`. The four helper sources belong to `rtl/machine.qip`.
`FDC_CLOCK_HZ=1000000/2000000` uses fixed SYS32 counter enables independent of
CPU/DMA ownership; it does not map the capacity latch to FDCCLK. Turbo and
the ordinary 32-MHz system profile are required; single-clock and other rates
are rejected. No board revision selects this parameter.

`make -C verilator turbo-fdc-timing FDC_CLOCK_HZ=1000000 FDC_TIMING_DMA=0`
builds the non-savable delay-aware runner in a rate/DMA-specific directory.
The 1-MHz CPU and 2-MHz DMA candidates build and complete 200,000-reference-cycle
smokes with explicit JSON identities. Without an uploaded IPL or disk these
smokes produce no frames or disk requests and are not transfer/game tests.
The enabled runner rejects snapshot requests before creating a state file.
Actual CPU/DMA, dual-drive and cancellation fixtures are being prepared.
The fresh `test-machine-fdc-default-state` gate freezes the actual updated
manifest/RTL/top and compares all eight default base/Turbo generated headers
and serializers against c744767. They are byte-identical; each profile retains
60 inherited warning messages with no additions. Frozen evidence:
`/var/folders/sv/859j7h856t5gzg1kv3nnqdj40000gn/T/x1-machine-fdc-default-state-igj_w1xt/comparison.json`.
This qualifies generated state after the helper-manifest connection, not
runtime restore or enabled transfer behavior.

The connected-source ordinary headless build and 200,000-reference-cycle smoke
complete zero. Its fresh default fast/snapshot regression also finishes exit
zero with all 144 PASS markers in `/tmp/x1-fdc-machine-connected-default-fast.log`;
runner SHA-256
`b75923cfecb0658479c8e325bee054447469d6f06896f5d27d7b4cb175db8609`.
No enabled bridge profile is exercised by this default regression. Invalid
4-MHz FDC rate execution reaches the explicit profile fatal, an invalid DMA
setting is rejected before building, and the snapshot rejection creates no
state file. These are separate guard checks, not enabled transfer acceptance.

Independent inspection finds the existing media glue asserts `changing` before
updating the active drive, so the vendor cancellation suppresses serial stores,
arrivals and completion consumption while the old SD ACK owner drains. Coupled
stream/reselection tests remain required. READY-only loss is not a justified
automatic stream-abort contract: WD FD179X-01 (October 1979) PDF pp8/11/12
samples READY at Type-II command entry, without a READY decision in the payload
loops or multi-record continuation. PDF pp14/15 separate armed Type-IV READY
transition interrupts from live inverted-READY status. Fujitsu MB8877A (October
1986, PDF pp3/6/7) defines eligibility, transition interrupt conditions and
status, but does not establish automatic mid-transfer termination. Its stated
compatibility is FD1793-02; the -01 flowcharts are family evidence, not measured
Fujitsu silicon equivalence. Local MAME `wd_fdc.cpp` lines558/941 and1463
corroborate command-start checks and transition IRQs without automatic abort.
Evidence/hashes: `/tmp/x1-ready-contract.Sf40b2/evidence.md`; original PDFs
remain ignored under `references/manuals/`. No proposed READY-abort patch is
made. A bare `!ready` cancellation would also strand the waiting FSM after
discarding its completion. Existing search/pre-flush readiness rechecks remain
implementation policies, not qualified native sampling points.

The first existing `test_disk.py` CPU run at 1 MHz passes its basic and large
container reads, then reaches its 250-ms limit during the deleted-mark
multi-sector case, with 15 of the 16 multi-record sectors serviced. Preserve
`/tmp/x1-machine-fdc-timing-cpu1m-disk.log`; it is a failed bounded run, not a
completed suite. A rerun adds only an explicit 16,000,000-reference-cycle
(500-ms) case budget, keeping the default 8,000,000 unchanged and every payload/
status assertion intact. The same frozen runner hash is
`c244826e3f9da196276431ceb4e3ce7b7f8a1d0d849b4e8af977c99c27ca76cc`.
The full rerun now finishes exit zero with 40 PASS reports (including its final
summary) in `/tmp/x1-machine-fdc-timing-cpu1m-disk-16m.log`. This includes the
formerly failing deleted-16 case, variable/multiple-sector/deleted reads,
warm reset, side/READ ADDRESS/CRC/RNF/density/status isolation, protected and
cross-block writes/readback, metadata/remount and dump CRC cases. Original
media hashes and every payload/status assertion remain unchanged. This is
actual CPU/SD coverage at the explicit 1-MHz experimental rate, not DMA,
native MB8877A failure-edge/mechanical timing or board acceptance.

The first connected-source ordinary delay-aware `make test` stops at the
intentional runner-coverage assertion: its 31-recipe inventory excludes the
new 32nd FDC recipe. Preserve `/tmp/x1-fdc-machine-connected-default-timing.log`;
it is not a completed regression or an RTL failure. The reviewed fixture now
requires exactly 32 recipes and explicit FDC rate/DMA flags and isolated
default paths. The actual nested-object isolation check passes with the same
matched parent-reuse negative in `/tmp/x1-fdc-machine-isolation-32.log`.
A stronger four-profile expanded-Make-command gate now passes ten exact
mutation rejections: missing `-B`, aliased directories/Mdir, conflicting or
mismatched RTL/C++ rate/DMA flags. It checks every CFLAGS group and four
distinct expanded directories, not a literal-name count. It is connected to
`test-runner-build-isolation`; the combined actual-object/dry-run gate finishes
zero in `/tmp/x1-fdc-machine-isolation-expanded.log`. This proves configuration
and object isolation, not four actual machine compilations. The full ordinary
delay-aware rerun now finishes exit zero with 149 PASS reports in
`/tmp/x1-fdc-machine-connected-default-timing-repaired.log`; runner SHA-256
`005a6902deb46051706e6b49cbc3e0ae86d9fa8d4a4c2fe5dc4075f4436fcfbd`.
The expanded four-profile gate is also qualified separately as above.

## Native software boot through the candidate

The frozen 1-MHz CPU runner (`c244826e...ca76cc`, full hash above) completes a
15-second native CROSS Chase run through ioctl-loaded checked-in IPL and the
existing authorized read-only disk. SYS=32 MHz, video=28,571,428 Hz, reset spans
4,159 SYS edges, IPL download=4,095 bytes; the run services 763 SD requests and
no writes. Standard startup PS/2 input sends 24 bytes; actual RGB captures 926
frames at 320x200. Main verifies release-specific RAM player `(22,14,1)` and
the real text-RAM `*` at that coordinate, then visually inspects the PNG.
This is a native game-screen boot, not a commercial-game count.
A second cold 15-second run with late I/J input now
terminates exit zero: 30 PS/2 bytes, the same 763 SD requests/no writes and
926 frames. Main checks the player moves from `(22,14,1)` to `(21,13,1)`,
the corresponding real text-RAM `*`, and changed captured RGB bytes. This
qualifies actual keyboard movement through this frozen candidate, not native
timing or hardware acceptance.

Ignored evidence: `output_files/fdc-native-cross-7Ri8Vj/`, including inputs,
log, RAM/text dumps and original PPM/converted PNG. All four before/after input
hashes match; originals and snapshots are not changed or committed.
PNG SHA-256 `e5abb689da1426e7fce294fbfa1c520beef31c2778ed5a5dcd19f657ac760755`;
PPM SHA-256 `9befdf3c3984765778a143e58f138b06938e4ce53a1e1e3a7ebe2e739fc74d07`.
Movement evidence uses the same directory's `move.log`, `move.ram/text`,
`late_move.keys`, and `move.ppm/png`; all four input hashes match before/after.
Movement PNG SHA-256
`aa4d9a1411348998fe247510bb7a1290c5049e237ff386361d13fcd5625f0f25`;
PPM SHA-256
`2c8614bffc839be168f1d59d4b7ffcfc43c51e27fa6b70968a483074ecc064a9`.

A separate 15-second cold repeat terminates zero (Main session 99080), with
the same frozen executable, ROM, disk and late-key script. The retained
`check_repeat.py` checker also terminates zero: full progress/JSON log and all
six outputs (RAM, text, attributes, CPU, sub-CPU RAM and PPM) match byte-for-byte.
Player `(21,13,1)`, actual text marker, 763 reads/no writes, 30 PS/2 bytes,
926 frames and frame hash `d54e64069df6d555` match. All four input hashes still
match; no snapshots are loaded or converted. Repeat log SHA-256
`d6e8b1b6d8e8892376fc8dde4e26510f687cd231e8a8b03bb8626f0595eee879`.
This establishes exact cold repeatability for this one homebrew/profile only.

## Actual CPU/DMA fixed-clock qualification

The new original public-port fixture qualifies 128 full cases across nominal
1/2 MHz and width20/24, plus 28 cancellation/reset cases and three exact
rejecting controls. All nine driver exits zero are recorded from the worker's
actual tool sessions in `/tmp/x1-fdc-machine-handoff.ZF0PCz/HANDOFF.md`; no
separate outer-driver log was retained. Independent review verifies all 999
source comparisons, all 159 regenerated IPLs, nine executable hashes and
exact per-case result/negative markers in the retained logs. Main then runs a
fresh four-case 1-MHz A/B CPU/DMA gate, terminal exit zero including final
integrity checks, in `/tmp/x1-fdc-machine-main-fresh.log` and frozen directory
`/var/folders/sv/859j7h856t5gzg1kv3nnqdj40000gn/T/x1-machine-fdc-timing-lwrbesna`.
Main's new bounded Make target subsequently finishes exit zero on both 1M/20
and 2M/24 (eight cases total), including final frozen/live source checks;
log `/tmp/x1-fdc-machine-bounded-target.log`. The bounded target is scheduled
in CI; no hosted result is claimed from that scheduling edit.

Stable fixture/checker hashes:

- Fixture: `65225d5356ee3670f2a820b8fa5e111d87588331500018d28a1b09d2c8d9928e`.
- Checker: `8f74ef25baab3ebc60ba25336c111de961970b673862680cfb6826957952acf7`.
- Shared machine: `fa81ec13a3266c8dada97715b5cfaaa5b31f64c7674c01c5fca04312c7a84f67`.

`test-machine-fdc-timing` is the bounded two-profile gate;
`test-machine-fdc-timing-full` runs all nine qualifications. Each freezes the
actual manifest sources, fixture, checker and emitter; original IPLs are
generated from the frozen emitter, uploaded through ioctl, and self-check RAM
using genuine CPU instructions. Hierarchy is observation only. No forced
state/grants/Ready, private firmware, fake IRQ or external CPU bus is used.
Negatives reject disabled timing, wrong clock, and Ready tied active at their
specific assertions, not compilation errors or timeouts. Only the actual
mutated source is checked against its alternate recorded hash.

Sizes128/256/512/1024, A/B and byte/continuous/burst DMA check exact DATA counts,
bus pairs, guards, DRQ removal and real request/ACK ownership entry/release.
Independent host oracles check each published 512-byte store and both complete
media images. Payload starts at 1032; 1024 bytes span three SD blocks. Width24
cases here still use low addresses, not >1-MiB media. Serial arrivals/DSR loads
advance every 32 independent chip events, never on CPU service. CPU1M uses
polling transfers; CPU2M deliberately misses a read, checks sticky lost-data
and recovers with DMA. This is not general successful CPU polling at 2 MHz
or proof that every optimized CPU loop is impossible.

Cancellation covers active-drive mount, CPU reselection and reset during
ACK-owned read/write payload traffic on A/B, preserving published LBA/drive/
buffer through drainage. Owned-DMA reset observes stopped CPU/upload wait,
exactly one already-started pair retirement, release and native-IPL recovery.
Idle BUSRQ-high/BUSACK-low ownership tails remain legal. CPU1M/128 observed
DRQ-to-accepted-DATA maxima are 16.09375/17.84375 us (read/write), from SYS
observations, not native pin timing or silicon failure-edge measurements.
Earlier failed fixtures and changed assertions remain documented in the handoff.

## Cached-stream and pending-completion cancellation

The separate original `fdc_timing_media_machine_tb.sv` fixture and frozen
`test_machine_fdc_timing_media.py` driver pass 24 cases: both drives at 1 MHz/
20-bit and 2 MHz/24-bit. They use public ioctl, mount/reset and SD pins with
genuine CPU firmware; hierarchy is read-only coverage observation. No private
RAM, state, CE, Ready or CPU transactions are injected. Sources are held stable:
SV SHA-256 `cc031203eaec8ab3c97c639a4e553a2fcd44a6d462f002ecd1d5c6d6cb5750f6`;
driver SHA-256 `f47ae3911ec93b0eddd1c3d7147a0abf4c27a18a7fad52c79124a2bd42d7e808`.

Cached read/write cases require CPU reselection with host transport idle and
the stream still active, partially serialized, without a pending completion.
Pending read/write cases first observe an actual valid completion before its
normal controller consumer CE, then drive public reset or active-drive mount.
They require no stale consume/store/arrival and no unpublished prelude flush.
This exercises the real short completion window, not artificially stopped CE.
Recovery reads both original media, writes/readbacks the selected payload,
checks RAM guards/status and independently predicts every published SD byte.
Both whole media are checked against that publication ledger; neither observed
DUT data nor metadata seeds the prediction. CPU2M uses real DMA, including
exactly two initial stores for cached-write service, not a general polling pass.

Worker terminal exits zero: sessions 92281/27898, frozen
`x1-fdc-media-machine-7p_v8fh1` / `5ivhv6hr` under the system temporary directory.
Cached-cancel and completion-cancel mutated-source controls reject at their
specific cancellation assertions (sessions 92671/7014, `mfd92akc`/`78r53ixs`),
not compilation failures or timeouts. Main's fresh 12-case 1-MHz rerun also
terminates zero with final source checks, frozen `pifrywv2`, log
`/tmp/x1-fdc-media-main-fresh.log`. Main's fresh 2-MHz/24-bit 12-case rerun also
terminates zero with final source checks: `_5ayo1oi`, session 87672, log
`/tmp/x1-fdc-media-main-fresh-2m.log`. Both fresh rejecting-control drivers
terminate zero after the intended runtime assertion: cached `dbdsqcxm` /
session 80841 and completion `9xb2jo8u` / session 86166. Logs are
`/tmp/x1-fdc-media-main-negative-cached-cancel.log` and
`/tmp/x1-fdc-media-main-negative-completion-cancel.log`.
Independent review finds no blocking defect for this bounded claim, verifies
the worker's four folders (452 source comparisons, byte-exact regeneration of
all 26 IPLs from frozen emitters, four executable hashes, order/arguments and
exact terminal markers). Build logs contain 61/66 warnings; none name the new
fixture/helpers or missing `fdc_ce`, but this is not warning-clean acceptance.
Earlier failed CPU2M-prefill and erroneous zero-length
DMA fixture attempts remain preserved; production RTL is unchanged.

`test-machine-fdc-timing-media` runs both complete positive profiles;
`test-machine-fdc-timing-media-full` additionally runs both rejecting controls.
The positive target is scheduled in CI, not claimed as a hosted result.
Main separately inspects all four fresh artifact sets: 452 live/frozen source
comparisons, 26 ROM hashes, four executable hashes and every terminal record
match, with only the explicitly recorded negative source allowed to differ.

## Exact consumer-CE, final-store and prefill boundaries

The separate original boundary fixture/checker now pass 24 positives: six
scenarios on both drives at 1 MHz/20-bit and 2 MHz/24-bit, plus five exact
rejecting mutations. Production RTL and both older qualified fixture pairs
are unchanged and hash-protected. Source hashes:
SV `3499bdf58335f5da14b79a8b4ec9aa4fb8c1247ad1d5054a44eca892598bb4ac`;
driver `26f9b5d428f4d7cdfe0799c695578b7e2761a1a0855ccdce86d2164135896bcb`.

Read/write consumer collisions prove real `valid && ce && taken` eligibility,
then apply only active-drive mount before that same SYS edge. The fixture
requires `valid && ce && cancel`, suppressed taken, a cleared lease and no
old publication. Pending-final-store cancellation observes emit/index255
with 255 retired stores, mounts before the next retirement and suppresses
store256. Prefill cancellation observes armed/DRQ before the deadline, with
zero accepted DATA writes/emits/stores, then requires arming to clear. No
runtime reset, forced CE/state, invented Ready or private RAM injection is used.

Uncancelled controls require completion consumption and all 256 stores;
distinct final-byte sentinels, real CPU readback/guards and independent
per-block/whole-medium/padding ledgers prevent cancellation from hiding an
already-broken write path. Five matched mutants reject cancelled taken,
cancelled final-store eligibility, retained prefill arming, last-byte
misaddressing and payload corruption at exact runtime assertions.

Worker handoff `/tmp/x1-fdc-boundary-HANDOFF.md` records seven terminal-zero
drivers and their frozen folders. Main independently checks 805 source
comparisons, 29 byte-exact IPL regenerations from frozen checker/emitter,
seven executable hashes, every terminal result and exact single mutations.
Main's fresh complete positive reruns also terminate zero: sessions 43604 /
91318, frozen `x1-fdc-boundary-machine-mhk0qxn7` / `qckgl17q`, logs
`/tmp/x1-fdc-boundary-main-1000000.log` / `-2000000.log`.
Warning inventories retain the preceding media fixture's 61/66 warnings,
not warning-clean acceptance. `test-machine-fdc-timing-boundary` runs both
positive profiles; `-boundary-full` adds all five negatives. CI schedules the
positive target; no hosted result is claimed.

This is the fixed-divider low-address experiment, not a native boundary tie,
high-address, 2HD, hardware or stopped-consumer retention qualification.
Pending CPU reselection has a source-derived phase constraint: the lease is
captured at phase1 and consumed at phase4, while a newly issued phase4 CPU
OUT is sampled at phase5. This is not an executed impossibility proof; the
public mount cases must not be labeled CPU-reselection coverage.

## Split metadata, owned publication and high-address media

The original `fdc_timing_metadata_machine_tb.sv` / Python driver now qualify
18 distinct selected positives and three matched mutants on unchanged machine/
vendor RTL. This is not the exhaustive rate/drive/address/edge product.
SV SHA-256 `72846361e157aef89b64f36263f09773542fa15bd618669d21af8c9ef32b1cfa`;
driver `9ecca42496612479b8e355e509ec49f8de47db54fbf0769d72f50c7e6d56a455`.
Generated original media and IPL use public CPU/DMA/ioctl/SD interfaces only.

The 1024-byte payload begins at header+16 and spans three SD blocks. Header
1016 puts deleted mark/status at 1023/1024; high header `(1<<20)+504` puts
them at 1049087/1049088, in separate blocks. Initial mark `10` / status `B0`
produce actual CPU status `28`. Normal writes clear the mark and repair only
the modeled `B0` status; deleted writes set mark `10`. Real payload/status
readback, both remounts, buffer guards, independent planned publications and
both complete media/padding are checked. These are D88 conventions, not Sharp
wire encodings or arbitrary dump-status qualification.

Selected cancellation requires the original published block to drain with
held drive/LBA/buffer and rejects later unpublished writes. Payload-first
pre-ACK reset (1M/20), payload-middle byte128 reset (2M/24), payload-final
ACK-tail mount (2M/24) and CRC byte128 reset (1M/20) pass on both drives.
High24 mark-publication mount passes on A. Width20 high rejection passes on
A/B at 1M, plus 2M/B rejection followed by low-medium mark-publication reset.
Admission is non-vacuous: selected scanning must finish with `d88_bad`, and a
genuine accepted CPU STATUS read must report NOTREADY before low-media remount.
No high payload DATA or SD write may escape the rejected profile.

Uncancelled low-media cases pass both drives at 1M/20 and 2M/24. Final-source
high24 uncancelled A/B also pass at 1M: each performs 5,120 DATA reads, 2,048
writes and `5/4` planned publications, with 6,190/6,191 SD requests.
Session 71184 terminates zero; frozen `x1-fdc-metadata-machine-y02yj1k3`, log
`/tmp/x1-fdc-metadata-final-high24-both-20261010.log`.
The earlier uncancelled high24 `6a9_fdql` predates admission-witness strengthening
and remains separately bound, not relabeled as final-source evidence.

Independent review verifies the initial 12 folders: 1,380 source comparisons,
18 byte-exact regenerated IPLs, all executable hashes and terminal records
(15 positives/three exact mutants). B0-repair omission fails at offset1024;
missing split continuation fails publication count before CPU readback;
early cache update fails during owned ACK. No compile failure or timeout counts.
Main's bounded Make target completes zero with six fresh cases, and its negative
target completes zero after all three expected assertions: sessions 41652/73577,
logs `/tmp/x1-fdc-metadata-main-make.log` / `-negatives.log`. Separate Main low/
high-admission reruns also complete zero (86210/93344). Main checks all nine
fresh/final folders' 1,035 source entries, 15 ROM hashes, executable hashes and
terminal records with only explicitly mutated inputs differing.

`test-machine-fdc-timing-metadata` is the bounded low-media target scheduled in
CI; `-metadata-selected` adds the larger selected address/cancellation matrix;
`-metadata-negative` runs the three mutants. No hosted result is claimed.
The original four-second high scan/remount budget failed at stage40; the final
scanner-aware allowance changes duration, not byte cadence, prefill or payload
assertions. Later witness/check additions are recorded rather than represented
as a budget-only source change. Inherited 61/66 warnings remain; no new fixture/
helper warnings are claimed. Active non-B0 status, further high/rate/cancellation
combinations and native/hardware timing remain open.

## Remaining acceptance

Add final serialization/native boundary-tie qualification, pending CPU
reselection phase qualification, remaining metadata/high-address combinations,
active non-B0 status preservation, READY/Type-IV and native clock/firmware/hardware
qualification. The new cached and pending cases do not cover every
idle-transport stream phase. Recheck ordinary state after any further
manifest/profile connection; preserve measured scope rather than inferring it
from standalone register tasks or generated machine diagnostics.

The Sharp ASIC capacity-to-MIN contract and contradictory physical MIN pin
maps, native initial/final/IRQ timing, recovered RCLK, BUSY mode changes,
FM/format/WRITE TRACK, drive mechanics and authorized native HD software still
need qualification. See `FDC_VFO_CLOCK_STATUS.md` and
`HD_FDC_BYTE_TIMING_DESIGN.md`. No enabled snapshots, timing-qualified RBF,
physical clock change or hardware loading follows this experiment.
