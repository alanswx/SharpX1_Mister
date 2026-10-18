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

Existing-profile regressions after the MR16 change (unchanged `rate_ce=1`
path): recorded in the handoff once complete. The board revision's Quartus
fit, eight-corner timing and MiSTer boot remain open.
