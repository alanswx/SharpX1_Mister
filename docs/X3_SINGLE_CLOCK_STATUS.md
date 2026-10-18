# Single-clock X3 master

October 18, 2026. User decision: move X3 revisions from two unrelated clocks
(32 MHz SYS + 42.954545 MHz VID) to one X3 master with clock enables, rather
than constraining each SYS/VID handshake. Opt-in; every existing revision and
simulation profile keeps its clocks.

## Why

The two-clock external-font fit (`quartus-linux-dNZEiKaH`, commit `3adb2d3`)
fails ~26,370 setup paths per slow corner. At slow 100 °C, 25,693 are
SYS→VID transfers inside the machine (25,334 in the Kanji cache publication),
plus PCG, CRTC-write and display handshakes. A further ~630 are framework
crossings that stock MiSTer never times: the separate X3 PLL is not in
`sys_top.sdc`'s core-PLL clock group. Inventory and grouping:
`output_files/TIMING_FONT_SCALER_20261017T1403Z/global-before/` and
`global-classification.json` (ignored outputs).

The same fit's worst same-clock paths need at most 22.1 ns (MR16 ROM→work
RAM, +8.552 ns at 31.25 ns) and VID→VID already meets 23.28 ns with +9.0 ns.
An X3 master therefore leaves roughly +0.6 ns on the worst former-SYS path
before refitting. That is an estimate, not a fitted result.

## Design

- `X1_SINGLE_CLOCK` with `X1_TURBO_VIDEO_MASTER` ties `clk_sys` to the X3
  PLL. `MASTER_HZ` is the nominal 42,954,540 Hz (divisible by four for the
  accumulators); the fitted PLL is 42,954,545.45 Hz, a 0.13 ppm difference.
- Z80, PSG, FM, FDC and cassette already use rate-parameterised enables
  (`x1_clock_enables`: CPU spacing 10/11, PSG 21/22 master edges).
- MR16 (`mr16_x1.v`): above 32 MHz, a 32-MHz-average `rate_ce` gates the core
  enable, interrupt vector capture, IN-acknowledge pulses and ACK outputs.
  Read responses are always retained between enables (the existing
  `RETAIN_RESPONSE` path). The firmware timer advances zero or one virtual
  32-MHz tick per edge. At or below 32 MHz `rate_ce` is constant one, so
  existing profiles are unchanged. This removes the 28.6 MHz single-clock
  profile's ~10.5% slower MR16 instruction rate rather than inheriting it.
- Former SYS/VID handshakes (PCG, CRTC, palette, Kanji cache, snapshots)
  remain in place and now run on one clock; they are timed same-clock paths.
- Guards: one clock may drive X3 only at exactly 42,954,540 Hz. Z video and Z
  Kanji now accept that master. Fixed FDC timing and DMA restart keep their
  existing clock requirements.

## Board revision

`sharpx1_turbo_z_font_single` = turbo-video + `X1_SINGLE_CLOCK` + external
font + local scaler reset release. Its only revision SDC is
`scripts/constraints/x3_single_clock_groups.sdc`, which gives the X3 master
exactly the framework separation stock MiSTer gives `CLK_VIDEO` (HDMI,
audio, SPI, I2C, HPS, 50-MHz clocks). It refuses unless exactly one X3 clock
exists. The two-clock font SDCs are not used: their 31.25 ns payload bound
would loosen a now same-clock path, and no raw reset-pin cut is selected.
The two-clock `sharpx1_turbo_z_font` revision is unchanged.

## Simulation

`make -C verilator test-x3-single` builds `turbo-x3-single` (delay-aware,
non-savable, `obj_dir_v12_x3_single`) and runs:

| Check | Result |
| --- | --- |
| MR16 timer golden model at 42,954,540 Hz (plus 28.6/28.57/32 MHz) | PASS |
| Fractional enables at 42,954,540 Hz: 10/11 and 21/22 spacing, bounded error, reset repeatability | PASS |
| `test_single_clock.py --hz 42954540` (physical duration, CPU rate, determinism, FST, wrong-clock rejection) | PASS |
| `test_keyboard_poll.py`: F/Space/Enter, cold/steady Caps/Shift while the CPU polls E4/E6 | PASS |
| `test_subcpu.py`: native MR16 firmware E7/E8, PPI TX/RX, PS/2 make → ASCII | PASS |
| `test_dual_disk.py`: distinct A/B sectors, retained heads/registers, RNF, isolated writes/protection, B-only mount, unchanged originals, cold repeats | PASS |

These are digital simulation results at the nominal master. They do not
establish native game boot, Kanji/font pixels, fitted timing or hardware.

Existing-profile regressions after the MR16 change all pass: the MR16 RTC
driver at CE 1/2/3/17/32 (with its unretained negative), the 12 retained-
response reset cases (negative still rejected) and the 28.57 MHz
`test-board-single` matrix.

External-font machine (`test_z_external_font_machine.py --single-x3`): all
five frozen cases pass, with exact 80/40-column frames, CPU traces and the
three fault controls rejected at their markers. Single-X3 mode runs one
free-running clock, so three stopped-VID-only terms (`upload_wait` held while
VID is stopped; CPU held after release with VID stopped) are not asserted,
and the CPU-read cancel phase uses an IPL START: on one clock a font START is
acknowledged at once and would really begin an empty upload. Stopped-video
behaviour is therefore not covered in this mode. The two-clock mode is
unchanged and passes all five cases on the final testbench.

## Quartus and timing (October 18)

Source-bound build `quartus-linux-qVRrLqJI` from clean commit `97bf6d2`,
Quartus 17.0.2, exit 0. RBF SHA-256
`242e0beac4d4496ea3ddd7c9f95ac2783ab0d6e4aaa88387dab9a65fdb7db820`.
65% ALMs (27,097), 37,881 registers, 76% block-memory bits. The X3 PLL is
reported at 42.95 MHz (23.280 ns).

The eight-corner inventory (slow/fast × −40/0/85/100 °C; setup, hold,
recovery, removal) reports **zero failing paths in all 32 reports**. The
two-clock font revision had ~26,370 setup, 4 hold and 2 recovery failures
per slow corner. TimeQuest summary minima: X3 master setup +3.574, hold
+0.251, recovery +6.882, removal +0.690 ns; HDMI setup +0.579 ns. Zero
unconstrained clocks; 3 input and 44 output ports remain unconstrained, as
in the earlier single revision. This is digital STA, not I/O or physical
signoff. Evidence: `output_files/X3_SINGLE_FONT_20261018/` (ignored).

## MiSTer 192 (user-authorized, October 18)

Deployed under new names `/media/fat/_Computer/X1X3S_20261018/` and
read-only media in `/media/fat/games/SharpX1/HWTest/X1X3S_20261018/`; all
hashes verified on the device. Raw screenshots came from mrext
`raw_screenshot`, and pixel comparisons used `scripts/compare_video_png.py`
(no scaling, cropping or tolerance).

| Case | Result |
| --- | --- |
| October 15 diagnostic IPL, 80 columns + synthetic physical font | 256,000/256,000 pixels match `diagnostic-80-expected.ppm` |
| Diagnostic IPL, 40 columns | 128,000/128,000 pixels match `diagnostic-40-expected.ppm` |
| Native Turbo IPL + ANK16 + synthetic font + Galaga D88 (`d0cdeb82…`) | Title screen; Space → level select; Space → Stage 1 |

Assets: synthetic font `d18c7cb9…`, diagnostic IPLs `b1e6bdc7…`/`792d8520…`,
native Turbo IPL `21289570…`, ANK16 `e356dd19…`. The font is synthetic, not
native Kanji. This is a bounded boot/pixel/input check, not gameplay,
audio, write, reset-retention or long-run acceptance. Six screenshots remain
in 192's `/media/fat/screenshots/SharpX1/`; 192 was returned to MENU.
