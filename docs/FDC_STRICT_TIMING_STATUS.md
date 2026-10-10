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
This is a native game-screen boot, not movement/repeatability acceptance or a
commercial-game count. A separate cold run with late I/J input is still active.

Ignored evidence: `output_files/fdc-native-cross-7Ri8Vj/`, including inputs,
log, RAM/text dumps and original PPM/converted PNG. All four before/after input
hashes match; originals and snapshots are not changed or committed.
PNG SHA-256 `e5abb689da1426e7fce294fbfa1c520beef31c2778ed5a5dcd19f657ac760755`;
PPM SHA-256 `9befdf3c3984765778a143e58f138b06938e4ce53a1e1e3a7ebe2e739fc74d07`.

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

## Remaining acceptance

Add cached-stream reselection, pending-completion cancellation, metadata/CRC
ACK phases, high-address media, READY/Type-IV and native clock/firmware/hardware
qualification. The current reset/selection cases exercise owned host traffic,
not all idle-transport stream phases. Recheck ordinary state after any further
manifest/profile connection; preserve measured scope rather than inferring it
from standalone register tasks or generated machine diagnostics.

The Sharp ASIC capacity-to-MIN contract and contradictory physical MIN pin
maps, native initial/final/IRQ timing, recovered RCLK, BUSY mode changes,
FM/format/WRITE TRACK, drive mechanics and authorized native HD software still
need qualification. See `FDC_VFO_CLOCK_STATUS.md` and
`HD_FDC_BYTE_TIMING_DESIGN.md`. No enabled snapshots, timing-qualified RBF,
physical clock change or hardware loading follows this experiment.
