# Auto-reloaded DMA destination versus starting buffer

October 8, 2026. This fixes an independently reproduced DMA defect, not full
work-group-2 or Turbo Z acceptance. Ordinary board profiles still leave DMA off.

## Reproducer and correction

The extended native-register fixture fails on `2cfe29b`: after the first
auto-reload, its interrupt handler changes both starting buffers without LOAD.
The second block's source counter remains old, but its first destination write
uses the new starting buffer: address `1120` instead of `1000` in B→A Byte mode.
Original evidence remains in `/tmp/x1-dma-restart-buffers-diagnostic.log`.

[Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf), printed 60
and 124–125, distinguishes starting buffers from the counters loaded at an
auto-restart boundary. The correction records that the first destination was
already loaded by auto-restart and uses that counter, not a subsequently
changed buffer. The ordinary explicit-LOAD first-destination policy is unchanged.
Hardware/software reset and LOAD clear the new flag; both automatic-reload
paths set it, and a completed destination write consumes it.

The correction applies to the DMA device, including non-IRQ automatic repeat;
it is not conditional on the restart-IRQ qualification parameter. Added DMA
serialized state has revision 7, using previously unused application-identity
bit 41. Non-DMA v12 defaults are unchanged. Regenerate DMA states from execution;
do not convert or patch older states.

## Qualification

The expanded register/CPU targets exit zero in
`/tmp/x1-dma-restart-buffers-final.log`:

- 9,216 vector/mode/transfer-or-search/direction cases at CE=1/4/7, with exact
  source as well as destination addresses and original retained-IRQ checks.
- 36 three-block buffer-update cases: updates during the first service leave
  the already-loaded second block unchanged and affect the third block only.
  Both directions and all three modes, transfer and pure search, are covered.
- 36 delayed-grant cases: terminal BUSRQ release with BUSACK still owned,
  sixteen stopped-enable edges, retained pending event, no premature IRQ or
  new read, then delivery only after actual grant release.
- Original owned/stopped-CE reset and three real TV80 two-block service cases.

The first delayed-grant fixture failed at sparse CE because it sampled the
combinational capture wire after the preceding enabled edge. Its corrected
fixture qualifies capture immediately before the accepting edge; production
capture conditions were not weakened. The intermediate bound failure when a
12-read fixture reset its test counters too late is also preserved. Those are
fixture issues, separate from the original wrong-destination RTL failure.

The negative-control copy restores only live-buffer first-destination selection.
It builds, then exits one with the original `1120` versus `1000` assertion in
`/tmp/x1-dma-buffer-negative.log`. All build/control outputs remain ignored.

The nine-target default/completion/Ready/search/service suite exits zero in
`/tmp/x1-dma-restart-buffer-regressions.log`, including original 65,537-byte
non-IRQ restart boundaries and 27 pre-existing CPU service profiles. It used
the correction before the subsequent comment-only flag explanation.

Four actual shared-machine CPU automatic-repeat profiles (both directions,
transfer/pure search, three blocks and buffered updates before terminal reload)
pass on both final fast and delay-aware runners. Logs:
`/tmp/x1-dma-buffer-machine-fast-final.log` and
`/tmp/x1-dma-buffer-machine-timing-final.log`. These are non-IRQ machine profiles;
they do not qualify native Turbo software or restart service integration.

All four native-programmed completion-service snapshot profiles pass fresh
continuation with exact report/RAM/CPU agreement and cross-profile rejection
in `/tmp/x1-dma-buffer-snapshot-final.log`. The separate revision test passes
old/new same-profile rejection in both directions, each runner's own unmodified
state restore, unchanged input hashes, and exact bit-41 application identity
delta: `/tmp/x1-dma-buffer-snapshot-version-final-qualified.log`. No state
bytes were patched. The initial test supplied an old runner that did not match
the required revision pair, assumed a newer JSON key and then inspected the Verilator
prefix instead of the application header; those failed probes are preserved.
The qualified pair uses the default-DIP old runner and a verified save02 prefix.

Reproduction commands (from `verilator/`):

```sh
make test-dma-restart-irq test-dma-restart-irq-cpu HEADLESS_DIR=obj_dir_restart_irq
make test-machine-dma-irq-snapshot \
  DMA_SAVE_DIR=obj_dir_v12_dma_buffer_save DMA_IRQ_SAVE_DIR=obj_dir_v12_dma_buffer_irq_save
make test-machine-dma-restart test-machine-dma-search-restart \
  DMA_DIR=obj_dir_v12_dma_buffer_timing
python3 tests/test_dma_snapshot_revision.py ./obj_dir_v12_dma_irq_default_savable/Vtop \
  ./obj_dir_v12_dma_buffer_irq_save/Vtop
```

Final SHA-256 identities:

| Artifact | SHA-256 |
|---|---|
| DMA RTL | `6e3c7cea90bb387f813fcd36fa9a40984ec52ffc01cfa1c50feaeb287b393fe4` |
| Restart register runner | `92d22bb95079a2d512ec18b8513af649a9e9c06acd26dcc1574d6cf86bdb6a2b` |
| Restart CPU runner | `baf5822b5ed7440ea0249d976a5b198637fad45af979f6ef58ca6c6d38dbbef3` |
| Plain savable machine | `afd071c9e36c1ff2f3e9c956d377f73f4e7b89246428626dba64d5f6ae9649b8` |
| IRQ savable machine | `cb1aee323526d60ce20ed1ca86457e7680a637eaf35f2d8afb94336355b2ffd8` |
| Delay-aware DMA machine | `b0bab9e4d5cf35ace55960857b637b71c687f89ff5b105dcf3c19a20e24bbb6c` |

Hosted runs for `3051066` and `2cfe29b` were observed live, not terminal; their
results cannot validate this later correction. No hosted or hardware pass is
claimed here. No private asset or original firmware was changed.

## Remaining gates

The subsequent [real-CPU handler extension](DMA_HANDLER_BUFFER_STATUS.md) now
qualifies buffered updates in both directions and all three transfer modes.
The [executing snapshot follow-up](DMA_RELOAD_SNAPSHOT_STATUS.md) now qualifies
the new destination flag at the actual non-IRQ shared-machine reload seam.
Mixed Ready/match restart interrupts, long-count IRQ boundaries, and
restart-handler snapshots remain acceptance work.
The existing shared-machine
IRQ snapshot test covers completion service, not that new auto-reload seam.
FDC/SIO/native Turbo firmware, exact pins/CDC, source-bound Quartus and physical
MiSTer acceptance remain open. No board revision now enables restart IRQ.
