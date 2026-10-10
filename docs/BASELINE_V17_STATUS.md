# Ordinary v17 acceptance

October 9, 2026. The optional signed FM interface changes machine/model
layout; application states require v17. Ordinary profiles still disable
FM/SIO/Turbo/DMA/Kanji/Z and retain unsigned PSG audio. No private states
are converted, no game bytes injected and no native Turbo acceptance inferred.

`make -C verilator test-fast` terminates zero, **137 PASS reports** in
`/tmp/x1-v17-fast.log`. Current fast/savable runner SHA-256:
`73181a8f87e1194a8899bb2801263548ecb5c926ef7d8f78a87cb5983648c06f`.
Direct continuation/old-v16 rejection/clock/joystick checks also pass:
`/tmp/x1-v17-snapshot-final.log`. The negative modifies only a generated
incompatible header, never a real private state.

`make -C verilator test HEADLESS_DIR=obj_dir_v17_baseline` terminates zero,
**140 PASS reports** in `/tmp/x1-v17-baseline.log`.
Its delay-aware runner SHA-256:
`166bf9129b272ce03b8d6c2d2d72ebf157627705fab59f569060a4c79cbd14e1`.
Both ordinary profiles run SYS=32 MHz/VID=28.571428 MHz; fast ignores
inherited intra-assignment delays and is not the timing reference.

## Fresh commercial qualification: all five terminal passes

All five original release-bound helpers run from ignored frozen root
`verilator/obj_dir_v17_games/games-nxk8dE/`, source
`0e6ba8a710d789a90c7fcf6e88b411edad93fcaa`. Root runner, copied IPL,
unmodified scripts/keys, full RTL/vendor-chip tree and runner sources were
copied before launch; `inputs.sha256` verifies before all runs.
Each collector additionally freezes/hashes its own runner and checks
private disk/IPL/key inputs. Runner hash is the ordinary fast hash above;
FM remains **off** in these games. Future board-profile-only changes do not
replace this frozen runner.

All five titles complete their 16-second native boot as 8+8 checkpoints.
Xevious now terminates zero with gameplay verified: right moves `(30,40)`
to `(36,40)`, exact RGB/RAM/report repeatability and unchanged assets pass.
Independent checks verify collector flags, native return codes/profile/zero
disk writes, all original/frozen inputs, every saved prefix state and runner
hashes. Druaga, Mappy and Shanghai now also terminate zero and pass the same
independent input/prefix/runner audit. Druaga left moves `(68,32)` to `(67,32)`;
Mappy left `(129,84)` to `(126,84)`; Shanghai cursor `(488,167)` to `(544,160)`
and matching removal `0` to `2`, with unchanged release-bound repeatability
assertions. Galaga now also terminates zero: right `(32,24)` to `(40,24)` plus
active enemy wave, native firing and projectile travel `(33,12)` to `(33,8)`.
Its separate firing return code is zero, and collector/input/prefix-state/
runner audit passes. All later control durations and Shanghai feedback/pair
assertions stay unchanged. The 7200-second host timeout per stage does not
change simulated duration. No old state is restored or converted.
Logs `/tmp/x1-v17-{xevious,druaga,mappy,galaga,shanghai}.log`.
All five terminal collector/control results, original/frozen inputs, every
native-prefix state and all six root/per-title executable hashes are checked.
The complete initial input manifest still matches after all runs
(`/tmp/x1-v17-games-inputs-final.log`). This is bounded ordinary fast-model
gameplay, not full-game completion, delay-aware gameplay or native FM/SIO/Z.

Full work groups 1–6 and Turbo Z remain open, including native/physical
device gates, Arcus/Bastard Special and analog/IRQ FM acceptance.

## Fresh ordinary regression after local-reset PCG repair

`make -C verilator test HEADLESS_DIR=obj_dir_headless/pcg-reset-baseline`
now finishes with an observed exit zero and **143 PASS reports** in
`/tmp/x1-pcg-reset-full-baseline.log`. The final delay-aware runner SHA-256
matches its initial identity:
`dd6d2f5c1f00dee4372765c2a0d8b210ceda8ba3853c74578cca6e1b3fda6439`.
Ordinary clocks remain SYS=32 MHz/VID=28,571,428 Hz. This freshly executes
the prescribed video/transition/peripheral/disk/helper suite on the current
PCG source; it does not rerun the five commercial collectors or qualify
native Turbo/Z, FPGA timing or physical behavior. X3 separately requires
revision-3 snapshot identity; ordinary v17 identity remains unchanged.
See [the PCG repair evidence](PCG_BUNDLE_TIMING_STATUS.md) for scope,
snapshot checks and remaining source-bound fitting/hardware gates.
