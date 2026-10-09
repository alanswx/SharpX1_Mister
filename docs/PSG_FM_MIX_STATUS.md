# Signed PSG / FM mixing foundation

Current follow-up: the [shared machine audio integration](FM_MACHINE_AUDIO_STATUS.md)
now passes actual CPU-programmed mixed captures and stereo C++ WAV checks.
Standalone-only statements below describe this preceding checkpoint.

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

## Sample-aligned output and genuine-chip follow-up

Original `rtl/x1_audio_mix.sv` captures FM L/R on the same sample edge as
the PSG converter. Its signed stereo/mono outputs hold between enables.
Reset clears all outputs even with CE stopped. It remains standalone in
`x1_fm.qip`; machine ports, board audio and snapshots are unchanged.

The strengthened scalar fixture also checks this sampled output, changing
both FM channels and PSG during stopped enables. All 2,236,486 cases pass
again, including between-edge asynchronous reset. Log:
`/tmp/x1-psg-mix-sampled.log`. The older fixture/runner table above is
historical; current fixture hash is
`936b77f5126d5f4f71a4b322564bf72aab33a4236605b871e61165ce4e961ef0`,
and its runner is `0fa44c86f18b7873a273da02a9494ce74df4fb47e469c12cd37b0064630d71e7`.

`test-fm-psg` programs genuine JT49 through BDIR/BC1 and genuine JT51
through the existing bus adapter, not injected oscillator samples or chip
state. PSG A uses period 125 at 2 MHz for a 1 kHz tone, noise/envelope/B/C
muted. FM uses the existing documented A4/MUL=1 carrier program. Five
profiles cover FM left/right/both/neither and an exact reset/reprogram
repeat. Each warms up for 20,000 samples and captures 6,250 actual sample
events, asserting 64 input-chip ticks per event. Rounded integer-ps clocks
are simulation approximations, not fitted or measured board frequencies.

An independent integer DC oracle tracks every sample from reset through
programming/warm-up, never seeded from DUT state. SV checks sample-aligned
sums; Python checks all 31,250 captured rows per frequency, PSG DC/pitch,
FM pitch/panning, saturation sums and exact first/final waveform equality.
Actual signed mixed stereo WAVs and CSVs are ignored build outputs.
PSG measured crossing frequencies are 1000.081 Hz at 32 MHz and 999.919 Hz
at both single-clock frequencies; all pass the 0.5% frequency bound.
The ordinary unmixed `test-fm` also passes after the fixture extension,
including unchanged timer/queue/busy checks and 491.619 Hz FM pitch.

| Master Hz | Concurrent-chip runner SHA-256 |
|---|---|
| 32,000,000 | `f4801813de637c4f6fbb6985aedce3cd8972f136d6145e1c62fba86a38391199` |
| 28,636,364 | `03f52616cdd22c2659cbc47474720fdd7ffb105e37959efb252c2f6f39806c4d` |
| 28,571,428 | `0758cab7763a8d72c5613dbef38e038be45eece140cd3f8f54438ba72f0fa4c6` |

First three runs terminate zero in `/tmp/x1-fm-psg-{HZ}.log`.
The three executable hashes are checked before a second complete run;
all three terminate zero again in `/tmp/x1-fm-psg-{HZ}-final.log`.
Post-run executable hashes remain unchanged. No rebuild replaces a runner
during these final captures.
Source/audio hashes: `x1_audio_mix.sv`
`cee9b0848b9ad4b4656d29401c1c44a843ba8d15b98ddc5a53d9867dd7e036d1`;
`fm_tb.sv` `831923294c7f37812db3772f1be60d37b745b47189a5b3b366d9d29eb97f470c`;
Python verifier `a3780c36ff6c2734d94cc314498ccd7953483abf0923e7a1ea64fec32964c9fb`.
No private media or vendor sources are changed. Hosted CI selects the new
target; no hosted result is claimed yet.

An isolated `/tmp/x1-audio-hold-negative.SMtE0Z` copy removes the FM
register sample-enable guard. The strengthened scalar test exits 1 with
`sample-aligned audio hold/mix` at the first stopped-enable profile, after
the constant-CE case passes. Log `/tmp/x1-audio-hold-negative.log`.
No mutation is applied to production RTL.

## Remaining acceptance

Integrate the qualified sampled mixer through an explicit signed
stereo/mono machine output without reinterpreting the default unsigned port,
qualify actual CPU programs and shared reset, regenerate any affected
snapshots, and perform native/hardware sound and analog calibration.
The CPU-bus [FM subset](FM_MACHINE_STATUS.md) is not full Turbo Z sound.
