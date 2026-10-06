# First-level Kanji high-speed CG backend

October 6, 2026. Work group 3 / Turbo Z dependency. An original opt-in
`KANJI_SUPPORT=1` extension to `x1_pcg_access.v` connects the tested physical
selector and synchronous ROM CPU port in standalone fixtures. The shared
machine still disables it and ties off the new inputs. There is no machine
loader/profile, glyph renderer, native font or hardware acceptance claim.
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

1. Add an explicit opt-in shared-machine loader/backend profile, bind its
   identity/assets and reject incompatible snapshots without editing state
   bytes. Defaults must retain their old unsupported-Kanji response.
2. Execute this native CG sequence in the shared CPU/machine, on delay-aware
   and synthesis-style runners, including absent/malformed/reloaded ROM,
   pending-read short reset, held bus and retained warm state.
3. Resolve native archive-to-physical chip identity and font order; qualify
   authorized assets instead of treating Shift-JIS exports as raw chip dumps.
4. Finish display KACE/PCG/ANK/raster/underline selection and actual glyph
   pixels; resolve the separate CPU latch/conversion protocol from primary
   documentation or traces. Synthetic CPU bytes do not prove native display.
5. Implement Turbo Z's larger first/second-level memory path, then source-bound
   resource/CDC/timing refit and physical video/OSD reset acceptance. The earlier
   single-store inference audit does not qualify this adapter's fitted timing.
