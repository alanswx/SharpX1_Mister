# DMA Byte-mode sequential Stop on Match

October 6, 2026. Original GPL-2.0-or-later implementation in
`rtl/x1_dma.sv`, restricted to sequential transfer/search, Byte ownership,
standard memory/I/O cycle lengths. Defaults remain DMA-disabled.
This is an increment in work group 2, not completed DMA or Turbo Z support.

## Contract

Primary [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf),
printed 76, Table 12's intact sequential Byte row: a match on operation M
completes M reads and M writes, reports byte counter M-1, source advanced M
and destination advanced M-1. WR3 bit 2 enables stopping; mask bits set to
one exclude comparison. The matching destination write completes before
sticky RR0 match status is asserted and DMA disables/releases ownership.
No following source read or fabricated destination transaction occurs.
WR3 immediate-enable supports this bounded stop mode too.

Match on the terminal byte sets both match/EOB. Automatic restart does not
override match stopping: the engine does not reload either counter or clear
the match. Nonmatching bytes retain the previous sequential block policy.
Pure search, non-Byte stop, IRQ and variable timing still fail closed.
The [search contract](DMA_SEARCH_CONTRACT.md) records the older/later
primary-reference disagreement that blocks extrapolating Byte behavior.

The existing match latch is reused, not a new clock/state register. DMA's
snapshot profile advances to revision 2 (additional bit 52) because restored
commands now have changed behavior. Ordinary non-DMA v12 identity stays
unchanged. No supported DMA snapshot restore target or native qualification
is claimed; regenerate affected states, never modify serialized bytes.

## Verification

Verilator 5.044, assertions and timing enabled:

```sh
make -C verilator test-dma-compare test-dma-cpu test-sio-dma test-sio-dma-cpu \
    HEADLESS_DIR=obj_dir_v12_dma_byte_stop
```

Exit zero. The fixture retains all 6,144 comparison cases and adds 4,096
Byte stop cases: all 256 masks, two source directions, four match positions,
CE=1/4. FF correctly matches immediately even if a later position was
selected. Exact actual bus read/write totals, both counters, byte count,
remaining length, sticky match/EOB, disabled engine and no automatic reload
are checked. Additional tests cover a matching write under WAIT and stopped
CE, nonmatching stop through EOB and WR3 immediate enable. Held bus/data
checks remain active; no warning suppression was introduced. The initial
build rejected three width warnings; explicit-width fixture expressions
fixed them rather than suppressing warnings.

The actual shared-CPU diagnostic now includes eight generated-ROM stop
profiles (both sources, four positions), CPU readback of all counters and
status, transferred prefix and untouched destination suffix, including
terminal match with automatic restart programmed. Existing twelve
non-stopping CPU profiles retain their eight-million-reference-cycle runs.
Final-source fast/delay-aware execution is still being qualified; do not
infer native DMA use or hardware acceptance from these synthetic programs.

Source SHA-256:
`689dbd30821af9d42f00cded8555abab4b8d0bce611162d6992028a4e2fc746c`.
Final standalone log `/tmp/x1-dma-byte-stop-final-regression.log`.
Final comparison/stop unit SHA-256:
`b82c49e5990beb8c0eca0d86cd8155c0701c0f99fb4ed9085301eff4719bc8c6`.
Transfer/restart matrix and shared-machine logs remain separate gates.
Quartus fit, native Turbo software, physical pin timing and board tests
remain unavailable/unverified.
