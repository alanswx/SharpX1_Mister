# Native BASIC digital colors and erasing in the local reference

October 16, 2026. The existing CLI revision 4 CSP base reference passes
**22 native PSET/PRESET cases**, **66 PNGs**, **3,248,128 exact pixels** and
**192 CPU GRAM writes**. An independent artifact audit passes. This extends
the earlier white PSET/LINE reference coverage; it does not qualify these
new cases on RTL or hardware. MiSTer remains with the user and was not accessed.
No reference VM, CLI, RTL, original disk or private ROM bytes change.

## Frozen native cases

Each fresh process boots the unmodified base IPL and CZ-8FB01 V1.0 disk,
then types two separate commands through real VM keys:

```basic
PSET(400,160,7)
PSET(401,160,7)
```

The two neighboring pixels share a GRAM byte and start white. The final
command is `PSET(400,160,C)` for each color C=0..7, or `PRESET(400,160)`.
Every operation cold-repeats in another fresh process. The pixel at x=401
must remain white while the target takes the selected color or becomes black.
Each phase checks the exact native banner/transcript/Ok and the complete
32×32 target window, including black background and both doubled low-scan
rows. No OCR, image scaling, tolerance or RAM injection is used.

Four controls each require their own expected behavior and reject the
unchanged final graphics oracle: omitted Enter for blue PSET and PRESET,
red instead of blue, and PRESET at the neighboring x=401. Both omitted-Enter
cases also reject native command/Ok completion and produce only the six
seed writes. Controls must execute successfully; process failures do not count.

The oracle derives digital RGB from blue/red/green bits 0/1/2. Independent
GRAM addressing gives offset `20*80+400//8 = 0x672`, plane addresses
`4672/8672/C672`, and masks `80/40`. Seed writes must be `80` then `C0` in
all planes. Final writes must retain the neighbor's bit and set/clear the
target's bit separately in each plane. Trace checks require the exact native
write order/data and the correct command's frame interval, rather than
deriving expected bytes from the observed trace.

## Configuration and evidence

The frozen executable is the already-qualified CLI v4 X1 binary SHA-256
`5c96bdb232b602605d52b905e172f182eb45cc5d563409f468ec6146ce9675b7`.
The 156 reference source inputs and all three qualified model binaries
remain unchanged. Base CSP uses its existing 4-MHz CPU/61.94-Hz frame policy,
pseudo-controller and explicit PSG-only configuration. Each case runs 2,800
frames, no scheduled reset, with the actual frame log checking 64,580 clocks
per frame and 640×400 output. These are reference policies, not physical X1
frequency measurements or FPGA clock equivalence.

Input, seed and final captures are at frames 799/1999/2799. Commands start
at 800/1400/2000 with 16 pressed and 16 released host frames per character.
Every disk mount is a protected private copy. The original D88 retains SHA
`ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a`;
each private copy equals the input with only its protection policy applied.

`scripts/qualify_csp_basic_colors.py` freezes collector, oracle/emitter,
executable and assets before the matrix. `check_basic_colors.py` holds the
fixed native pixel and CPU-write expectations. Cold repeats require exact
whole PNGs and frame logs; other raw differences are reported without
normalization. All other collected files also happen to match in this run,
but no broader host-clock-independent raw-artifact contract is inferred.

Evidence is in `output_files/BASIC_COLOR_20261016T2253/qualification/`;
session 75182 is terminal zero, `/tmp/x1-basic-colors-qualification.log`.
The independent `scripts/audit_csp_basic_colors.py` recomputes pixels, all
command/key arguments, original/copy preservation, current/frozen sources,
CPU writes with command phases, frame clocks and repeats. Its result is
`BASIC_COLOR_20261016T2253/independent-audit.json`; its exact source is
preserved as `auditor.py`, SHA
`c358a8300bfd7dc216a9a366684871d77a2e7c7730b7f1fbcb9b24f23541cc2b`.

`explore.py` / `explore.json` are earlier syntax observations, not acceptance.
Embedded-color PSET succeeds and embedded-color LINE reports Syntax error.
The exploratory helper did not map colon to a valid VM punctuation key:
the COLOR-prefix/combined-erase strings therefore omit that character in
the native echo. They cannot establish the intended colon syntax. The frozen
matrix uses separate native commands and an explicitly checked key mapping.
Earlier trailing-color syntax failures remain preserved in the white
[graphics report](BASIC_NATIVE_GRAPHICS_STATUS.md).

Native color/PRESET on RTL and hardware, colored LINE syntax, other graphics
commands, wider coordinates/modes, Turbo/Z firmware/font combinations and
physical timing remain open. The existing source-bound RBF still fails
timing; this reference-only work makes no new Quartus or hardware claim.
