# Turbo Z full-glyph cache/publication prerequisite

The initial source-bound gate below is historical. The later
[committed-half extension](TURBO_Z_CACHE_HALF_STATUS.md) records the current
cache source, default-behavior requalification and separate Quartus profiles.
Do not apply the hashes/resource evidence below to a later RTL revision.

October 14, 2026. Original GPL-2.0-only `rtl/x1_z_kanji_cache.sv` is a standalone
storage/publication experiment, outside `machine.qip` and every board/runner
profile. It does not replace the existing full-size simulation font store.
It is not yet a machine text-write policy, native renderer or CPU arbiter.

## Storage and publication contract

The default configuration has 2,048 cells, two 32-byte glyph slots per cell,
and a 32-bit opaque descriptor plus 13-bit physical glyph tag. SYS refills only
the inactive slot through the qualified frontend's level-read/ACK interface.
All 32 bytes must drain before one held bank/tag/descriptor packet is offered
to VID. VID commits that packet atomically; SYS cannot reuse a slot or accept
another update until acknowledgement returns and completion is consumed.

VID accepts one cell/row-half request per edge and returns the aligned byte,
cell, offset, glyph tag and descriptor on the second sampling edge. Same-cell
descriptor RAM read/write uses explicit forwarding. An unfilled/invalid cell
returns a completed miss with zero data/metadata; idle replies are also zero.
Consumers must honor response validity and hit, including after reverse/blink;
zero data alone is not permission to display text ink.

`invalidate` is an explicit SYS transaction, not a raw machine reset. A pulse
or held request drains an admitted font read and any already-offered
publication before clearing VID validity. Its acknowledgement waits an extra
VID edge to retire the last old reply. A held request is acknowledged once;
stopped VID blocks completion and subsequent admission until it resumes. Validity is
explicitly cleared, so repeated invalidations cannot wrap an epoch and
resurrect old entries. Payload RAM is neither initialized nor cleared.

The caller must preserve a serviceable, stable font image until invalidation
completes, then quiesce updates through replacement. Do not simultaneously
cancel/reset the frontend's CPU port or start a font upload while the cache
still owns that port. Its read response has no cancellation-complete signal.
The subsequent standalone [fair service/lifecycle gate](TURBO_Z_FONT_SERVICE_STATUS.md)
now connects these components and qualifies drain-before-permission with
synthetic CPU/consumer hold. Actual machine integration remains separate.
This cache fixture supplies upload permission; it does
not instantiate or qualify machine CPU/renderer reset dispatch.

## Simulation gates

`make -C verilator test-z-kanji-cache` finishes zero in
`x1-z-kanji-cache-ibnd2_68`, session `76750`, log
`/tmp/x1-z-kanji-cache-final-qualified.log`: three positive profiles and sixteen
exact rejecting RTL mutations, nineteen warning-free Verilator builds/runs.
Optimized Python refuses before evidence allocation. A separate read-only
review rechecks current/frozen sources, all executables and logs, and retrieved
Quartus artifacts: `x1-z-kanji-cache-final-review-6ik7sz8w`. Runtime terminal
report SHA-256:
`b5eae47ab12fc80640b3498eadd27d5b6b45d70979418c95ebab9cc7ad7e382e`.

The fixture connects the real qualified frontend and DDR backend, with an
independent mock DDR medium. It uploads every physical font byte twice,
changing every value in the second image. Full 2,048-cell runs use SYS 32 and
100 MHz with VID half-period 11,640 ps (rounded nominal X3); a separate eight-
cell run uses SYS 100 MHz / VID 25 MHz. Each full run requires 10,246 completed
updates, eight invalidations, 524,288 DDR writes and 327,921 DDR reads.

Independent public-intent ledgers check every font request/DDR word address,
upload byte enable/data, descriptor and returned byte. For the first image,
both full runs require every one of 262,144 physical bytes to be fetched and
checked through VID replies, covering all 8,192 glyphs and 32 offsets. The
changed image additionally exercises fixture phase-10 requests every sixteen VID
edges, with exact reply latency and idle/miss suppression.

Nine scenario groups include visible-cell replacement during continuous reads,
held completion, a pulsed cancellation of a real BUSY-held DDR read, middle/
last-byte cancellation, stopped VID ownership, quiescent-font stopped SYS
recovery, exact commit forwarding, a three-edge stopped-VID invalidation
witness, more than two invalidations, full-cell scans and font replacement.
The stopped SYS case has no outstanding DDR operation; it does not qualify
stopped SYS while memory transport is owned.

Simulated durations are approximately 231 ms (SYS32), 96 ms (SYS100) and
22 ms (small slow-VID), with exact edge counts and clock half-periods recorded
in the terminal report. These are generated diagnostic scans, not native frames.
Sixteen mutants reject at their exact data/descriptor/address/latency/ownership
assertions, including active-slot overwrite, incomplete glyph, non-held or
wrong forwarded descriptor, wrong font level/offset, invalid/idle ink, lost
invalidate pulse, premature ACK and premature admission. Compiler failures and
the whole-test timeout are never accepted as matched controls. Earlier review
and failed checker attempts remain preserved.

Qualified SHA-256:

- Cache RTL: `043165d89c07693ff345849b60de7cbdaa9b6b88f3ad320ae10d800f9c4d46df`
- Fixture: `5eff02e51db2d2bfbcb57c1b7cea09659e14e19d4260c4b6f94bd125112e6bc4`
- Checker: `ea671d2a0d5dbfb01e9b05711bfdd16d48443634c827ee5c3bd26e35f69d4fd2`

The frontend/backend retain their earlier qualified hashes unchanged.

## Source-bound Quartus resource probe

`bash scripts/probe_z_kanji_cache_quartus.sh --build` runs only Quartus 17
mapping/fitting in a new directory, with virtual data pins and synthetic
31.250/23.280-ns input clocks. It does not assemble a board RBF or run STA.
The corrected probe on `misterubuntu` completes exit zero:

| Resource | Standalone fitted use |
|---|---:|
| ALMs | 3,720 / 41,910 |
| Registers | 4,318 |
| M10Ks | 138 / 553 |
| RAM payload bits | 1,142,784 |

Remote evidence:
`/tmp/x1-z-cache-build-mb6FZFeh/output_files/z-kanji-cache-probe-RelynuEd`.
Local read-only retrieval/hash review: `x1-z-cache-quartus-review-t0lbxjey`.
All five frozen source/project/script inputs matched the then-current local files
and remote post-build checks. Input-manifest SHA-256:
`4d8d008ad9be437a28ea6e0c81da3e15f300d3c97a3992c891eefc220a0b498f`.

The first behavioral implementation mapped the descriptor table into registers
instead of RAM: 98,524 synthesized registers. Its isolated owned fit was
deliberately stopped (143), with evidence preserved in
`/tmp/x1-z-cache-build-CsbcYvx6/output_files/z-kanji-cache-probe-6YmI1dId`.
That is not a completed fit or a functional test failure. The corrected
unconditional synchronous descriptor read plus separate forwarding mux maps
the table to RAM; synthesis reports 4,317 registers and the fit above succeeds.

Quartus warnings remain explicit: two unrecognized `async_reg` attributes and
two dual-clock RAM collision warnings at map; LogicLock licensing, incomplete
I/O assignments and two unlocated clock pins at fit. No warning suppression,
global false path or RAM collision assumption is added. Placement/MTBF,
bundled-data delay/skew and physical collision exclusion remain open.

The 138-block result is below the older X3 fit's estimated 164 spare blocks,
but this does not establish a combined fit. The newer 393-block handoff fit
would nominally total 531/553 before other integration changes. A main-project
fit, actual clock constraints, DDR allocation and timing/CDC acceptance are
still required. No MiSTer core has been loaded for this component.

## Remaining integration

Integrate the separately qualified fair service/lifecycle components with
real text/attribute/Kanji writes and renderer requests without exposing
new metadata with old glyphs. Resolve the provisional refill-before-write
WAIT/native visibility policy. Then run real-Z80/pixel, simultaneous-device,
stopped-clock/reset and ordinary-profile identity gates before board work.
Native fonts, broader rasters, ANK/PCG composition and snapshot policy remain
separate. See [the external-font plan](TURBO_Z_EXTERNAL_FONT_PLAN.md).
