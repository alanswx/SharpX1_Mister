# Shared-machine DMA restart service and handler snapshots

October 8, 2026. `TURBO_DMA_RESTART_IRQ=1` now explicitly connects the existing
device restart-interrupt implementation to the actual shared X1 machine.
It requires `TURBO_DMA_IRQ=1` (which requires Turbo and DMA). No board revision
or default machine enables this capability; work groups 1–6 and Turbo Z remain
incomplete. This is not a replacement for full DMA programming or native Turbo
firmware acceptance.

## Contract and integration

[Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf), printed
80–81, describes per-block interrupts during automatic restart, with EOB
status kept clear. Printed 102 disallows status-modified vectors in that
combination. The existing engine retains its separate terminal event and
reloaded counters; the existing DMA→CTC→keyboard ACK/vector/RETI bridge now
services it under a distinct, explicit machine profile. No DMA engine or
bridge behavior is changed in this increment.

The shared RTL parameter is appended, preserving earlier positional parameter
order. The simulator passes it explicitly. `DMA_RESTART=1` adds both the RTL
setting and matching runner macro to dedicated build targets/directories.
Snapshots retain v12 and DMA revision 7; previously unused identity bit 40
distinguishes restart-service state before deserialization. Completion-only
profiles retain their previous identity and state layout. The new `.dma`
dump adds read-only pending/IUS evidence only for the restart profile.

Ready/match/pulse combinations, status-modified restart and unsupported timing
still reject programming. This is the existing EOB-only restart capability,
not a claim that the entire documented interrupt set is implemented.

## Executed actual-CPU acceptance

Verilator 5.044, SYS 32 MHz / video 28,571,428 Hz; normal ioctl IPL upload/reset,
real CPU/BUSACK, real IM2 and RETI. No private assets or forced interrupts,
grants, model writes, Ready pins or edited snapshots are used.

- Six memory cases pass on fast savable and delay-aware runners: both transfer
  directions, Byte/Burst/Continuous. Three four-byte blocks and three real
  handlers complete. The first handler updates both starting buffers without
  LOAD, checks old live counters and leaves the already-reloaded second block
  isolated. CPU checks the untouched next buffer before block three can conceal
  a redirected write. Final source/destination/guard and exact 12R/12W counts
  pass; Byte has twelve grants, other modes three.
- Six executing-handler snapshots save at 200,000 reference cycles with CPU
  phase marker 1, old counters/new buffers, reload flag 1, pending 0 and IUS 1.
  Restoring for 7,800,000 cycles matches fresh 8,000,000-cycle execution:
  stable final JSON and all RAM/text/attribute/sub-RAM/CPU/DMA dumps. Only
  invocation-local download bytes and accumulated video hash are excluded.
  Completion-only↔restart-service states reject before deserialization. Both
  runner hashes and snapshot bytes are checked for changes.
- Six additional pre-ACK snapshots hold the CPU genuinely DI in a real
  instruction loop. At save time, exactly four pairs have completed, pending
  is 1, IUS is 0, reload is 1, and both buffers/counters still contain their
  old addresses. Each resumes through all three genuine handlers/blocks to
  exact fresh execution, including cross-profile rejection. These check the
  retained terminal event before ACK, not only its cleared handler value.
- Twelve FDC cases pass on both fast and delay-aware runners: A/B, both
  transfer directions, all three modes. Each performs three whole READ SECTOR
  commands with 768 DRQ-paced DMA read/write pairs and three real handlers.
  The handler checks FDC status and buffer isolation before issuing the next
  command; it does not stop FDC clocks or stretch Ready to hide late servicing.
  CPU FDC-data accesses and disk writes remain zero, both whole images remain
  unchanged, and payload/guards match the selected drive's distinct sector.
  Continuous has three grants, Byte/Burst 768.
- The actual-board-frequency single-clock fast profile also passes all six
  memory and twelve FDC cases at SYS/video 28,571,428 Hz. The runner reports
  that exact frequency and each final fixture asserts it. Its 8,000,000
  cycles remain 32 MHz reference-duration units, not physical edge counts.
  This is clock-matched simulation, not a fitted DMA build or hardware test.
- The existing real-CPU nested DMA/CTC and three-device real-MR16 mailbox
  diagnostics pass on the restart-enabled fast model, including cold repeats.
  Those diagnostics program completion interrupts, not concurrent restart
  causes; do not promote them to a restart-contention matrix.
- Four completion-only delay-aware profiles and the standalone restart unit/
  21 real-CPU restart cases pass. Two unmodified, executing completion-service
  states also cross-restore in both directions between the earlier frozen
  revision-7 runner and the new completion-only build, with exact continuation,
  two blocks/guards/RETI and all dumps. No old state is converted.
- `lint-wrapper`, Python syntax checks and `git diff --check` pass. Wrapper
  lint is not Intel PLL simulation, fitting or hardware acceptance. Inherited
  TV80/MR16 missing-pin and width warnings remain visible; none is suppressed
  by this increment.

The original new fixture incorrectly selected inactive physical Ready in
Byte mode and expected the wrong active-low RR0 IP bit. It stops after one
pair in `/tmp/x1-machine-restart-{snapshot,timing}.log`. Programming active-high
Ready for memory transfers and expecting ACK-cleared RR0 fixes the diagnostic,
not RTL or its acceptance conditions. The final memory tests do not FORCE READY.

## Negative controls and identities

The unchanged real-CPU test fails on a completion-only build: restart programming
is unsupported, no pair occurs, and the CPU cannot publish success. A separate
ignored machine restores only the original first-destination buffer bug; it
fails with CPU `EE` after eight pairs, before a third block could hide the defect.
Production RTL and private assets are untouched by either control.

| Frozen executable | SHA-256 |
|---|---|
| Restart savable | `8c908ea7b90bcf26af9a804e794df8c459563bcadc1f1e455e577a80d75e1821` |
| Completion-only control | `8556ceeef2d6126d15605d011a1ec0970c1c1342164e5d2f2fdea2134d51f68d` |
| Restart non-savable fast | `d426ec508856b4d8db5ae79072769f99f0f0027f86132d622ab4617cd3c5e315` |
| Restart delay-aware | `a8601ef7abbdee9871fd706a426a060e819966420d85f16e5bd48bbbc036d287` |
| Restart actual-board single-clock fast | `3058ff48dce8da0527ffc8afe7a21b47c584a0871c473f5b3c121ee673e67004` |
| Earlier completion compatibility runner | `cb1aee323526d60ce20ed1ca86457e7680a637eaf35f2d8afb94336355b2ffd8` |

Unchanged DMA engine SHA-256:
`6e3c7cea90bb387f813fcd36fa9a40984ec52ffc01cfa1c50feaeb287b393fe4`.
Logs: `/tmp/x1-restart-shared-snapshot-final.log`,
`/tmp/x1-restart-pending-service-snapshot-final.log`,
`/tmp/x1-restart-shared-board-final.log`,
`/tmp/x1-restart-shared-timing-final.log`,
`/tmp/x1-machine-restart-timing-qualified.log`,
`/tmp/x1-machine-restart-fdc-{fast,timing}.log`,
`/tmp/x1-restart-shared-nesting.log`, `/tmp/x1-restart-default-completion.log`,
`/tmp/x1-restart-device-regression.log`, `/tmp/x1-restart-completion-compat.log`,
`/tmp/x1-restart-{disabled,shared}-negative.log`.

## Reproduction and remaining gates

```sh
make -C verilator test-machine-dma-restart-irq-snapshot
make -C verilator test-machine-dma-restart-irq \
  DMA_RESTART_DIR=obj_dir_v12_dma_restart_timing
make -C verilator test-machine-dma-restart-fdc \
  DMA_RESTART_DIR=obj_dir_v12_dma_restart_fdc_fast DMA_TIMING=--no-timing
make -C verilator test-machine-dma-restart-fdc \
  DMA_RESTART_DIR=obj_dir_v12_dma_restart_fdc_timing
make -C verilator test-machine-dma-restart-board
```

CI schedules all four targets with their full durations and 900-second
per-target limits; a hosted pass for this change has not yet been observed.
The completed hosted runs on `bc2cd9a` and `63600fb` terminate with exit 124
at `test-board-single`'s old 180-second allowance, after clock/keyboard/MR16
passes while the dual-disk matrix executes. That target now also receives
900 seconds; no case, duration, assertion, clock model or compiler is changed.
Its new hosted terminal result remains required, not inferred from this fix.
Physical and board-frequency delay-aware/snapshot restart, source-bound Quartus fit/CDC, Main reset,
IRQ-service/owned/SD snapshots and reset races, long counts, mixed causes,
live-sector sub-block servicing, SIO and native Turbo/Z firmware still need
qualification. The existing MiSTer RBF remains unchanged and DMA-disabled.
