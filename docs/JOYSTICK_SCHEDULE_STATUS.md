# Deterministic scheduled joystick input

October 9, 2026. Runner-only change, no machine RTL, clock-enable, game bytes,
snapshot-layout or board revision changes. This supplies the missing input
sequence for continuous delay-aware native gameplay tests without snapshots.

## Interface and execution

`--joy-at MS A|B BYTE` may be repeated. Times are unsigned milliseconds up to
1,000,000; the port is uppercase A or B and the active-low value fits a byte.
The numeric parser accepts the same integer syntax as other runner options.
Events must be globally time-ordered; ties preserve command-line ordering,
including last-value-wins on one port. Static `--joya`/`--joyb` establish initial
values; an event replaces only its selected port, not both ports or RAM.

The scheduler considers joystick deadlines alongside clocks, delayed RTL,
PS/2, reset and audio. All due changes are applied to `top.joya_n/joyb_n`
before evaluation at their timestamp. Time-zero events execute at the first
1-ps scheduler advance; later events execute at their specified deadlines.
Machine reset does not disable external input. On restore, events are relative
to the restored time and unscripted ports retain their saved values. No CPU
state, interrupt, game variable or enable is forced.

Live `--joystick-keys` and scheduled input together are rejected instead of
silently racing two sources. An unconsumed event queue prevents snapshot save
before opening the state output: future host events are not serialized into
the model. Ordinary v17 model identity/layout stays unchanged. JSON exposes
`joystick_events_applied`, `joystick_events_pending`, `joya_n`, `joyb_n`.
Those fields report host pin handling, not CPU recognition by themselves.

## Executed checks

`tests/test_joystick_schedule.py` uploads an original small IPL that repeatedly
selects PSG registers 14/15 with real Z80 OUT and reads/stores A/B with real IN.
It checks CPU RAM against scheduled pins at 2.5/5 ms, same-time changes,
release, a 50-us warm reset during events, SYS=32 MHz with both 28,571,428 and
24,000,000 Hz VID, full RAM/report repeatability, static pins and eight malformed
or conflicting CLI cases. Fast additionally saves drained events and restores
with new A input while retaining non-neutral B, and rejects a save with
pending events without creating a state file.

Both final-source executions terminate zero:

- `/tmp/x1-joystick-schedule-final-timing.log`, delay-aware runner SHA-256
  `520d17f2a1a700a72ecbb221a59c0448193502996d87733e30d474366f8d7321`.
- `/tmp/x1-joystick-schedule-final-fast.log`, fast/savable runner SHA-256
  `e21f57815b0967ed804f2e7f1689858aa836f38da7b2daca7eadcc7960906b1f`.

Final-source existing timing/determinism/FST, key-comment/PS2 and snapshot/
clock/joystick persistence/live-input regressions also terminate zero:
`/tmp/x1-joystick-schedule-final-{clocks,keys,snapshot}.log`.
`sim_headless.cpp` SHA-256:
`15b415aa52e6ca8805aec6ab1e29bc5f93669b34eca5176f941f49c51b982a05`;
new scheduling fixture:
`ac1fb44746b9a1ef7cc914514e12a2dd52559e5769f31b2e2103e2716f17ba07`.
The target is in both full ordinary suites and asset-free hosted diagnostics;
full reruns and hosted results are separate, not inferred from these checks.
Both full ordinary suites are subsequently launched with the new input case:
`/tmp/x1-joystick-schedule-full-baseline.log` and
`/tmp/x1-joystick-schedule-full-fast.log`. The fast suite subsequently completes
zero with 141 PASS reports and the unchanged `e21f5781...0906b1f` executable.
The delay-aware baseline subsequently also completes zero with 144 PASS
reports and unchanged `520d17f2...8d7321` executable. Independent
`scripts/audit_fast_timing_video.py` inspection confirms all eighteen video/
transition cases agree between these two logs, including frame hashes,
counts, clocks, periods and program/font identities. This is ordinary
regression coverage, not native Turbo/Z or hardware acceptance.

## Continuous commercial qualification completed

`test_xevious_cold_gameplay.py` launches three independent 19.8-second native
ordinary delay-aware runs: idle, right movement and exact repeat. Each uploads
the original IPL through ioctl, uses existing native startup keys and the
authorized release-bound D88. Start is pressed at 16 seconds/released at
16.5; the 300-ms comparison starts at 19.5. There is no RAM injection, game
patch, snapshot conversion or old-state restore. These simulated durations
match the existing fast collector; host timeout 7200 seconds does not change
the program, pixels or gameplay assertions.

The frozen tree is
`verilator/obj_dir_headless/joystick-schedule/cold-xevious-w6hxN424/`.
Its **695-entry** input manifest passes before launch
(`/tmp/x1-xevious-cold-initial-inputs.log`); runner/RTL/vendor/BIOS/keys/oracles/
runner-source copies are preserved before the long test. Log:
`/tmp/x1-xevious-continuous-timing.log`, ignored evidence under `results/`.
Original cold-gameplay oracle SHA-256:
`3f01be5d975ab0daaa4d5b649326101bd3343d3855504ea00b8786950b6316ba`.
It requires three zero native exits, correct ordinary delay-aware clocks/profile,
actual input/ROM/disk activity, active release-bound player structures,
rightward movement, actual RGB change, full dump/report repeatability and
unchanged inputs.

All three native runs subsequently terminate zero, followed by the collector's
terminal PASS. Independent inspection rechecks the actual stdout reports,
commands, artifact hashes, original inputs and both executable copies. Each
run captures 1,228 frames and services 1,151 disk requests without disk writes.
The player moves from `(30,40)` idle to `(36,40)` controlled. Controlled and
repeat reports and all six dumps/frame artifacts are byte-identical; idle and
controlled RGB frames differ. Final full **695-entry** input-manifest validation
also terminates zero: `/tmp/x1-xevious-cold-final-inputs.log`.

Idle PPM SHA-256:
`b11a7abae52389c01f7ecabc17724d42888f74679c9690ae6708fdf896fb8db5`;
controlled/repeat:
`0153f12ce1c432687ae27d49ac55ec12e3c4fea96cbfc24f0ed51f3713f73d9b`.
This qualifies bounded ordinary delay-aware cold boot/start/right movement
without snapshots, not a complete game or the other four delay-aware titles.
Music, Turbo/Z/native firmware and physical input acceptance remain separate.

## Three further continuous action-title tests launched

The new `tests/test_commercial_cold_gameplay.py` extends this cold, snapshot-free
procedure to Druaga, Mappy and Galaga. It preserves the native stages from
`requalify_commercial.py` and the release hashes/player symbols/direction
assertions from `test_commercial_gameplay.py`. Cold runs last 30,550/27,300/
33,300 ms respectively, including the unchanged final 300-ms controls.
Mappy's original title-start key script is applied at 18 and 24 seconds,
without replacing boot keys or injecting memory. Galaga's later enemy-wave/
fire/travel acceptance is separate, not claimed by this movement collector.
Shanghai's native cursor-feedback/pair test has no continuous replacement yet.

Four asset-free tests pass in `make -C verilator test-commercial-cold-plan`:
exact stage/control times and prohibited snapshot/injection options, original
key times/repeated Mappy start and invalid scripts, release-specific player
structures/invalid dumps, and CLI refusal before reading missing assets.
They are planning/oracle checks, not commercial execution. CI now includes
that target; hosted results are not inferred. Helper SHA-256:
`54c24a3d49297f8ec98d3346ce34e2d9da2cf70e6c522263dab0f8e23d735c52`;
asset-free fixture:
`0475befbb1c87a588091e308ffe655b6e60fb6a606512e9211cffcdd4f7daf85`.

Frozen root:
`verilator/obj_dir_headless/joystick-schedule/cold-actions-PHNPmGki/`.
Its **654-entry** manifest passes before launch
(`/tmp/x1-actions-cold-initial-inputs.log`); generated Python caches are excluded.
It contains the already qualified delay-aware runner, machine/vendor/BIOS/
keys/source/oracle copies, frozen before any new native launch. Each title's
preflight and original asset hashes are inspected and pass ordinary
SYS=32 MHz/VID=28,571,428 Hz delay-aware profile checks. Nine actual cold runs
(idle/controlled/repeat per title) are running; no gameplay pass is inferred.
Logs: `/tmp/x1-{druaga,mappy,galaga}-continuous-timing.log`.
Collector host timeout is 10,800 seconds per run, without shortened simulation
durations or loosened assertions. Final executable/input manifests and actual
reports/artifacts must be independently checked after terminal completion.

Druaga and Mappy subsequently both terminate zero for all three actual runs
and finish their collector acceptance. Independent inspection verifies each
original/frozen executable and input hash, actual stdout profile/report,
recorded artifact hashes, snapshot-free commands, changed RGB and identical
controlled/repeat main/sub/text/attribute/CPU/frame bytes. Druaga moves
`(68,32)` to `(67,32)` left across its 1,887-frame cold trial; Mappy moves
`(129,84)` to `(126,84)` left across 1,687 frames. Both keep zero disk writes.
The full **654-entry** frozen manifest also validates after these completions:
`/tmp/x1-actions-cold-two-complete-inputs.log`. Galaga remains running, not a
pass; final three-title manifest/acceptance and Shanghai's continuous pair
removal remain open. Together with Xevious, three ordinary delay-aware cold
action-game controls are now qualified, not full-game/Turbo/Z/hardware support.

Galaga subsequently also completes all three runs and collector acceptance:
native right movement `(32,24)` to `(40,24)` across 2,057 frames. Independent
final inspection covers **all nine** actual native runs: exact ordinary
delay-aware clocks/durations, six boot PS/2 bytes (twelve for Mappy), actual
release-bound RAM coordinates, every artifact and source/media/executable hash,
generated key-file identity, no snapshot/injection options, RGB change and
byte-identical controlled/repeat dumps/reports. All three collectors report
gameplay verified with zero writes and unchanged inputs. The entire **654-entry**
manifest finally validates zero after all complete:
`/tmp/x1-actions-cold-final-inputs.log`. Four ordinary delay-aware cold movement
titles now pass including Xevious; Galaga enemy-wave/firing/travel and Shanghai
continuous pair removal are still separate. The old fast five-title/firing/
pair evidence is not relabelled as delay-aware or Turbo/Z/hardware acceptance.
