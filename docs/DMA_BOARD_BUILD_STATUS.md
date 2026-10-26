# DMA single-clock FPGA qualification revision

## October 25, 2026 (later): FM reset

`0b1d857` (JT51 held in reset 64 cen_p1 after the machine reset) seed 1
(`quartus-linux-0qN0TCRs`): 22,749 ALMs, worst slack 0.246 ns, RBF
`07c6d841…` (`releases/SharpX1_20261025.rbf`). MiSTer 126 smoke test:
Thunder Force demo reaches its high-score screen, Zero Fighter (tape)
its title. FM sound not listened to (the capture path records no audio).

## October 25, 2026: Kanji in 15 kHz 8-raster rows, aspect ratio

`1cad521` (Z Kanji in any 16-raster row and 15 kHz 8-raster rows,
scan-dependent Original aspect) seed 1 (`quartus-linux-y1EY4wef`): 22,697
ALMs, worst slack 0.241 ns, RBF `012bd12b…`. MiSTer 126 (setnames
`X1F_20261024`, `X1S_20261025`):

| Title | Result |
| --- | --- |
| Aoki Ookami (Turbo), Monitor Standard | "SIMULATION WAR GAME" and the 1-3 menu in Kanji under the title (8-raster rows, every other glyph line) ✓ (was blank); picture 1,472 px wide at 1,080 lines (19:14 = 1,466; 4:3 = 1,440) |
| Sangokushi Turbo (`9253317`) | Scenario years, all rulers' stats and the stat roll show numbers ✓ |
| Hi-School Adventure (hi-res), Monitor High-res, Disk writes Enabled | AS-SOFT title, 1-3 menu, first room with Kanji text and "2F" ✓; picture 1,444 x 1,080 (4:3) |
| OSD | Top page: drives, tape, 16-row ANK, Load ROM; Advanced: Boot device, Disk writes, Load X1 IPL / Kanji font / tape ctrl. ✓ |

## October 24, 2026 (later): tester fixes

`9253317` (PSG period 0, D88 ID-CRC protection records, Z Kanji in any
16-raster layout, tape turbo silence gate, OSD/tape-slot changes) at seeds
1 and 2 (`quartus-linux-x6ZsoaT7`, `-fj0UoV2W`): 22,840 / 22,599 ALMs,
worst slack 0.245 / 0.244 ns. Seed 1 RBF `15fb0c7519ead0cbb9a7faff5c2acbce297794cc2fce147138e0e32331c8e8c6`.

MiSTer 126, setnames `X1F_20261024` (disks) and `X1H_20261024` (tapes, no
remembered disk):

| Title | Result |
| --- | --- |
| Suikoden (Turbo) | Loads; intro scene with its Kanji story line ✓ (did not load: rejected protection record) |
| Shin Kugyokuden (new disk A + B) | Intro scene at 70 s ✓ (did not boot) |
| The Man I Love (disks 1 + 2) | "DISK MISTERY #4 / THE MAN I LOVE" title at 40 s ✓ (did not load) |
| Hyper Olympic '84 (TAP, quick start + 5x) | Score screen clean at 60 s, overlay `5:15/ 5:59` without x5 (silent tail at 1x); event screen on black at 100 s ✓ (was striped) |
| Aoki Ookami (Turbo) | Title graphic at 60 s; the prompt row below it still shows no glyphs ✗ (Kanji fix did not cover this screen) |
| Thunder Force speech | Not checked: the capture path recorded no audio at all (music silent too) |

A tape MGL under a setname whose drives remember a disk boots the disk
(IPL order); use a separate setname for tape tests.

The tape sweep (`dcf6ac52`, 124 MAME machine-code TAPs, quick start + 5x):
failures were 3D Bomberman, Dezeni Land, Maharito, Tomato-hime (2),
Yakyu-kyou (2) (IPL TV timer: program over the IPL stack, excluded since
`01e8aba`), Hyper Olympic (2) (fixed above) and Super Mario Bros. Special
(game's TAPE ERROR, also at 5x without quick start: open). TanTan Tanuki A/B
stay at "IPL is loading" with and without quick start (two-tape game).
## October 24, 2026: tape speed 5x and quick start

`fef6013` (5x, ROM port, quick start) built at seeds 1/2 (22,405/22,896
ALMs, worst slack 0.201/0.242 ns) but was superseded before hardware: its
quick start crashed Zero Fighter in simulation. `bd6f331` (boot stub) at
seeds 1 and 2 (`quartus-linux-ulBM1ZVG`, `-NTVe3T3c`): 22,655 / 22,590
ALMs (54%), worst slack 0.240 / 0.248 ns, no negative slack in either; seed
1 RBF `dcf6ac527f9e9c2716bd25c9bb64ee53906f5f3b6bdbd17fa2fed6ca0f7a8786`.

MiSTer 126, setname `X1Q_20261024` (seed 1; media copied from
`X1R_20261023`, plus Pock-Kun), fresh settings (Tape speed 5x + quick
start), MGL tape mount then reset; times from the MGL load:

| Title | Result |
| --- | --- |
| Yellow Cab (8 kHz TAP, one 52 KB block) | Title by 26 s, instructions by 40 s ✓ (`592196b` 4x: instructions at 85 s) |
| Zero Fighter (128-byte loader, then its own loader) | "IPL is loading ZERO" and overlay `0:31/ 0:41 x5` at 18 s: the stub-booted loader reads the rest at 5x; title and attract by 42 s ✓ |
| Pock-Kun (BASIC) | "File mode error" and the IPL menu, as without quick start ✓ |
| Yellow Cab mounted with OSD Tape at that IPL menu | Core resets itself, title 30 s after the mount ✓ |

## October 23, 2026: fast tape, tape overlay, OSD layout, Z80 R register

`555cccc` added fast tape, the tape overlay and the computer-core OSD
layout (Machine/Video/Advanced, settings latched at Apply and reset);
`dd02266` fixed its hide flags and made Monitor default to Standard again;
`592196b` made the TV80 R register count fetches. Builds at `592196b`:
seeds 10 and 11 (`quartus-linux-xZ3dluy2`, `-YMHkn6LR`), no negative slack
in the 33 timing summaries of either. Seed 10: 22,444 ALMs (54%), worst
slack 0.154 ns, RBF
`941fde5261868359de407fc27b10c025188badd9b2de8357fb7bf2d45f6e465a`
(`releases/SharpX1_20261023.rbf`); seed 11: 22,449 ALMs, 0.194 ns, RBF
`0aa71d44…`.

MiSTer 126, setnames `X1OSD_20261023` (`555cccc` seed 11, `9d445777…`),
`X1OSD2_20261023` (`dd02266` seed 11, `60bb4ad4…`), `X1R_20261023`
(`592196b` seed 10) and `X1MON_20261022` (the previous release), each with
the Turbo IPL, tape controller, X1 IPL and Kanji font as boot.rom/boot1-3.rom:

| Title | Core / settings | Result |
| --- | --- | --- |
| Zero Fighter (TAP) | `555cccc`, fast tape | Overlay `TAPE > 0:19/ 0:41 x4` with its bar at 15 s; title by 45 s ✓ (`592196b`: same) |
| Yellow Cab (8 kHz TAP) | `555cccc`, Turbo Z + High-res default | Loads, but every other raster is missing ✗ |
| Same | `dd02266`, Turbo Z + Standard | Instructions screen at 85 s (260 s at real speed) ✓ |
| Thunder Force (D88) | `555cccc`, High-res | Title garbled (half the rasters) ✗ |
| Same | Previous release, X1 Turbo + Standard | Title fine; stops on the high-score screen for minutes, keys ignored ✗ |
| Same | `592196b`, Turbo Z + Standard | Demo plays (scene 2, score 2400), then the high-score screen with its random starfield, cycling ✓ |
| Space Harrier (S-OS) | Previous release | Caps Lock, `L SPACE HARRIER`, `J DB80`: SEGA title, Space starts stage 1 ✓ |
| Yoshie's Cookie (S-OS) | Previous release, X1 Turbo and X1 | After HIT KEY: empty panels; it waits for a joystick trigger (the KVM cannot press one) |
| Hi-School Adventure (hi-res) | `dd02266`, Monitor High-res + Disk writes Enabled via Apply and reset | AS-SOFT title ✓ (Standard: loader text garbled, as expected for the hi-res disk) |
| Gaiflame (two .d88) | `592196b`, Turbo Z | Kanji story, then the "最後の決戦がはじまる" art ✓ |

OSD on hardware: the top page has media and ROM loads, then Machine,
Video, Advanced and Apply and reset. Changing Model shows "Changes
pending" with no reset; setting it back clears it. In `555cccc` the
Monitor and Boot device rows never showed: Main strips `H`/`h` before the
page prefix, so `P2H1O[8]` is not an option (fixed as `H1P2O[8]`;
`test-osd-config` rejects the old order). With X1 selected both rows hide.

High-res is no longer the default: X1 software reprograms the CRTC for
15 kHz but leaves the IPL's 1FD0 high-scan bit set (Yellow Cab, Thunder
Force). MAME's DIP default is also standard.

Thunder Force (125 s release simulation, then the bus trace): no I/O; the
random-number routine at 9EE2 (`LD A,R`, XOR/RRC/ADD) stores 0000 to FD8D
every time, and the caller at A51B retries random positions forever. TV80
kept R only under `TV80_REFRESH`, which no profile defines.
`test-cpu-refresh` reads 00 on the previous core.

Yoshie's Cookie (95 s simulation, same screen as hardware): the loop at
B478 reads PSG registers 14 and 15 (both joystick ports) and repeats while
`AND 60h` is 60h, so it waits for trigger A or B on either stick.
A second 90 s run with `--joy-at 70000 A 0xDF` / `70300 A 0xFF` (trigger A
pressed for 0.3 s) shows both cookie boards ("2P SLAVE") at 90 s.

A `SC` drive keeps its image across core loads (`config/<setname>.s0`),
so after a disk MGL a tape-only MGL boots the remembered disk instead.

## October 22, 2026: OSD monitor type and boot3.rom Kanji font

`93a72ce`: OSD `Monitor` (Standard / High-res) drives Turbo DIP 1FF0 bit 0,
previously fixed at 1 (standard); `boot3.rom` (Main index 0xC0) now loads
the physical Kanji font (index 5). Seeds 4 and 11 (`quartus-linux-UXtUG0BH`,
`-bJeF5IDL`), no negative slack in any of the 33 timing summaries each.
Seed 11: 21,993 ALMs (52%), worst slack 0.249 ns, RBF
`3102cf335c859b8b2aeda2fd3da98c8acd6791141bfe71d73eba2f844d158abd`
(`releases/SharpX1_20261022.rbf`); seed 4: 21,871 ALMs, RBF `1965aa0b…`.

Simulation (release runner, `TURBO_DSW=240` in a separate directory):
Hi-School Adventure No. 1 (hi-res) boots Turbo BASIC CZ-8FB02 in 640x400.

MiSTer 126 (`_Computer/X1MON_20261022`, setname home
`games/X1MON_20261022` with the Turbo IPL, cassette controller, X1 IPL and
the Kanji font as boot.rom/boot1-3.rom; X1 Turbo model; no MGL Kanji item):

| Title | Settings | Result |
| --- | --- | --- |
| Hi-School Adventure No. 1 (hi-res, two .2d) | Standard or High-res, disk writes Protected | Loader stops after `TITLE PL` with "エラーーーガハッセイチャッタノ..ドウスル?" (the tester's "Japanese question") |
| Same | High-res, disk writes Enabled | Title, then 1/2/3 menu in Kanji; option 3 reaches the first room with Kanji text and the verb bar ✓ |
| Gaiflame (two .d88) | Standard, Kanji font from boot3.rom | Kanji story scroll, then the "最後の決戦がはじまる" art after Space ✓ (without the font the story is solid white bars, reproduced in simulation) |
| Yellow Cab (8 kHz TAP) | Tape mounted, then reset, no disk | "IPL is loading Yellow_Cab", instructions screen at 260 s ✓ |

The game writes to its disk at start; the OSD writes setting is the
deciding factor. OSD changes are lost when an MGL is reloaded unless saved.

## October 21, 2026: PS/2 joystick emulation off at start

`08c17a4` (`SUB_JOY_OFF`): A tester found A and C dead in X1 Turbo BASIC;
the inherited MR16 firmware's PS/2 joystick emulation was on at start.
`test-release-keyboard` passes (A fails on the previous runner).
Seeds 10 and 3 (`quartus-linux-VzLz7geZ`, `-c7Q1fxDn`), 0 negative slack in
33 summaries each. Seed 10: 22,072 ALMs, RBF
`322cc621bb1598852d13750d88fcdfabfa9ad1d69f662e8cb64dbe00697db291`; seed 3:
21,811 ALMs, RBF `b7fc3987…`; seed 10 is `releases/SharpX1_20261021b.rbf`.

MiSTer 192 (`_Computer/X1JOY_20261021`, X1 Turbo model, native Turbo IPL +
ANK16, no Kanji font): HuBASIC CZ-8FB01 boots to `Ok` and typed
`aczxaczx` echoes. The rebuilt joystick-off/CAPS-off cassette controller
(`861fbbcb…`) loads the K01 tape (Zero Fighter) to its attract screen.
With the controller and no disk/tape, the IPL shows its F/R/C/T menu;
mounting K01 from the OSD then loads it. The keypad was not tested (the
KVM cannot send keypad keys). Screenshots in the session's `hw_joy/`.

## October 21, 2026: no-font boot and reduced-mode Z palette writes

Seeds 10 and 3 (`quartus-linux-JHSjBPZL`, `-aRtnwstg`), about 25 minutes,
no negative slack in any of the 33 timing summaries. Seed 10: 21,703 ALMs
(52%), RBF `aa3c2332749372b99832d5ad2dba6f65b6a059b7834cb495fe6d1759242dfba9`;
seed 3: 21,727 ALMs, RBF `b888f127…`. Hardware results are in
[MODEL_SELECT_STATUS.md](MODEL_SELECT_STATUS.md#no-font-boot-and-reduced-mode-palette-writes-october-21).
The seed-10 RBF is checked in as `releases/SharpX1_20261021.rbf`.

## October 20, 2026: Turbo Z merged (X1 Turbo Z model)

The release core now carries the Turbo Z video set behind a third OSD model,
X1 Turbo Z; Z registers decode only there and only for CPU (not DMA)
cycles. Seed 10 (`quartus-linux-ckCYfUI1`, RBF `b8cf96ef…`) and seed 3 both
have 0 failing paths in all 32 inventory reports; 21,905 ALMs (52%), 443/553
M10K. Simulation, generated-pixel hardware checks and the title sweep are in
[MODEL_SELECT_STATUS.md](MODEL_SELECT_STATUS.md#turbo-z-mode).

## October 20, 2026: merged release core (model select, boot device)

This revision is now the single release core (`REVISIONS.md`). It adds the
runtime X1 / X1 Turbo model, a separate X1 IPL slot and the OSD boot-device
DIP (`MODEL_SELECT_STATUS.md`).

| Build | Seed | RBF SHA-256 | ALMs | M10K | Timing (32 reports) |
|---|---|---|---|---|---|
| `97p2xIJ1` | 10 | `281c6730dc1084af2d387daa6122c347ca9f3b1e55dae6c8a160c012bb964265` | 21,397 | 437 | 0 failing |
| `4fBKgwzB` | 2 | `c03a757c…` | 21,289 | 437 | 1 failing (HDMI OSD→scaler setup, −0.074 ns, −40 °C) |
| `pTJ67DNo` | 6 | `9c4585ed…` | 21,480 | 437 | 9 failing (DDR f2sdram→font hold, worst −0.137 ns; one HDMI hold) |

The model-select build without the DIP option (`gBqaBgqX`/`BHJsjSyB`/
`XE8qBhKY`, seeds 10/2/6) had 0 failing paths in all three. Builds took
about 23 minutes.

Hardware, MiSTer 192, seed 10 (`_Computer/X1MERGE_20261020`), Turbo mode:
Sorcerian story (25 s), title (58 s) and menu (95 s); Zeliard, Xanadu II,
Tetris, Gall Force, Relics, Mappy, Silver Ghost, Valis, Ys II, Dione (FM
prompt after Return), Galaga and K01 (150 s) all show the same screens as
the earlier rounds. The OSD shows `Model` and `Boot device`. X1-mode results
are in `MODEL_SELECT_STATUS.md`. Audio is unverified (capture returns none).

## October 20, 2026: sub-CPU RAM in block RAM; Sorcerian FM/DMA fix

**Three seeds build with 0 failing paths in all 32 timing reports. ALMs fall
from 75% to 51%. Sorcerian reaches its title and menu on every 192 boot.**

Two changes:

- `22de4d7`: an owned DMA I/O read no longer takes the CPU's retained FM/SIO
  reply. This caused Sorcerian's intermittent hang after its story text; see
  `FM_MACHINE_STATUS.md`. The `11c7f30` section below saw one good run only.
- The sub-CPU's 2-KiB work RAM (`x1_sub` `sub_w_ram`, 1024×16) was a
  two-writer `dpram`. Quartus could not infer its read-during-write behavior
  (map Info 276009), so it built the RAM from 8,287 ALMs and 16,408 registers.
  This was true since the original bring-up, in every revision. Their wide
  read muxes congested routing (peak 77%), which is why several seeds would
  not fit. It is now an `x1_tdp_ram` with `SAME_CLOCK=1`: both ports on one
  clock, cross-port collisions return old data as the Verilator model and the
  old `dpram` did, and `clock1` is left unconnected (altsyncram error 272006).

| Build | Seed | RBF SHA-256 | ALMs | Registers | M10K | Peak routing | Timing |
|---|---|---|---|---|---|---|---|
| `HimGqNVP` (`22de4d7`, before) | 10 | `65fb88ac…` | 31,547 | 43,048 | 431 | — | 0 failing |
| `cTKSNWJS` (`22de4d7`, before) | 6 | — | — | — | — | 77% | No fit (routing) |
| `F6KdzVl6` (sub RAM) | 10 | `8e115ecc5a81262246b981cd740b04aab47d60704ea998e7e8613a26ac2ea059` | 21,472 | 26,704 | 433 | 31% | 0 failing in 32 reports |
| `MF5YcQ2b` (sub RAM) | 2 | `4fcb6c3136b2d40dbc83ebb44c872dbdce92f5b3d2cb0fc8060619f97cc69e83` | 21,517 | 26,669 | 433 | 27% | 0 failing in 32 reports |
| `ABafMARn` (sub RAM) | 6 | `f71aedc9da41a6238d1ff53e45efc18ce07838770ddae324d1216ffe394e26b7` | 21,246 | 26,532 | 433 | 30% | 0 failing in 32 reports |

Each build took about 11 minutes, down from about 25. The next largest logic
consumer is `x1_z_kanji_cache` (~7,150 ALMs): its per-cell `visible` and
`active_bank` bits are 2,048-bit register vectors.

Simulation: `make -C verilator test`, `test-machine-cassette`, `test-sub-rtc`,
`test-ctc` (real MR16 keyboard IRQ ACK at three clocks), `test-rtc-keyboard`,
`test-machine-dma-irq-keyboard`, `test-machine-fm`, `test-x3-fm-dma-irq` and
`lint-wrapper-turbo-z-font-single` all pass.

Hardware, MiSTer 192:

- `22de4d7` seed 10 (`_Computer/X1TAIL_20261019`): three Sorcerian boots all
  show the story at 25 and 45 s, the title at 58 and 75 s, and the menu at
  95 s, with audio RMS 2,225–2,819. The other titles match the `11c7f30`
  table below, with the same audio RMS within 5% (DM05/DM07/DM08/Galaga were
  silent at the capture point in both rounds).
- Sub-RAM seed 10 (`_Computer/X1SUBRAM_20261020`, `x3subram.rbf`, same MGLs):
  two Sorcerian boots reach the story, title and menu at 95 s. Every other
  title shows the same screen as above, K01 reaches Zero Fighter's attract
  screen at 150 s, and the Dione prompt accepts Return (keyboard through the
  new sub RAM). **Audio was not recorded:** the capture now returns 0 s of
  audio for the earlier X1TAIL build too, with `dvi_mode=0` unchanged, so
  this is open on the capture/HDMI side, not attributed to the change.

These are bounded screen observations, not gameplay acceptance.

## October 19, 2026: FDC command deferral; Sorcerian boots once

**Sorcerian reached its story text and title with music in this run, but
it later hung intermittently after the story (fixed by `22de4d7`, above); the
other titles do not regress. Seed-6 timing: 8 failing setup paths in the
framework HDMI domain (see below).**

Source `11c7f30` enables `FDC_DEFER_COMMAND` on boards. A command written
while the controller rescans the newly selected drive's D88 now reports BUSY
and runs after the scan, instead of being dropped (see `DISK_STATUS.md`).
Sorcerian had been black because its RESTORE on drive 1 was dropped.

| Build | Seed | Result |
|---|---|---|
| `YIlMaLg5`, `5AQih3hX` | 2, 4 | Killed at 75 minutes, still in the fitter |
| `1QI7FBWZ`, `XVtwYqQx` | 5, 7 | No fit (error 170143) |
| `JgvgRDWb` | 6 | Built in 18 minutes. RBF `ebcdf711f60f04264db6c6ff45f78d4e54d3749eceb917274702ecf8329e8af9`. 31,551 ALMs, 431/553 M10K. Timing: 8 setup paths fail in four slow corners, worst −0.265 ns (−40 °C), all pll_hdmi→pll_hdmi (`hdmi_out_de`/`hdmi_out_d[22]`, `ascal o_vcpt_pre3`); 0 in the other 28 reports and none in core clocks |

Hardware: MiSTer 192, `_Computer/X1FDC_20261019` (`x3fdc.rbf`, MGLs copied
from `X1DMA_20261019` with only the RBF path changed). HDMI audio recorded with
`kvms record`.

| Title | Result |
|---|---|
| **Sorcerian** | Black until 14 s (loading), story text ("A long time ago…") at 19–42 s, title with "Copyright 1987 FALCOM" at 51–61 s, then the starfield attract scene (the runner also settles there at 60–75 s). Audio from 15 s, RMS 2,000–3,200 |
| Zeliard | Kanji intro over the crest art; audio RMS 1,865 |
| Xanadu Scenario II | Status screen with castle art; audio |
| Tetris | Title art; music (RMS 5,404) |
| Gall Force | Title with Kanji menu |
| Relics | Intro; audio |
| Mappy | Title / top 5 |
| Silver Ghost | Team menu |
| Valis | Title; music (RMS 6,917) |
| Ys II | Kanji vertical story intro; music |
| Dione | Disk prompt; FM music after Return (RMS 3,899) |
| Galaga | Attract screen |
| Zero Fighter (K01 tape) | Attract screen at 150 s |

These are bounded screen/audio observations at 25–60 s (Sorcerian to 61 s;
K01 to 150 s), not gameplay acceptance.

## October 19, 2026: DMA on the X3 font board (`sharpx1_turbo_z_font_single`)

**Build PASS, eight-corner timing PASS (0 failing paths), bounded hardware
PASS for 9 of 10 titles; Sorcerian open (fixed by `11c7f30` and `22de4d7`, above).**

Source `4fcb116` adds `X1_TURBO_DMA_FONT` to the X3 external-font revision:
the Z80 DMA with completion/restart IRQ and the DMA/Kanji shared-bus profile.
The FM board, its CTC and the cassette deck stay enabled. Chain: FM CTC > DMA >
main CTC > keyboard. FDC DRQ drives DMA RDY. A reset drains an owned DMA pair
before the font service pauses the machine.

It builds on `7cfc26f`, which makes video/PCG/controller RAM explicit true
dual-port blocks (`rtl/x1_tdp_ram.sv`; Verilator keeps a behavioral model).
Quartus had built each as two duplicated copies. RAM blocks fell from 545 to
431 of 553, and seed builds dropped from about 41 to 18–21 minutes.

| Build | Seed | RBF SHA-256 | ALMs | M10K | Timing (32 reports) |
|---|---|---|---|---|---|
| `ULBkGxA0` (TDP only, `7cfc26f`) | 2 | `d0e7b09c…` | 31,594 | 431 | 0 failing paths |
| `wKLdfk5S` (TDP + DMA, `4fcb116`) | 2 | `ec195e633c91d642ea82314260ae07472620c339aebfd228dd09e96e5aa4a434` | 31,413 | 431 | 0 failing paths |
| `ELPLI0QX` (TDP + DMA) | 4 | `6c6da30f…` | 31,389 | 431 | not inventoried |

Simulation:
- `test-x3-fm-dma-irq` runs the real-CPU nested DMA-over-CTC fixtures (plain,
  and keyboard with `--caps-off`). It also runs restart IRQ (3 modes × A/B
  source) and FDC restart (2 drives × 3 modes × A/B, real DRQ). All pass on the
  X3 FM/FM-CTC/DMA runner at 42.95 MHz.
- `test-machine-fm-ctc` adds an X3 DMA-present case.
- Zeliard, which stalled at "IPL is loading" without DMA, makes 36,352 DMA
  transfers in the runner. It reaches its intro and has audio from 16 to 70 s.

Hardware: MiSTer 192, `_Computer/X1DMA_20261019`, with the CAPS-off
controller. HDMI audio was enabled for this round by setting `dvi_mode=0`;
the original ini is kept as `MiSTer.ini.bak_dvi_20261019`. Audio was recorded
from the capture stream with `kvms record`.

| Title | Result |
|---|---|
| Zeliard | Kanji intro over the crest art; music until about 69 s (runner: 70 s) |
| Ys II | Kanji story intro (30 s) and credits (55 s); music |
| Xanadu Scenario II | Title art |
| Tetris | Title art; music |
| Gall Force | Title with Kanji menu |
| Relics | Static-noise intro, matching the MAME frame; audio |
| Mappy | Title |
| Silver Ghost | Team menu |
| Valis | Title; music (RMS about 6,400) |
| Dione | Disk prompt; FM music after Return (RMS 3,100–4,300; runner 3,500–4,800) |
| **Sorcerian** | **Black from 15 s to at least 100 s** (raw core frames), while the DMA runner shows stars at 40 s and MAME the title at 60 s |

Galaga (level select) and the Zero Fighter tape (attract screen) did not
regress. Sorcerian's DMA reads the FDC data port (`0FFB`, fixed) into
graphics RAM through I/O, at incrementing addresses from `7800`, 1 KiB per
block, paced by DRQ. This is unlike Zeliard's memory destination. Its
diagnosis is open.
These are bounded screen/audio observations, not gameplay or timing acceptance.


October 16 local `sharpx1_turbo_z_font` timing follow-up:
**build PASS, selected snapshot payload timing PASS, global timing FAIL,
hardware UNEXECUTED**. The font-only loader admits the measured 74-bit logical
synthesis inventory and retains the original exact 72-bit fitted/STA guard.
No RTL, existing shared SDC or other board assignment changes. Native
synthesis warning 330000 is removed, with the original 159-warning set retained.

Local Quartus 17.0.0 build 595, seed 1, completes in 14m08s / 171 stage warnings:
25,525 ALMs, 37,234 registers, 534/553 M10Ks, 32 DSPs/four PLLs. New RBF SHA
`c783fb3ee0c9e0a8ea424b32bb1fa2dc12a7d7aaae34994bab0aaf7a0071a720`.
The 429-input manifest SHA is
`1d02bc33d1437f687780c77f33f40ddd37c04efa11c365c56fbaa06d6fcb9912`.
Fitted SYS/VID remain 32/42.954545 MHz, not physical frequency measurements.
All eight selected timing corners pass: 1,152 exact rows, minimum setup/hold
+20.504/+0.498 ns, maximum data delay 12.876 ns; actual path relationships
remain 31.25 ns maximum / zero minimum. No analysis-only exception is added.

Main slow setup/recovery remain −15.149/−8.300 ns; hold/removal +0.194/+0.830 ns.
Across eight corners, reported global minimum hold/removal are +0.080/+0.333 ns,
but setup/hold I/O constraints remain incomplete and MTBF is not calculated.
No timing closure or hardware qualification. Effective-assignment/source/
report/preservation audits pass in `TIMING_FONT_20261016T2302/`; original and
corrected completed builds remain exact. See [the detailed gate](EXTERNAL_FONT_TIMING_STATUS.md).
MiSTer remains with the user and was not accessed. DMA and other revisions
retain their existing qualification status.

October 16 separate `sharpx1_turbo_z_font` base-text candidate:
**build PASS, slow-corner timing FAIL, bounded native hardware PASS**.
Local installed Quartus 17.0.0 build 595 completes map/fit/ASM/STA in 16m11s,
seed 1, 171 stage warnings; 25,228 ALMs, 37,234 registers, 534/553 M10Ks,
32 DSPs/four PLLs. RBF SHA
`4c0a95f2cc91c91df46eff8e3b22577b809fa6247725bd91294c3db1ce300a23`.
The 428-input manifest, generated build ID, reports and QPF/QSF effective
assignment audit pass in `output_files/BASE_TEXT_20261016T1524/build-audit.json`.
Unmodified original SDC, Slow 1100mV 100C: setup −15.031 ns, recovery
−8.167 ns, hold +0.251 ns; this flow does not execute fast-corner analysis
and reports incompletely constrained hold requirements. No timing closure.
Fitted SYS/VID remain 32/42.954545 MHz, not physically measured. Unmodified
base/Turbo arithmetic cold-repeats; base Main R/T reset and LIST/RUN pass
without warm upload/remount. Independent audit checks 21 raw mrext captures
and 245,760 exact pixels, remote payloads/Main/full font DDR. See
[the bounded implementation gate](BASE_TEXT_COMPATIBILITY_STATUS.md).
This changes neither the DMA revision nor other disabled board profiles.

Same-RBF native graphics follow-up: [bounded PSET/LINE](BASIC_NATIVE_GRAPHICS_STATUS.md)
passes five Main-R-boot hardware cases and 15 raw PNGs / 168,960 exact pixels,
including repeats, missing Enter and a one-pixel-wrong control. Independent
audit checks reference logical pixels and retained source/remote/Main/DDR
hashes. No FPGA input, timing constraint or enabled-device change; timing
still fails. Wider native graphics and SAVE/LOAD remain open.

October 15 Main OSD reset follow-up: [both menu commands](Z_FONT_OSD_RESET_STATUS.md)
now pass the bounded external-font hardware gate at 80/40 columns. Six cases
produce eighteen raw PNGs matching **3,840,000 exact control pixels**. Menu
navigation without Enter and two wrong-final-byte controls reject the unchanged
readback oracle. T Reset closes with F12 before R; R Reset-and-close needs no
extra F12. No warm load/upload/mount or keyboard reset chord is requested.
All 127 qualification inputs, 428 compiler inputs, RBF/Main and font DDR hashes
pass. This reuses fd9a0850; no new Quartus or simulation run. Physical owned
phase, stopped clocks, native fonts, wider modes/devices and timing closure
remain open. Earlier checkpoint statements retain their dated scope.

October 15 active-traffic reset follow-up: [owned simulation and Main reset controls](Z_FONT_ACTIVE_RESET_STATUS.md)
pass. Four simulation cases check 34,544 completed CPU reads and 2,688,000
control pixels, including an exactly cancelled pending read and one-commit owned
write drains with DDR/VID service stopped. Three actual MiSTer cases produce
nine PNGs matching **1,920,000 pixels** at 80/40 columns;
Main's keyboard chord recovers retained VRAM after the firmware traffic loop.
No-reset and wrong-final-byte controls reject the unchanged magenta oracle.
The exact physical owned phase is unobserved. RBF/compiler inputs are unchanged;
OSD-menu reset, native fonts, wider modes and timing closure remain open.
Earlier checkpoint statements below retain their dated scope.

October 15 retained-reset follow-up: [real F/R and reset/no-reset controls](Z_FONT_RETAINED_RESET_STATUS.md)
now qualify bounded post-HALT retained IPL/font/VRAM on fd9a0850. Three
simulation cases check 18,570 actual CPU reads; nine actual Main/mrext frames
match 1,920,000 control pixels. Main's keyboard reset chord plus R reaches a
post-readback magenta marker at both widths; R without reset and a wrong last
expected byte fail the unchanged warm oracle. No warm upload is requested;
all compiler inputs/RBF remain unchanged. OSD-menu, owned/stopped-clock reset,
native fonts, broader raster/device behavior and timing closure remain open.
Earlier checkpoint statements below retain their dated scope.

October 15 CPU-completion follow-up: a [new post-check visible marker](Z_FONT_CPU_COMPLETION_STATUS.md)
closes final CPU-readback observability for separate 80/40-column RBF-load
controls. Four simulation cases pass 184 traced reads/768,000 control pixels;
five actual MiSTer cases match 1,024,000 pixels, including two one-byte failing
IPLs rejected by the unchanged completion oracle. Source-bound fd9a0850 is
reused with all 428 compiler inputs unchanged; no new Quartus flow. Older
IPLs retain their original scope. Physical warm-reset causality, native fonts,
wider modes and timing closure remain open.

## October 15 malformed font upload recovery

Separate `sharpx1_turbo_z_font`: **full build PASS, timing FAIL, hardware
recovery PASS (bounded)**. The actual HPS decoder/ACK gate passes full,
oversized, short and gapped uploads/retry plus four exact rejecting controls.
All 39 frontend cases, five machine cases and wrapper lint pass. Ordinary
build/run/test is terminal zero with 164 PASS reports and unchanged executable.

Current RBF `fd9a085061a5fa5f6cc3c929a37f5b266d2391b5dd1b14752f3d8f794db83692`:
Quartus 17.0.2, seed 1, 17m34s/170 warnings; 25,384 ALMs, 37,244 registers,
534/553 M10Ks, 32 DSPs/four PLLs. Frozen 428-input source and remote QPF audits
pass; only the frontend differs from c6. Evidence and RBF are in
`output_files/X1ErrorDrain_20261015T145753Z/rebuild/`.
Original SDC slow setup −14.851 ns/recovery −8.257 ns, fast hold −0.098 ns
at measurement snapshot bit 4. Same-clock SYS/VID setup +8.258/+9.540 ns;
SYS/VID and VID/SYS bundles −10.952/−9.488 ns. No cuts added.
Actual MiSTer valid/oversized-retry/short-retry frames match 640,000 pixels
and full DDR hashes; Main handles the oversized-only case and subsequent load
without a Linux reboot. Physical error/readiness flags are not observed.
[HPS recovery scope](Z_FONT_HPS_UPLOAD_STATUS.md).

## October 15 external-font hardware repair

Separate `sharpx1_turbo_z_font`: **full build PASS, bounded hardware pixels
PASS, timing FAIL**. Initial `52be576d…` physically uploads all 256 KiB but
stalls Main at the terminal SPI ACK. Its disabled evidence is retained. The
frontend repair releases WAIT after the last backend command and separately
guards excess writes. Its 39-case gate includes the old-condition rejection;
the five-case machine CPU/pixel gate and wrapper lint also pass.

Current repaired RBF:
`c6a2ac021173a18fa1f45ac2ea0d9ed8b2a44db1979db1d18de549125afc3880`.
Quartus 17.0.2 full flow, seed 1, 16m14s, 170 warnings; 25,419 ALMs,
37,216 registers, **534/553 M10Ks**, 32 DSPs/four PLLs. All 428 captured
inputs match locally; the remote QPF rewrite is explicitly audited. No other
compiler source differs from the previous snapshot. Original-SDC slow setup
-14.956 ns/recovery -8.277 ns; fast hold -0.084 ns at measurement snapshot
bit 47. No new timing exceptions. Fitted SYS/VID are 32/42.954545 MHz,
not physically measured.

On user-authorized mister14, actual raw mrext captures match all **768,000**
pixels in 80/40-column cold and post-reset-request frames. Native Turbo IPL
also reaches Galaga/Mappy/Xevious titles with the synthetic full font loaded.
Retained-VRAM reset causality, native Kanji, wider native software, physical
signals/audio and timing remain open. See [hardware scope, RBF and evidence](TURBO_Z_EXTERNAL_HARDWARE_STATUS.md).

## October 14 current-source external-font board build

Separate `sharpx1_turbo_z_font` (not the DMA revision): **full build PASS,
timing FAIL, hardware feature UNEXECUTED**. Quartus 17.0.2 Build 602 Lite,
5CSEBA6U23I7, `sys_top`, seed 1. Final compile session `35333` is terminal zero
in `/tmp/x1-z-font-board-syksUXgN` after 24m52s / 170 warnings. Fit: 25,512 ALMs,
37,215 registers, 4,319,336 memory bits, **534/553 M10Ks**, 32 DSPs, 4 PLLs.
Current-source RBF SHA:
`52be576dd7cc74d6009f89bd7f280f47d43ee3cb92cc79d7efdf3a93f093771a`.
[RBF and evidence manifest](../output_files/z-font-20261014-52be576d/manifest.json).

Original-SDC slow 100C setup -14.978 ns / recovery -8.570 ns. Fast -40C hold
-0.045 ns in dimensions-to-SYS measurement bits 59/44. Same-clock SYS/VID setup
+5.548/+7.034 ns is positive, but HDMI data, cache payload bundles, measurement
snapshot and reset-release paths still require qualification. No new timing
exceptions/cuts. Video PLL fits at 945 MHz / 22 (42.954545 MHz), SYS 32 MHz;
not hardware frequency measurements. Source/post-QPF metadata and all 59
retrieved evidence files pass hash review; archive SHA `27dcd377…`.

Complete-machine five-case gate passes 280 actual CPU IN reads, 12,358 commits
and six exact frames / 1,152,000 pixels, including retained and changed-font
rebuilds, owned writer/CPU-read cancellations, upload rejection/retry and three
exact controls. Required ordinary regression and 12 exact generated base/Turbo/
X3 state files pass. Read-only mister14 memory inspection verifies the backing
range outside Linux RAM; active MacPPC7300 is preserved. No new core load,
reset, input or physical DDR test. Native font/broader-mode acceptance remains
open. See [current full status](TURBO_Z_EXTERNAL_MACHINE_STATUS.md).


## Earlier October 14 prototype (superseded by current build above)

The **prototype** `sharpx1_turbo_z_font` full Quartus 17 compile succeeds and
produces an RBF (not the DMA revision). Device 5CSEBA6U23I7, seed 1:
25,740 ALMs, 37,196 registers, 4,319,336 memory bits and **534/553 M10Ks**
(19 spare), 32 DSPs, 4 PLLs. Remote `/tmp/x1-z-font-board-RBcNDcMC`, session
`46389`, terminal zero, 22m37s, 170 flow warnings. RBF SHA-256:
`d454e3153e37ffbec210f09207e84fdda3123aaed51dd6eb60a5ec0ed43bbef5`.
This snapshot precedes the wrapper address guard and ordinary-state alias
repair. The corrected current-source compile in
`/tmp/x1-z-font-board-syksUXgN` (session `35333`) has since passed; the prototype
is not qualification of those repairs.

**Timing gate FAIL / hardware gate UNEXECUTED.** Original SDC, slow 100C:
worst setup -15.250 ns (HDMI data to X3 output), hold -3.469 ns (HDMI),
recovery -8.279 ns (consumer reset release). Reporting-only sidecar also checks
fast -40C. Same-clock SYS/VID setup minima are +7.909/+7.576 ns at slow 100C,
but SYS-to-VID held-cache payload/visible paths have no qualified bundle
constraints (-11.067 ns under the ordinary edge checks), and VID-to-SYS paths report -10.119 ns. These are observed path
classes, not exceptions or CDC acceptance. The fitted PLL is 945 MHz / 22,
approximately 42.954545 MHz; SYS remains 32 MHz. No false paths or clock-group
cuts were added. Native fonts and hardware captures remain open; no MiSTer
connection/load occurred.

All 58 retrieved prototype reports/RBF/clock/path/source-evidence files match
manifest hashes in local temporary `x1-z-font-board-_08vrlhp/evidence`.
Archive SHA `36156552c21baadd675f2da66edfc09db51dfbb3adcf86496b7d030351fa55e8`.
Post-build review verifies 427 inputs unchanged and explicitly checks only
Quartus's generated QPF date/revision metadata rewrite; generated build_id is
hashed separately. Full current scope is in
[external-font machine status](TURBO_Z_EXTERNAL_MACHINE_STATUS.md).


October 14 integration follow-up: the separate default-off
[external-font machine profile](TURBO_Z_EXTERNAL_MACHINE_STATUS.md) now connects
DDR, committed VRAM writes and renderer packets, with owned reset/upload drains
and retained-cache reconstruction. Complete-machine synthetic CPU/80/40-column
pixel gates pass, including CPU VRAM readback and changed-font replacement.
The corrected-source full Quartus build/RBF passes at 534 M10Ks / 25,512 ALMs.
Timing fails and physical feature acceptance remains open.
Native font conversion, broader text policies and physical acceptance stay open.
Earlier standalone-only scope statements below describe those checkpoints.


## October 14 standalone font-cache resource gate

Current cache follow-up: [committed-half qualification](TURBO_Z_CACHE_HALF_STATUS.md)
records the source `e9671fb7…` RAM-inference repair and both source-bound
Quartus 17.0.2 map/fit results: descriptor bit 22 uses 138 M10Ks/3,715 ALMs/
4,314 registers; caller-half mode uses 138 M10Ks/3,717 ALMs/4,327 registers.
Sixty current-source component/CPU cases pass. These are isolated virtual-pin
component fits, with warnings retained; no main-project STA, combined fit,
board RBF or hardware result is added. The initial fit below remains historical.
The later [cached VRAM writer](TURBO_Z_VRAM_WRITE_STATUS.md) passes eighteen
connected CPU/VRAM/cache cases outside all board revisions. No Quartus build
has run for its known-mask/VRAM/cache combination; neither earlier cache fit
establishes its combined area, timing or physical CDC. No new MiSTer result.
The subsequent [cache-renderer adapter](TURBO_Z_CACHE_RENDER_STATUS.md)
passes eighteen unit/connected cases and ten actual CRTC/RGB frames in a
separate simulation fixture. No Quartus build runs for this combination and
no board revision, timing result, RBF or hardware evidence changes.

The separate [full-glyph cache/publication component](TURBO_Z_CACHE_STATUS.md)
completes a source-bound Quartus 17.0.2 standalone fit on `misterubuntu`:
138 M10Ks, 3,720 ALMs and 4,318 registers. This is a virtual-pin component
probe, outside the machine manifest and all board revisions. No main-project
flow, STA/CDC closure, board RBF or MiSTer deployment is performed for it.
The existing DMA revision and hardware-qualified RBF are unchanged. Cache
integration, source-bound board fitting/timing and physical gates remain open.
Subsequent standalone [font service/lifecycle components](TURBO_Z_FONT_SERVICE_STATUS.md)
pass 35 strict simulation/fault runs with the unchanged cache/frontend/backend.
They have no new combined fit, board RBF, timing/CDC or hardware result; every
board profile remains unchanged.
The subsequent [real-CPU service boundary](TURBO_Z_CPU_SERVICE_STATUS.md)
passes its connected component fixture only. It adds no board fit, timing/CDC,
RBF or hardware result and does not alter the qualified DMA revision.

## October 10 current-source build gate

Latest follow-up: the frozen `aa05dd2f7bbedc2491f2de9eeb72624002dd3e4a`
handoff revision starts on the idle host at 10:35:07 UTC and finishes at
10:43:50 UTC, **exit 3**. Synthesis, fitting and assembly finish; the agent's
terminal report records 20,596 ALMs, 34,009 registers and 393 RAM blocks.
Final STA refuses `completed_generation~DUPLICATE` as an unreviewed source
replica before loading the held/inactive constraints. The partial setup/hold
numbers (-21.246/-15.799 ns) are therefore **not** a completed constrained
audit. No timing guard is broadened and no hardware deployment is performed.
The unaccepted RBF SHA-256 is
`7461c9454ace92c6708c5a4f7fe779805a8493e4df5ac6fe10ed3441f308ff09`.
Frozen source root is
`output_files/quartus-linux-I30pZ0zU/source` on the build host; input-manifest
SHA-256 is
`f4d50a76350604f5ce2aa33814486b5d0acfbfd08c0ba4abc2c1fab441245fc1`.
The agent reports all 410 checkout inputs match that manifest, with only
generated QPF rewriting in the snapshot. Reporting-only fitted replica
inspection and independent artifact review remain follow-up gates; this build
does not contain the subsequent experimental wide-D88 changes.

The latest guarded idle-host check permits a fresh Quartus 17.0.2 full flow
at 08:02:29 UTC, source `3c6242e771446dc11843cc8f4b7d4c58430b8f17`.
This is the separate `sharpx1_turbo_z_handoff` revision, **not** a rebuild or
new qualification of the DMA single-clock revision below. Frozen remote root:
`/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-VlAoOluh/source`;
input-manifest SHA-256:
`5643c4693d104110957118b0b62b93ccb13fcd1b836d7434a61bec9a5a841219`.
Launcher PID 1836585/session 39592 and live synthesis/fitting were observed;
local log `/tmp/x1-quartus-3c6242e-handoff-local.XhSvnjgI`. The full flow now
terminates **exit 3** at 08:15:43 UTC: final STA rejects an unreviewed
whole-prefetch D/ASDATA profile. Fitting precedes this failure; the guard is
not loosened and there is no full-flow timing or hardware acceptance.
The terminal source/artifact audit completes: all 408 checkout inputs match
the frozen manifest; only generated QPF metadata/revision differ in the build
snapshot. Direct fitted-summary readback confirms 20,605 ALMs and 393 RAM
blocks. The unaccepted RBF SHA-256 is
`7f6a2009cbebe2caa34fec785bd39a19da0ba58e4f970f2ca80b9f0384d5a993`.
Partial STA setup/hold is -10.317/-2.636 ns, not a completed constrained audit.
Native fitted-profile discovery remains pending because other actual fitters
occupy the host; no guard is broadened or failed artifact deployed.
The C++ RTC/X3/Kanji profile
does not enable those devices in this board revision. Older outputs and
other cores/media are preserved; no MiSTer is loaded or reset.

## Earlier DMA source-bound qualification

October 8, 2026. `sharpx1_turbo_dma_single` is a separate opt-in FPGA revision,
inheriting `sharpx1_turbo_single` and enabling the existing shared-machine DMA,
completion IRQ and EOB-only restart IRQ. SYS/video use the checked-in actual
28,571,428 Hz PLL output and enables. Existing revisions remain DMA-disabled.
This is not full DMA, native Turbo firmware or Turbo Z support.

The wrapper passes the three capability parameters together under
`X1_TURBO_DMA_RESTART`. Invalid combinations without single-clock Turbo
foundation, or with X3 video, are rejected. No framework, clock constraints,
private assets, device engine, reset drain or interrupt bridge are changed.
The Linux and Apple-container build helpers accept this revision explicitly.

Both baseline and DMA-profile wrapper lint pass (Verilator 5.044); inherited
framework warnings remain, log `/tmp/x1-dma-board-wrapper-lint.log`. Shell
syntax checks pass. The native Quartus 17.0.2 full flow completed from frozen
commit `818b0de28e6a3331e3894fd0313369bad618e534`, in build-host directory
`output_files/quartus-linux-mlCE5xen/`. Input-manifest SHA-256 is
`0ea6cc295cca21472203cb1a08cf8e56ebd66c8d3fc4dfd3ec68700c7ba00d99`.
Build started 00:23:55 UTC October 9 and finished 00:31:08 UTC, exit zero,
123 warnings. Fit uses 20,947 ALMs (50%), 394 RAM blocks (71%), 3,143,582
memory bits. Its hierarchy report retains the DMA engine/service, IRQ bridge
and reset guard. Quartus warns that reset-guard `pending` powers
up high despite the RTL initializer (`18061`/`18010`). Do not suppress this or
claim cold-start equivalence from the RTL initializer; physical startup/reset
must be qualified. Inherited framework mode-array/CDC warnings remain too.

The shared-machine clock-matched simulator previously passed six memory and
twelve A/B FDC restart cases; see [exact scope](DMA_RESTART_MACHINE_STATUS.md).
That is not fitted or hardware evidence. The dedicated wrapper lint target
uses the same PLL interface stand-in as the other wrapper checks.

```sh
make -C verilator lint-wrapper-turbo-dma
ssh misterubuntu 'cd /home/alans/mister/SharpX1_Mister && QUARTUS_REVISION=sharpx1_turbo_dma_single bash scripts/build_quartus_linux.sh --check'
# Only after checking for competing Quartus jobs:
ssh misterubuntu 'cd /home/alans/mister/SharpX1_Mister && QUARTUS_REVISION=sharpx1_turbo_dma_single bash scripts/build_quartus_linux.sh --build'
```

The candidate is locally available at
[sharpx1_turbo_dma_single.rbf](../output_files/quartus-linux-mlCE5xen/sharpx1_turbo_dma_single.rbf),
SHA-256 `c1d83e6bc7218a5736d3c8cf4505cc3eb69d4c75c4ca958a5106f3c698bc8ca3`.
Supplemental all-corner STA and path reports each exit zero, with RBF hash
unchanged. Every local input matches the original 359-file manifest.
Post-build snapshot verification intentionally reports a mismatch for
`sharpx1.qpf`: Quartus added notices/date and the requested revision, preserving
the original revision. All other 358 inputs, including RTL/QSF/SDC/assets,
match. The failed checksum command remains recorded, not rewritten as a pass.
Generated QPF SHA-256 is
`c7c997185f5007e626d8fa70fa8ebac07a56b6f622f43194e262f37a2adac4a5`.

| All eight models, constrained checks | Worst slack (ns) |
|---|---:|
| Setup | 0.649 |
| Hold | 0.052 |
| Recovery | 4.153 |
| Removal | 0.434 |
| Minimum pulse width | 1.122 |

Zero unconstrained clocks, but 3 input ports / 7 input paths and 44 output
ports / 50 output paths remain unconstrained. No global clock cuts or timing
constraint changes were made. Inherited CDC/PLL/external-I/O and physical
qualification are not closed by these positive numbers. Original STA reports
are preserved before supplemental analysis. Local ignored reports/logs are
under `output_files/quartus-linux-mlCE5xen/`.

Actual CPU-driven hardware diagnostics need visible RGB success/failure markers: the existing
RAM-completion-only simulation fixtures do not prove hardware success from a
black screen. Protected disposable A/B media, restart/RETI, native boot/input,
owned/pending-SD reset and broader video/audio must be tested separately.
Do not contact or use reserved mister192. The recommended previously qualified
experimental RBF remains `quartus-linux-ZOMREvtv/sharpx1_turbo_single.rbf`.

## Visible CPU diagnostics

`test_dma_visible_ipl.py` now emits eighteen original, 32 KiB IPLs based on
the existing memory/A/B restart programs. A real CPU prologue programs PPI,
40-column CRTC and palette/VRAM. Pending/failure stays red; green is published
only after the original buffered-address/payload/guard/status and three-handler
assertions. GRAM power-up data cannot affect the uniform palette marker.
No machine debug writes, forced IRQ/grants or private assets are used.
The six default memory and twelve default FDC fixture byte streams are unchanged.

All eighteen pass the board-matched 28,571,428 Hz fast runner
`3058ff48dce8da0527ffc8afe7a21b47c584a0871c473f5b3c121ee673e67004`:
exact CPU completion/counts, unchanged generated disk images and 1,152,000
green pixels. The completion-only control stays red with zero pairs. The
earlier isolated first-destination-buffer bug control produces CPU `EE` after
eight pairs and all 64,000 red pixels; production RTL is untouched.
Outputs: ignored `output_files/dma-visible-818b0de/`; logs
`/tmp/x1-dma-visible-ipl.log`, `/tmp/x1-dma-visible-bug-negative.log`.
The separate SYS32/video28,571,428 Hz delay-aware visible matrix also completes
all eighteen cases, checking another 1,152,000 green pixels and the same CPU
counts/guards/status/unchanged disks. Its frozen executable SHA-256 is
`a8601ef7abbdee9871fd706a426a060e819966420d85f16e5bd48bbbc036d287`;
outputs `output_files/dma-visible-timing-818b0de/`, log
`/tmp/x1-dma-visible-ipl-timing.log`. This is independent-clock simulation,
not board-frequency delay-aware or physical acceptance.

```sh
make -C verilator test-machine-dma-restart-visible
```

`scripts/mister_dma_matrix.py` stages unique MGLs/configs, verifies RBF/IPL/disk
hashes, accepts only mister126/mister14 and defaults to no core loading.
`--execute` loads each test and records actual PNGs, requiring exact 320×200
green pixels and unchanged disposable disks. It refuses incomplete local
fixture qualification. The hardware matrix completed on released
mister126 in `/media/fat/_Computer/X1DMA_20261009T003346Z/`, with local evidence
under ignored `output_files/X1DMA_20261009T003346Z/`. All eighteen cases pass:
six memory and twelve A/B sector-boundary restart programs, all three bus modes
and both programmed transfer directions. Each captured PNG is exactly 320×200
green; all 1,152,000 captured pixels match. Disposable generated A/B image hashes
remain unchanged after every case. Log `/tmp/x1-dma-hardware-matrix.log`.

The actual CPU program verifies payload/buffer isolation/guards, DMA/FDC status,
live-counter readback and three genuine IM2 handlers followed by RETI before
publishing green. Hardware grant/pair counts and exact bus/IRQ pin timing were
not independently instrumented: those quantities remain simulation evidence.
These are cold MGL/core/IPL loads, not power-cycle/physical-keyboard, concurrent
interrupt, OSD-reset/owned-SD drain, writable-media or native Turbo acceptance.
The recommended general native-game test RBF remains the DMA-disabled artifact;
this is a separately qualified bounded DMA diagnostic candidate.

The same first memory IPL also runs on the earlier DMA-disabled RBF
`a0a03761…` as an independent hardware negative. Its captured 320×200 PNG is
exactly red, not success; generated disks stay unchanged. Evidence:
`output_files/X1DMA_20261009T004022Z/`, log
`/tmp/x1-dma-hardware-disabled.log`. This does not measure hardware pair counts
or identify every possible red-screen cause. `--disabled-control` runs only
that case and explicitly expects red; the normal matrix still requires green.

The native matrix helper now accepts explicit RBF path/hash and an optional
single-title selector; its earlier defaults and observation-only verdict stay
unchanged. A protected CROSS Chase trial on the DMA candidate completes:
native title at 30 seconds, then keyboard input reaches "Press key" and a
populated playfield. Actual PNGs were inspected, not inferred from filenames.
Evidence `output_files/X1Matrix_20261009T004105Z/`, log
`/tmp/x1-dma-native-cross-hardware.log`; copied disk/ROM hashes stay unchanged.
This is native boot/input progression, not exact movement, game music, long
compatibility, physical keyboard or native Turbo firmware acceptance. No five
commercial games are newly qualified by this single homebrew trial.
## October 10 fitted-profile follow-up

The subsequent source repairs remove the raw-reset bypass into palette
selection D inputs and add an opt-in two-stage HDMI measurement synchronizer.
Their local tests pass; see `HDMI_MEASUREMENT_CDC_STATUS.md`. These do not
alter the completed fifth-fit audit or qualify this DMA revision/new RBF.
The fresh source-bound `aa05dd2` handoff build's initial 10:30:32-UTC check
finds active DSPPC604 shell/fitter PIDs 2001830/2002631. No flow is launched
or competitor disturbed at that check; native follow-up remains pending.

The separately fitted `3c6242e` Z-handoff full flow's fifth physical HDMI
profile now passes native reporting-only discovery and independent original
artifact/source preservation auditing. The experimental guard recognizes
only that complete observed pattern; five scoped positives, 100 invalid
scope controls and 16,379 mixed-pattern rejections pass locally. See
[exact evidence and remaining gates](HDMI_MODE_STATUS.md#fifth-fitted-profile-discovery-and-guarded-scope-complete).
This does not qualify the DMA board or a new RBF: same-fit preservation,
full-flow constrained timing and hardware remain open. No MiSTer is loaded.

The new `--fit-3c6242e` auditor separately binds all eleven original/staged
hashes and the exact pin profile. Its synthetic 384-report/preservation and
36 provenance/actual-source rejecting checks pass alongside historical gates.
The native same-fit attempt at 09:33:45 UTC is not launched because another
project's actual synthesis is active; no native result comes from that attempt.

The subsequent idle-host same-fit run finishes at 10:06:42 UTC, zero errors/
warnings. Independent exact-source/artifact auditing passes 384 reports,
928 held-budget and 6,624 active/raw/mode rows unchanged; 848 inactive rows
remain excluded, not passed. Global setup **still fails at -9.659 ns**
(hold +0.010 ns). See the native fifth-profile evidence in
`HDMI_MODE_STATUS.md`. This does not qualify this DMA board, a fresh full
flow or any new RBF. Original artifacts are preserved; no MiSTer is loaded.

The exact `9cc1141` fit's reporting-only whole-bank inventory subsequently
finishes on the idle host at 16:19:39–16:19:43 UTC, exit zero, no errors/warnings.
It uses an isolated fitted database and no SDC, not a compile or timing pass.
Local evidence: `/tmp/x1-9cc-prefetch-inventory-N9cG4eJw/`; raw log SHA-256
`4c7f6fbd6d356f18fe57c0e242b683b33fafd28ef0e54ac171f98857fb015942`.
Main independently checks the terminal record and exact before/after manifests:
415 source inputs, five artifacts and 511 original database files are unchanged.

The whole prefetch bank has 24 keepers, 72 pins and 24 canonical registered
drivers. Its complete observed input vector is:

- ASDATA: `hs`, `vs`, `de`, data bits 0/1/5/7/12/16/17/19/23.
- D: data bits 2/3/6/9/10/11/13/14/15/18/21/22.
- Physical prefetch keepers absent: data bits 4/8/20; output aliases remain
  4←0, 8←12, 20←16.

The output bank has 27 keepers/133 pins/85 driver records; no target replicas
appear. This vector differs from the six allowed profiles and is not permission
to mix arbitrary per-bit alternatives. The exact seventh-bank proposal now
passes all seven complete profile vectors, 140 fault checks and all 1,048,569
mixed-profile rejections before any cut. Original Tcl session exits zero;
log `/tmp/x1-hdmi-inactive-data-seven-profile.log`, SHA-256
`a285e6d53adadf922c893cafd7bed52d353ac59db1aef393365377a3152452e2`.
Candidate `b80a0946ca3b310f8e87254f587c26d9414292df24ddf247fd283cc1ab2dd6ad`
and fixture `2cc95faf7eb8d585abee11b27e08e27063cce9c4c4462c3f6e3fc69abaf70064`
remain unchanged afterward. The log creation-to-final-write span is 3,563
seconds, not a separately timed process measurement. No cases are removed.

The exact eleven-file/384-report context auditor passes synthetic preservation
and rejecting controls, but that is not native TimeQuest acceptance. Native
same-fit launch is deferred at 17:33:10 UTC because PID 2352689 is fitting
SunSparcStation20; no competing job is launched. The prepared isolated study
rejects escaping/database symlinks and preserves originals. Same-fit path
preservation remains next. Strict production constraints are unchanged;
complete constrained timing, a fresh full flow and hardware acceptance remain
open. The assembled `9cc1141` RBF is still unaccepted and not deployed.
