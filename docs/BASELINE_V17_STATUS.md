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

`make -C verilator test HEADLESS_DIR=obj_dir_v17_baseline` remains running
in `/tmp/x1-v17-baseline.log`; do not mark complete from individual passes.
Its delay-aware runner SHA-256:
`166bf9129b272ce03b8d6c2d2d72ebf157627705fab59f569060a4c79cbd14e1`.
Both ordinary profiles run SYS=32 MHz/VID=28.571428 MHz; fast ignores
inherited intra-assignment delays and is not the timing reference.

## Fresh commercial qualification in progress

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
hashes. Druaga, Mappy, Galaga and Shanghai remain live, not yet gameplay passes.
all later control durations, Galaga firing and Shanghai native feedback/pair
assertions stay unchanged. The 7200-second host timeout per stage does not
change simulated duration. No old state is restored or converted.
Logs `/tmp/x1-v17-{xevious,druaga,mappy,galaga,shanghai}.log`.
Only Xevious is a terminal gameplay pass so far. Audit final collector return codes,
input/prefix-state hashes, control reports and all copied runners after
terminal completion before promoting the historical v16 qualification.

Full work groups 1–6 and Turbo Z remain open, including native/physical
device gates, Arcus/Bastard Special and analog/IRQ FM acceptance.
