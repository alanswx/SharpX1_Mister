# Committed-descriptor glyph half selection

October 14, 2026 continuation (probe manifests use October 15 UTC). The
standalone `rtl/x1_z_kanji_cache.sv` now accepts optional
`VID_DESCRIPTOR_HALF_BIT`. Default `-1` preserves caller-supplied five-bit
row/half addressing. A valid descriptor bit selects the half from the same
committed or collision-forwarded descriptor as the returned glyph and bank;
only the caller's four row bits remain active. Descriptor bit 22 can represent
Kanji bit 6 in a future `{mode,kanji,attribute,text}` packet. That packing is
not connected to the machine yet.

Both RAM addressing and returned offset use this captured half. A completed
miss returns the requested row with half zero and zero data/metadata; idle
outputs remain zero. All 32 glyph bytes still drain before publication. The
existing two-sampling-edge response and invalidation retirement are retained.
Payload reads are unconditional synchronous registers followed by selection
using registered bank/validity signals, permitting Quartus 17 RAM inference
without adding an edge. Uninitialized or colliding inactive-bank data is masked, not treated
as valid pixels.

This component remains outside `rtl/machine.qip` and all board/machine
profiles. It does not implement CPU text-write admission, automatic refill,
machine rendering, native visibility or Main/OSD reset dispatch.

## Focused simulation

`make -C verilator test-z-kanji-cache-half` completes zero in session `58493`,
folder `x1-z-kanji-cache-half-t5ez__di`, log
`/tmp/x1-z-kanji-cache-half-sync-final.log`. Four positives, eleven exact RTL
mutants and two runtime parameter rejections give seventeen warning-free
Verilator 5.044 timing/assertion builds/runs. Optimized Python refuses before
allocating evidence; compilation errors and global timeouts cannot qualify
fault controls.

The fixture connects the real frontend/backend and delayed/BUSY mock DDR.
Every positive uploads and verifies all 262,144 generated font bytes. Each
cell receives three complete versions: half zero, half one of the same glyph,
then half zero of a different glyph. Every version must return all sixteen
rows with exact data, descriptor, tag and latency. Update inputs are poisoned
immediately after admission. Caller half toggles through both values at every
row; its opposite-half witness must exceed sixteen per cell.

An extra highest-cell update stops VID during publication, then requires
new-bank/new-half collision forwarding on the exact fourth resumed edge.
Stopped-VID invalidation must wait for recovery, retire old replies and leave
only zero-data misses during a sparse full-cell scan. All transport ledgers
derive expected word addresses/lanes/data from upload and admitted update
intent, independently of observed DDR data.

| Positive | Cells | SYS | VID half-period | Descriptor width / half bit | Updates | DDR reads |
|---|---:|---:|---:|---:|---:|---:|
| full32 | 2,048 | 32 MHz | 11,640 ps | 32 / 22 | 6,145 | 196,640 |
| full100 | 2,048 | 100 MHz | 11,640 ps | 32 / 22 | 6,145 | 196,640 |
| one-bit-slow-vid | 8 | 100 MHz | 20,000 ps | 1 / 0 | 25 | 800 |
| wide-top-bit | 8 | 32 MHz | 11,640 ps | 64 / 63 | 25 | 800 |

These runs last approximately 132.363 / 53.875 / 11.036 / 34.193 simulated ms.
They use synthetic scans, not actual CRTC frames. Unlike the default cache's
separate full-address regression, this focused gate does not exhaust all
8,192 glyph addresses. Its controls reject caller/live/pending/unforwarded/
adjacent/flipped halves, wrong returned half or payload address, invalid-half
leakage, missing commit forwarding and live-row substitution. Half `-2` and
half `32` at descriptor width 32 must elaborate/build and then fail the exact
`Z_CACHE_PARAMETERS` assertion at runtime.

## Current-source dependency refresh

All current-source jobs are terminal, exit zero:

| Gate | Cases | Evidence folder | Session / log |
|---|---:|---|---|
| Descriptor half | 17 | `x1-z-kanji-cache-half-t5ez__di` | `58493` / `/tmp/x1-z-kanji-cache-half-sync-final.log` |
| Default cache | 19 | `x1-z-kanji-cache-fqlxtk26` | `32165` / `/tmp/x1-z-kanji-cache-sync-default-final.log` |
| Lifecycle | 13 | `x1-z-kanji-quiesce-jz3781bk` | `90871` / `/tmp/x1-z-kanji-quiesce-sync-cache.log` |
| Actual Z80/PCG | 11 | `x1-z-kanji-cpu-service-iknm9csp` | `17850` / `/tmp/x1-z-kanji-cpu-service-sync-cache.log` |

Together these are twelve positive configurations and forty-eight exact
rejections, including the two invalid-parameter cases. Forty-nine builds are
strict warning-free; eleven connected CPU builds preserve exactly the same
34 reviewed warning headers. Separate strict bridge lint remains warning-free.
Every positive counter in the default/lifecycle/CPU refresh matches its
original frozen run, including actual edges, DDR reads and completed updates.
The CPU gate repeats twelve complete boots and 12,504 independently checked
port reads, retained-font reset and owned-read recovery.

Read-only review in `x1-z-cache-half-review-y9kkuwuv` verifies every current/
frozen input, executable and run-log hash; rechecks compiler warnings, exact
rejections and program/font/CPU traces; and repeats the independent bus audit.
Review SHA-256:
`1c1a8a6963ec3c8f90c04f6322e446ffdee40239c6b78ec8eb61e110ac9627c3`.

Only two default-cache mutation injection sites moved with the new output
mux; their invalid/idle-data assertions remain unchanged. Lifecycle and CPU
checker edits update only the bound cache digest. Their fixtures, CPU program,
font, independent bus oracle and warning inventory remain unchanged.

## Quartus resource gate

The earlier `8e5d431f…` source passed simulation, but descriptor bit 22 failed
Quartus 17 mapping with uninferred payload RAMs and error 276003. No fit ran
for that profile. Evidence is preserved under
`/tmp/x1-z-half-quartus-build-TcCWoQRu/output_files/`, failed probe
`z-kanji-cache-probe-vsMjX5zf`, and local retrieval
`x1-z-cache-probe-retrieval-938gk4hh`. Its successful default fit does not
qualify the subsequent repair.

The repaired source passes separate `CACHE_HALF_BIT=22` and
`CACHE_HALF_BIT=-1` probes using the frozen script. This sets an explicit top-entity
parameter in an isolated QSF copy. The manifest binds original and derived
QSF separately, plus RTL/project/SDC/script; input hashes are rechecked after
map/fit. The synthesis reports confirm actual elaboration of both parameter
values. Remote root: `/tmp/x1-z-sync-half-quartus-build-ylqMb5g3/output_files/`.

| Half selector | Probe | ALMs / 41,910 | Registers | M10Ks / 553 | RAM bits |
|---|---|---:|---:|---:|---:|
| Descriptor bit 22 | `z-kanji-cache-probe-asZgXCno` | 3,715 | 4,314 | 138 | 1,142,784 |
| Caller (`-1`) | `z-kanji-cache-probe-kInFAoiz` | 3,717 | 4,327 | 138 | 1,142,784 |

Probe session `26174` finishes zero; log
`/tmp/x1-z-kanji-cache-sync-half-quartus.log`. Manifest times are
03:58:38–04:00:24 UTC and 04:00:24–04:02:12 UTC respectively. All six input
hashes, post-build checks, derived QSF, current local sources and report
parameters/resources pass read-only review in
`x1-z-cache-probe-retrieval-6mnss6j8`. Review SHA-256:
`188805f17b3d510a8bae8a9021c6e3b2b858ec3d845902e22c14556a854f0282`.

Mapping retains two unrecognized `async_reg` warnings and two dual-clock RAM
collision warnings. Bit 22 additionally reports the intentionally ignored
caller-half alias as assigned-but-unused; no suppression is added. Each fit
retains LogicLock licensing, incomplete I/O assignment and unlocated clock
pin warnings, the last a critical warning for these two virtual-probe clocks.
Functional collision exclusion still needs physical bundled-data/CDC proof.

These virtual-pin, standalone probes use Cyclone V `5CSEBA6U23I7`, Quartus
17.0.2 Build 602, synthetic SYS32 / 23.280-ns VID clocks, mapping and fitting
only. No combined board fit, STA/physical CDC, DDR allocation, RBF or MiSTer
acceptance follows. The MiSTer at `10.0.2.14` has not been contacted here.

## Frozen inputs and remaining integration

| Input | SHA-256 |
|---|---|
| Cache RTL | `e9671fb7ef9548f265cc50c4e3effdc6358c3d292c90eca1ca2b4788ca310f0e` |
| Half fixture | `d2c68432bc588c6d77d1c4c8a0668b11d22083df85b6bae94d08d43fe479869b` |
| Half checker | `f207cdc1366f0f3274c771f809cd318bc67cbe67f1fb67eb245adeba86c2c204` |
| Default cache checker | `f2115166b65673a38d716a9753b5e7c61ba0a1cab818ae45386fd29479613f37` |
| Lifecycle checker | `ffc42a53594150d392a286c56d3d504ccc92d421954bb114e6f42932c78dd5e5` |
| CPU checker | `f067c17e7e6fb0ca847414f3dcce8ca7622cf9e05fed8b80b4e1308e3fb2e9da` |

Focused terminal report SHA-256:
`898d36216cde37a14b7a37a99d631367e0dfc492f95c9249b986a9c1381f7edc`.
Default/lifecycle/CPU terminal report SHA-256 respectively:
`1169d8999429be11a3f0787f8ef852edcb953bedd5ead1d8f10128c8b40e969e`,
`389f3ba408c615f0bf22efe9d47204f1e557ab3431200dcea32c4b4763604f9a`,
`4f5251a410c885d5169c2b819f80f3009e0c4e87dcbd4832d883b2119c9890a7`.
Backend/frontend/arbiter/lifecycle/CPU bridge RTL retain their earlier hashes.
The focused target is scheduled in CI with a 900-second limit; no hosted
result is claimed.

The later [VRAM write-boundary component](TURBO_Z_VRAM_WRITE_STATUS.md) now
qualifies one captured real CPU write, complete publication and one VRAM strobe
in a separate fixture. Connect that component to actual machine decode and make
renderer request/load consume its packet. Resolve refill-before-write
WAIT/native visibility and missing-font boot policy. Then qualify real-Z80
RGB, reset/upload/stopped-clock ownership, ordinary-profile identity and
simultaneous devices. Native fonts, broader rasters/ANK/PCG, snapshots and
physical full-board memory/timing remain open. See
[the external-font plan](TURBO_Z_EXTERNAL_FONT_PLAN.md).
