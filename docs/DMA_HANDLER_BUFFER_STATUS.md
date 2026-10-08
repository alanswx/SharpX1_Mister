# Real-CPU restart handlers and buffered addresses

October 8, 2026. Advances DMA work group 2; not shared-machine restart service,
native Turbo firmware or hardware acceptance. Production RTL, PLLs, firmware
and snapshot identity are unchanged from `bc2cd9a` in this increment.

## CPU-driven qualification

`test-dma-restart-irq-cpu` now includes eighteen buffered cases: both directions,
Byte/Burst/Continuous, CE=1/4/7. Three original continuous two-block controls
remain. The actual TV80 program initializes distinct old/new source data and
destination guards, programs WR4/WR6 and IM2, and enters HALT with upstream
IEI blocked until the real terminal event exists. No interrupt or grant is forced.

Each genuine interrupt handler changes both address buffers with WR0/WR4
address-only streams, without LOAD, and executes ENABLE→RETI except at its
third/final service. IUS holds bus requests off throughout the handler. The
second block uses the already-loaded old counters; the third uses new buffers.
Source/destination address observations check every accepted memory operation,
not merely the final buffer contents. The CPU itself checks both destination
payloads and untouched guards before publishing success; a wrong value branches
to a separate failure port/loop. Distinct new data prevents repeated old payload
from qualifying the new block.

Each buffered case completes 12 reads, 12 writes, three genuine ACKs/handlers/
RETIs and exact destination guards. Byte mode has twelve real grants;
Burst/Continuous have three. The first genuine ACK/vector remains held across
eighty stopped-enable master edges, retaining the prior acceptance condition.
Sparse Byte mode may let the CPU HALT before block completion; the fixture
waits for the real pending event while IEI remains blocked, not a guessed delay.

This is the existing diagnostic CPU/DMA ownership mux, not the X1 shared machine.
Physical Ready stays high; Ready stalls, mixed causes, long-count IRQ boundaries
and exact silicon timing are not covered by this increment.

## Executed evidence

The final four-target suite exits zero in `/tmp/x1-dma-handler-buffer-final.log`:
48 CPU cases (18 new buffered, three original restart, twelve completion,
three Ready and twelve service-only cases). The existing CI target invokes
the expanded matrix; no separate reduced hosted variant was introduced.

```sh
make -C verilator test-dma-restart-irq-cpu test-dma-native-irq-cpu \
  test-dma-ready-irq-cpu test-dma-service-cpu HEADLESS_DIR=obj_dir_restart_irq
git diff --check
```

Final fixture SHA-256:
`93397c3f99744de770c23a28b11486f5773c75920091ac5c81c732ef46805615`.
Final restart CPU executable SHA-256:
`c7711154f66dc7cbb230acc1db66075b7550ee16066bdcea67f66be4fca57475`.
Production DMA RTL remains
`6e3c7cea90bb387f813fcd36fa9a40984ec52ffc01cfa1c50feaeb287b393fe4`.

An ignored negative control restores only the original live-buffer destination
selection while keeping the real interrupt engine. It builds, then exits one
on the unchanged final fixture with `CPU buffered restart destination address
9120 write=4` in `/tmp/x1-dma-handler-buffer-negative-final.log`. This demonstrates
that actual handler programming detects the defect previously reproduced by
direct register streams. No assertion, payload duration or enabled-edge hold
was reduced. An added failure-loop PC width warning is fixed rather than
suppressed; the inherited TV80 DIRSET warning remains visible.

## Remaining gates

The [executing reload snapshot](DMA_RELOAD_SNAPSHOT_STATUS.md) now qualifies
that flag in the non-IRQ shared machine. Restart-handler snapshots, combined
Ready/match/restart interrupts, SIO/FDC/multi-device service, schematic-qualified
shared-machine profile identity and native Turbo firmware remain required.
Source-bound Quartus and physical MiSTer gates remain unexecuted for restart
IRQ; the current experimental RBF does not enable it. No private assets were
used or changed. Hosted execution of the expanded target is a separate gate.
