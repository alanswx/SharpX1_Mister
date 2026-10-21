# Turbo Z fair font service and lifecycle prerequisite

The initial gates/hashes below describe their frozen source revision. The
later [cache-half checkpoint](TURBO_Z_CACHE_HALF_STATUS.md) records a cache
source change and refreshed connected lifecycle/CPU gates; arbiter and
coordinator RTL remain unchanged. Keep the earlier resource fit historical.

October 14, 2026. Original GPL-2.0-only `x1_z_kanji_arbiter.sv` and
`x1_z_kanji_quiesce.sv` are standalone components outside `machine.qip` and
every board/runner profile. They connect the unchanged qualified full-font
frontend/backend and dual-slot cache in a synthetic fixture. Actual Z80,
VRAM/renderer and Main/OSD reset integration remain open.
The subsequent [actual Z80/PCG boundary](TURBO_Z_CPU_SERVICE_STATUS.md) now
qualifies a CPU reply bridge with these unchanged service components in a
separate generated diagnostic, not a shared-machine profile.

## Fair service contract

The arbiter captures each admitted CPU/cache byte address, retains its owner
through the frontend response and ACK, and supplies zero data outside a valid
client response. Both clients require an observed low read before another
admission, and an independently observed low ACK after response consumption.
A stale high ACK cannot consume a later response. Alternating preference
gives each continuously eligible client service after at most one competing
transaction. This is a transaction bound: DDR stalls and a held client
response can prevent either client making progress indefinitely.

Disabling admission preserves an existing owner. `cpu_cancel` immediately
suppresses CPU delivery, retains an in-flight read until the actual response
arrives, and acknowledges it through the frontend. It never cancels a cache
owner. Clients must keep the port serviceable and enable admission only when
the font is ready. An idle indication alone does not prevent a pending request
being admitted next edge; first disable both clients at the correct lifecycle
boundary.

## No-font boot (October 21)

The machine coordinator (`x1_z_kanji_machine.sv`) no longer pauses while no
font has been committed. It pauses for reset, any host download, or a
rejected upload (`load_error`). With `BLANK_WHEN_UNLOADED=1` (machine only;
the standalone default stays 0) the frontend answers unloaded reads with 00
directly, with no backend command, so text/ANK/PCG display and
blank Kanji work without a font, as in Common Source and MAME. CPU 14xx Kanji
reads still terminate with FF through `x1_pcg_access` (`kanji_available`).
A later font upload still pauses, invalidates and rebuilds from the journal.
`test-machine-z-external-font` now requires the CPU to leave reset without a
font, with zero DDR reads/writes, before its original upload sequence.

## Pause, reset and upload contract

The coordinator holds consumers and disables new CPU/cache-update admission
on a pause or cold request. It cancels CPU delivery through the arbiter, then:

1. Invalidates the cache while continuing to admit its font reads. An already
   offered cache read waiting behind CPU ownership still needs admission.
2. Waits for the cache's VID invalidation/reply-retirement acknowledgement,
   then disables cache admission and waits for arbiter idle.
3. Waits for caller-owned `consumers_quiescent`, a SYS acknowledgement that
   actual CPU and VID consumers are held.
4. Cancels the now-unowned frontend CPU interface and applies any latched cold
   reset, then offers a retained pause grant and upload permission.

A pause pulse persists until explicit release; a held request is acknowledged
once and prevents release. Cold events latch through drains. Warm pause retains
font readiness; cold loss revokes it only after owned reads drain. Initial
values are launch-only; no raw reset may clear transport or CDC ownership.

The caller gates frontend font-download START **and** WR with
`upload_permitted`, exposing upstream WAIT while it is absent. The connected
fixture implements this wiring. Hold the consumer acknowledgement through
upload commit. Raw upstream `host_download` and frontend `upload_active` both
block release. Retire `release_pause` after its ready handshake. The grant does
not mean an upload has finished; release readiness additionally requires its
transport to drain.

Cold loss during upload withdraws permission and ends the gated download,
while the frontend retains any already-staged write. Permission stays blocked
for that same upstream transaction until download goes low. Otherwise a
restored grant could create an unintended fresh START from an old held level.
After ending the raw download, wait for `upload_active` to fall before retrying
with a fresh START and complete image. Backend write acceptance still denotes
accepted commands, not physical DDR persistence.

## Qualification

`make -C verilator test-z-kanji-arbiter` completes zero in
`x1-z-kanji-arbiter-a_lyb7ux`, log `/tmp/x1-z-kanji-arbiter-final.log`:
two SYS 32/100-MHz positives and twenty exact rejecting RTL mutations,
twenty-two warning-free Verilator builds/runs. Each positive has 77 requests,
77 actual DDR reads/ACKs and 262,144 ordered upload writes. The 64-request
contention sequence alternates CPU/cache with response backpressure; further
cases cover captured address, early read withdrawal, both stale ACKs, both
held reads, BUSY/delayed/held CPU cancellation, both admission gates and cache
ownership retained while quiescing. The cache client here is synthetic.

`make -C verilator test-z-kanji-quiesce` completes zero in
`x1-z-kanji-quiesce-btz0dt19`, log `/tmp/x1-z-kanji-quiesce-final.log`:
two positive configurations and eleven exact rejecting RTL mutations,
thirteen warning-free builds/runs. The connected lifecycle fixture uses eight
cells and instantiates the real cache, arbiter,
frontend and backend with SYS 32/100 MHz and VID half-period 11,640 ps.
Its five scenario groups require 68 actual DDR reads/ACKs, four cache updates,
five frontend cancellations, two cold losses and 786,435 accepted upload
writes: three complete images plus a drained three-byte partial upload.
The second full image changes every byte; visible highest-glyph bytes and
descriptors are checked at all 32 offsets before/after replacement, and
invalidated cells must return exact misses. This is bounded component
coexistence, not the full-font scan or native pixel matrix.

The scenarios include START/WR held before consumer acknowledgement, held
pause/release attempts, a BUSY-owned cache read with stopped VID, consumer
acknowledgement delayed after VID recovery, a queued cache read behind a
cancelled CPU read, a separate delayed CPU-only cold drain, final upload write
stalled during release, and cold loss during an owned partial-upload write.
The mock DDR independently checks requested word address, byte lane, payload
and write sequence; request/response ownership comes from fixture intent.
There is no injected DUT state or forced cache/arbiter internals.

Each checker freezes and hashes its sources before building, refuses optimized
Python, retains all attempts, checks exact terminal counters and rejects
compiler warnings/failures or the global timeout as fault evidence. Mutants
must terminate at their intended functional assertion. Earlier review attempts
remain preserved; refinements add queued-read/release witnesses and improve
counterfactual attribution without relaxing functional assertions.

The final read-only review in `x1-z-font-service-review-2380tk29` verifies
current/frozen sources, every executable/run log, compiler logs and each
intended rejection again. Review SHA-256:
`e3b7b4a7029ded8d1a72a0865b3e891f02c43d70a577758b679a4e1757067ad3`.
All jobs are terminal. Both targets are scheduled in CI with 600-second limits;
no hosted CI result is inferred.

Qualified SHA-256:

| Input | SHA-256 |
|---|---|
| Arbiter RTL | `e97c58a3890a542af7056fc16ccd8a6a18720f0b744b29b19699f33e37eca0a6` |
| Arbiter fixture | `aa51d6d19b6b2bc1cd009fabe894aaec1430c7ffc045d0fe47cd19e21155b1b1` |
| Arbiter checker | `17f2a9ec3bba02fa4be4f830775b0576a29f74c1c894792a2ebf3c46856a9fa7` |
| Coordinator RTL | `ee2e02b26ca3bc135a9e9ad4c41ef822105bba33502e1f07ef6e96858a64f313` |
| Connected fixture | `fb1a578b3d2927cf9eef5a9d6d2b9435e4abc4a02d17535e4f342dc70b061d99` |
| Lifecycle checker | `860ba57a05f2c3e4404880ede21a3664b2831820ef4f6cc2c7e1be03b05fda12` |

Terminal report hashes are respectively
`2d4f4ad922d4cff283e7a023dd119c5f2f6de887df3e764b036d63ebbf09a7b9`
and `65b8f8deaa181f1d75d3b26e29921815d2b69c22b58dbc8dfaa47a3a32526488`.
Backend/frontend/cache inputs retained their earlier hashes for that gate.

## Remaining machine and FPGA gates

Wire actual CPU font reads, VRAM/attribute/Kanji writes and renderer descriptors
through the service; resolve provisional refill-before-write WAIT and native
visibility. Implement actual consumer-hold acknowledgement and Main/OSD reset
dispatch, including abort/retry policy for the real upload source. Repeat
real-Z80/address/pixel, competing-device and ordinary-profile identity tests.
These original fixtures use a synthetic CPU and caller acknowledgement; they do not
qualify stopped SYS while DDR is owned, native software or a physical CDC path.
The later CPU-boundary fixture linked above supplies actual CPU/PCG execution
and diagnostic reset acknowledgement, while renderer/Main integration stays open.

The cache's earlier 138-M10K component fit remains unchanged. No combined
service/board fit, STA, placement/MTBF, DDR allocation, RBF or MiSTer test is
performed for these new components. The available MiSTer at `10.0.2.14` has
not been contacted or loaded in this continuation. Native fonts, broader
rasters/ANK/PCG composition and snapshot policy remain separate gates.
