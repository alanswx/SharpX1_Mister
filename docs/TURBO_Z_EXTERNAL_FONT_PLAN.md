# Full Turbo Z font backing memory

October 10, 2026. Design work, not an enabled board feature or fitted result.
Keep all 262,144 physical bytes (IC65 followed by IC66). The simulation store
is not an FPGA storage solution; reducing it to fit spare BRAM is not accepted.

## Interfaces inspected locally

The wrapper exposes the MiSTer 64-bit DDR interface: 29-bit eight-byte-word
address, byte enables, burst count, BUSY and read-data-valid. It currently ties
the entire interface inactive. `sys/sys_top.v` connects this to
`sysmem_lite.ram1`; no new framework port is required. SDRAM is also unused.

Read-only references inspected: SharpMZ `rtl/tape_ddr.sv` (GPLv2-or-later),
FM7 `rtl/sdram.sv` (GPLv3-or-later) and Apple IIgs `rtl/sdram_burst.sv` (GPLv3).
Their controllers are not imported. The tape controller demonstrates the
DDR word/byte-lane interface, not video deadlines or safe machine reset.
The SDRAM examples' clock/refresh constants cannot be adopted blindly.
An original GPL-2.0-only backend is being developed separately from the shared
machine manifest and existing board defaults.

The standalone [DDR backend checkpoint](TURBO_Z_DDR_BACKEND_STATUS.md) now
passes full-font 32/100-MHz and boundary/reset/admission tests. This is not the
ordered-loader, display-cache or FPGA integration gate below.

## Deadline and capacity

At nominal 42.954540 MHz X3, phase-10 glyph request to phase-14 load is four
master edges, about 93.1 ns. Average DDR bandwidth does not guarantee that
latency. Active 80-column scanout requests 2.6847 million glyph bytes/s;
uncached eight-byte reads would transfer 21.4773 MB/s. Full external backing
requires 32,768 DDR words. A core-owned DDR allocation must be verified;
SharpMZ's byte base 0x30000000 is a reference, not an X1 reservation.

One possible design caches the complete 32-byte glyph for each of the 2,048
text cells (64 KiB). That payload is ideally 52 M10Ks, before actual banking,
tags and fragmentation. In-place refill is unsafe: VID must never see a
partially replaced glyph. Two entries per cell would require 128 KiB (ideally
103 M10Ks), plus atomic bank/descriptor publication. A smaller staging scheme
must prove equivalent coherence under continuous writes and stopped VID.
Neither estimate establishes fit or native write visibility.

An alternative is earlier prefetch using dedicated SDRAM with bounded refresh
and arbitration. Its request/CDC/refresh worst case must meet actual scanout
deadlines. Do not choose either architecture solely because it passes a mock.

## Ordered implementation and acceptance

1. Implement an isolated full-address DDR byte backend. Capture one request,
   hold address/data/enables through BUSY, consume same-edge or delayed read
   responses, and retain the response until acknowledged. Parameterize the
   base address. Exhaust all font bytes/lanes with independent memory readback.
2. Qualify synchronous machine reset with memory clock continuing. Drain
   already offered/accepted commands, suppress stale consumer delivery and
   prevent replay. Test reset during BUSY, acceptance, delayed response and
   held response, plus stopped consumers. Avalon write acceptance has no
   separate physical-persistence response; document that limit explicitly.
3. Resolve display caching/prefetch and metadata coherence. A CPU text,
   attribute or Kanji write must not expose new metadata with old cached rows.
   Bundle descriptors and publication across SYS/VID. A refill-before-write
   WAIT policy is provisional and needs native comparison; it cannot silently
   become the ordinary machine contract. Guarantee CPU read progress too.
4. Connect index-5 ordered upload with backend backpressure. Readiness must
   not publish before every accepted write drains and cache invalidation is
   complete. Preserve both reset-held admission and retained warm-reset font.
   Repeat malformed uploads, response cancellation and generation rollover.
5. Integrate the separate machine experiment without changing defaults. Run
   full CPU-address and pixel matrices with adversarial memory latency,
   competing CPU/display/upload traffic, delayed/stopped clocks and resets.
   Qualify broader raster, double-size, ANK/PCG and attribute transitions.
6. Resolve native font conversion and electrical/ASIC behavior separately.
   Build a source-bound board revision, verify allocation, fitted resources,
   timing/CDC, physical font readback, native software and hardware reset.

The framework safe terminator addresses core/platform reset at the DDR
boundary; it is not proof that an arbitrary machine reset may discard an
outstanding read or drop a held command. Private font bytes remain uncommitted.

## Backend/front-end reset boundary

The separate original DDR backend has a single outstanding request/response
lease. Its synchronous reset stops admission and suppresses delivery while
draining queued/accepted commands, including writes. The caller must retire
valid after acceptance and cancel its pending valid on reset; holding an old
valid through drain requests a new transaction when ready returns. There is
no caller-generation quarantine in the backend itself.

Do not tie this reset blindly to held machine `core_reset`: reset-held ordered
font uploads would never be admitted. The future frontend must separately
quiesce consumers, cancel their delivery, drain old ownership with SYS running,
and admit loader requests while CPU/VID remain reset. It must wait for drain
before taking ownership, not assume that asserted machine reset means idle.
Warm reset retains font readiness; malformed/new uploads revoke it explicitly.

Frontend acceptance must cover upload START during an outstanding CPU read,
stopped VID, held machine resets, backend BUSY, last-write acceptance and
falling upload commit, permission lost mid-upload, orphan/short/overflow
strobes and recovery with a new complete image. Public `ioctl_wait` must prevent
lost/replayed bytes. Cache invalidation/publication and native visibility are
later gates; backend command acceptance alone is not a font publication proof.
