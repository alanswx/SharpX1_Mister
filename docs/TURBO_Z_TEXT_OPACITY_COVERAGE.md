# Text visibility coverage audit and transparent-window correction

October 9, 2026. Acceptance-fixture correction, **not an RTL change or a newly
resolved native opacity rule**.

## Reproduced coverage gap

Read-only analysis of the original generated scenes found no selected text
pixels for full-color graphics-on-top, or paired graphics-on-top. The planes
look varied, but every position with transparent graphics also had absent
text. The corresponding exact-frame passes therefore established graphics
output/order, not text rendering beneath graphics. Selected-screen 64-color
and between-screen scenes did select text; their bounded results remain valid.
Do not promote the older frozen matrices to full analog text ordering acceptance.

| Scene | Selected pixels per nonzero text color, old | New planned window coverage |
|---|---|---|
| Full graphics-on-top | 0 for each color 1–7 | 36 for each color 1–7 |
| Paired graphics-on-top | 0 for each color 1–7 | 36 for each color 1–7 |
| Selected-screen graphics-on-top | 50–51 | 85–87 |
| Paired text-between | 50–52 | 85–87 |

The table is an independent source-visibility audit, not terminal machine
evidence for the corrected scenes. Existing raw-code transparency/intensity
policies remain explicitly experimental.

## Corrected actual CPU fixture

Every new `--text` fixture now clears a 128x8 graphics window through real
CPU OUT instructions: both GRAM banks, all three components and both source
offsets. Compact loops preserve the existing code/table aperture. The window
spans all eight colors and normal/reverse cell groups, deliberately decoupling
graphics transparency from the ANK mask. It is initialized only on cold entry;
the retained warm-reset branch does not refill it.

The independent pixel oracle models the window from spatial coordinates,
not the emitter's instruction stream. An additional visibility audit requires
at least one selected pixel from **every** nonzero raw text color. Programmed
black color 7 is included, so this is not a final-RGB-nonzero proxy. Existing
counterfactual order/reverse images and every-pixel/period/reset/hash assertions
remain in force. Non-text fixture behavior is unchanged.

## Running corrected gates

Fresh frozen actual-CPU warm tests both terminate with exit zero:

- Full-color `FBh` graphics-on-top: `/tmp/x1-z-opacity-full-warm.log`.
- Paired `19h` bank-1 graphics-on-top, SCRN selecting bank 0:
  `/tmp/x1-z-opacity-paired-warm.log`.

Each checks all 64,000 pixels/periods, actual CPU completion, retained reset
without palette/VRAM refill, runner/font hash stability, and exactly 36 selected
samples for each raw text color 1–7. The alternate text order differs from the
actual full frame at 16,638 pixels and the paired frame at 16,609 pixels.
Frozen directories: `opacity-full-jh8izq` and `opacity-paired-4dZJHo` under
`verilator/obj_dir_v13_z_paired/`. Program hashes:
full `834b811c1758c5360b32f3c5268151e9e0ce8d0e353f29371c98e934387db6cf`;
paired `2d1f01ce9ff4da4be70d1a1be953725b1b2176d9d734bf4ace5882f57152dadd`.

`make -C verilator test-z-text-visibility` exits zero in
`/tmp/x1-z-text-visibility-unit.log`: three unit groups reject the old full/
paired zero-text scenes, every missing nonzero color (including black), and
check corrected selected-screen/between/reverse coverage. These are oracle
guards, not a substitute for executed-machine or native acceptance.

Both use the current single/paired compositor runner
`6420d29945b4958ee8509334fb8e774f7191ab490babd2172f00b65e0ed634e0`.
The prior graphics-only, paired-text and single-text matrices still use their
own frozen scripts; they are not restarted or silently replaced. Their
terminal records must retain the old fixture's coverage limitation.

Rerun the strengthened cold/warm ordering matrices; the two corrected warm
gates alone do not close the whole matrix. Native zero-code/blackclip/intensity, attribute cross-products,
firmware and Quartus/physical acceptance still remain open.

## Distinct text-entry follow-up

A second fixture audit finds the original text programming formula assigned
identical RGB to entries 1/5 and 2/6. Those frame passes cannot distinguish
these palette-index swaps, even with transparent windows. New fixtures program
seven distinct writable RGB entries (including raw code 7 black), with all
four levels present in each channel. The expected RGB values are independent
literal triples, not decoded from the fixture's CPU write words.

`make -C verilator test-z-text-visibility` now passes four groups in
`/tmp/x1-z-distinct-text-unit.log`. The additional group checks uniqueness,
channel-level coverage, CPU-word/RGB agreement and glyph-ink samples that
distinguish each writable entry from every other. This is oracle evidence,
not a terminal machine result.

A new actual-CPU paired `1Ah` text-between/reverse/warm case is running in
`/tmp/x1-z-distinct-text-warm.log`, frozen under
`verilator/obj_dir_v13_z_paired/distinct-text-1Zu1ji/`. Its runner remains
`6420d29945b4958ee8509334fb8e774f7191ab490babd2172f00b65e0ed634e0`;
fixture hash is `31f5ab3fe223f753948d9e984a553bf4b7aad399c6fbe1a142cf530ab87f7188`,
program hash `2637ee82f0a666faa08cdc20c7d0f74e9e68e2e671a73187660d42a9f6e25adb`.
No older running fixture is replaced. Fresh complete matrices still need
these stronger distinct-entry fixtures; no native intensity/opacity rule or
RTL behavior was changed by this test correction.

The original paired-text matrix subsequently terminates with exit zero,
12/12 cases, retaining its original visibility/alias limitations. Only after
that terminal handle was observed, a new independent twelve-case strengthened
matrix was launched in `/tmp/x1-z-strengthened-paired-text-matrix.log` with
the current fixture. It remains pending; the other old matrices and the
independently frozen reverse/warm case continue unchanged.
