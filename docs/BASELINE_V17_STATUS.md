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

The fresh full ordinary fast/SDL/snapshot suite is now running in
`/tmp/x1-pcg-reset-full-fast.log`, runner SHA-256
`88bb30c8ec465c15099a3897c1ee1da059816e2211cafb284445de9afc45ac69`.
Its video and mixed-transition fixtures have completed. Independent
`scripts/audit_fast_timing_video.py` comparison against the completed fresh
delay-aware log passes all eighteen ordinary cases: equal frame hashes,
dimensions/counts, HS/VS periods, nominal clocks, reset/cycle parameters and
program/font identities. Each log retains one executable identity and its
expected delay-aware/fast flag. This is logged video agreement, not full
fast-suite acceptance, bytewise frame-file comparison, native gameplay or
FPGA behavior. An early comparison rejected the live log's missing final
transition case; no coverage assertion was loosened. CI's synthetic audit
passes nineteen invalid profile/input/timing/coverage controls.

The fresh full `test-fast` subsequently completes with observed exit zero
and **140 PASS reports** (`/tmp/x1-pcg-reset-full-fast.log`). Final executable
hash matches its initial `88bb30c8...f45ac69` identity above. This includes
the existing ordinary snapshot continuation/old-header/clock/joystick and
SDL-adapter tests, along with video/transitions, reset/keyboard, PSG,
memory/bus/sub-CPU and disk/helper diagnostics. It remains a no-delay model,
not the timing reference; the separately completed fresh delay-aware suite
and eighteen-case video comparison qualify their stated diagnostic scopes.

## Fresh five-title launch after local-reset repair

All five original collectors are now running from ignored frozen root
`verilator/obj_dir_headless/pcg-reset-games-RVmiod/`, on the current ordinary
fast runner hash above. Source/runner/collector/key/font/BIOS/vendor copies
are frozen; all **646** entries in `inputs.sha256` pass before launch and
again during native boot (`/tmp/x1-pcg-reset-games-{initial,live}-inputs.log`).
An initial shell enumeration failed to generate a hash manifest, before any
collector launch; its empty manifest is preserved at
`/tmp/x1-pcg-reset-games-failed-initial-manifest.sha256`. The corrected
enumeration is fully checked rather than treating that failed attempt as
provenance.

Collectors use the same existing authorized release-bound disk images, native
IPL and original controls for Xevious, Tower of Druaga, Mappy, Galaga and
Shanghai. Each starts anew with `--boot-chunk-ms 8000 --timeout 7200`; the
16-second native boot and later simulated control durations are unchanged.
Shanghai retains native cursor-feedback preparation; Galaga retains firing
checks. Each collector makes its own runner copy and hashes original assets
and actual native prefix states. No old state conversion or game-byte patch
is used. Logs: `/tmp/x1-pcg-reset-games-{xevious,druaga,mappy,galaga,shanghai}.log`.
Started is not gameplay acceptance. Earlier five-title passes remain
historical for their frozen runners; these new results, full input checks,
Turbo/Z native software and hardware gates remain separate.

### Completed current-source five-title qualification

All five collectors subsequently finish with observed exit zero. Independent
inspection checks their final `gameplay_verified`/`unchanged_inputs` flags,
zero control return codes, original asset hashes and all six root/per-title
executable hashes against `88bb30c8...f45ac69`. All **30** native-prefix saved
state hashes and actual stdout JSON reports match the recorded evidence:
Xevious 4, Druaga 5, Mappy 6, Galaga 10 and Shanghai 5. Each prefix has ordinary
profile flags, SYS=32 MHz/VID=28,571,428 Hz, no disk writes, no injected RAM,
and an exact predecessor-state chain starting from the ioctl-loaded IPL.
The complete **646-entry** frozen input manifest passes after all runs:
`/tmp/x1-pcg-reset-games-final-inputs.log`.

Xevious right moves `(30,40)` to `(36,40)`; Druaga left `(68,32)` to `(67,32)`;
Mappy left `(129,84)` to `(126,84)`; Galaga right `(32,24)` to `(40,24)`.
Galaga additionally has an active enemy wave, successful separate fire check
and projectile travel `(33,12)` to `(33,8)`. Shanghai moves the native cursor
`(488,167)` to `(544,160)` and removes the selected matching pair (`0` to `2`).
The original control helpers enforce RGB/RAM/state/report repeatability and
unchanged assets; all terminal PASS lines are inspected. These are bounded
ordinary fast-model gameplay checks on freshly native-booted states, not
delay-aware commercial gameplay, full-game completion, Turbo/Z software,
Quartus timing or physical MiSTer acceptance. Private states/media remain
ignored and are neither converted nor bundled.

The runner-only [scheduled joystick increment](JOYSTICK_SCHEDULE_STATUS.md)
now passes focused real-CPU input and existing timing/key/snapshot checks.
Three freshly frozen continuous delay-aware Xevious cold runs subsequently
complete zero: IPL/disk cold boot, start/right movement, changed RGB and exact
repeatability pass without snapshots. The independent final 695-input manifest
and actual report/artifact audit pass; see the scheduled-input evidence for
hashes and scope. The new full fast suite also completes zero with 141 PASS
reports and unchanged executable; the new baseline suite subsequently also
completes zero with 144 PASS reports and unchanged executable. Independent
inspection confirms eighteen video/transition cases agree across these suites.
Fresh frozen continuous Druaga/Mappy/Galaga runs are now started, not passed;
see the scheduled-input evidence for exact startup durations and acceptance.
The earlier completed fast five-title results retain their
original frozen executable identity; no machine RTL/layout was changed.
