# Connected 4096-color video experiment

## Pin-order correction after `533961a`

Printed 156 table 4-22 reverses CPU-address bit order within each nibble
relative to display QHA/QHB/QHC channels. The first fetched source therefore
supplies logical component bit 3, not bit 0. The initial renderer and oracle
at `533961a` shared the unreversed convention: their pixel passes below are
historical internal-agreement evidence, **not native index-significance proof**.
See [the explicit pin table](TURBO_Z_PALETTE_CONTRACT.md#cpudisplay-pin-reconciliation-table-4-22).

Corrected `x1_z_graphics.sv` and independent CPU-pixel/shifter oracles now
use the physical-to-logical permutation. `test-z-palette-pins` checks all
4096 indices times eight pixels through real component RAM, sequential fetch,
shifter and palette RAM at three video half-periods; all profiles pass.
This connected fixture drives accepted RAM writes, not Z80 instructions.
All-address standalone shifter checks also pass after the correction.
The preserved old identity capture differs at 52,198 pixels under the new
pin-derived oracle, a negative control rather than a converted asset.

Corrected identity retained-reset CPU pixels pass all 64,000 pixels, periods
and no-refill I/O assertions. Frozen renderer SHA-256:
`8afb17c15999327b59b66de5f5b8ffa12ac00e8f4fa31ed24f2cc5829ca2018c`;
logs `/tmp/x1-z-indexfix-{identity,custom}-warm.log`. Custom retained-reset
also passes all 64,000 pixels, periods and no-refill I/O assertions.
Old four-case matrix results use the preceding
convention and must not be promoted to this corrected renderer's acceptance.
New matrix invocations freeze both Python fixture/emitter and runner identity,
and print the oracle revision/source hash, so later cases cannot silently
adopt edits made while a long matrix is active.

## Profile and historical integration evidence

`TURBO_Z_VIDEO=1` connects the sequential GRAM fetch, original twelve-bit
shifter and synchronous external palette to the shared machine's RGB12
output. It requires `TURBO=1`, `TURBO_VIDEO_MASTER=1` and
`TURBO_Z_PALETTE_CPU=1`; DMA and compensated single-clock profiles are excluded.
Ordinary simulator/board defaults and published RBFs remain unchanged.

This is an initial **320x200/4096, low-scan, 40-column, transparent-text**
experiment, not complete Z support. Other formats, analog text colors,
native priority/blackclip, ASIC address wrap/live switching and native software
remain acceptance gates. Unsupported expansion/underline/blackclip controls
fall back to the digital renderer rather than claiming analog support.

The existing video port of each component RAM supplies four sequential bytes:
bank 0 at q and q+400h, then bank 1 at those addresses. Four independent byte
lanes shift only on pixel enables; their high bits form each component nibble.
The palette index is logical G:R:B; output nibbles are conventional R:G:B.
CRTC phase-zero requests complete before the existing phase-14 load.
Synchronous palette responses and graphics-selection tags share the legacy
RGB/blank stage's one-video-edge latency. Real palette ownership masks display
reads during a CPU lease; invalid responses are black, never stale colors.
No GRAM replicas or extra memory ports are introduced.

## Executed and pending checks

```sh
make -C verilator turbo-z-video
make -C verilator test-z-graphics
cd verilator
python3 tests/test_machine_z_video.py ./obj_dir_v13_z_video/Vtop \
  --output obj_dir_v13_z_video/NEW_IDENTITY_DIRECTORY
python3 tests/test_machine_z_video.py ./obj_dir_v13_z_video/Vtop --custom --warm \
  --output obj_dir_v13_z_video/NEW_CUSTOM_DIRECTORY
```

Verilator 5.044 delay-aware compilation succeeds. The independent shifter
fixture passes all 16,384 base addresses, eight pixels and twelve bits at
17,500 / 11,640 / 25,000 ps half-periods, including held physical edges,
mode exit, incomplete startup and reset during a fetch. This fixture uses a
synchronous source model; it does not itself qualify native CRTC or RAM ports.
Video timing/status/text-raster and existing Turbo video unit checks pass.

The original full-machine fixture writes all 96 KiB through actual Z80 I/O,
clears text/attributes, programs a real CRTC and compares every captured
pixel to an independent address/bit/palette formula. No host GRAM mutation,
private font or native ROM is used. It records executable/program hashes before
execution and rejects replacement of the executable during a run.
Custom mode writes all three components of all 4096 palette entries through
the CPU adapter; warm reset must retain palette and GRAM rather than refill.
SYS is 32 MHz, video nominal 42.954540 MHz. Identity runs now allow four seconds,
with reset at 3.5 seconds;
custom-palette runs now allow five seconds, with reset at 4.5 seconds.

The first full-machine run **failed** timing and produced black pixels:
the diagnostic omitted the genuine PPI IN between mode-set and width OUT.
Mode-set's C5 transition arms DAM, so that width write was ignored. Original
ROM, JSON and capture remain in ignored `identity-cold/`; runner SHA-256
`6294b37f86d41cc1f26a61a71783479a140aab72fb10fdd8f8b20956cdd99e9e`.
The corrected diagnostic adds that IN, without changing renderer RTL or
relaxing geometry/pixel assertions. The corrected identity cold run passes
all **64,000 actual full-color pixels** and exact line/frame period checks:
`62,562,500 ps` / `16,145,062,500 ps`, with 30 captured frames. Program SHA-256
`0b42d98ceaace27c75b8bf19ef5d900daacfc3ed775434d2c3965b7bc29967d6`;
log `/tmp/x1-z-video-identity-cold-dam.log`, outputs `identity-cold-dam/`.
The same frozen runner also passes the unchanged 40-column digital-text pixel
test with analog disabled; the rebuilt default model passes timing/reset/FST.

The custom-palette run with reset at 2.5 seconds fails before reaching its
completion marker, with no completed frames. Preserve `custom-warm-dam/`
and `/tmp/x1-z-video-custom-warm-dam.log`. Reset before cold initialization
finishes is a hypothesis, not a proven palette/renderer diagnosis. The longer
custom cold test passes all 64,000 custom-palette pixels. Its later warm-reset
case reaches completion but fails seven pixels at the character whose GRAM
base aliases PPI `1A03`; the separate identity warm case reproduces those
same seven affected pixels. The [DAM transaction correction](DAM_TRANSACTION_STATUS.md)
passes standalone and actual-CPU regressions. Fixed identity and custom warm
tests now each pass all 64,000 pixels, including the seven original failures.
Post-reset I/O traces require all 32 CRTC writes, the two PPI writes and no
GRAM/text/palette refill. This proves retained storage, not just a final frame
recreated by cold initialization. Logs:
`/tmp/x1-z-video-damfix-{identity,custom}-warm.log`; ignored outputs under
`obj_dir_v12_z_video_damfix/{identity,custom}-warm/`. Frozen fixed runner:
`d25519800d563fc840d564aa125066682d0f6b6c0b644e7de1e065eb92b798e6`.
Rebuilding current v13 source under `obj_dir_v13_z_video/` produces that exact
same non-savable executable hash. The new four-case `test-machine-z-video`
matrix and complete baseline suite are running; their terminal results remain
separate from the completed bounded tests above.
Identity/custom frames contain 1,944 distinct colors; do not claim all 4096
raw indices occurred in these patterned frames. Separate palette-storage tests
exhaust all 4096 entries; custom CPU initialization writes all three components.

No combined Quartus fit, CDC/metastability signoff, physical output test,
native Z boot or new RBF exists for this experiment. Four reduced formats,
opaque analog text/priority, active-display palette policy, pending mode/reset
phases, simultaneous CPU/DMA activity and hardware/native acceptance remain
required; shifter success does not complete Z3 or the active work groups.
