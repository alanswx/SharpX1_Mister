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
`/tmp/x1-joystick-schedule-full-fast.log`. They are running, not completed.

## Continuous commercial qualification launched, not passed

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
unchanged inputs. Started is not gameplay acceptance. Other titles, music,
Turbo/Z/native firmware and physical input acceptance remain separate.
