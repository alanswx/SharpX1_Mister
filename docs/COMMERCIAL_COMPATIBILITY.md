# Private commercial-game bring-up

## CRTC-source ordinary requalification: all five pass

Fresh collectors run sequentially from frozen ordinary fast runner
`328b3b6b0ab12371838a7f610e012714398460ec5ed6b750b2dd2bd37d86f3e7`
under ignored `verilator/obj_dir_headless/crtc-baseline-games-SWAKsH/`.
Runner, machine, support scripts/keys and IPL are copied before launch;
`/tmp/x1-crtc-games-inputs.sha256` records their initial hashes. No old
snapshots are reused or converted; native prefix remains sixteen seconds
in unchanged eight-second chunks, with original controls/assertions.

Xevious, Druaga, Mappy and Galaga collectors have completed with all native stage codes
and control codes zero, `gameplay_verified=true`, original inputs unchanged,
repeatable RGB/RAM/reports, and movement `(30,40) -> (36,40)` and
`(68,32) -> (67,32)` for the first two. Mappy moves `(129,84) -> (126,84)`;
Galaga moves `(32,24) -> (40,24)` and separately passes active-enemy,
firing/projectile travel and release/repeatability checks with return code zero.
Shanghai also finishes zero: native cursor `(488,167) -> (544,160)` and
matching-pair removal `0 -> 2`, with RGB/full dump/state/report repeatability.
Logs are `/tmp/x1-crtc-native-TITLE.log`. The sequential job finishes zero;
all 378 initial frozen-input manifest entries match after all five finish,
log `/tmp/x1-crtc-games-inputs-final-audit.log`. A separate final check verifies
all five terminal collector flags/native/control codes, Galaga's fire code,
every recorded input hash, all native-prefix state hashes and zero original
disk writes. All native reports retain baseline SYS=32 MHz, VID=28.571428 MHz.
This runner predates the subsequent read-only X3 JSON/short-restore C++
increment; ordinary machine RTL/layout is unchanged by that increment.
These are bounded ordinary gameplay results, not X3/Z software or hardware.

## Post-blink ordinary v17 requalification

All five fresh collectors terminate zero on ordinary fast runner
`b1452906a5548333486d16007ba90bdc663382ee97980b545d4d8bdcf47a1915`.
Xevious, Druaga, Mappy and Galaga pass unchanged release-bound movement,
RGB/RAM/report repeatability and original-asset checks. Galaga also passes
active-enemy/firing/projectile checks. Shanghai passes native cursor and
matching-pair removal (`0` to `2`) with dump/state/report/RGB repeatability.
No game bytes or old snapshots are patched or converted.

The ignored frozen root is
`verilator/obj_dir_headless/blink-baseline-games-Pu8Q0v/`. Runner, machine and
test sources, keys and IPL were copied before all five launches. The original
16-second native prefix runs as unchanged 8+8-second checkpoints. All 552
entries in `/tmp/x1-blink-games-inputs.sha256` match again after completion;
audit log `/tmp/x1-blink-games-inputs-final-audit.log`. Per-title collector
logs are `/tmp/x1-blink-native-TITLE.log`. This is bounded ordinary fast-model
gameplay, not new X3/Z gameplay, full-game completion or FPGA acceptance.
The previous v17 evidence below remains source-bound historical evidence.

## Current v17 qualification: all five bounded gameplay gates pass

Fresh [v17 native qualifications](BASELINE_V17_STATUS.md) all terminate zero
from frozen runner `73181a8f87e1194a8899bb2801263548ecb5c926ef7d8f78a87cb5983648c06f`.
Xevious right `(30,40)` → `(36,40)`, Druaga left `(68,32)` → `(67,32)`,
Mappy left `(129,84)` → `(126,84)`, Galaga right `(32,24)` → `(40,24)`
plus native firing/projectile travel, and Shanghai cursor/matching removal
`0` → `2` pass unchanged release-bound assertions. Original/frozen inputs,
every native-prefix state, collector/control/firing codes and all six runner
copies are independently audited; the initial manifest still matches.
Both ordinary full suites pass too (fast 137/delay-aware 140 PASS reports).
This is bounded ordinary fast-model gameplay, **not** full-game completion,
delay-aware gameplay, FM/SIO/Z software, Arcus/Bastard or physical acceptance.
The source-bound v16 results below are historical, not relabelled.

## Historical v16 qualification: all five bounded gameplay gates pass

October 9: after [shared FM CPU-bus integration](FM_MACHINE_STATUS.md), all
five freshly native-booted processes terminate zero on the frozen ordinary
fast/savable v16 runner, SHA-256
`b7ae59432af08fd357f5721840a54316587819a021c81dd82dc44df40105435a`.
Each collector records gameplay verified, original inputs unchanged, successful
control return and successful native-prefix stages with zero disk writes.
Galaga's separate firing/active-enemy/projectile-travel check also exits zero.

| Title | Actual native input evidence |
|---|---|
| Xevious | Right movement `(30,40) → (36,40)` |
| Tower of Druaga | Left movement `(68,32) → (67,32)` |
| Mappy | Left movement `(129,84) → (126,84)` |
| Galaga | Right movement `(32,24) → (40,24)` plus native firing/projectile travel |
| Shanghai | Cursor `(488,167) → (544,160)` and matching removal `0 → 2` |

Ignored frozen root: `verilator/obj_dir_v16_fm_machine/games-r7GvWa/`.
Runner, IPL, unmodified support scripts/keys and machine/runner sources are
copied before launch. The original 16-second native boot runs as 8+8-second
checkpoints; later native/control durations and release assertions are
unchanged. No old snapshot is restored or converted, no RAM/game bytes are
patched and no private original is overwritten.

After all handles terminate, independent checks verify collector flags/codes,
every original/frozen input hash, every native-prefix state hash, root/support
manifest and all five copied runner hashes. SYS=32 MHz, VID=28.571428 MHz,
cold reset=4159 SYS edges; actual RGB/memory/state/report repeatability checks
remain enabled. Logs: `/tmp/x1-v16-{xevious,druaga,mappy,galaga,shanghai}.log`.

This is bounded ordinary base-X1 fast-model gameplay, not full-game completion,
delay-aware gameplay, native FM/SIO/Turbo Z, Arcus/Bastard Special or hardware
acceptance. FM and SIO remain off in the ordinary runner. The full ordinary
v16 fast suite and direct snapshot checks also pass; the ordinary delay-aware
baseline finishes with 140 PASS reports. The source-bound `832766f` Quartus
refit also finishes, but does not establish hardware gameplay or full timing
closure (see [audit](FM_MACHINE_STATUS.md#completed-source-bound-refit)). Earlier
v15 evidence is retained below, not silently relabelled.

## Historical v15 qualification: all five bounded gameplay gates pass

October 9: after the default-off shared SIO integration, a fresh ordinary
fast/savable v15 runner has SHA-256
`f484bede6fde9a1f0bbba6ff30b6f5727c05041762a5b6179520b3b094e987f9`.
All five independently launched qualification processes terminate with exit
zero. Every collector records `gameplay_verified=true`, `unchanged_inputs=true`,
control return code zero and successful native boot stages with zero disk
writes. Galaga's additional real firing check also exits zero.

| Title | Bounded actual native-input evidence |
|---|---|
| Xevious | Player `(30,40) → (36,40)` on right input |
| Tower of Druaga | Player `(68,32) → (67,32)` on left input |
| Mappy | Player `(129,84) → (126,84)` on left input |
| Galaga | Player `(32,24) → (40,24)` on right input; active enemy wave and native firing/projectile travel |
| Shanghai | Cursor `(488,167) → (544,160)`; actual matching-pair removal count `0 → 2` |

Frozen ignored root:
`verilator/obj_dir_v15_sio_machine/games-cRZFOe/`. The runner, IPL and unchanged
collector/gameplay/Shanghai-preparation/Galaga-fire helpers and keys are frozen
and hashed **before** qualification. Machine/runner sources are separately
copied there for provenance. Each new native boot uses the same private media
as the v14 checkpoint below, starts with IPL/ioctl rather than a restored old
state, and runs the unchanged total 16-second boot in 8+8-second checkpoints.
Subsequent native/control durations and original input assertions are retained.
No RAM/game patches, new input substitutions or state conversion were used.

An independent final audit checks all five terminal collector flags/return
codes, original/frozen input SHA-256, every saved native-prefix state hash,
root/support manifests and all five copied executable hashes. SYS=32 MHz,
VID=28.571428 MHz and cold reset=4159 SYS edges; actual frame/dump/report/state
repeatability checks remain enabled. Individual logs are
`/tmp/x1-v15-{xevious,druaga,mappy,galaga,shanghai}.log`.

This is ordinary base-X1 **bounded fast-model gameplay** on these exact
releases, not full-game completion, delay-aware gameplay, native SIO/Turbo Z,
Arcus/Bastard Special or current-source physical hardware acceptance. SIO
remains off in this runner. The [v15 ordinary suites](BASELINE_V15_STATUS.md)
and [enabled SIO generated diagnostics](SIO_MACHINE_STATUS.md) are separate
evidence. Private originals, screenshots and states remain ignored/unbundled.

## Historical v14 qualification: all five bounded gameplay gates pass

October 9: source `c7c35b2` builds a fresh ordinary fast/savable runner with
snapshot v14. Its SHA-256 is
`c03a0de6b0fa08af4fe763cb0ca6a92b7590c9b5b4a10611ce78bc78656a5c86`.
Fresh Xevious, Druaga, Mappy, Galaga and Shanghai native boots and controls
terminate successfully. Galaga's firing and Shanghai's cursor/matching-pair
gates also pass. The entire two-worker batch exits zero; all five final
collectors record `gameplay_verified: true` and unchanged inputs. An
independent final check verifies each title and every frozen support hash.

The isolated ignored qualification root is
`verilator/obj_dir_v14_c7c35b2_requalify/frozen-4CLvS6/`. It contains frozen
copies of the runner, collector, unchanged release-bound gameplay assertions,
Shanghai cursor-feedback helper, boot/start key sequences and IPL. The
`frozen-inputs.json` manifest records every support-file hash; the batch checks
them again after each title. Per-title logs are at the root; native commands,
states, actual RGB/dumps and gameplay provenance go under `verilator/<title>/`.
The original authorized D88 files remain protected and release-hash checked.

Each collector uses `--boot-chunk-ms 8000 --timeout 7200`: the host timeout
does not alter the original simulation/control durations. States are generated
from real IPL/disk boot, never converted from v13 or populated by game RAM
injection. Required gates remain movement/repeatability for the four action
games, Galaga firing, Shanghai cursor/pair removal and unchanged private inputs.
Only terminal successful provenance qualifies this runner; the five-title
v13 result below remains historical. Delay-aware gameplay, Turbo/Z native
software, Arcus/Bastard and current-RBF hardware acceptance are still open.

Xevious passes the unchanged 300 ms idle/right/repeat test: player `(30,40)`
to `(36,40)`, actual RGB `cdabbdb5bde7e775` / `6db18481a8469bda`, main
RAM/report/RGB repeatability and unchanged media. Native live-state SHA-256
is `cb3194a81715b069aa9c83bac1cde11051e241464d79dab330196a85fed1c3a7`.
The collector's final `gameplay_verified` and `unchanged_inputs` are true;
an independent post-run check also verifies every frozen support/private
input hash. This is baseline 32 MHz system / 28.571428 MHz video,
4159 cold-reset edges, no inherited intra-assignment delays and no optional
Turbo/Z/DMA devices, not delay-aware or hardware game acceptance.

Druaga also passes the unchanged 300 ms idle/left/repeat test: player `(68,32)`
to `(67,32)`, RGB `644b6cc15d598873` / `d44c80e1ae854377`, exact
main RAM/report/RGB repeats and unchanged media. Native live-state SHA-256
is `6b97bc24a4ee6c452855258f6918e9fd703831bfc4ba1696eb49b99180fc01c8`.
Terminal collector gameplay/input checks and independent frozen-support/private
input hashes pass on the same runner/configuration, without RAM injection.

Mappy passes the unchanged native Space-start chain and 300 ms idle/left/repeat
test: `(129,84)` to `(126,84)`, RGB `12a8415dfa9a77e0` / `fadfbb7c90035011`,
RAM/report/RGB repeatability and unchanged inputs. Native live-state SHA-256
is `8814b6c48bee74fe8ebacf77a0d9f0a51f07f222cbbc66a056bf3938a9cc57de`.
Terminal collector gameplay/input checks and independent frozen-support/private
input hashes pass, using the same baseline fast runner/configuration.

Galaga passes native movement `(32,24)` to `(40,24)` with exact idle/right/
repeat checks, RGB `7f98f926506a84a6` / `b5d2b564ec188ca6`. The native
live-state hash is `9222a3260467411c7897dcd8322b129ca4da3a9830272298937e55860c8c2435`.
After the unchanged six-second active-wave continuation, firing produces one
shot rather than zero and a projectile `(33,12)` moving to `(33,8)` on release;
all 16 enemy slots, RAM/RGB/state/report repeatability and unchanged inputs
pass. Wave-state hash is
`e0c7326e8a77ecdc3b11b258213134e6bddc2488373414176431e31a50ef5671`;
idle/fire/released RGB hashes are `2f6825fad688832a`, `d631622b672b906d`,
`8ea1be19fcf625a4`. Final gameplay/control/fire provenance and independent
frozen-support/private-input integrity checks pass on the same runner.

A convenience Xevious screenshot is retained at
`verilator/xevious/controls/controlled.png` inside the ignored frozen root.
It is a format conversion of the actual controlled-run PPM, not an illustration.
`scripts/compare_video_png.py` checks all 64,000 decoded PNG pixels against
that PPM with zero mismatches. This conversion check is not MiSTer evidence.

Shanghai passes the unchanged cursor/matching-pair assertions: idle cursor
`(488,167)` to `(544,160)`, matching raw tiles at `3E1B/3EBA`, removed count
`0` to `2` and repeatable full RAM/RGB/state/reports. Native cursor feedback
positions the same historical pair using only normal joystick inputs;
it does not patch game RAM or alter release-bound assertions. Idle/removed
RGB hashes are `f80f4af748047b39` / `44ed23bc5976312c`;
cursor-state hash `2a1f480412964859b9374a50beb892f1640b6905186f8025171208187854a75d`,
pair-state hash `0139b7aed9911bcc9ff5e6c72aa3b891f8ae87012cb27f473c513499ff521cb5`.
The final collector and independent asset/support integrity checks pass.
This completes the five-title bounded ordinary fast v14 gameplay gate, not
full-game compatibility, optional-device/native Turbo Z or hardware acceptance.

## Five-title v13 bounded requalification passes

Source `9748410` starts fresh native Galaga/Mappy boot chains after the
transaction-bound DAM correction. Old v12 states are not converted or used.
Frozen ordinary fast/savable runner SHA-256:
`e3cb7cb2b0f91d4ebe200ecfc67c48f6aea650a5f123f5574ca70283aaba3b82`.
Ignored outputs: `verilator/obj_dir_v13_requalify/{galaga,mappy}-9748410/`;
logs `/tmp/x1-v13-{galaga,mappy}-requalify.log`. Both invocations use
`--boot-chunk-ms 8000`, retaining the original sixteen-second total native
boot and title-specific controller checks. Each invocation copies its runner
and hashes originals; no private media or state is committed. The media is
the release-bound Galaga `d0cdeb82…` and Mappy `297e89aa…` listed below.
Galaga and Mappy finish with exit zero, verifying controlled movement, actual
RGB changes, RAM/report/frame repeatability and unchanged original inputs.
Galaga additionally passes active-enemy native firing/projectile checks.
Xevious also finishes with the same bounded movement/RGB/repeatability gates.
Their `provenance.json` files each record `gameplay_verified: true`; screenshots,
states and dumps remain ignored. These are source-9748410 fast-model tests,
not acceptance of later internal8 edits, delay-aware native gameplay or hardware.
Druaga also finishes with exit zero and `gameplay_verified: true`: controlled
left movement, actual RGB change, repeatable RAM/frame/report and unchanged
inputs. Log `/tmp/x1-v13-druaga-requalify.log`, output
`verilator/obj_dir_v13_requalify/druaga-9748410/`. **Four v13 titles now pass
bounded controls**. Shanghai subsequently finishes with exit zero and
`gameplay_verified: true` on the same runner: native cursor input, matching
pair removal (0 to 2 removed tiles), actual RGB change and full dump/state/
report repeatability. Its disk hash remains unchanged. Log
`/tmp/x1-v13-shanghai-requalify.log`, output
`verilator/obj_dir_v13_requalify/shanghai-9748410/`.
**All five fresh v13 titles pass the release-bound bounded fast-model checks.**
This requalifies the DAM/state correction at source `9748410`, not full-game
completion, all releases, later experimental Z code, native Turbo, Arcus/
Bastard Special or new-RBF hardware gameplay. Old snapshots were not converted.

## Historical qualified checkpoints

October 4, 2026: **5 of the required 5 commercial games reached reproducible
native gameplay-control evidence at the earlier checkpoint**. That five-title
set was subsequently requalified as recorded below; historical results must
not be attributed to a newer executable without that requalification.
This is bounded simulation gameplay, not
complete software compatibility, level completion, or hardware acceptance.
CROSS Chase is a separate homebrew regression and does not count toward five.
All game media and native snapshots remain ignored private testing assets.
Do not commit or redistribute them; collection availability is not a license.

October 5 **v11**: fresh baseline Xevious, Druaga, Mappy and Galaga controls
and Galaga firing pass on source `95c181c`. Shanghai's original timed replay
failed, but [native cursor feedback](SHANGHAI_FEEDBACK_STATUS.md) now prepares
the same historical pair and passes the unchanged removal/RGB/repeatability
test. **Five v11 titles pass bounded gameplay checks.** The old failure is
preserved; this is not Turbo or hardware acceptance. Frozen runner SHA-256:
`ee270b8052a350528c0d16f69da119a4576769ad0fa026ae9b4bd29b8d9507c7`.
Evidence: ignored `obj_dir_v11_fast/native-requalification/` and
`obj_dir_v11_fast/shanghai-feedback/` beneath `verilator/`.

October 5 X3/font-source follow-up: fresh baseline v03 native-boot
requalification has passed all five baseline games at the X3/font checkpoint.
Four action games use frozen executable
`d3f6f53a852e82ddeccb3a12f5731484d86ad1f0ee4c2e6faf05378edccb1dda`.
Its RTL matches `cd2695e`; the only subsequent runner change rejects combining
font download with snapshot restore. Neutral/right coordinates remain
`(30,40)` / `(36,40)` and RGB hashes remain `1b4795935e709306` /
`867c8d2c709720a8`. New native live-state hash is
`6e77334a5908c02f2e9d29c78e0356aae885fe3cbfdfd72256e9b59020a21101`.
Commands, cold/continuation reports and controls are retained under ignored
`verilator/obj_dir_fast/x3-requalification/xevious/`. This does not establish
Turbo-profile or hardware gameplay.
Druaga's fresh native live-state hash is
`c66564df93fb731d25027995f223ae1e18f1ad49bd350131056765c2b0958687`;
neutral/left coordinates are `(68,32)` / `(67,32)`, RGB hashes
`052e84d3a9ef2ddb` / `17a6be7d42032c0f`. Its cold/continuation/control
evidence is under `verilator/obj_dir_fast/x3-requalification/druaga/`.
The first Mappy joystick-start trial and the 21/24-second Space/neutral
continuations failed the live-player assertion. Native Space at 24 seconds,
then a three-second continuation, reaches the live stage at 27 seconds without
weakening that assertion. Neutral/left are `(129,84)` / `(125,84)`, RGB hashes
`3479dbcfb5b7f078` / `fbb1f17f6eba2d58`, native state SHA-256
`fe9a095481af03987ea556bb3c00e81c16a5e824ab5cd1c87b8e2cc09ef51824`.
Failed and successful trials remain under `x3-requalification/mappy/`.

Galaga's native 33-second movement state SHA-256 is
`34f517c9968eacdbf28be97dc3ae02e31db25b70da27152090f476fdd82ecc53`;
neutral/right `(32,24)` / `(41,24)`, RGB `7f98f926506a84a6` /
`b5d2b564ec188ca6`. A six-second neutral continuation reaches the 39-second
enemy wave: 16 active slots, zero/one shots for neutral/fire, projectile
`(33,12)` → `(33,8)` after release. Full RAM/RGB/state/report repeats pass.
Wave state SHA-256:
`2750523b1955742147606785970034de1c8a95fca76c77dede59867990394c14`.

Shanghai uses frozen executable
`5e863541bdf32a9bbc09671c6f3c5961a53151362acf50c471937e13d079592b`
(same RTL, additional runner restore guard). Native cursor and pair-state
hashes are `dca082ed30997f57163e1aea978dcdb3e47a70e601ec37e6646f4d8d65f75070`
and `6d5f09f447b1a6b5134506aa5d3142d23358ffc84066bfe9c652edcf9906f17f`.
Cursor `(488,167)` → `(536,160)` and removed count `0` → `2` pass with
repeatable actual RGB, RAM, state and reports. Each game's frozen runner,
native boot chain and test outputs remain under `x3-requalification/`.
These are **pre-deleted-data-index** results, not acceptance of subsequent
storage changes or complete Turbo/hardware compatibility.
`tests/requalify_commercial.py` regenerates states through native IPL/disk
and recorded controls rather than importing incompatible historical states.

### CRC/v05 qualification — completed with one failure

The `76d87a2` CRC/CPU-wrapper checkpoint required fresh v05 states; old v04
passes below do not qualify it. Its frozen fast baseline runner is
`2b48f7818c7fa584b82502c9fc2a99ed536fae2b923093eb387f0035a77ed1c0`.
Fresh sequential qualifications for all five titles have been started under
ignored `verilator/obj_dir_fast/d88-v05-requalification/`; none is asserted
passed until its actual controls and source-integrity checks finish.

For a CPU-contended host, `requalify_commercial.py --boot-chunk-ms 8000
--timeout 7200` checkpoints the same 16-second boot as 8+8 seconds and divides
long neutral continuations without changing their total durations or inputs.
All initial key events must finish in the first chunk. Keyed continuations
are not split. The frozen runner still enforces quiescent snapshots; no old
state conversion, RAM loading or firmware patching is used. Host timeouts
retain partial logs and an explicit failed result, never a gameplay pass.
`make -C verilator test-requalify-scheduling` checks orchestration and timeout
reporting with asset-free mocks, **not machine execution or gameplay**.

Bastard Special's two new native four-second cold probes on this runner
produce identical reports, RAM, frames and quiescent states, with unchanged
assets and zero writes. Private evidence is under
`verilator/obj_dir_fast/special-probes/bastard-v05-cold4s/`.
The actual frame hash is `b7b725b914373325` (640×200); state SHA-256
`b7d835a7be6896d812bae7d3e1f30c1f675deb3393d5a80f2355d945a58731c1`.
This is repeatability, not gameplay. `continue_native_probe.py` verifies the
source probe's hashes and frozen runner, then restores native state without
ROM/font/RAM downloads. Four-second continuations toward 16 seconds followed
by a Z/1 input probe are running; playability remains unverified.
The completed native 4→8-second continuation shows the actual Bastard Special
title/logo and “PRESENTED BY XAIN”; frame hash `22b566650e6207c3` at 640×200.
This is a title screen, not a playable scene or a successful start sequence.
The native chain subsequently reaches 16 seconds unchanged. Its four-second
Z/1 continuation reaches 20 seconds, performs 95 additional read requests and
changes the actual screen to a title overlay labelled “DIM”, frame hash
`29ce8173ecbffc53`; still no game-play acceptance. The completed neutral
20→24-second continuation shows the title and an empty bordered lower panel,
frame hash `d4322a9b14ddbb53`, not a verified playable scene.
The subsequent unchanged 24→28-second Enter/Z exploratory probe reaches an
actual Japanese menu under the title, frame `7d0cc9430f23194a`.
`special-probes/bastard-v05-confirm/` retains the native continuation and RGB;
this is menu/input progress, not a playable scene or repeatable gameplay.
The unchanged 28→32-second numeric-1 probe also completes without disk writes,
but its actual RGB still shows the menu, frame `c3c8a386fbc61a81`.
The saved state is `60bae891b030b5e44b09d41eedc33e7f12a463b1604009580a6a037f5f454723`;
evidence is in `special-probes/bastard-v05-menu-one/`. The unchanged ordinary
Enter continuation completes at 36 seconds and its actual RGB shows a
name-entry panel containing “DAHAN”, frame `4d2751b05b089e53`, still not
gameplay. Three PS/2 bytes, zero new disk requests/writes; state SHA-256
`06c89bbadec12de1c119e1a7345d0d3211d2321e0bcbaadc61d78e4b79a1cd40`.
Evidence: `special-probes/bastard-v05-menu-enter/`. A subsequent ordinary
Enter/name confirmation toward 40 seconds is running. No firmware/RAM
patch or unsupported device-ready value was supplied to advance the menu.
`--from-continuation` verifies the parent
chain's asset identities and saved-state hash, so longer probes can continue
without reloading ROM/RAM or silently changing clocks/model/runner.

Fresh CRC/v05 Xevious qualification completed on frozen executable
`2b48f7818c7fa584b82502c9fc2a99ed536fae2b923093eb387f0035a77ed1c0`:
native 16-second boot, 0.5-second start and three-second live stage, then
300 ms controlled/idle/repeat checks. Right moves `(30,40)`→`(36,40)` with
matching main RAM/report/RGB repeatability and unchanged media. The private
provenance is `verilator/obj_dir_fast/d88-v05-requalification/xevious/`.
The daemon restart interrupted the remaining batch; a hash/schedule-checked
`requalify_commercial.py --resume` retained Druaga's verified native prefix
and completed the unchanged 250 ms start, 14-second live continuation and
300 ms idle/left/repeat checks. Coordinates `(68,32)` → `(67,32)`, RGB
`052e84d3a9ef2ddb` / `17a6be7d42032c0f`, RAM/report/RGB repeatability and
unchanged assets pass. Native state SHA-256:
`315fd60fdad62858d154645f4b16644e377f0fd23a3e96a564b4f3fdbd7f0982`.
Evidence: `verilator/obj_dir_fast/d88-v05-requalification/druaga/`.
Mappy now passes repeatable left movement `(129,84)`→`(126,84)` with unchanged
inputs, RAM/report/RGB repeatability and native state
`69856d0aa9e33e344f5ebbcd17c4339aa17c3ba83d598d7bd401900d7449482a`.
Galaga's collector also returns zero and its active-wave firing/projectile
and repeatability checks pass. The frozen v05 batch therefore has four
accepted titles, not five. Shanghai's collector returns one: the gameplay
assertion that the neutral board contains matching `91` tiles at `3E1B/3EBA`
fails. Inputs stayed unchanged; native states and `controls.stderr` are retained
under `d88-v05-requalification/shanghai/`. Determine whether its staged input
sequence chose a different board before changing RTL or assertions. None
of this v05 evidence qualifies the subsequent PCG/metadata/v07 or PPI/v08 machine.

The separate older v04 Z/1 16-second cold probe retained one host timeout and
one completed run; its collector correctly reports **not repeatable**. That
is inconclusive rather than a game pass or a proven RTL failure.
Arcus's older frozen v04 X3 savable runner completes two identical eight-second
A-only cold probes (Disk 1; no B), unchanged assets and zero writes, but still
shows the IPL disk-search screen. A native 100 ms continuation records PPI
`1A01` polling, with no FDC accesses in that bounded window. Offline IPL
inspection identifies a cassette-style polling routine; this does not yet
establish why disk boot chose that path. The new v05 100 ms startup trace
observes DMA DISABLE and ordinary SIO writes, not a completed DMA transfer.

### Deleted-data/v04 requalification

October 5: all five control gates also pass on the new deleted-data checkpoint
`2db40b0`, frozen baseline executable SHA-256
`16e1fb66b3e3ea001e8e9d084cc568addf6720b63ffcc5080c246ce3beaacb99`.
These are new native cold boots and continuations, not converted v03 states.
The shared machine uses 32 MHz system / 28.571428 MHz video, 4159 initial reset
edges, unchanged native IPL/game disks and no intra-assignment delays.
Commands, reports, control comparisons and frozen executables remain under
ignored `verilator/obj_dir_fast/d88-v04-requalification/<title>/`.

| Title | Native control result | v04 live-state SHA-256 |
|---|---|---|
| Xevious | Neutral/right `(30,40)` / `(36,40)` | `79e1798ffc5c29160172cc3bbda2606ceb603414be7d55325f0a8fb7c1abed47` |
| Druaga | Neutral/left `(68,32)` / `(67,32)` | `b724d9e4283a4e39ad824e7576f56930e56ba60b7997d926728dd58b29ee6989` |
| Mappy | Native Space start at 24 s; live at 27 s, neutral/left `(129,84)` / `(125,84)` | `6a47618099825b688e27ebce641bbeef22aa3e58743908c1976c2a2ae057d0cd` |
| Shanghai | Cursor `(488,167)` / `(536,160)`; legal pair removed, count `0` / `2` | Cursor `7b91f4896abf231cbe622a61b07bff533f5115138f4e9b972229ab0dacd7279d`; pair `2c38cdb41aeb8ee9e1212bec2ed865cc84505cc1ea4259a87417df10b3eb8a02` |
| Galaga | At 33 s, neutral/right `(32,24)` / `(41,24)` | `cbe0c735c67665325ee6517334f20b7a309952d3a0cc3893d2140c55243269cc` |

Galaga additionally passes the unchanged firing regression after a native
six-second neutral continuation: 16 enemy slots, shots `0` / `1`, projectile
`(33,12)` to `(33,8)` after release. Wave-state SHA-256 is
`8434d27a3623f4bc46982431ff49a8edd5952e76b3392909969e08b8d9dbcb93`.
Idle/fire/released RGB hashes are `320906a1036afe92`, `53fa204c036a640b`,
`7f55bbd4fdce64ea`. This continuation was run separately from the original
movement helper; its command/report/dumps and firing comparisons are in
`galaga/wave39s.*` and `galaga/fire/`. Future helper runs include it automatically.
All five bounded control comparisons repeat actual RAM/RGB/state/reports and
verify unchanged inputs. This closes the five-title baseline control gate for
this storage checkpoint, not complete game, Turbo or hardware compatibility.

Active path: `verilator/sim.v` → `rtl/sharpx1.v` → shared renderer/FDC/CPU.
These commercial runs use `obj_dir_fast/Vtop`, baseline 32 MHz system and
28.571428 MHz video clocks, without inherited intra-assignment delays. The
delay-aware video diagnostic matrix is separate; commercial single-clock,
delay-aware gameplay and MiSTer verification remain open.

| Game | Native boot observation | Control evidence | Counted |
|---|---|---|---|
| The Tower of Druaga | IPL/D88 → title → floor 1 maze and running timer | Left moves player `(68,32)` → `(67,32)`; repeated run matches main RAM, report and actual RGB | Yes |
| Xevious | IPL/D88 → title → live playfield/ship | Right moves ship `(30,40)` → `(36,40)`; retained coordinates and actual RGB agree; repeated run matches | Yes |
| Shanghai | IPL/D88 → title → live tile board | Repeatable joystick cursor movement, tile selection and legal matching-pair removal; 144 → 142 tiles | Yes |
| Battle City | IPL/D88 → title/menu at 16 simulated seconds | Start and gameplay being tested | No |
| Mappy | IPL/D88 → title → live stage at 21 simulated seconds | Left moves player `(129,84)` → `(126,84)`; actual RGB changes; main RAM/report/RGB repeat identically | Yes |
| Woody Poco | IPL/D88 loading observed | No live gameplay/control evidence yet | No |
| Galaga | IPL/D88 → title → selection → Stage 1 and active enemy wave | Repeatable left/right ship movement plus firing and upward projectile travel; actual RGB agrees | Yes |
| Arcus (X1turbo) | Fresh native IPL/Disk 1 probe; loading message observed through 16 seconds | No gameplay or disk-change evidence; Turbo foundation exists but full compatibility remains open | No |
| Bastard Special | Fresh native IPL/D88 probe; actual RGB title observed through 16 seconds | No start/playfield/control acceptance yet | No |

## Completed RTC-enabled probes: repeatable, not gameplay acceptance

After the separate delay-aware RTC runner qualification at `8480899`, new
sixteen-second cold/repeat probes complete with explicit local source-derived
controller upload, supplied Turbo IPL/4,096-byte ANK and protected original
game disks. No state restore, RAM injection, disk writes or game patches are
requested. The probe now accepts `--rtc-controller` and rejects its combination
with `--save-state` before asset/output access; that parser control passes.

Ignored outputs:
`verilator/obj_dir_v17_rtc/special-probes/arcus-rtc-8480899-16s/` and
`verilator/obj_dir_v17_rtc/special-probes/bastard-rtc-8480899-16s/`;
logs `/tmp/x1-arcus-rtc-8480899-16s.log` and
`/tmp/x1-bastard-rtc-8480899-16s.log`. Each probe freezes its actual executable
before launch and requires identical cold/repeat results and unchanged media.
Arcus Disk 1 in A / Disk 2 in B is explicitly exploratory, not verified disk
order. The controller's completed RTC qualification and hash are recorded in
[RTC status](RTC_MACHINE_STATUS.md).

Independent auditing verifies both frozen executables, every original input,
identical cold/repeat JSON reports and RAM/text/attribute/sub-RAM/CPU/PPM/CSV
artifacts. Both `evidence.json` files record repeatability and unchanged inputs,
zero disk writes and `gameplay_verified: false`. Arcus issues 2,752 host disk
requests and captures 640x400; Bastard issues 1,062 and captures 640x200.
Actual RGB inspection shows Arcus's bright green background and small garbled
dialog, and Bastard's “ACTION ROLE PLAYING GAME / Bastard Special / PRESENTED
BY XAIN” title. Neither establishes gameplay.

Each ignored folder contains `cold.png`, converted from its actual `cold.ppm`
using macOS `sips`, not a generated illustration. The existing strict RGB
comparator checks 256,000 / 128,000 pixels respectively with zero mismatches.
The executable is bound to the qualified `8480899` RTC checkpoint, not later
RTL changes. This
runner uses SYS 32 MHz / VID 28.571428 MHz, without the separate X3/video-master
option. High-scan software output cannot inherit nominal X3 or hardware
acceptance from this clock/profile. Correct-clock probes, handler/disk diagnosis
and actual start/playfield/control acceptance remain open.

## Arcus and Bastard Special: private native probes

These additional titles are locally supplied archives, outside the top-32
shortlist. No commercial images were downloaded. Arcus has five preserved D88
members; Bastard Special has one. Original archive/member hashes are recorded
in ignored `software/special-unpacked/manifest.json`. Archives carry a 38-byte
trailer warning from 7z; extraction succeeded and exact member bytes are retained.
Staging and execution do not infer redistribution rights.

```sh
# Repository root; idempotent only for identical staged bytes/manifests.
python3 scripts/stage_special_titles.py
cd verilator
python3 tests/probe_special_titles.py ./obj_dir_fast/Vtop arcus \
  --seconds 16 --output obj_dir_fast/special-probes/arcus-new-build
python3 tests/probe_special_titles.py ./obj_dir_fast/Vtop bastard-special \
  --seconds 16 --output obj_dir_fast/special-probes/bastard-new-build
```

Use new output directories after rebuilding RTL. The fixture freezes/hashes
the executable and starts **two fresh cold native IPL boots**; no checkpoints,
RAM injection or patched loader/game are used. It mounts Arcus Disk 1 only.
It runs the recorded F/Space `tests/commercial_boot.keys` script and retains
actual PPM, CPU registers, RAM dumps, commands, stdout/stderr and JSON counters.
PASS means report/RAM/RGB repeatability and unchanged input bytes, not a game
boot/control pass. `--io-trace` adds potentially large clock-sample CSVs; use
short diagnostic trials. No write-enabled disk output is passed.

Initial 8-second fast-baseline trials both passed deterministic report/main,
text, attribute, sub-CPU RAM, CPU-register and native PPM comparisons, with
zero disk writes. Inspecting the actual PPM showed Arcus's “IPL is loading
ARCUS X1” message, while Bastard Special showed its illustrated title and
“PRESENTED BY XAIN”. Arcus's loading message does not establish title boot;
Bastard's title does not establish gameplay. The probes used 32 MHz system /
28.571428 MHz video, 256,000,000 reference cycles, 4159 cold reset edges and
6 completed PS/2 bytes. Key transmission is not game acceptance.

| Initial evidence | Arcus Disk 1 | Bastard Special |
|---|---|---|
| D88 SHA-256 | `e1b05c477fc0369238c180db85e33840a27029aae6f417c731ae82e566422ef7` | `5c74588309d5f9a4fa03443bfdd5a0afff1c6e2620be58b63885f2dbdf6c3883` |
| Actual active raster | 320 × 200 | 640 × 200 |
| Frame hash | `d505f663fc0ba688` | `22b566650e6207c3` |
| Disk requests | 958 | 1062 |
| Ignored evidence directory under `verilator/obj_dir_fast/special-probes/` | `arcus-baseline-8s/` | `bastard-baseline-8s/` |

The initial executable was frozen before the main agent's later D88/keyboard
rebuild; its exact hash is in each `evidence.json`. Those runs are historical
evidence only and must not be attributed to the later RTL. Current rebuild
probes and their separately inspected results are recorded below.
Delay-aware and single-clock runs, authentic Turbo firmware/video, multi-disk
continuity, observed controls and hardware testing remain open. See the
[experimental Turbo foundation and clock plan](TURBO_IMPLEMENTATION_PLAN.md).

The later native cold **16-second** fast-baseline trials use executable
SHA-256 `5c1326b3b5bfdd72de947000a8aba5a90ab06113f8bb41735f9b35aed7c815db`,
frozen after the main agent reported the strict-D88 rebuild. Both native PPMs
were inspected and converted to retained `cold.png` files for convenient
viewing: Arcus remains on its loading message; Bastard Special remains on
its title. Frames and disk-request counts match the initial table, with
512,000,000 reference cycles, 988 frames, 4159 reset edges, six PS/2 bytes
and zero writes. Evidence directories are
`verilator/obj_dir_fast/special-probes/arcus-strict-native-16s/` and
`verilator/obj_dir_fast/special-probes/bastard-strict-native-16s/`.
Both pairs passed byte-identical native report/RAM/register/RGB comparisons
and unchanged-input checks. Build identity is recorded by executable hash;
these probes do not establish that subsequent concurrent RTL edits were
incorporated into that executable.

Final base-core confirmation after the D88 and receive-only keyboard changes
uses executable SHA-256
`31586f55cfb5cad068bb962bff621ca2a2048c87fb6b7a4e00193cdfe74ed515`.
Both titles again passed two fresh 16-second cold boots, with byte-identical
report/RAM/register/PPM repeats and unchanged original assets. The configuration
is explicitly `turbo_foundation=false`, 32 MHz system / 28.571428 MHz video,
512,000,000 reference cycles and 4159 reset edges. Frame hashes, dimensions and
disk-request counts match the table above; both have zero disk writes and six
transmitted PS/2 bytes. Evidence is retained under
`verilator/obj_dir_fast/special-probes/arcus-final-d88-keyboard/` and
`verilator/obj_dir_fast/special-probes/bastard-final-d88-keyboard/`.
The unchanged images confirm the same loading/title observations, not gameplay
or execution on the experimental Turbo model.

The historical Arcus 8-second I/O trace includes ordinary writes of `47` and
`5A` hex to CTC port `1FA0` and a read returning `FF`. This identifies a real
chip dependency to investigate with CPU/disassembly/IRQ traces, but does not
prove the loading stall's cause. Bastard's initial trace includes a sweep of
zero writes across `1Fxx`; that is not evidence of useful Turbo feature usage.

### CTC/Turbo-profile Arcus initialization diagnosis

The new opt-in Turbo/CTC fast executable is frozen as SHA-256
`aab42386bd335511854f52e371f5b1497c09f569dfd3f962af003f9ff695ec71`.
Both fresh 16-second Arcus Disk 1 runs retain 958 host requests, zero
writes, unchanged original media, 4159 reset edges and six transmitted PS/2
bytes. Actual RGB is entirely black at 640x400, frame hash
`03702d99714c4325`; HS/VS periods are 60.468750 us / 27.095031250 ms.
This is a different configuration from the base loading-message probe, not
correct high-resolution timing or successful game boot. Turbo aperture/RAM,
renderer controls and CTC all differ; this is not a CTC-only causal comparison.

At the endpoint, CPU PC is `F9B2`, AF=`8090`, SP=`00EE`. The routine beginning
`F9B0` reads FDC status `0FF8` and repeats while `status & 81` is nonzero.
Saved stack/script pointers identify the earlier drive-control value `81`.
A bounded, transaction-deduplicated trace from **15,990 to 16,000 ms** confirms
889 status-read transactions, every one with actual drive-control `81`, motor
on and effective media-ready false. Status values are `84/86`, both with
not-ready set and busy clear. Thus the immediate observed wait is **unsupported
drive B readiness**, not a CTC counter poll or a rendering loop.

Evidence is retained privately in
`verilator/obj_dir_turbo_fast/special-probes/arcus-ctc-status-final-16s/`.
Both cold runs have identical reports, RAM/register dumps and RGB; their
bounded transaction traces also compare byte-for-byte (889 reads each).
The black framebuffer matches the earlier CTC-profile observation exactly.
No fabricated readiness, injected game RAM,
restored snapshots or game/ROM patches were used. Staged disks 2–5 are preserved,
but were not mounted by that checkpoint's single-image host. See the
[dual-drive implementation/acceptance steps](TURBO_IMPLEMENTATION_PLAN.md#drive-b--disk-set-dependency).

The same frozen executable also passed two fresh **8-second** Bastard Special
boots, retaining 1062 disk requests, zero writes, unchanged inputs and identical
report/RAM/register/RGB repeats. The 640x200 title image matches the earlier
native title (`22b566650e6207c3`); no gameplay/start acceptance is inferred.
Evidence: `verilator/obj_dir_turbo_fast/special-probes/bastard-ctc-status-final-8s/`.

### Two-image Arcus probe — October 5

An explicit exploratory Disk 1 in A / Disk 2 in B probe removes the prior
unmounted-B readiness wait. Disk order has **not** been verified against
release instructions. The images are distinct staged originals, not mirrors;
no RAM injection, writable copy, game/ROM patch or restored snapshot is used.

Two cold **8-second** runs repeat reports, RAM/registers, actual RGB and the
bounded **7,990–8,000 ms** I/O trace, with unchanged input hashes. Frozen runner
SHA-256: `0a1ab3d93f4479c6aa925c1b9e9b356903d39fdc4a48ec202325a471afe90aaa`.
Both record 2752 host requests, zero writes, six transmitted PS/2 bytes and
4159 reset edges. The endpoint PC is `FAEC`; the final trace includes PPI/video
status `1A01` and sub-CPU `1900` reads with drive control `90`, motor on and
media-ready true. `FAE1/FAEB` are polling helpers for `1A01` bits 6/5; their
presence at one endpoint is not proof of a new permanent stall.

The captured 640x400 endpoint image is **not a recognizable game title**:
a green background and a small severely misrendered rectangle replace the
prior all-black framebuffer. Full-resolution PNG inspection and raw PPM
counts confirm 235,520 green pixels and 20,480 black/blue/white/cyan pixels;
it is not a uniformly green frame. Frame hash `25743cbe39750765`, HS/VS periods 60.500 us /
27.095031250 ms. This is still incorrect high-resolution timing/rendering,
not native gameplay or confirmed compatibility. Earlier and later shorter
probes must retain their own clocks, executable hashes and durations.

Private evidence: `verilator/obj_dir_turbo_fast/special-probes/arcus-dual-final-8s/`.
This frozen executable includes the A/B head/motor/owner integration and
unsupported-drive head protection, but predates the final previous-STEP-
direction retention fix. A later source-bound repeat qualifies that fix
separately; do not call this eight-second observation a test of subsequent RTL.
See [two-image behavior and limits](DUAL_DISK_STATUS.md).

The final STEP-direction-inclusive RTL at implementation commit `c6eab7d`
also passes two fresh **8-second** trials, frozen executable SHA-256
`5b6bc412b56e74925a1d88249eb3afca71b15676e611251c29e58edfa912da5d`.
Reports/RAM/register/RGB/I/O traces repeat exactly and both original disks,
IPL and key script remain unchanged. Its PPM and bounded CSV also match the
earlier eight-second observation byte-for-byte, with the same counters and
frame hash above. This rules out a short-run regression for this disk/keyboard
script, not complete software acceptance or correctness of all Turbo features.
Evidence: `verilator/obj_dir_turbo_fast/special-probes/arcus-dual-stepdir-final-8s/`;
the actual final PPM was converted to `cold.png` for local inspection.
A separate four-second repeat with the same final executable stops earlier
with only three PS/2 bytes transmitted, 958 requests and an all-black frame;
do not compare that endpoint with a completed eight-second input sequence.

Bastard Special was rechecked after the Quartus language fix (RTL matching
`ffc1c1c`): two fresh **8-second** native boots repeat reports/RAM/registers/RGB,
1062 disk requests, zero writes and unchanged inputs. Frozen executable SHA-256
`0cfbb6a9e438fa7633198ea516cb96cc92fa744bcb4e9d28f5ec7c8159c0eddc`.
The inspected 640x200 title PPM matches the earlier disk/keyboard checkpoint
byte-for-byte, frame hash `22b566650e6207c3`; gameplay remains unverified.
Evidence: `verilator/obj_dir_turbo_fast/special-probes/bastard-dual-verilog-final-8s/`.

### Fresh CROSS receiver-profile regression (separate homebrew)

After the special-title probes finished, two fresh 13-second native CROSS
boots and the original 200 ms PS/2 I/J control test passed on a newly frozen
baseline fast executable. This does not increase the commercial-game count
and is not Turbo video, delay-aware or hardware acceptance.

```sh
cd verilator
python3 tests/probe_cross_native.py ./obj_dir_fast/Vtop \
  --output obj_dir_fast/special-probes/cross-new-build
```

Completed evidence:
`verilator/obj_dir_fast/special-probes/cross-current-receive-13s/evidence.json`.
Each cold boot loaded the IPL and original protected D88 afresh, sent the
recorded `cross_start.keys`, ran 416,000,000 reference cycles and generated
a **new** private snapshot. Report, main/text/attribute/sub-CPU RAM, registers,
actual PPM and serialized state hashes matched the repeat. Both retained
4159 cold reset edges, 763 disk requests, zero writes, 24 sent PS/2 bytes,
803 frames and a 320 × 200 raster at 32 MHz system / 28.571428 MHz video.
Original IPL/disk/key bytes stayed unchanged. No earlier snapshot was restored
to establish this native boot.

The existing `test_gameplay.py` then resumed the newly generated `cold.state`:
neutral player `(22,14)` versus I/J `(21,13)`, with repeatable coordinates,
report and actual RGB. Neutral/controlled frame hashes were
`8a44e9d3762b883e` / `1b2144ae3d2c449e`; the original 200 ms / zero-extra-spacing
fixture passed. The fixture also checks the cyan player in text RAM and no
disk requests during controls; state provenance comes from the cold commands
retained by the new probe wrapper.

Executable identities must remain separate:

| Evidence | Frozen executable SHA-256 |
|---|---|
| Initial Arcus/Bastard 8-second probes | `fb095c6cce95d0d9325be76a7b1c9f42050c3271f6443262000f7122fd395c26` |
| Strict-D88 Arcus/Bastard 16-second probes | `5c1326b3b5bfdd72de947000a8aba5a90ab06113f8bb41735f9b35aed7c815db` |
| Fresh CROSS cold/repeat/controls | `5dbdb7dfc950f491db380a88c60137e84f2d7c18a8b7f535d788b657d113f20f` |

The shared `obj_dir_fast/Vtop` was rebuilt during CROSS testing and then hashed
to `31586f55cfb5cad068bb962bff621ca2a2048c87fb6b7a4e00193cdfe74ed515`.
The parent then repeated fresh cold boots and the original control regression
on this exact final executable at
`verilator/obj_dir_fast/special-probes/cross-final-d88-keyboard/evidence.json`.
Both native 13-second boots and all RAM/register/RGB/state repeats pass, with
unchanged originals. Controls again move `(22,14)` to `(21,13)` with the same
idle/controlled RGB hashes. This validates the current base machine's cold
boot plus bounded PS/2 movement; it does not requalify the five commercial
titles or any Turbo software.
The CROSS pass belongs to the frozen `5dbdb7df...` executable, not that later
build. These hashes bind actual tested executables, not every subsequent
concurrent source edit. The main agent reports explicit `PS2_RECEIVE_ONLY=1`
in the shared machine with standalone/legacy default 0; keep receiver profile
and executable identity explicit when regenerating these states.

## Reproduce the control checks

For live play, see [joystick-key window controls](PLAYING.md). Automated
release-bound tests below use the same actual PSG input pins, without SDL
event scheduling. These tests do not validate physical gamepads or a real mouse.

From `verilator/`, with the locally generated states and disks:

```sh
python3 tests/test_commercial_gameplay.py ./obj_dir_fast/Vtop druaga \
  obj_dir_fast/commercial/druaga-live-30s.state \
  ../references/software/private-downloads/commercial/tower-of-druaga-19xx-namco-c824fddb5d11/disk-0-bb8556981f09.d88
python3 tests/test_commercial_gameplay.py ./obj_dir_fast/Vtop xevious \
  obj_dir_fast/commercial/xevious-live.state \
  ../references/software/private-downloads/commercial/xevious-19xx-namco-ac4e0f6e45da/disk-0-3670f283005c.d88
python3 tests/test_commercial_gameplay.py ./obj_dir_fast/Vtop mappy \
  obj_dir_fast/commercial/mappy-21s.state \
  ../references/software/private-downloads/commercial/mappy-19xx-namco-5ba14e830be7/disk-0-297e89aa7a8d.d88
python3 tests/test_commercial_gameplay.py ./obj_dir_fast/Vtop galaga \
  obj_dir_fast/commercial/galaga-sidecar-live33s.state \
  ../software/top32-unpacked/06-galaga/6916bfea9bcb/75dc785e9ddf-Galaga.d88
python3 tests/test_galaga_fire.py ./obj_dir_fast/Vtop \
  obj_dir_fast/commercial/galaga-sidecar-wave39s.state \
  ../software/top32-unpacked/06-galaga/6916bfea9bcb/75dc785e9ddf-Galaga.d88
python3 tests/test_shanghai_gameplay.py ./obj_dir_fast/Vtop \
  obj_dir_fast/commercial/shanghai-22p5s.state \
  obj_dir_fast/commercial/shanghai-pair-remove-release.state \
  ../references/software/private-downloads/commercial/shanghai-1987-activision-1457d22f05da/disk-0-648d150e8e36.d88
```

Each check restores the same native-booted state three times: neutral input,
300 ms directional input, and its repeat. It checks unchanged original disk
and state bytes, zero disk writes, actual RGB change and release-specific
player coordinates. The tool never injects game RAM or substitutes screenshots.
A state alone cannot prove native-boot provenance: regenerate after RTL changes
and retain its actual IPL/disk run history. These snapshots were produced by
cold native IPL runs with `--rom ../bios/ipl_x1.hex --disk PATH`, followed by
restored continuations of the same machine, not diagnostic entry into game RAM.

Druaga reached its title after 16 simulated seconds. A 250 ms active-low
trigger (`--joya 0xdf`) started floor 1; neutral continuations reached the live
checkpoint at 30.25 seconds. Xevious reached its title after 16 seconds;
500 ms trigger followed by 3 seconds neutral produced the 19.5-second live
checkpoint. Both retain 4159 cold reset edges, including IPL loading.

| Evidence | Druaga | Xevious |
|---|---|---|
| Disk SHA-256 | `bb8556981f0910f33d7129f82de620a232e61b0fc41a61ed565366b5de4560b9` | `3670f283005c90b09a53e1b2dd1164c45c6a997eafbc0ca9c20248b9f7e19903` |
| Snapshot SHA-256 | `48b97822c27b06803172f3d2fe42ccaf88d6c5b2b26c2f074b98df287b9b87ae` | `af9af988f50b3dbc8fde2691a0e4d1ce569a2d63f77de7e43c59b86e883ad9fc` |
| Idle frame hash | `052e84d3a9ef2ddb` | `1b4795935e709306` |
| Controlled frame hash | `17a6be7d42032c0f` | `867c8d2c709720a8` |
| Active raster | 640 × 200 | 320 × 200 |

Druaga's routine at `0x0680` loads BC from `0xf828`, joystick handlers alter
B/C, and `0x1c16` stores them back. `0xf830/0xf832` are sprite/background
pointers, **not** coordinates. Right turns against the wall at this checkpoint;
only the tested left direction establishes displacement. Xevious's renderer
at `0x43bc` selects player structure `0x16e4`; offsets +1/+2 are Y/X and
+3/+4 retained copies, checked together. Its initial READY overlay remains
visible during the tested live movement; this is not level completion.

Mappy's player structure is selected with IX=`0xf800` at `0x03cd`.
Routines `0x0992/0x09b8` increment/decrement X at +`0x0b`;
`0x0973` checks Y at +9 against floor heights. At the live 21-second
checkpoint, neutral X=129 versus left X=126 with Y=84 and state=3.
Disk SHA-256:
`297e89aa7a8d9feb72651823bab210e66c09fdc1863bb6e4a9528c8ca652325b`;
snapshot SHA-256:
`74db00e257fd2609e65503ace8f7ad76c8ca5cc2dc7f03f2229d62ca90fe89c8`.
Idle/control frame hashes are `d94165a2b77ff168`/`049c495bf5bb7a89`,
640 × 200, with 4159 retained cold reset edges. The independent agent's
paired/repeat probes also matched text, attribute, sub-CPU RAM and register
dumps byte-for-byte; the shared regression also passed separately.

## Shanghai: a legal pair, not just a static board

The independent agent's joystick-only runs and the parent's new
`test_shanghai_gameplay.py` regression both pass. The latter repeats cursor
movement and pair removal on the rebuilt comment-capable runner; no `--keys`
option is used. Right changes the cursor from `(488,167)` to `(536,160)`;
native mouse emulation aligns the Y coordinate while moving X. The cursor
words are `0x5145/0x5147`, updated at `0x46e7..0x470b`. Button 2 (`0xbf`)
maps to Z/select, while button 1 (`0xdf`) maps to X/the other mouse action.

Native joystick navigation selected two free matching type-`0x11` tiles,
grid `(0,0)` layer 0 and `(3,5)` layer 1. Their RAM bytes at `0x3e1b/0x3eba`
became `0x91` when highlighted. A released/repressed select click confirms
the pair through the game's unmodified `0x2ac3..0x2b30` removal routine:
both bytes become zero, selection count at `0x2d2f` goes 2 → 0 and removed
count at `0x3f9f` goes 0 → 2. The actual display shows Tiles 142. Neutral
input retains both tiles and the 144-tile board. Controlled/repeated main,
text, attribute and sub-CPU RAM, CPU dump, PPM, state and reports match.

Disk SHA-256:
`648d150e8e36b5ba282bb7e3475e704f5f938d5c4a77ef6d7d000908f48513dc`.
Cursor checkpoint SHA-256:
`ea209764c04a6cde7475a44e6180ed220d2c4fc87b2b35d988ff1c53a0a02bd0`.
Selected/released pair checkpoint SHA-256:
`ef39f41826a438ee0fdaad4aee468577d4fb016aaf2fb4b0e709d453297632ef`.
Neutral/removed frame hashes: `f80f4af748047b39` / `44ed23bc5976312c`,
640 × 200. Both use the same native cold reset count 4159 and unchanged
original assets. No game RAM, registers, PC or synthetic firmware were injected.

The retained ignored `shanghai-gameplay-evidence.json` contains exact native
state-chain filenames, hashes and commands. Starting from the parent's
19.5-second native board checkpoint, the state preparation was:

| Input | Duration | Native result |
|---|---:|---|
| Neutral FF | 3000 ms | Stable board / cursor checkpoint at 22.5 seconds |
| Left FB, left FB | 100, 400 ms | Navigate toward tiles |
| Right F7 × three runs | 200, 50, 70 ms | End-tile selection test checkpoint |
| Select BF, cancel DF | 300, 200 ms | Exercise selection, then cancel |
| Left FB, up FE | 1000, 1000 ms | Reach top-left free matching tile |
| Select BF | 200 ms | First tile selected |
| Right F7 | 13 × 20 ms | Navigate toward matching tile |
| Down FD | 22 × 20 ms | Reach second free tile |
| Select BF, release FF | 300, 300 ms | Two selected matching tiles / removal checkpoint |
| Select BF, release FF | 300, 300 ms | Confirm pair and show 142 tiles at 27.92 seconds |

These are ordinary `--restore-state`, `--joya`, `--cycles MS*32000` and
`--save-state` continuations of the native machine. The fixture verifies the
last paired/repeated actions, not a complete puzzle or authentic mouse hardware.

## Galaga: native Stage 1 controls

The user-supplied standard raw 2D image was converted by the top-32 preparation
tool without changing sector payloads. Disk SHA-256:
`d0cdeb8275fbbdd2226851266a7bbf3d5e4ff77c268e331a81083c8eac3c342c`.
Cold native IPL loading serviced 1018 SD-block requests in the first six
seconds. The initialization countdown was not counted as a title or game.
From the 16-second checkpoint, 500 ms trigger plus 4 seconds neutral reached
the title at 20.5 seconds. A 250 ms trigger and 3 seconds neutral reached
level selection at 23.75 seconds. A second 250 ms trigger and 9 seconds
neutral reached active Stage 1 at 33 seconds.

Live-state SHA-256:
`35bc08e3a3d3c4eef9dd1206e4289311cd2f956bb7748142bcfca9f882295855`.
Native mode byte `0x0dd3=1` selects PSG port A, player state `0x230f=1` is
active, and X/Y are at `0x2311/0x2313`. Native routines `0x1a13/0x1a2b`
select X for decrement/increment; `0x1937/0x1947` render X/Y. The independent
agent verified both directions and the parent shared regression independently
verified right movement and repeatability on the current runner.

The 300 ms trials yield neutral `(32,24)`, right `(41,24)`, left `(23,24)`.
Frame hashes are `7f98f926506a84a6`, `b5d2b564ec188ca6` and
`5e4effd5b1247ca6`, respectively, at 320 × 200. Both directional repeats
match main/text/attribute/sub-CPU RAM, CPU dumps, reports and actual PPM
bytes. Original disk/state hashes remain unchanged; no new disk requests,
writes or PS/2 bytes are involved. Cold reset count is 4159.

Six more neutral seconds reach an actual enemy wave at 39 seconds. Wave-state
SHA-256:
`743c62302428ebf1c3802db2c261d48cf55c56a6ceddfe26136629108bbdf77f`.
There are 16 active enemy records (native table `0x4162`, stride 45, 45 slots).
A 300 ms trigger `0xdf` fires one shot versus zero for neutral input. Shot
count at `0x2714` rises to 1 and the first projectile record `0x5813` becomes
active at `(33,12)`, VX=0, VY=-1. After 100 ms release it moves to `(33,8)`
without increasing the shot count. The ship remains `(32,24)`. The native
trigger path is `0x513d` → `0x0bb1` → PSG bit 5; projectile initialization,
counter and motion routines are independently identified in this release.

Neutral/fire/released frame hashes are `320906a1036afe92`,
`53fa204c036a640b` and `7f55bbd4fdce64ea`. Both the sidecar's isolated-runner
probe and the parent's checked-in `test_galaga_fire.py` pass: RAM/RGB/state
and report repeats are identical, with unchanged originals and zero disk
writes/requests or PS/2 bytes. Native IPL and game bytes were never injected
through the diagnostic RAM path. Kills, scoring, level completion, audio
fidelity and hardware behavior are not established by these checks.

## Final simulation checkpoint

This section records the completed five-title milestone before the subsequent
D88/receive-only keyboard/Turbo foundation changes. Its hashes bind that earlier
checkpoint, not the present working tree. Regenerate private snapshots after
RTL changes; do not restore these historical states into a new model. Fresh
native CROSS checks and Arcus/Bastard probes above have separate executable
identities and do not requalify all five commercial titles on current RTL.

All five release-bound gameplay checks passed again together after the final
runner instrumentation/frontend changes. IPL hex SHA-256:
`2438a19d4846bf66bdec0d58c6665cf8dfa04adcee8d5d7821e248152c0b232c`;
current shared-machine/renderer SHA-256:
`4b97254e1122932eaf7ef83f91192f8afbcd8973bfae69d2f2e9d927a02ca0b0` /
`6ecc2b4b265bc3c641c033edf9a412250873fc1395349675b084a0176144a49e`.
Tool: Verilator 5.044, baseline fast system 32 MHz / video 28.571428 MHz.
Video acceptance separately passes sixteen independent pixel/period cases
and both live width switches in delay-aware baseline and single models; see
[video evidence](VIDEO_STATUS.md). Snapshot continuity, SDL joystick mapping,
key-script parsing, timing/FST and warm-reset checks also pass. This completes
the requested simulation/video-and-five-games milestone, **not** the broader
base-X1 release or full chip/Turbo/hardware TODO list.

## Remaining gates

- The five-title bounded control gate is reached; continue broader directions,
  actions and sustained gameplay. Title/loading counters alone still do not
  qualify as gameplay for future titles.
- Broader directions/actions and continued gameplay; reference audio fidelity.
- Rerun earlier comment-bearing key scripts: the runner previously stopped
  parsing silently on `#`, so the commented Space probe delivered no events.
  The parser now accepts full-line/inline comments and rejects malformed
  lines. Battle City's native IM2 handler receives held Enter (`0x0d`) and
  Space (`0x20`) after this simulation-only fix; neither proves gameplay.
  Fresh CPU E4/E6 diagnostics also accept these keys. No firmware fix is
  inferred from the invalid earlier probes.
- Reproduce native gameplay in delay-aware and single-clock configurations.
- Build current RTL and validate on MiSTer when hardware is available.
