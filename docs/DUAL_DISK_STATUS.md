# Two-image disk increment — October 5, 2026

The shared `rtl/sharpx1.v` now supports independently mounted A/B D88 images
through **one** WD1793-family controller, register set, IRQ/DRQ engine and
sector index. This is a tested development increment, not complete two-drive
mechanical fidelity or Arcus compatibility. The source-bound
[two-image FPGA build](DUAL_DISK_QUARTUS_BUILD.md) fits at 48% ALMs and passes
constrained paths at all eight analyzed corners, worst setup/hold
+0.394/+0.080 ns. All 334 FPGA inputs match `ffc1c1c`. External I/O constraints,
CDC/reset review and hardware remain open. No hardware deployment occurred.

## Architecture and observable limits

`rtl/x1_disk_media.sv` retains the active image owner until the controller's
published request, ACK pin and six-clock ACK history have fully drained.
Selection changes and active mount/eject pulses immediately quarantine ready
and invalidate the scanner; the requested image is rescanned only after the
old transfer completes. An unrelated inactive-drive mount does not invalidate
the current index. Descriptors survive warm reset in the caller.

Selection incurs an **index-rescan/not-ready interval**, not realistic drive
selection latency. A selection during a command aborts its controller/scanner
work; a host write already accepted can still finish against its original
owner. No timeout/cancel protocol or speculative write rollback is claimed.
Host identity is latched by drive, not a physical MiSTer media-generation
protocol; same-slot replacement while a host request is pending still needs
hardware transport validation.

`PHYSICAL_DRIVES=2` keeps two physical head positions separate from the shared
WD track register. Media selection/rescan does not reset track/sector/data
registers or seek either head. Real machine reset retains the inherited head
reset behavior; it is not a claim that physical hardware resets a head.
Drive selections 2/3 stay not-ready and cannot move either implemented head.
Default single-drive vendor instantiations retain their previous behavior.

Motor commands and 1.2-second hold counters are independent for A/B. Held bus
writes do not restart the falling-command hold repeatedly. This is a defined
adapter policy: local MAME uses a shared motor timer, so cross-drive shutdown
semantics still require a schematic/hardware cross-check. The existing
free-running 300-rpm index source is shared, not independently phased physical
spindles. Seek behavior remains the inherited simplified model.

MiSTer uses `hps_io VDNUM=2`, separate `S0`/`S1` OSD mount slots and per-drive
size/read-only descriptors. Only the retained owner receives the FDC SD request;
ACK is selected from that owner. Shared data-buffer buses remain unchanged.
Wrapper lint elaborates successfully; inherited warnings remain. This is not
HPS mount validation; Quartus fit/timing is recorded separately above.

## Simulator and verification

`--disk` selects A; `--disk-b` selects B. Both are preflighted separately and
read-only by default. Writes require an explicit **new** `--disk-output` or
`--disk-b-output` copy; neither original is overwritten. Duplicate export paths
and either input as an output are rejected. The runner freezes each request's
owner through ACK and rejects an unexpected owner change. Two-drive snapshots
are intentionally rejected; single-drive snapshot layout version was bumped
to reject older serialized RTL safely. Trace diagnostics use explicit
read-only simulator outputs, not optimized-away internal wire names.

```sh
make -C verilator headless turbo-single turbo-fast test-disk-control
cd verilator
python3 tests/test_dual_disk.py ./obj_dir_headless/Vtop
python3 tests/test_dual_disk.py ./obj_dir_turbo_single/Vtop
python3 tests/test_drive_selection.py ./obj_dir_headless/Vtop
```

Generated CPU tests pass repeated distinct-pattern A/B reads, alternating seeks,
head retention, shared register retention, logical/physical track mismatch RNF,
retained shared STEP direction across selection, unsupported-drive head isolation,
independent protection, isolated cross-block writes to **each** drive and
unchanged originals. A separate B-only mount starts with A empty, verifies B
data and checks that returning to A remains not-ready without any absent-image
host request. Baseline is delay-aware 32 MHz sys / 28.571428 MHz video;
single is delay-aware 28.636364 MHz sys/video. Each six-trial suite uses
7,000,000 reference cycles (218.75 ms per trial), a recorded synthetic RAM
download/reset and no private software bytes.
The B-only checks add two 2,000,000-reference-cycle trials (62.5 ms each).
All eight trials pass in baseline, single and fast Turbo builds. The Verilog
loop-declaration compatibility fix was followed by fresh CPU/motor checks;
it does not change the defined counter behavior.

The descriptor bench passes pending-owner hold, inactive mount isolation,
active eject/replacement, live protection and unsupported-drive recovery.
The connected real-FDC bench bypasses host preflight and verifies stalled A
scan ownership, an accepted A write's owner/LBA/buffer through B selection and
CE-stopped reset, unchanged B bytes, malformed/ejected B rejection and A recovery.
Default single-drive scanner and pending-read/write abort/reset regressions
also pass. Existing generated variable-size/read/write disk tests pass in fast
Turbo after explicitly waiting for ready on returning to A; no byte/status
assertion was weakened. CTC IM2/cold-key coexistence and bus-trace identity pass.
The full baseline `make test` exits successfully, including every calculated
base-video pixel, keyboard, PSG, RAM/GRAM, PCG, disk and board-adapter fixture.
It started before the final STEP-direction fix; the final disk/register/STEP,
transport/reset and motor tests were requalified separately afterward. The
earlier full-suite results are not represented as a single frozen final binary.

## Native software and next gates

An exploratory Arcus run mounts staged Disk 1 in A and Disk 2 in B explicitly;
this ordering is **not documented release acceptance**. It passes the prior
drive-B not-ready wait and produces non-black, visibly incorrect 640x400 RGB.
This is not a recognizable title or gameplay pass. B is neither fabricated
ready nor a mirror of Disk 1. Final source-bound probe details belong in
[commercial compatibility](COMMERCIAL_COMPATIBILITY.md).

Remaining: authenticated disk-order/instructions, active replacement before
ACK and during writes on HPS, metadata caching/selection timing, independent
index phase/mechanics, accurate seek/track-register stepping, authentic Turbo
IPL/font/video work and physical reset/mount/write tests.
Original project code and generated fixtures were added; vendor notices and
licensing restrictions are preserved. Private media/evidence remains ignored.
