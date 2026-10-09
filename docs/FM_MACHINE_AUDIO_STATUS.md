# Shared-machine signed FM / PSG audio

October 9, 2026. Opt-in `TURBO && TURBO_FM_CPU` now connects the qualified
sample-aligned mixer to signed `audio_left/right/mono` and `audio_sample`.
Default unsigned `audio={psg_sound,6'd0}` stays unchanged; disabled signed
outputs are zero. All mixer/DC state uses drained `core_reset`. No derived
audio clock is added. Digital gain/coupling remain provisional, not measured
native analog values. Dependencies are explicit in `machine.qip`.

Wrapper macro `X1_TURBO_FM_CPU` requires Turbo foundation and selects signed
L/R with `AUDIO_S=1`. The subsequent separate `sharpx1_turbo_fm.qsf` revision
now enables it on the actual 28.571428 MHz single master; all pre-existing
revisions remain off. Base/FM wrapper lint passes with a PLL stand-in only;
the new revision now has a source-bound fit and eight constrained-corner
passes; see [the build audit](FM_BOARD_BUILD_STATUS.md). Unconstrained I/O
and physical sound acceptance remain open. The new delay-aware `turbo-fm` C++ profile enables FM, not DMA,
SIO/Z/Kanji. `--audio` writes signed stereo at 48 kHz without a second DC
blocker. Default mono capture retains its original deterministic 1 kHz
PSG test, which passes. No FM savable/SDL profile is advertised.

## Executed CPU / real-chip qualification

`test-machine-fm-audio` uploads an original generated 8192-byte IPL via
ioctl, honoring WAIT. Actual CPU instructions initialize all JT51 channels/
operators, pan a bounded carrier left and program genuine JT49 PSG A
period 125 at 2 MHz. No chip state/samples/private ROM/results are injected.
Existing status/busy/WAIT/read-tail/PPI C5 DAM and real four-byte DMA checks
still pass. A complete audio boot requires exactly 480 FM dispatches, actual
DMA ownership/isolation, payload and four reads/writes. Reset clears signed
audio/DC/sample with stopped CPU/device enables; unchanged IPL reboots and
reprograms both chips without upload. Timer-flag reset remains covered.

Each cold/warm run settles 20,000 samples and captures 6,250 events. An
independent scalar DC oracle tracks raw PSG from reset/programming onward;
SV checks output sums at actual sample edges. Python checks PSG pitch/DC,
FM pitch/panning, signed sums and exact first/final waveform equality.
CSV/WAVs and generated IPL stay ignored. All three final commands exit zero:

```sh
make -C verilator test-machine-fm-audio
make -C verilator test-machine-fm-audio FM_MASTER_HZ=28636364
make -C verilator test-machine-fm-audio FM_MASTER_HZ=28571428
```

Baseline SYS=32 MHz/VID=28.571428 MHz are independent; other profiles use
their selected single master. SV periods are integer-ps approximations.
PSG crossings measure 1000.081 / 999.919 / 999.919 Hz respectively.
Logs `/tmp/x1-machine-fm-audio-{HZ}-final.log`. First HDL runs passed but
the two-profile Python option hit an indexing error (`*-first.log`). Storing
captures by profile identity fixes that bookkeeping, preserving required
0/4 profiles, sample counts and assertions. Preserved captures and complete
reruns pass. Bus-only three-clock/disabled-negative recipe also exits zero:
`/tmp/x1-v17-machine-fm-bus.log`.

| Artifact | SHA-256 |
|---|---|
| 32 MHz audio fixture | `f5ae3622e3da3e42f78baaed43206b4632fc668f5674a7961e525e8c7ab354b5` |
| 28.636364 MHz fixture | `b6a92f3781306d5e78cb48e874823601bfab27965e5a567d9eda073f0aa8cd37` |
| 28.571428 MHz fixture | `202742f0b79d0dbf5881f22b492ff91475cec8f86b7fa5fc433e3f831ad59f89` |
| `rtl/sharpx1.v` | `ddb49969b0c4e3cb0000c0aaac434c175e841e4dfa8c99f14b8c2f568e333b67` |
| `machine_fm_tb.sv` | `c750e392fa3b6c691961d3846288ccc46638f554095cf25df87f466a1cc90841` |
| Generated IPL | `06de8f3feb6a5974cf1306eeb11e100778ea3efa6168c921d8a35cf1315e6b61` |
| Final C++ FM runner | `a56824a059b1e7072e92144cbc3f628502570956f6bcfde750d4296b05964231` |

## C++ capture / remaining gates

The generated IPL reaches AA/HALT in the delay-aware C++ FM profile and
produces 38,400 stereo frames over 800 ms. This profile has DMA **disabled**;
its inert DMA writes/payload are not qualified by the sound result. The
shared DMA acceptance is above. `test_signed_audio_capture.py` checks WAV
format, explicit JSON profile, PSG on right and FM isolated by L−R:
1000.000 Hz / 491.617 Hz. Final log `/tmp/x1-v17-fm-cpp-audio-final.log`;
the earlier capture lacks the FM JSON flag and remains separate history.
The runner was hashed before this final capture, not replaced during it.

All snapshots now require **v17**, rejecting old v16 before deserialization;
never convert private states. Direct ordinary v17 snapshot continuation/
old-version rejection passes. The full ordinary fast suite finishes zero
with 137 PASS reports; the delay-aware suite finishes zero with 140. All five
fresh game qualifications pass on frozen inputs, including firing/pair removal.
See [v17 acceptance](BASELINE_V17_STATUS.md). V16 games remain
historical. Native Turbo FM software/IRQ, mixed-service/owned-SD resets,
FM DMA access, exact pins, analog calibration and physical acceptance remain
open. This is not full Turbo Z or completed work groups 1–6.
The subsequent [owned-DMA live-audio reset test](FM_OWNED_RESET_STATUS.md)
passes at three clocks and rejects an isolated premature-audio-reset mutation.
It covers RAM-to-RAM ownership, not owned disk-host or mixed-service traffic.
The [pending-SD live-FM extension](FM_SD_RESET_STATUS.md) subsequently passes
sixteen A/B read/write/ACK/held-pulse reset cases and retained-program sound
reboot, with unchanged whole-image assertions. Its expanded metadata matrix
is still running; mixed-service/native/physical gates remain open.
The separate [FM FPGA profile/build](FM_BOARD_BUILD_STATUS.md) fits and passes
eight constrained corners, but is not deployed or hardware accepted.
