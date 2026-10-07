# First-level Kanji high-speed CG backend

October 6, 2026. Work group 3 / Turbo Z dependency. An original opt-in
`KANJI_SUPPORT=1` extension to `x1_pcg_access.v` connects the tested physical
selector and synchronous ROM CPU port in standalone fixtures. A subsequent
explicit `TURBO_KANJI=1` shared-machine profile connects that backend and a
physical ROM loader. Defaults remain disabled. There is no glyph renderer,
native font or hardware acceptance claim.
The independent `0E80..83` protocol is not implemented by this `1400..140F` path.

## Transaction contract

Acceptance freezes the 17-bit physical address, high-speed/plane/read-versus-
write/unsupported qualifiers, and whether a ROM is available. The address
remains stable until the next accepted transaction. Kanji data is sampled only
on the CPU clock; no CPU-clock ROM bytes are captured by a video-clock latch.
The existing provisional video-window/ACK roundtrip is retained. Its completion
cannot release WAIT while a loaded Kanji read lacks valid CPU-domain data.

Missing ROM completes with FF; it does not hang or advertise a fabricated
glyph. Unsupported selection bypasses the backend and also returns FF. ROM
writes perform no ROM read or PCG write, and terminate normally. Loaded ROM
may not be changed during an owned request: the loader requires both resets,
which cancel the adapter transaction before rewriting bytes.

After completion the read response/qualifier survive the CPU's trailing I/O
sampling phase, but the backend read request stops. Held selects cannot create
another transaction. Global reset asynchronously clears pending reads, response,
hold and request metadata. The ROM is retained independently. CPU and video
resets must use the tested release path; this does not qualify arbitrary
video-only resets or Main/OSD command dispatch.

## Connected ROM/WAIT checks

`make -C verilator test-kanji-cg-access HEADLESS_DIR=obj_dir_v12_kanji_backend`
passes with Verilator 5.044 and strict RTL warnings, no suppressions. CPU is
32 MHz; video half-periods are 17,500, 11,640 and 25,000 ps, synthetic ratios
rather than exact fitted/nominal PLL claims. Each run performs **131,082**
transactions, including every one of the 131,072 physical bytes. Synthetic
data is supplied only through the real ordered loader while resets are held.

Checks cover concurrent complementary display reads; mutation of all live
request fields after acceptance; held select and inactive read tail; absent/
unsupported ROM; ignored writes and retained readback; CPU data-valid delayed
after video ACK; a closed video window; stopped video clock/resumption; pending
read reset in delayed-valid and closed-window states; a short pulse between
CPU edges; retained ROM and exact zero PCG writes after those resets.
Log `/tmp/x1-kanji-cg-access-qualified.log`.

Negative control: a temporary copy of the adapter removed only the backend
validity condition from completion. The otherwise unchanged fixture fails at
`WAIT released without backend validity`. Logs
`/tmp/x1-kanji-valid-negative{,-build}.log`; temporary mutant
`/private/tmp/x1-kanji-valid-negative-TMSRdZFw/`. Production RTL was not mutated
or bypassed, and no assertion/duration was weakened to obtain a pass.

## Actual CPU diagnostic

`test-kanji-cg-cpu` connects the repository CPU/TV80, real selector, adapter,
ROM loader and CPU-written RAM. It builds original Z80 instructions in
synthetic program memory, not a copy of the inspected monitor. Selector writes
use the shared machine's decoded text/Kanji/attribute predicates. CG accesses
use ports `1400..140F`, the intended monitor-derived high-speed sequence.
It is a connected device/CPU fixture, not an instance of `rtl/sharpx1.v`.

The diagnostic reads every bank/half/row for character codes 0, 1, 127, 128 and
255, then rejects level 2, exits to a constant ANK routing fixture and returns
to Kanji without reloading ROM. It also executes sixteen `INI` instructions
into real RAM, compensates the B decrement before the next row, and checks
those stored bytes with CPU loads/comparisons. All failure/success markers
are actual CPU stores; there is no debugger/chip-state or result injection.
It requires exact completed transaction counts and exercised WAIT.

The final matrix retains six CPU-enable/video-ratio profiles: CE=1/4/8,
32 MHz system, video half-period 17,500 or 11,640 ps. Each cold/warm run
performs **2,579** checked IN/INI reads, without reloading the synthetic ROM
between runs. All six profiles exit zero on Verilator 5.044. Log
`/tmp/x1-kanji-cg-cpu-qualified.log`. The inherited TV80
DIRSET warning is retained; an initial fixture width warning was corrected,
not suppressed. Narrow source selection avoids unrelated TV80 variants.

Existing `test-turbo-pcg-access` and base/X3 wrapper lint exit zero on the
changed adapter with Kanji disabled. The former preserves all ANK/PCG checks,
three base clock profiles and six high-speed profiles. Lint uses a PLL
interface stand-in, not Quartus/PLL/hardware behavior. Inherited framework
warnings and existing accommodations remain; no new warning suppressions
were added. Log `/tmp/x1-kanji-backend-regression.log`.

Qualified source SHA-256 identities:

| Source | SHA-256 |
|---|---|
| `rtl/x1_pcg_access.v` | `578e37ddba614e1c8c68734c1e08d337b75215e4abf424a19eff6deea84fb767` |
| `verilator/tests/kanji_cg_access_tb.sv` | `55cbc5f05ffd06198b00b737e90ba7f74c22b3d0bd910d385f7eb9bbfd9703db` |
| `verilator/tests/kanji_cg_cpu_tb.sv` | `bc32c6ae2592584fc314c0b1960fdd7b0eeff8bc140eb6b7d0c9dc60c10ead2e` |

The existing ROM and selector source identities are in the
[contract audit](KANJI_CONTRACT_STATUS.md). New backend/CPU targets are added
to hosted CI; their local success does not establish a completed hosted run.

## Required next gates

1. Broaden the explicit shared-machine profile to combined DMA only after
   qualifying reset/ownership/clock interactions. Nominal X3 CPU/snapshot and
   pending-read reset checks now pass separately below.
2. Broaden shared CPU/machine execution to held bus and retained warm-state/
   device concurrency. Malformed/reloaded ROM now passes below. Pending-read
   short resets now pass in the original whole-machine fixture below.
3. Resolve native archive-to-physical chip identity and font order; qualify
   authorized assets instead of treating Shift-JIS exports as raw chip dumps.
4. Finish display KACE/PCG/ANK/raster/underline selection and actual glyph
   pixels; resolve the separate CPU latch/conversion protocol from primary
   documentation or traces. Synthetic CPU bytes do not prove native display.
5. Implement Turbo Z's larger first/second-level memory path, then source-bound
   resource/CDC/timing refit and physical video/OSD reset acceptance. The earlier
   single-store inference audit does not qualify this adapter's fitted timing.

## Shared-machine physical-ROM profile

`make -C verilator turbo-kanji` builds the delay-aware ordinary-clock Turbo
profile, 32 MHz system / 28,571,428 Hz video. Set
`KANJI_DIR=obj_dir_turbo_kanji_fast KANJI_TIMING=--no-timing` for a separate
synthesis-style runner. Neither changes the existing base/Turbo/X3 targets
or enables Kanji in any FPGA revision. `TURBO_KANJI` requires Turbo and rejects
the currently unqualified combined DMA profile.

`--kanji-physical PATH` accepts exactly 131,072 bytes in physical IC106,
IC105, IC104, IC103 concatenation order, not Shift-JIS or an assumed emulator
filename order. Index 5 feeds the real ordered ROM loader. Downloads occur
under both resets; readiness commits on the first CPU edge after leaving
index 5, before the startup reset releases. The renderer port stays disabled;
the ROM source is now included in `rtl/machine.qip`. ROM absence remains a
terminating FF response. No private bytes are embedded.

`test-machine-kanji` executes original instructions on the actual shared
TV80/machine, using native PPI/CRTC/SCRN/text/attribute/KVRAM writes and
**1,024 INI bytes** across all halves/banks/rows at glyph codes 0/255.
INI stores real D000 RAM, which the CPU compares against the synthetic
physical pattern. Additional checks cover ignored ROM writes, absent level-2
selection, ANK exit, missing ROM and exact CLI length rejection. Cold and
100 ms warm-reset invocations require CPU-written KAN!/WARM markers. The fast
and delay-aware matrices both exit zero; logs
`/tmp/x1-kanji-machine-{fast,timing}-test.log`. Base/X3 wrapper lint and the
existing disabled-Kanji PCG regression exit zero after this integration, log
`/tmp/x1-kanji-machine-regression.log`. Warnings remain inherited; no new
suppression was added. Three shared-machine targets are added to hosted CI;
a push is not evidence of their completed hosted execution.

`turbo-kanji-savable` builds separate opt-in/default Turbo executables.
The opt-in application signature uses profile bit 45; existing profile bits
remain unchanged. Restores cannot download another ROM and cross-profile
states must be rejected before deserialization. The snapshot diagnostic saves
an executing original CPU fixture, resumes without asset injection, and
compares final CPU/RAM/VRAM/sub-RAM dumps. Sync counters are host-window values:
pre-save plus restored counts must exactly equal the uninterrupted counts.
This snapshot diagnostic exits zero, with exact reports (apart from documented
host-window fields), additive sync counts and all five dump comparisons.
Bidirectional default/opt-in rejection, default-loader rejection and rejection
of a ROM download during restore pass. Log
`/tmp/x1-kanji-machine-snapshot-qualified.log`. The first attempt's incorrect
whole-run sync-count comparison remains recorded in
`/tmp/x1-kanji-machine-snapshot.log`; no RTL or state was changed to fix that
test expectation. Do not edit state bytes to bypass the profile checks.

## X3 clock and whole-machine pending-read reset

`test-machine-kanji-x3` and `test-machine-kanji-x3-fast` repeat the unchanged
1,024-byte INI/read-only/level2/ANK/absent/cold/warm matrix with nominal
42,954,540 Hz video and 32 MHz system clocks. Both exit zero; logs
`/tmp/x1-kanji-machine-x3-{timing,fast}.log`. These are isolated opt-in builds,
not a changed default or fitted FPGA PLL frequency. `KANJI_VIDEO=1` sets both
the RTL parameter and runner/profile identity; always use a separate directory
when changing a compile-time model.

`test-machine-kanji-x3-snapshot` also exits zero. Its real executing CPU/INI
checkpoint resumes with the retained physical ROM, exact final dumps and
reports, additive sync counts and bidirectional rejection against the
same-clock default X3 model. Log `/tmp/x1-kanji-machine-x3-snapshot.log`.

`test-machine-kanji-reset HEADLESS_DIR=obj_dir_v12_kanji_reset` passes five
whole-machine profiles using the actual shared CPU, selector, RAM, loader,
video and release synchronizer. Clock half-periods are 15,625 ps system and
11,640 ps video (a synthetic X3-like ratio, not the exact nominal frequency).
All assets are original emitted instructions and synthetic physical bytes,
loaded through ioctl. The CPU increments a retained boot count and performs
sixteen INI operations into D000 RAM, then checks those bytes and stores a
success/failure marker. No machine state, bus or result is forced.

| Reset profile | Evidence |
|---|---|
| 0: normal pulse while read pending | Immediate cancellation and native CPU restart |
| 1: 100 ps pulse between CPU edges | Cancellation without a sampled CPU reset edge |
| 2: stopped video, 100 ps pulse | Video reset remains held until video resumes; CPU then completes |
| 3: stopped system clock, 100 ps pulse | Pending transaction cancels before system clock resumes |
| 4: CPU-programmed closed HSYNC window | HSYNC position beyond total holds WAIT/busy for 128 system cycles; reset restarts with normal sync |

Every profile requires retained ROM/readiness, no loader error, boot count two,
sixteen correct post-reset CPU INI bytes and exactly zero PCG writes. Log
`/tmp/x1-kanji-machine-reset-final.log`. Explicit unused fixture outputs remove
the initial fixture pin warnings; inherited machine warnings remain without
new suppressions. The initial closed-window draft incorrectly used zero sync
width and direct OUT instructions with the wrong BC port; it was corrected
and given the explicit 128-cycle stalled-window assertion before qualification.

Negative control: only the adapter CPU process's asynchronous reset sensitivity
was removed in `/private/tmp/x1-kanji-machine-negative-L6rPTg/`. The unchanged
whole-machine short-pulse fixture fails at `pending transaction did not cancel
asynchronously`, exit 1. Logs `/tmp/x1-kanji-machine-reset-negative{,-build}.log`.
Production RTL was not changed. Four new targets are added to hosted CI;
local success does not establish completed hosted execution or hardware/OSD
acceptance. Combined DMA, native fonts and glyph rendering remain open.

## Shared loader rejection and native CPU recovery

`test-machine-kanji-loader HEADLESS_DIR=obj_dir_v12_kanji_loader` extends the
same whole-machine fixture with nine real ioctl sequences: empty, short,
missing address zero, duplicate address, gap, overflow, a WR strobe on the
falling commit, a write with machine reset released, and an orphan index-5 WR
without DOWNLOAD. Each begins with a different complete valid synthetic image,
then requires `loaded=0` / error after the malformed upload. A failed partial
load is not a rollback interface.

Before recovery, an original CPU program executes sixteen INI reads and CPU
RAM comparisons requiring FF, proving malformed bytes do not expose the old
valid image through the connected machine. The host then holds both resets,
loads a complete third synthetic pattern and uploads the original diagnostic
program expecting those physical bytes. A real pending read is reset; CPU
restart completes sixteen correct INI bytes with no ROM re-download. The
retained boot counter must be three, distinguishing the malformed-image boot,
the canceled recovery boot and the successful recovery boot. Exactly zero PCG
writes are permitted throughout. All nine profiles and the original five
reset cases exit zero; log `/tmp/x1-kanji-machine-loader-qualified.log`.
No firmware bytes, snapshot edits, forced machine state or result injection
are used. This adds one hosted CI target; native assets/display and physical
loader behavior still need qualification.

Negative control: a temporary shared-machine copy gated index-5 WR with
DOWNLOAD, preventing orphan strobes from reaching the parser. The unchanged
case-8 fixture fails at `malformed shared upload did not invalidate kind=8`,
exit 1. Temporary source `/private/tmp/x1-kanji-loader-negative-Eqc3EB/`;
logs `/tmp/x1-kanji-loader-negative{,-build}.log`. Production wiring remains
unchanged; no expectation was weakened to accept a retained old image.

The subsequent [explicit model-40 converter](KANJI_CONTRACT_STATUS.md#executed-explicit-model-40-conversion-and-cpu-read-candidate)
now passes exhaustive asset-free layout checks. The private inferred candidate
also passes the shared X3 cold/warm matrix on fast and delay-aware runners via
`test_machine_kanji.py --physical-rom PATH`. The default fixture still generates
only synthetic bytes. Native pixels, JIS/0E80 protocol and board identity are
not established by those CPU comparisons.
