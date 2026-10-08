# Executing DMA auto-reload snapshot seam

The opt-in shared-machine DMA runner now passes an original, asset-free CPU
diagnostic in both transfer directions. This qualifies serialization of the
revision-7 reloaded-destination flag; it does not enable restart IRQ on MiSTer.

`make -C verilator test-dma-reload-snapshot` builds a separate savable fast
runner. The CPU programs three four-byte Byte-mode blocks with automatic
restart. After block one, it changes both starting buffers without LOAD,
reads back the still-old counters, and delays before starting block two.
The snapshot is taken during this executing delay, not at HALT.

Read-only `--dump` instrumentation confirms `reload_destination=1`, new
starting buffers and old live counters at the save seam. Restoring and running
7,800,000 reference cycles matches fresh execution for 8,000,000 cycles:
all stable final JSON fields, RAM/text/attribute/sub-RAM/CPU/DMA dumps, twelve
reads/writes/grants, final payloads, guards and real CPU `DMA!` completion.
Invocation-only download bytes and accumulated video hash are excluded from
JSON comparison. No debug state injection or snapshot patching is used.
The test checks executable and saved-state hashes for changes.

## Executed evidence

Both directions pass on Verilator 5.044. Frozen runner SHA-256:
`28bae684465dac4e5c5f9c0964d4d55ff8d1837c9b5c54e63b4635e24293645b`.
The final target exits zero; local log:
`/tmp/x1-dma-reload-seam-final.log`.

A separately built negative-control machine restores the original first-write
redirection bug, without modifying production RTL. It fails the CPU payload
check after eight reads/writes, returning `EE` instead of `DMA!`; log:
`/tmp/x1-dma-reload-negative.log`. Thus the regression detects the original
defect even when continued execution is compared against the same faulty model.

The target is added to hosted diagnostics, but a hosted pass for this change
has not yet been observed. No private assets were used or changed. Default
machine profiles, RTL and snapshot identity are unchanged in this increment.
The complete delay-aware baseline `make -C verilator test` subsequently exits
zero, including its disk/loader/PCG/index checks; log:
`/tmp/x1-dma-reload-baseline.log`.

## Remaining gates

This is non-IRQ Byte-mode shared-machine acceptance. Restart-handler snapshots,
mixed Ready/match/restart causes, other mode/count boundaries, native Turbo
firmware and source-bound Quartus/MiSTer acceptance remain separate work.
