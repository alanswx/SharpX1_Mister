# Default-off controller byte-timing integration

October 10, 2026. Original experimental bridge in `rtl/vendor/wd1793.sv`,
not native MB8877A timing, a shared-machine enabled profile or board acceptance.

## Implemented experiment

`STRICT_D88_TIMING=1` requires the SD-backed indexed strict-D88 configuration.
The trailing `fdc_ce` input is an explicit nominal chip-clock event, separate
from the existing controller/bus `ce`; no capacity-derived rate is invented.
No ordinary board or runner enables this parameter. The actual shared machine
ties the new input inactive while preserving its legacy controller enable.

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

## Remaining acceptance

Freeze/hash the exact enabled shared-machine runner and execute actual
CPU transfers at both explicit rates. Add real DMA ownership/DRQ/deadline and
owned-reset transport checks separately; do not infer them from register tasks.
Regenerate/check ordinary state again after any manifest/profile connection.

The Sharp ASIC capacity-to-MIN contract and contradictory physical MIN pin
maps, native initial/final/IRQ timing, recovered RCLK, BUSY mode changes,
FM/format/WRITE TRACK, drive mechanics and authorized native HD software still
need qualification. See `FDC_VFO_CLOCK_STATUS.md` and
`HD_FDC_BYTE_TIMING_DESIGN.md`. No enabled snapshots, timing-qualified RBF,
physical clock change or hardware loading follows this experiment.
