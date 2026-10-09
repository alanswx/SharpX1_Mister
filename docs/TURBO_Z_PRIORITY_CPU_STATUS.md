# Turbo Z CPU priority register and ordering increment

October 9, 2026. Original GPLv2-only components, opt-in and not a completed
priority renderer. The [primary table/remaining composition contract](TURBO_Z_PRIORITY_CONTRACT.md)
is the ordering source; no emulator implementation was copied.

## Connected CPU behavior

`TURBO_Z_TEXT_CPU=1` now also connects exact `1FC0` access through
`rtl/x1_z_priority_register.sv`. Its existing `turbo-z-text-cpu` target is
non-savable, delay-aware, asserts enabled, SYS 32 MHz / VID 28,571,428 Hz.
Ordinary profiles and all board revisions leave this capability off.

The experiment stores all eight written bits, gates access to modes `80h/90h`,
excludes DAM writes/reads and retains a completed IN through the Z80's late
sampling tail. Reset clears register/response state and disarms an already
asserted OUT until idle. Inactive reads return `FF` and writes are ignored.
**Reset-to-zero, unused-bit storage/readback and inactive-AEN behavior remain
provisional**; reference emulators disagree about inactive access and the
manual does not supply these electrical/reset values. Undefined ordering
does not prevent CPU storage/readback of the corresponding byte.

The control output now occupies bits 31:24 of the existing held multi-mode
video-control snapshot; mode/SCRN/blackclip/width retain bits 23:0. The
renderer does not yet consume priority. This is real CPU register acceptance, not an enabled
priority display, a native Z identity or an RBF capability.

## Ordering decoder

`rtl/x1_z_layer_order.sv` implements the documented combined field:
`00` text above graphics, `01` graphics above text, `10` text between front
and back screens, `11` undefined. Bank priority is bit 3 when simultaneous
display (bit 4) is enabled in two-screen mode. Otherwise bit 1 is effectively
zero and the ordinary selected screen is used; the unselected graphics bank
cannot leak into output. Unused bits do not alter order.

The decoder selects backdrop/text/bank0/bank1 from **caller-supplied
visibility**, not from palette RGB or a chosen zero-index transparency rule.
It is separately tested and not yet instantiated in the machine. It rejects
undefined paired ordering instead of inventing a fallback. Native opacity,
blackclip, analog text significance and the reduced palette-bank policy
must be resolved and connected separately.

## Executed qualification

```sh
make -C verilator test-z-layer-order test-z-priority-register
make -C verilator test-machine-z-priority-cpu test-machine-z-text-cpu
```

All terminal checks exit zero:

- 16,384 ordering combinations: all 256 controls, single/two-screen mode,
  selected bank, active/inactive and all eight visibility combinations.
  An unchanged ordered-list oracle rejects the deliberate `10 -> 00`
  text-on-top substitution. Log `/tmp/x1-z-priority-final-units.log`.
- Register unit profiles at held-OUT lengths 1/4/7: all 256 byte values,
  poisoned held address/data, every single-bit address alias, late IN,
  inactive re-enable/contradictory strobes and raw short reset pulses.
- Five actual-Z80 controls: `80h/90h`, each cold and warm reset, plus the
  unchanged disabled-profile negative. Each positive checks all 256 values,
  `1FBF` text-palette isolation, adjacent-port exclusion, AEN and DAM. Warm
  reset at 100 ms for 10 us verifies reset readback and real reprogramming
  from the bus trace. Each invocation lasts 125 ms.
- The five existing text-palette CPU controls still pass on the same runner,
  including retained warm palette RAM without refill.

CPU log: `/tmp/x1-z-priority-cpu-matrix.log`. Frozen copies:
`verilator/obj_dir_v13_z_text_cpu/priority-matrix-Z84WKu/` and
`cpu-matrix-8Y6M5n/` (ignored). Runner SHA-256:
`98847a54a86a8065e1c1fc0e189eb8da9be1e81bfec2867bc1961569dbe489fb`.
Priority fixture SHA-256, mode `80h`:
`6c665788566014e2d22f3186506f44cc91aae4d9f0b5a67ac84a7a3bd184e26d`;
mode `90h`: `17f2e3bdd453445e9ecd507ecf6e33ef59d51c7275a2a4706ad0b127c9178182`.
No private assets or boot/rendered-game claims are involved.

Ordering/register unit executable hashes:
`e2a6635aeffa5efbb6062c58c651ea72ceddca0a898414efb9d9df1727d47bbd` /
`c11f82864395cf26aae383e07659287376e6efca939dee31bc84cfda479b90b6`.
Ordinary/X3/DMA wrapper lint passes with inherited warnings and a PLL stand-in,
log `/tmp/x1-z-priority-register-wrapper.log`. Current default timing,
graphics-bus and DAM CPU checks pass on runner
`b8a661fadec7aff8479e0f2032d9fc9764ffd956d325328b24c620c5e91df893`.
These are focused checks, not a new full baseline or fitted timing result.
The preceding paired-fetch checkpoint's four full-color actual-CPU cases
also finish successfully; their runner disables this CPU capability. See
the separate [source-bound record](TURBO_Z_PRIORITY_CONTRACT.md#executed-paired-screen-fetchshifter-increment).

Hosted CI now includes these targets and explicitly installs ripgrep for
negative-log validation. Its source-bound hosted result remains pending.
Complete dual-screen palette lookup/composition, actual
glyph/opacity/blackclip, native Z software and Quartus/physical gates before
checking off Z3/Z4 or the user's broader work groups.

## Connected control crossing follow-up

`make -C verilator test-machine-z-priority-cdc` executes an original synthetic
IPL through the real shared CPU with X3, palette/video/multi-mode and text CPU
options enabled. All 256 priority bytes must appear in the actual video-domain
payload alongside mode `90h`, bank/blackclip zero and 40-column width. The same
sweep must pass after warm reset without an asset reload. SYS is 32 MHz;
video half-periods 17,500 / 11,640 / 25,000 ps cover ordinary, nominal X3 and
slower independent clocks. These are half-period fixtures, not exact fitted
PLL frequencies.

The fixture physically stops SYS and VID separately, checks settled destination
and held-source stability, then resets with VID stopped and verifies coherent
reset controls after restart. The first expectation incorrectly assumed PPI
width reset to zero; actual retained width is one. Only that oracle expectation
was corrected; no PPI behavior was changed. The initial failure remains in
`/tmp/x1-z-priority-machine-cdc.log`. The subsequent positive three-profile
matrix and generic CDC/order/register gates exit zero in
`/tmp/x1-z-priority-machine-cdc-final.log`.

No new public ports or default-board capabilities were added. The existing
text CPU experiment remains non-savable; ordinary snapshot v13 is unchanged.
Unused priority bits can still optimize away in hardware until a renderer
consumes them. This test does not verify physical CDC placement, live
composition, native reset/readback or opacity.

The final three-profile sweep and disabled-priority negative also pass in
`/tmp/x1-z-priority-cdc-negative-wrapper.log`; its subsequent wrapper command
used a nonexistent DMA target and exited two. The corrected ordinary/X3/DMA
wrapper lint invocation exits zero in `/tmp/x1-z-priority-cdc-wrapper-final.log`,
with inherited warnings and a PLL interface stand-in, not Quartus validation.
The negative uses the unchanged CPU and crossing oracle with text/priority CPU
disabled and must fail specifically at the incomplete-sweep assertion, not
merely with any nonzero exit. Final positive executable SHA-256:
`a79c7a7c9adefe6d8ee3912ae1aa26f427178e1769c2156c2bae995b92ba0d3a`.
After declaring the fixture's intentionally unused output connections explicitly,
the final positive/negative matrix exits zero again in
`/tmp/x1-z-priority-cdc-final-clean.log`; the hash above binds that final build.
Each positive invocation executes approximately 57 ms. CI now selects this
connected crossing target; its hosted result is not yet verified.
