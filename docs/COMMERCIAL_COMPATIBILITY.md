# Private commercial-game bring-up

October 4, 2026: **3 of the required 5 commercial games have reproducible
live-player control evidence**. This is bounded simulation gameplay, not
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
| Shanghai | IPL/D88 → title → tile board at 19.5 simulated seconds | Board interaction being tested; title Space probe did not start, joystick trigger did | No |
| Battle City | IPL/D88 → title/menu at 16 simulated seconds | Start and gameplay being tested | No |
| Mappy | IPL/D88 → title → live stage at 21 simulated seconds | Left moves player `(129,84)` → `(126,84)`; actual RGB changes; main RAM/report/RGB repeat identically | Yes |
| Woody Poco | IPL/D88 loading observed | No live gameplay/control evidence yet | No |

## Reproduce the control checks

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

## Remaining gates

- Two further commercial titles with real start and live control proof;
  title screens, loading counters and static boards do not qualify.
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
