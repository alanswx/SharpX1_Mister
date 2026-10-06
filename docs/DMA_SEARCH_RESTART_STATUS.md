# Read-only DMA Byte search: automatic restart

October 6, 2026. Original GPL-2.0-or-later changes to `rtl/x1_dma.sv`.
This extends the [pure Byte search checkpoint](DMA_PURE_SEARCH_STATUS.md),
not the remaining Burst/continuous search, IRQ or native/hardware gates.
DMA remains disabled in ordinary base/Turbo/X3/board profiles.

## Contract and evidence

Reread primary [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf),
printed 60 and 103–104: WR5 D5 selects end-of-block repeat, clears EOB and
reloads the byte/address counters from programmed buffers. The generic WR5
contract is applied at **completed source read** for read-only Byte search,
not by inventing a destination write. This is a functional implementation;
the page-60 prose describes block transfers and is not a separate silicon
qualification of search timing.

At terminal read, automatic restart reloads **both** address buffers,
remaining length and zero byte count. It clears candidate match/EOB status,
as the already-tested sequential reload does. Match reset is a model-tested
policy; exact silicon pipeline/status interaction remains unverified.
The otherwise-unused port does not step during reads, but its counter does
reload at repeat. This differs from explicit LOAD's immediate-source-only
behavior, and is tested with independently changed buffers.

Byte ownership releases after every read, including terminal read. Physical
Ready must be active or CPU Force Ready programmed to start another read.
An actual Stop on Match overrides repeat even when match and EOB coincide:
retain the completed source/count, assert match/EOB, disable and do not reload.
DISABLE or pending software/hardware reset drains an owned read but prevents
restart. WAIT/CE stop retain the read and do not expose premature completion.
Pure Burst/continuous and IRQ/variable/simultaneous timing remain rejected.

No new clock or serialized state field was added. DMA profile revision 4
adds bit 50 because existing restored search commands change behavior.
Ordinary non-DMA v12 identity is unchanged; regenerate affected states,
never patch/convert state bytes. No DMA snapshot restore acceptance is claimed.

## Executed qualification

Verilator 5.044, timing/assertions enabled; SYS 100 MHz synthetic host,
CE=1/4 (functional intervals, not electrical DMA pin timing):

```sh
make -C verilator test-dma-search test-dma-compare test-dma-cpu \
    test-sio-dma test-sio-dma-cpu HEADLESS_DIR=obj_dir_v12_dma_search_repeat
```

All exit zero. Retains 10,240 pure-search and 10,240 comparison/Byte-stop
cases. New repeat checks cover both directions, memory/I/O,
increment/decrement/fixed/wrapped source addresses, twelve observed source
addresses across three blocks, both reloaded counters and cleared count/status.
An actually matched non-stopping block clears match on reload; terminal match
does not restart. DISABLE/C3/raw stopped-CE reset under terminal-read WAIT
drains exactly once without restart. 256/65,536/65,537-read blocks complete
and then execute a real first read of the next block, checking its address,
count and remaining length. The fixture globally forbids destination writes.
No warnings were suppressed. Extended unit log
`/tmp/x1-dma-search-repeat-unit-final.log`; CPU/SIO regression log
`/tmp/x1-dma-search-repeat-regression.log`.

Actual shared-machine Z80 tests:

```sh
make -C verilator test-machine-dma-search-restart test-machine-dma-restart \
    DMA_DIR=obj_dir_v12_dma_search_repeat_machine
```

Exit zero. Both sources, three four-read blocks, masked first-byte match,
changed source/other-port buffers before terminal read **without LOAD**,
per-read real CPU status and six-counter-byte verification, preserved source
and untouched destination RAM, exact twelve reads/grants and **zero writes**.
Each case retains eight million 32 MHz reference cycles (250 ms).
The original two write-transfer restart cases also pass unchanged in behavior.
Fast run passes these four cases independently; its twenty comparison/Byte-stop
and GRAM/PCG cases also exit zero in `/tmp/x1-dma-search-repeat-fast.log`
(session 11752).
Delay-aware completed log `/tmp/x1-dma-search-repeat-machine.log` (session 55468).
Fast seven-case RAM/overlay/A/B read/write/protection/CRC and four owned-reset
matrices also exit zero in `/tmp/x1-dma-search-repeat-disk-fast.log`
(session 53996). Original 40-group transfer/restart remains live in
`/tmp/x1-dma-search-repeat-transfer.log` (session 93583); terminal result
is not assumed.

| Tested artifact | SHA-256 |
|---|---|
| DMA source | `9f75837e25a4ecda276a9c6e7adb689a8f6dfcad83e23e94e9844e707a78b45d` |
| Extended search unit | `4b2b1f4ef0c46195f5793d7ac20f2fce6b7ddf3a3ff34bfe743a25bbe0480dea` |
| Delay-aware shared machine | `28c88b9300834f40b1889f023abfe87429a10eb9d9e20489b0941d71ca83d6ec` |
| Fast shared machine | `07d05d1ed2ba8689baa1aa8d9e2639ae6e63333929d49d62b0f3dc9dce08ea5b` |

Fresh base savable runner remains byte-identical to the five-commercial-game-
qualified v12 runner, SHA-256
`159062a12920cb398d1bd348b8e901a7b6139d31cfcadd8d038b73235d962a8a`.
Snapshot/clock/mismatch/joystick checks exit zero in
`/tmp/x1-dma-search-repeat-base-snapshot.log`. This is base/DMA-disabled
acceptance only. The existing 25-target hosted workflow retains this expanded
fixture; current-source hosted result, native DMA, Quartus/CDC and MiSTer
acceptance remain open, not inferred from older green checks.
