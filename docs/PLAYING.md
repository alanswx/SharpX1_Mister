# Playing and verifying CROSS Chase

The shared `rtl/sharpx1.v` machine boots the acquired CROSS Chase D88 through
the checked-in IPL, renders 320×200 RGB, and accepts real PS/2 input through
the MR16 replacement sub-CPU. This is not RAM-injected game execution.

## Local quick start

Install Verilator 5.x, a C++20 compiler and SDL2 (`sdl2-config` on PATH), then:

```sh
make -C verilator play
```

I/K/J/L move up/down/left/right; Space fires. Close the window to stop. The
saved state has Caps Lock off: the game expects lowercase letters. Caps Lock
toggles the firmware's case mode. Simulation is about 10.6 times slower than
real time on the tested host; hold controls long enough for simulated time to
advance. SDL currently displays video only; `--audio file.wav` captures PSG
audio for offline listening.

The local state `verilator/obj_dir_fast/cross-start.state` contains actual RTL
state after 13 simulated seconds of native boot/start-screen inputs. It is
build-specific and contains ROM/game bytes. Neither it nor the disk is a
redistributable release asset. See [software provenance](../references/software/README.md)
and the root README's inherited RTL/BIOS licensing caveats.

## Regenerate and test

After changing RTL or rebuilding with an incompatible Verilator version:

```sh
make -C verilator boot-game
make -C verilator test-game
make -C verilator play
```

`boot-game` requires the already acquired, ignored disk and checked-in IPL.
It performs 416,000,000 system cycles, boots the disk read-only, sends startup
PS/2 input from `tests/cross_start.keys`, and saves the model plus a PPM and RAM
dumps. It takes several minutes. It does not download software automatically.
Override `GAME_DISK`, `GAME_STATE`, or `PLAY_CYCLES` explicitly if needed.

`test-game` resumes that native state for 200 ms with and without scripted I/J
make/break packets, checks the release-specific player structure against text
RAM, and requires changed RGB frames and byte-exact repeatability. Verified:

| Observation | Idle | I/J input |
| --- | --- | --- |
| Player (x,y) | (22,14) | (21,13) |
| RGB frame hash | `2917b1d92124ea6c` | `16f792d1d2c74a8c` |

Disk SHA256: `2fb70389737a7d54bff5a746b581343385ebde115cefb77ded32c473dcde97ec`.
IPL binary SHA256: `db612eaee19dd2b46d70f8fb96a64b744f0fc3e8f494cc6d015aa1b03d653ec7`
(4095 populated bytes). Base X1: 32 MHz system, 4 MHz CPU enables,
28,571,428 Hz video; reset spans 4159 system cycles including ROM download.
Native startup services 763 SD-block requests. No debug RAM loading is used.

An eleven-second native run in the delay-aware and clocked builds produced
identical full main RAM and PPM bytes (frame hash `e1d6010e6bbbe483`). A
sixteen-second scripted run reached a populated level and score 00025.
Actual SDL windows were exercised for both IPL and the native-booted game;
dummy-driver tests independently cover SDL make/break/extended-key events.

## Live commercial-game joystick controls

The optional `--interactive --joystick-keys` frontend maps arrows to the X1
joystick's directions, Space to button 1 and either Ctrl to button 2. Other
keys still produce PS/2 packets. Captured joystick keys do not also reach the
keyboard firmware. Losing window focus releases every joystick key. This is
host input connected to the real PSG pins, not game-memory manipulation.
Without `--joystick-keys`, the original CROSS Chase PS/2 controls are unchanged.

For example, from `verilator/` with the existing private native checkpoint:

```sh
make fast
./obj_dir_fast/Vtop --interactive --joystick-keys --cycles 32000000000 \
  --restore-state obj_dir_fast/commercial/shanghai-22p5s.state \
  --disk ../references/software/private-downloads/commercial/shanghai-1987-activision-1457d22f05da/disk-0-648d150e8e36.d88
```

In Shanghai, Ctrl selects/confirms a tile; Space is the other native mouse
action. Release between clicks. In Druaga/Xevious/Mappy, use arrows to move
and Space for the first trigger. Substitute the matching state and media from
[the commercial matrix](COMMERCIAL_COMPATIBILITY.md). Never restore a state
with a different disk or after incompatible RTL changes. Hold controls long
enough for simulated time to advance; this is not real-time emulation.

Joystick-key mode begins with neutral port A rather than retaining a pressed
button from a snapshot; explicit `--joya` is combined by active-low AND with
live keys. Port B remains governed by saved/explicit pins. This frontend does
not implement a real X1 mouse or physical SDL gamepad input.

## Remaining limits

For deterministic cold boots without fast snapshots, repeated
`--joy-at MS A|B BYTE` supplies scheduled active-low PSG joystick pins. For
example, `--joy-at 16000 A 0xdf --joy-at 16500 A 0xff` presses and releases
button 1 at 16.0/16.5 seconds. Events are relative to the current invocation
or restore, not wall time; they continue during machine reset. Unscripted
restored ports are retained. This cannot be combined with live joystick-key
mode, and saving with unconsumed scheduled events is rejected. See
[tests and limits](JOYSTICK_SCHEDULE_STATUS.md). It is host input, not a native
mouse protocol or evidence of hardware/game compatibility.

Playable input is a bring-up milestone, not a compatibility certificate.
Generated floppy read/write/error and PSG tone/noise/envelope diagnostics now
exist; exact controller timing, native PCG scanline waits, full keyboard
commands, cassette, CTC/DMA/SIO and Turbo extensions remain incomplete or
unverified. Game music fidelity remains open. The earlier single-clock CROSS
Chase checkpoint has separate MiSTer observations; the current video-alignment
RBF builds, but has not been hardware-tested. Neither validates the new live
host-input frontend on hardware. The board PLL still needs review. Broad
warning cleanup and inherited licensing reconciliation remain release blockers.
