# Signed PSG / FM mixing foundation

October 9, 2026. Original `rtl/x1_psg_signed.sv` supplies the previously
missing unsigned-to-signed conversion for `x1_fm_mix.sv`. Standalone only:
the shared machine, base audio, board profile and snapshot v16 are unchanged.
No native FM sound, IRQ routing or physical analog acceptance is claimed.

## Digital contract

JT49's unsigned ten-bit amplitude is scaled by 32 into 0..32736. A Q16
unsigned DC estimate follows that amplitude with alpha=1/2048 on each
audio sample enable. Output subtracts the previous estimate's integer part.
Negative estimator deltas round toward negative infinity. Both estimator
and output hold between enables; asynchronous reset clears them to silence.
Only the master clock is used. At 62.5 ksample/s the provisional digital
corner is about 4.86 Hz; it is **not** a measured native capacitor/resistor
network, board gain or reconstruction filter.

This avoids treating unsigned zero/silence as signed -32768. The existing
unity-gain saturating mixer adds PSG once to each stereo channel and once
to its separate FM-left + FM-right mono sum. Native gain, filter and speaker
calibration remain required. This module is listed in standalone `x1_fm.qip`,
not `machine.qip`; it does not yet deliver mixed samples to MiSTer or WAV.

## Executed qualification

`make -C verilator test-psg-mix` exits zero with Verilator 5.044/macOS Clang.
The original independent scalar oracle uses integer multiply/divide and
explicit negative-floor rounding, not the DUT's fixed-width shifts.
It checks 2,236,486 sample/estimator/stereo/mono results across sample-enable
gaps 1, 4 and 7, all 1024 PSG amplitudes ascending/descending, and all 81
cross-products of nine signed FM boundary values. Changing PSG while CE is
stopped must not change output/estimate. Constant full-scale and zero inputs
settle to within one output count after 40,960 sample enables each; reset
between edges with stopped CE clears immediately, followed by exact silence.

The first compile rejected a 32-bit conditional used as a boolean; the
fixture now uses explicit `direction != 0`, without warning suppression.
Logs: `/tmp/x1-psg-mix.log` (first failure),
`/tmp/x1-psg-mix-final.log` (terminal pass). These are local, not hosted CI.

| Input/artifact | SHA-256 |
|---|---|
| `rtl/x1_psg_signed.sv` | `4c86eb26e6402dbc6dd5145f152e9714747f9cdf74ac963b05e340316bfb9e2f` |
| `verilator/tests/psg_mix_tb.sv` | `db497fed7a94257944a317d700eb06d34a1d0135006755b14446f6a72a5d2dd2` |
| `verilator/obj_dir_headless/psg-mix/Vpsg_mix_tb` | `743d9a43ef7407a5780c3fb3b476c61f4bd3f263e19d482537b3a057700eb5cc` |

An isolated `/tmp/x1-psg-mix-negative.HE2FD9` copy changes mono to sum
the already-PSG-mixed stereo channels, doubling PSG. Its fixture exits 1
with `mono mix (PSG must occur once)`; log `/tmp/x1-psg-mix-negative.log`.
The production mixer is not modified. This negative demonstrates that the
mono oracle detects that specific regression, not native analog fidelity.

## Remaining acceptance

Drive the converter/mixer from genuine concurrent JT49/JT51 notes at all
three master frequencies; capture samples and verify sample timing, PSG/FM
frequency/panning, clipping and reset. Then integrate an explicit signed
stereo/mono machine output without reinterpreting the default unsigned port,
qualify actual CPU programs and shared reset, regenerate any affected
snapshots, and perform native/hardware sound and analog calibration.
The CPU-bus [FM subset](FM_MACHINE_STATUS.md) is not full Turbo Z sound.
