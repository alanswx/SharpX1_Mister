# Full Turbo Z font backing memory

October 15 Main OSD reset follow-up: [both menu commands](Z_FONT_OSD_RESET_STATUS.md)
now pass the bounded external-font hardware gate at 80/40 columns. Six cases
produce eighteen raw PNGs matching **3,840,000 exact control pixels**. Menu
navigation without Enter and two wrong-final-byte controls reject the unchanged
readback oracle. T Reset closes with F12 before R; R Reset-and-close needs no
extra F12. No warm load/upload/mount or keyboard reset chord is requested.
All 127 qualification inputs, 428 compiler inputs, RBF/Main and font DDR hashes
pass. This reuses fd9a0850; no new Quartus or simulation run. Physical owned
phase, stopped clocks, native fonts, wider modes/devices and timing closure
remain open. Earlier checkpoint statements retain their dated scope.

October 15 active-traffic reset follow-up: [owned simulation and Main reset controls](Z_FONT_ACTIVE_RESET_STATUS.md)
pass. Four simulation cases check 34,544 completed CPU reads and 2,688,000
control pixels, including an exactly cancelled pending read and one-commit owned
write drains with DDR/VID service stopped. Three actual MiSTer cases produce
nine PNGs matching **1,920,000 pixels** at 80/40 columns;
Main's keyboard chord recovers retained VRAM after the firmware traffic loop.
No-reset and wrong-final-byte controls reject the unchanged magenta oracle.
The exact physical owned phase is unobserved. RBF/compiler inputs are unchanged;
OSD-menu reset, native fonts, wider modes and timing closure remain open.
Earlier checkpoint statements below retain their dated scope.

October 15 retained-reset follow-up: [real F/R and reset/no-reset controls](Z_FONT_RETAINED_RESET_STATUS.md)
now qualify bounded post-HALT retained IPL/font/VRAM on fd9a0850. Three
simulation cases check 18,570 actual CPU reads; nine actual Main/mrext frames
match 1,920,000 control pixels. Main's keyboard reset chord plus R reaches a
post-readback magenta marker at both widths; R without reset and a wrong last
expected byte fail the unchanged warm oracle. No warm upload is requested;
all compiler inputs/RBF remain unchanged. OSD-menu, owned/stopped-clock reset,
native fonts, broader raster/device behavior and timing closure remain open.
Earlier checkpoint statements below retain their dated scope.

October 15 second repair: the [actual HPS error-recovery gate](Z_FONT_HPS_UPLOAD_STATUS.md)
adds real decoder/ACK framing and four exact rejecting controls. New RBF
fd9a0850 builds; actual valid/oversized-retry/short-retry controls match
640,000 pixels/full DDR with Main responsive. Native CROSS Chase shows a
populated field. This supersedes c6 as the current source-bound RBF; timing,
native font conversion and broader raster/physical gates remain open.

October 15 [hardware follow-up](TURBO_Z_EXTERNAL_HARDWARE_STATUS.md): repaired
RBF `c6a2ac02…` builds at 25,419 ALMs / 534 M10Ks after fixing the upload's
terminal SPI ACK deadlock. Complete physical 256-KiB readback and 768,000 exact
80/40-column cold/post-reset-request pixels pass on mister14; Mappy/Xevious
reach native stages with the Turbo IPL. Timing, native Kanji, retained-reset
causality and broader policies remain open. Historical results follow.

October 14 integration follow-up: the separate default-off
[external-font machine profile](TURBO_Z_EXTERNAL_MACHINE_STATUS.md) now connects
DDR, committed VRAM writes and renderer packets, with owned reset/upload drains
and retained-cache reconstruction. Complete-machine synthetic CPU/80/40-column
pixel gates pass, including CPU VRAM readback and changed-font replacement.
The corrected-source full Quartus build/RBF passes at 534 M10Ks / 25,512 ALMs.
Timing fails and physical feature acceptance remains open.
Native font conversion, broader text policies and physical acceptance stay open.
Earlier standalone-only scope statements below describe those checkpoints.


October 10 design and historical standalone component gates. The October 14
follow-up above now supplies a separate experimental board profile and combined
prototype fit; native and physical qualification remain open.
Keep all 262,144 physical bytes (IC65 followed by IC66). The simulation store
is not an FPGA storage solution; reducing it to fit spare BRAM is not accepted.

## Interfaces inspected locally

The wrapper exposes the MiSTer 64-bit DDR interface: 29-bit eight-byte-word
address, byte enables, burst count, BUSY and read-data-valid. Ordinary profiles
tie it inactive; the separate external-font profile now connects its service. `sys/sys_top.v` connects this to
`sysmem_lite.ram1`; no new framework port is required. SDRAM is also unused.

Read-only references inspected: SharpMZ `rtl/tape_ddr.sv` (GPLv2-or-later),
FM7 `rtl/sdram.sv` (GPLv3-or-later) and Apple IIgs `rtl/sdram_burst.sv` (GPLv3).
Their controllers are not imported. The tape controller demonstrates the
DDR word/byte-lane interface, not video deadlines or safe machine reset.
The SDRAM examples' clock/refresh constants cannot be adopted blindly.
An original GPL-2.0-only backend is implemented separately from the shared
machine manifest and existing board defaults.

The standalone [DDR backend checkpoint](TURBO_Z_DDR_BACKEND_STATUS.md) now
passes full-font 32/100-MHz and boundary/reset/admission tests. This is not the
ordered-loader, display-cache or FPGA integration gate below.
The separate [upload/CPU frontend](TURBO_Z_FRONTEND_STATUS.md) now passes
twenty-four 32/100-MHz positive profiles and fourteen exact rejecting mutations.
Its ordered admission and drain contract do not supply the machine display
cache/publication gate.
The standalone [full-glyph cache/publication experiment](TURBO_Z_CACHE_STATUS.md)
now connects to that font service and has a source-bound 138-M10K/3,720-ALM
Quartus fit. Three positive configurations and sixteen exact mutants pass,
including every physical font byte through refill and VID replies at two SYS
rates. Subsequent standalone [fair service/lifecycle components](TURBO_Z_FONT_SERVICE_STATUS.md)
pass 35 strict simulation/fault runs, including queued cache reads behind CPU
ownership, stopped VID and guarded full-image upload/cold retry. Actual machine
write/renderer integration, consumer-hold/reset dispatch and native policy
remain open.
The later [real-Z80/PCG service boundary](TURBO_Z_CPU_SERVICE_STATUS.md) now
passes three clock configurations and eight exact mutants with the original
service. The later [committed-half extension](TURBO_Z_CACHE_HALF_STATUS.md)
qualifies descriptor-based half selection and refreshes all sixty cache-half/
default/lifecycle/CPU cases. Both current cache profiles fit at 138 M10Ks;
the bit-22 profile uses 3,715 ALMs, caller selection 3,717. Actual machine VRAM
write admission/publication and renderer metadata consumption remain next.
The later [VRAM write-boundary gate](TURBO_Z_VRAM_WRITE_STATUS.md) now supplies
a separate real-Z80/three-VRAM/cache transaction component: eighteen cases
qualify one captured write, full publication, then one RAM strobe/WAIT release.
Actual machine decode/renderer wiring, writer drain before lifecycle pause and
reconstruction after retained-VRAM invalidation remain open. The new writer
has no Quartus result; existing cache fits do not bind its combined resources.
The subsequent [renderer packet gate](TURBO_Z_CACHE_RENDER_STATUS.md) connects
the real CRTC/RGB path in a separate fixture and passes ten full 80/40-column
frames (1,920,000 exact pixels), CPU writes, retained-video reset and cache
invalidation, plus exact live-VRAM/wrong-glyph controls. The actual machine
and DDR ports, writer-drain/lifecycle integration and combined FPGA gates
remain open; no default profile changes.

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
The new two-slot component actually fits in 138 M10Ks with a 32-bit opaque
descriptor, including glyph tags and control logic. Its separate RAM/register
inference gate does not establish a combined board fit or native visibility;
see the cache status above. Wider descriptors require a new resource check.

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
font uploads would never be admitted. The standalone frontend separately
cancels CPU delivery, drains old ownership with SYS running,
and admits loader requests while caller-held consumer reset remains asserted.
Future machine integration must preserve this drain-before-admission contract,
not assume that asserted machine reset means idle.
Consumer cancellation retains font readiness; malformed/new uploads revoke it explicitly.

Standalone frontend acceptance now covers upload START during an outstanding
CPU read, held consumer cancellation, backend BUSY, last-write acceptance and
falling upload commit, permission lost mid-upload, empty/short/overflow
strobes and recovery with a new complete image. Public `ioctl_wait` prevents
lost/replayed bytes within this synchronous fixture. There is no VID port in
the component: stopped VID, cache invalidation/publication, integrated machine
reset and native visibility remain later gates. Backend command acceptance
alone is not a machine font publication proof.
