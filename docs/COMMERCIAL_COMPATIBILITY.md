# Private commercial-game bring-up

October 4, 2026: **5 of the required 5 commercial games have reproducible
native gameplay-control evidence**. This is bounded simulation gameplay, not
complete software compatibility, level completion, or hardware acceptance.
CROSS Chase is a separate homebrew regression and does not count toward five.
All game media and native snapshots remain ignored private testing assets.
Do not commit or redistribute them; collection availability is not a license.

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
| Arcus (X1turbo) | Fresh native IPL/Disk 1 probe; loading message observed through 16 seconds | No gameplay or disk-change evidence; experimental Turbo work pending | No |
| Bastard Special | Fresh native IPL/D88 probe; actual RGB title observed through 16 seconds | No start/playfield/control acceptance yet | No |

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

The historical Arcus 8-second I/O trace includes ordinary writes of `47` and
`5A` hex to CTC port `1FA0` and a read returning `FF`. This identifies a real
chip dependency to investigate with CPU/disassembly/IRQ traces, but does not
prove the loading stall's cause. Bastard's initial trace includes a sweep of
zero writes across `1Fxx`; that is not evidence of useful Turbo feature usage.

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
