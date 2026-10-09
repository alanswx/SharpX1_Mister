# Reduced-format video experiment

`TURBO_Z_MULTIMODE=1` is a **separate opt-in extension** requiring the existing
Z video/CPU-palette and X3 profiles. Ordinary video experiments and board
defaults remain unchanged. It compiles with Verilator 5.044, delay-aware,
assertions enabled. No new RBF or combined Quartus/hardware signoff exists.

```sh
make -C verilator turbo-z-multimode
make -C verilator test-z-graphics
make -C verilator test-machine-z-multimode
cd verilator
python3 tests/test_machine_z_video.py ./obj_dir_v13_z_multimode/Vtop \
  --mode wide64 --custom --warm --output obj_dir_v13_z_multimode/NEW_DIRECTORY
```

## Implemented experimental paths

| Controls / mode | Fetch and raster policy | Output / open gate |
|---|---|---|
| AEN `80h`, low scan, 40 columns | Four bank/+400h sources | Existing 320x200/4096 |
| AEN+C64 `90h`, low scan, 40 columns | Two sources from selected SCRN display bank | Selected 320x200/64 screen; simultaneous two-screen priority not implemented |
| AEN `80h`, low scan, 80 columns | One source from each bank, contiguous 80-byte rows | 640x200/64 |
| AEN `80h`, high scan / SCRN `01`, 40 columns | Two sources from alternating raster banks, 16-raster rows | 320x400/64 |
| High scan, 80 columns | Not admitted by ordinary multi-mode profile | Separate [internal8 extension](TURBO_Z_INTERNAL8_STATUS.md) connects 640x400/8 |

Unsupported controls fall back to digital video; this is not a general native
ASIC register decoder. Expansion/underline/blackclip remain excluded.
Palette programming currently uses the qualified full/40-column CPU sequence
before switching display modes. **Reduced-mode CPU bank/read/write behavior
is not implemented or qualified** by that procedure.

The book's printed 161 effective-channel expansion supplies the experimental
external address policy: repeat each effective source pair, then apply the
table-4-22 physical-to-logical permutation. First source bit alone yields
logical nibble `Ah`; second alone yields `5h`. This explicitly differs from
X Millennium's `CCC`/`333` bank-only table; MAME's different C64 condition is
marked incomplete. Exact reduced ASIC/page policy and native acceptance remain
open. A pixel pass qualifies this stated policy, not a silent resolution of
the emulator discrepancy.

Printed 124 fig. 4-12 confirms 640x200/64 contiguous 80-byte raster rows:
4000..404F, next character row 4050..409F; each component's second bank supplies
the other effective channel. Do not copy the separate +400h half-plane
drawing for the 320-column or 320x400 mode into this width. The inherited
graphics address helper already supplies these contiguous CRTC addresses.

Mode, SCRN, blackclip and width cross as one 24-bit held snapshot. Analog
admission also requires agreement with the timing-domain width/SCRN samples;
this avoids combining independently sampled register bits. The snapshot
primitive moves from board-only `files.qip` to `rtl/machine.qip` without a
duplicate dependency. Placement, payload bounds, reset/live-switch and native
clock phase still require review. Destination reset masks output; transfer
continues independently of CPU enables. No metastability signoff is inferred.

Fetch captures mode/page/parity at request. The shifter retains the requested
mode through the corresponding load; live control changes cannot reinterpret
an already-fetched character's source count. Incomplete/rejected fetches remain
invalid, not stale previous pixels. Only the existing video RAM ports are used.

## Verification checkpoint

The expanded shifter unit passes five source layouts, all 16,384 base
addresses, eight pixels, both relevant page/parity choices, held enables,
mode exit and pending reset at three video clocks. Existing all-4096 connected
palette-pin tests also pass. Unit log `/tmp/x1-z-multimode-shifter.log`.

Four actual CPU-written retained-reset cases finish with exit zero:

| Case | Exact active pixels checked | Palette |
|---|---:|---|
| 640x200/64 | 128,000 | Custom |
| 320x400/64 | 128,000 | Custom |
| 320x200/64 screen 0 | 64,000 | Custom |
| 320x200/64 screen 1 | 64,000 | Cold identity |

They initialize both GRAM banks,
program a real CRTC, independently check every pixel and measured periods,
and require post-reset CRTC/PPI writes with no GRAM/text/palette refill.
Frozen runner SHA-256:
`b6942e60c2c9a1f00504334b9455d75bf026c7637941b1720c848ae1cc910e52`.
Logs: `/tmp/x1-z-{wide64,tall64}-custom-warm.log`,
`/tmp/x1-z-dual64-screen0-custom-warm.log`, and
`/tmp/x1-z-dual64-screen1-warm.log`. Fixture SHA-256:
`8d1002ba731e36188348d99e443d53d760b70f2681229c597adad6ec782b7f17`.
These passes qualify the explicit experimental expansion above, not native
reduced ASIC compatibility.

The shifter also passes directed mode/page/parity/address mutation after
request acceptance, during reads and between pixels at all three clocks:
`/tmp/x1-z-multimode-live-controls.log`. This is a held-request test, not
full-machine live-switch or CDC placement acceptance.

The sixteen-case reduced-mode matrix passes all four configurations under
both identity/custom palettes and cold/warm reset. It copies the executable,
Python oracle and Z80 emitter into a unique ignored directory before starting;
subsequent source edits/builds cannot change that run. Current directory:
`verilator/obj_dir_v13_z_multimode/mode-matrix-jvzqF9/`, log
`/tmp/x1-z-multimode-frozen-matrix.log`. Runner hash remains the one above;
fixture hash is `d5d8fb8e0f660a716199093bcc46c892bbf0afdc4d50317e53a25810d2fdf6d9`.
The full matrix finishes with exit zero on October 9, 2026: all sixteen cases
pass. This qualifies the stated provisional pixel policy, not native ASIC
compatibility. Every case checks all active pixels; warm cases require
post-reset initialization without refilling palette/GRAM/text memory.

The preceding default v13 baseline suite finishes successfully with frozen
runner `fb0b6a7764210609335083c07255122278c16a80776f59fa0278fff98572ca16`
in `/tmp/x1-z-video-damfix-baseline-full.log`; it does not enable this extension.
The separate corrected full-color frozen matrix finishes with exit zero:
identity/custom, cold/warm, each 64,000 pixels; log
`/tmp/x1-z-pins-frozen-matrix.log`, runner
`8afb17c15999327b59b66de5f5b8ffa12ac00e8f4fa31ed24f2cc5829ca2018c`.
Current default-source timing/GRAM/DAM CPU checks also finish with exit zero
on runner `805f0f4273b0247f11801eec393316ded69728ec1b6e9489803a309426d980b7`.
This is focused current-source coverage, not a second complete baseline suite.
Current wrapper checks also finish with exit zero: ordinary/X3/DMA interface
lint, four-ratio stopped-clock snapshot protocol, and all-4096 RGB12 wrapper
boundary combinations (`/tmp/x1-z-multimode-wrapper-checks.log`). Explicit CDC
source duplicates were removed from wrapper lists after the manifest move.
These checks use a PLL stand-in; they do not verify fitting or the scaler.

Still required: text/graphics priority and simultaneous
two-screen composition, reduced CPU palette controls, mode/reset races,
native Z software and source-bound fitting/CDC/physical video. Z3 and the
user's work groups are not completed by this experiment.
