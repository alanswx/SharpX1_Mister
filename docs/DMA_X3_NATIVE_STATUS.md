# X3/DMA native-read follow-up (October 6/7)

The repeated F1/2D-floppy native Arcus renderer probe now reaches a 640×400
disk-read error screen. Its 6000–7500 ms trace proves real CPU setup/enable
of DMA at `1F80` before a floppy sector read; that renderer build disables
DMA. See [DIP/native evidence](TURBO_DIP_STATUS.md). This identifies a missing
capability in that configuration, not a complete cause of every native failure.

## Separate enabled profile

The simulator Makefile now accepts `DMA_VIDEO=1` for the opt-in DMA and
completion-IRQ families, including savable recipes. Both Verilog X3 parameter
and C++ clock/profile macro are passed; the machine still uses 32 MHz system
and nominal 42.954540 MHz video with enables. Default DMA video remains off.
Use distinct build directories when changing parameters. No board default,
PLL, machine input, private asset or snapshot format is changed here.

This profile enables DMA **without** the unqualified combined Kanji backend.
The machine's existing combined-DMA/Kanji guard remains. It is not equivalent
to the renderer profile, and it does not establish native Kanji glyph support,
completion IRQ, high-speed PCG timing or full Turbo/Turbo Z compatibility.

## Executed diagnostic gates

Both full original seven-case machine matrices pass at X3: RAM, RAM under IPL,
A/B reads, A writes, B deleted/CRC-repair writes and protected B. Each case
retains its original eight-million reference-cycle duration, actual CPU grant,
count/readback, whole-image and no-CPU-FDC-data assertions. Fast log:
`/tmp/x1-dma-x3-fast-matrix.log`; delay-aware:
`/tmp/x1-dma-x3-timing-matrix.log`. Build warnings remain inherited.

The original generated diagnostic `test_dma_native_read_stream.py` uses the
observed register stream `C3 83 7D FB 0F FF 03 2C 10 8D 00 80 92 CF 87`.
A generated N=3, R=4 sector supplies 1024 distinct patterned bytes through
real mount/SD/FDC DRQ. CPU checks all destination bytes at `8000..83FF`,
terminal DMA count and both address registers. No force-ready, grant injection,
game byte copying or header patching. Cold/warm fast cases pass 1024/2048
actual pairs/grants, respectively, zero CPU FDC data transfers and unchanged
protected source media (`/tmp/x1-dma-native-shape-fast.log`). Delay-aware
cold/warm execution also passes (`/tmp/x1-dma-native-shape-timing.log`).
Warm reset is ten microseconds at 250 ms in the
original half-second run, without reloading ROM or remounting media.

Fast runner SHA-256:
`09c6f31c3a6d63397ec937a4c635dccec1844e8c695b51a3aae50a99db736325`.
These are original asset-free diagnostics, not native firmware acceptance.

## Native probe and remaining gates

Two fresh protected eight-second Arcus boots are running under a frozen
X3/DMA fast runner with the authorized Turbo IPL and ANK16, Disk 1 A / Disk 2 B
explicitly exploratory, and Kanji disabled. Private ignored outputs:
`output_files/arcus-dsw-f1-dma-x3-eight/`; log
`/tmp/x1-arcus-dma-x3-eight.log`. The first run completes with 26,624 DMA
reads/writes/grants, 2,826 host requests, zero host writes and 469 actual
640×400 frames. Final frame hash `d1d122b69457d46d` displays the Glodia logo,
visually inspected from the terminal PPM's lossless `cold-final.png` conversion.
This is progress beyond the disk-read error, **not gameplay**. The independent
repeat also completes with identical reports/dumps/CSV/frames and unchanged
input hashes. Collector exits zero; logo boot is repeatable, not gameplay.

A sixteen-second probe with the existing exploratory late-Space key script
is also running in a distinct ignored `arcus-dsw-f1-dma-x3-sixteen/` folder,
same frozen executable/assets/disks. Space at eight seconds is an explicit
input experiment, not a verified release-specific start command. Log:
`/tmp/x1-arcus-dma-x3-sixteen.log`.

The first sixteen-second run completes: 57,344 real DMA pairs/grants,
2,914 host requests, zero host writes and 913 actual 640×400 frames. Final
hash `03702d99714c4325` is a black frame, visually inspected, not gameplay.
The 14–15.5 second trace contains further native DMA programming and real
FDC data reads; execution progresses beyond the earlier logo. Its independent
repeat remains running. A 32-second savable two-drive attempt exits 2 before
simulation with the intended `dual-drive snapshots are not supported` guard;
the failed collector evidence is retained in `arcus-dsw-f1-dma-x3-thirtytwo/`.
No state-header bypass or unverified dual-drive serialization was added.
A fresh protected 32-second **non-savable** two-drive native probe now runs
in `arcus-dsw-f1-dma-x3-thirtytwo-native/`, preserving the same disk assignment
and late-Space input experiment. Log `/tmp/x1-arcus-dma-x3-thirtytwo-native.log`.

A frozen single-clock Quartus rebuild including the DIP implementation is
running under `output_files/quartus-5ge19D0o/`; runtime preflight completes
and map has completed; fitter placement preparation has begun. No completed
fit/timing/RBF or hardware
acceptance is claimed. Log: `/tmp/x1-dip-single-quartus.log`.

Next: inspect terminal actual images, reports and bus transactions; qualify
native transfer/count/interrupt behavior, combined DMA/Kanji ownership and
ROM WAIT, further X3 snapshots and reset during owned transfers, broaden video targets,
then fit current sources and test hardware. No new RBF has been built for
this profile. The recommended single-clock RBF remains unchanged.

## Subsequent default-build and snapshot qualification

The initial `DMA_VIDEO=0` flag expansion emitted an empty `-CFLAGS` value;
Verilator then passed the next RTL `-G` parameter to the C++ compiler.
The default savable build failed, preserved in
`/tmp/x1-dma-baseline-savable-build.log`. The Makefile now omits the entire
optional flag argument when X3 is off. Default plain/savable/IRQ-savable
builds pass; the full seven-case default transfer matrix passes
(`/tmp/x1-dma-default-fixed-matrix.log`), and all four existing default
completion-IRQ snapshot/service cases pass
(`/tmp/x1-dma-default-irq-snapshot-fixed.log`). No RTL workaround was added.

`test_dma_x3_snapshot.py` reuses the same original generated 1024-byte read
diagnostic. At 100 ms it checkpoints a genuinely partial FDC/DMA transfer
(strictly between zero and 1024 pairs), then continues to the original 500 ms
endpoint. All final chip reports, counters, destination bytes and five RAM/CPU
dumps exactly match uninterrupted execution. Host request/write/sync counters
match exact additive totals. X3/non-X3 states reject each other with the same
disk supplied, so a missing fingerprint cannot explain rejection.
Log `/tmp/x1-dma-x3-snapshot-additive.log`, exit zero. Initial fixture failures
are retained: the 125 ms checkpoint was already complete, restore initially
omitted required media fingerprints, and per-invocation host counters were
mistakenly treated as cumulative. The corrected test retains real partial
transfer and exact state/data assertions; snapshot bytes are never patched.

The new target is added to asset-free CI. The earlier renderer run
[37556227786](https://github.com/alanswx/SharpX1_Mister/actions/runs/37556227786)
passes on `5b93c25`, taking 41m47s for its 52-target job including pinned
Verilator build. The expanded workflow allows 90 minutes overall, retaining
all per-target limits, assertions and simulation durations. This is not a
hosted pass for the newer default-build fix or X3 snapshot target.
