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

## Remaining limits

One playable game is a bring-up milestone, not a compatibility certificate.
Disk writes, FDC error/density/motor behavior, exact PCG raster/scanline waits, full keyboard
commands, cassette, CTC/DMA/SIO and Turbo extensions remain incomplete or
unverified. PSG has an original 1 kHz waveform regression, not comprehensive
music/noise/envelope verification. Quartus and MiSTer hardware were not tested;
the board PLL frequency still needs review. Broad warning cleanup and inherited
licensing reconciliation remain release blockers.
