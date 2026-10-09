# Live FM/audio reset during owned DMA

October 9, 2026. This extends the original generated-IPL
`machine_fm_tb.sv` fixture, not production machine RTL. FM and DMA are
explicitly enabled; SIO, Turbo Z, X3, Kanji and disk media are absent.
No private assets, fabricated BUSACK, injected chip state or patched CPU
registers are used. The scalar audio oracle now follows drained `core_reset`,
not raw reset, matching the required ownership contract.

## Executed acceptance

Actual CPU instructions configure JT51 timer/CT and audible FM plus JT49 PSG
before requesting a real four-byte RAM-to-RAM DMA transfer. During its source
read, the fixture asserts raw reset between SYS edges for 2.001 ns. It checks:

- Nonzero signed audio/DC, asserted genuine FM timer IRQ and CT=3 at entry.
- Real DMA ownership remains; CPU CE stops, uploads wait, and machine reset
  does not occur before the started source/destination pair completes.
- Signed audio/DC survive the asynchronous reset assertion unchanged.
- Exactly one read/write pair commits. Destination byte zero becomes 31h;
  the remaining three bytes retain EEh, so no extra pair is hidden by reboot.
- Drained reset clears signed output/sample, CT, timer IRQ and FM read-tail,
  and releases FM WAIT.
- The unchanged retained IPL reboots without another download. Its complete
  four-byte copy, 480 FM dispatches, busy/status/WAIT, DAM and read-tail checks
  pass. Subsequent cold/warm captures each settle 20,000 samples and collect
  6,250 actual sample events; independent scalar sums, pitch, panning and
  byte-exact reset/reprogrammed waveform repeatability pass.

All three final commands finish successfully:

```sh
make -C verilator test-machine-fm-owned-reset
make -C verilator test-machine-fm-owned-reset FM_MASTER_HZ=28636364
make -C verilator test-machine-fm-owned-reset FM_MASTER_HZ=28571428
```

The first configuration is independent 32 MHz SYS / 28.571428 MHz video;
the others use their specified single master. Clock half-periods are truncated
to integer picoseconds. Runtime PASS messages and generated C++ constants
confirm the selected master and single-clock configuration. Logs are
`/tmp/x1-fm-owned-reset-{HZ}-final.log`. These reordered owned-reset captures
measure PSG 1000.081 Hz at each profile, within the unchanged tolerance;
do not substitute the earlier ordinary audio fixture's crossing estimates.

Executables were hashed before the final runs and remain unchanged:

| Artifact | SHA-256 |
|---|---|
| Fixture source | `349a0a7965520e18bcb41cc03670e2a3713eac63bdf68f5cdd845e5e2796f724` |
| Shared machine source | `ddb49969b0c4e3cb0000c0aaac434c175e841e4dfa8c99f14b8c2f568e333b67` |
| 32 MHz executable | `0f7337a3407c486d260fefdffb54843f594a7f705e065f7cce8c4006c49dbcc1` |
| 28.636364 MHz executable | `648bfda05d095337433a8cc30f1aee316b55d5ebf33d722468b29ee3aad6c93a` |
| 28.571428 MHz executable | `7c4bc4e8111f2465b739fd158e315d0ac619ab4d63e25c607c2383c18c390ec3` |

The bus-only three-clock regression and disabled-FM negative also finish
successfully (`/tmp/x1-fm-owned-reset-bus-regression.log`). The CI workflow
selects the owned-reset target, retaining its cold/warm audio checks; hosted
acceptance of this change still needs a terminal run.

## Deliberately failing control and remaining scope

An isolated temporary copy changes only the audio mixer's reset from drained
`core_reset` to raw reset. It fails specifically with
`signed FM state reset before DMA drain completed` at the asynchronous pulse
(`/tmp/x1-fm-drain-negative.log`). Production RTL remains unchanged. This
shows the retention assertion rejects premature audio clearing; it does not
establish every reset phase or exact native pin timing.

Owned SD/FDC traffic with live FM, mixed SIO/IRQ service, DMA accesses to FM,
native Turbo firmware and physical OSD/audio acceptance remain open. This
fixture does not enable DMA on the separate FM FPGA revision, change snapshot
format v17, or qualify full Turbo Z/work groups 1–6.
