# Live FM / PSG with pending SD reset

October 9, 2026. The original generated-media
`dma_machine_sd_reset_tb.sv` now has an explicit default-off `FM_ENABLED`
parameter. Its FM experiment uses the same shared machine, actual CPU,
JT51/JT49, FDC, DMA and independent host ACK service. SYS is 32 MHz and
video 28.571428 MHz; SIO/Z/X3/Kanji remain disabled. Production RTL,
snapshot v17 and board revisions are unchanged.

## Test contract

The original CPU program additionally keys on one real FM carrier, programs
PSG A and starts the genuine FM timer/CT state before its mount delay. The
fixture must observe nonzero FM and signed PSG samples, CT=3 and asserted
timer IRQ before resetting. No chip registers, CPU state, audio samples,
DMA ownership or Ready signals are injected.

Reset occurs while a published disk payload request is unacknowledged or
mid-ACK, with no owned DMA pair. It must clear FM/audio/control while the
original host owner/LBA/buffer and ACK drain checks remain unchanged. The
same retained program must reboot without another upload, produce audible
samples/timer/CT again and finish 256 fresh exact DMA pairs. Original
whole-image checks before and after reboot preserve committed-write versus
aborted-read distinctions, the untouched drive and every padding byte.

The target spans A/B, read/write, before/mid-ACK and held/2 ns reset: sixteen
cases, not an owned-pair test or physical OSD acceptance.

```sh
make -C verilator test-machine-fm-sd-reset
make -C verilator test-machine-fm-sd-metadata-reset
```

## Completed payload qualification; metadata in progress

The model builds successfully with Verilator 5.044, delay-aware scheduling
and assertions. New fixture wiring adds no warning suppressions; inherited
machine warnings remain. The sixteen-case FM run finishes with exit zero and
all sixteen distinct profiles in `/tmp/x1-fm-sd-reset-final.log`, each with
the additional live-FM cold/reboot checks. The original FM-disabled sixteen-case
payload matrix also finishes with exit zero
(`/tmp/x1-fm-sd-disabled-final.log`). Pre/post executable hashes are unchanged;
no long test used a subsequently rebuilt runner. A further
48-case FM metadata matrix is running on the same frozen executable in
`/tmp/x1-fm-sd-metadata-final.log`: A/B, held/pulsed, before/mid-ACK,
single-block first-header read/write and split-header first/second read/write.
This launch uses a shell loop equivalent to the metadata target; the composite
Make recipe itself has not yet executed.

Pre-run SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| SD fixture | `bf3bc7d05bbe6b540735ec88acdb577aee884bd54568d317262c63fae2c4de3d` |
| Shared machine | `ddb49969b0c4e3cb0000c0aaac434c175e841e4dfa8c99f14b8c2f568e333b67` |
| FM-enabled executable | `5050ddcb96151fa41fc175ea6a6a98e87f3184cd70f9fde7eafa0924de642b1f` |

The expanded metadata matrix is not accepted until terminal completion.
Partial CPU payload,
Ready loss, mixed SIO/IRQ traffic, native Turbo firmware and physical audio/
host acceptance remain separate gates. The earlier
[owned RAM-DMA live-audio reset qualification](FM_OWNED_RESET_STATUS.md)
does not substitute for these pending-host cases.
