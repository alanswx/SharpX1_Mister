# Bounded native HuBASIC PSET/LINE qualification

Later October 16 local extension: [eight colors and PRESET](BASIC_COLOR_REFERENCE_STATUS.md)
pass 22 CLI v4 reference cases, with shared-byte neighbor preservation,
3,248,128 exact pixels and 192 CPU GRAM writes. Independent audit and four
rejecting controls pass. The new color/erase cases remain unexecuted on RTL
and hardware. Local [SAVE/LOAD](BASIC_SAVE_LOAD_REFERENCE_STATUS.md) also now
passes; the older writable-CLI limitation below describes this earlier gate.
MiSTer is with the user; the CORENAME below is historical, not current ownership.

October 16, 2026. Unmodified CZ-8FB01 V1.0 guest on the existing qualified
CSP base reference and separate external-font MiSTer revision. No RTL,
reference VM, native ROM or original-disk change for this graphics work.

The frozen reference gate passes seven cases: PSET and LINE, each cold-
repeated, missing-Enter controls for both commands, and a one-pixel-wrong
point control. Exact banner/command/Ok and 32×32 graphics-window checks cover
346,112 pixels. All 105 native CPU GRAM writes match independently computed
addresses, plane order and bit masks; both no-Enter cases make no GRAM writes.
Cold-repeat machine artifacts are byte-identical. The independent audit passes.
The matched five-case hardware matrix also passes, with 15 native raw PNGs
and 168,960 exact pixels. The final independent audit recomputes both gates,
checks logical graphics equality between renderers and verifies remote
RBF/media/Main/font-DDR hashes. This is bounded PSET/LINE qualification.

Commands are `PSET(400,160)` and `LINE(400,160)-(415,175)`, with no trailing
color argument. The expected point and 16-pixel diagonal are white on black.
The wrong-point case types `PSET(401,160)`, requires that exact native transcript
and actual shifted point, then must reject the unchanged x=400 graphics oracle.
Every missing-Enter frame must retain a wholly black target window and fail
the unchanged completion check. Drawing accompanied by a syntax error never
qualifies as completion.

The oracle independently computes each point's interleaved X1 GRAM address as
`((y & 7) << 11) + (y // 8) * 80 + x // 8`, with bit `0x80 >> (x & 7)` in all
three planes. CSP repeats each low-scan row in a 640×400 frame; the FPGA emits
640×200. Glyphs use each implementation's own separately hashed ANK source;
only logical graphics pixels are compared between renderers.

## Evidence and collectors

- `scripts/qualify_csp_basic_graphics.py`: freezes checker/emitter/executable/
  assets before seven cold processes, protected private D88 copies, explicit
  16/16-frame key events and actual CPU I/O trace. Evidence
  `output_files/BASIC_GRAPHICS_20261016T1605/qualification/`, session 72454
  terminal zero, `/tmp/x1-basic-graphics-csp-qualification.log`.
- `verilator/tests/check_basic_graphics.py`: fixed command/Ok and RGB oracle,
  independent coordinate/plane address emitter. No observed DUT data builds
  its expected pixels or publication ledger.
- `scripts/mister_basic_graphics.py`: five PSET/LINE/repeat/wrong-coordinate
  cases on the audited `4c0a95f2…` RBF. Each starts with actual Main R reset,
  then a fresh prompt/black window, missing Enter, and native completion.
  These are retained-asset hardware boots, not cold FPGA reloads. No core
  load, font/IPL upload or disk remount is requested.
- `scripts/audit_basic_graphics.py`: recomputes native glyphs, RGB, CPU writes,
  controls, artifact/source/asset hashes and cold repeats. CSP independent
  result is `BASIC_GRAPHICS_20261016T1605/csp-independent-audit.json`;
  its original auditor bytes are preserved in `csp-auditor-v1.py`.

The first hardware collector attempt is retained in `.../hardware/`, session
24429 terminal nonzero, `/tmp/x1-basic-graphics-hardware.log`. Before and
no-Enter checks pass, but the exact-one-fresh-PNG assertion rejects two arrivals.
`hardware-rejection-review/` preserves both: the native 640×200 frame passes
the exact point/Ok oracle, while the 1024×768 auxiliary image is rejected as
a native raster. The source copy and failed manifest remain unchanged.
No inference is made about what requested the auxiliary capture.

The revised frozen capture policy preserves every fresh PNG, checks **every**
640×200 native frame, requires at least one per phase, and retains other
rasters as auxiliary without pixel acceptance. It neither scales images nor
selects frames by pixel content. Pixel/CPU/command assertions are unchanged.
Session 5894 is terminal zero in `.../hardware-v2/`,
`/tmp/x1-basic-graphics-hardware-v2.log`. All five cases pass after actual Main
R boots, including both repeats and a wrong-coordinate witness that rejects
the unchanged point oracle. Every no-Enter frame remains black in the target
window and rejects completion. All 15 new captures are native640×200; no
auxiliary format enters this accepted matrix. The rejected first attempt
and its auxiliary image remain preserved separately.

Final independent audit session 15431 is terminal zero,
`/tmp/x1-basic-graphics-final-audit.log`, output
`BASIC_GRAPHICS_20261016T1605/final-independent-audit.json`, SHA
`58d3d46eddfb566271d046ad709bf5f9ae4965f2e610410da72e809f66c7a85b`.
Its exact source is preserved as `final-auditor.py`. All 428 compiler inputs,
qualified reference inputs, collector/checker/emitter and assets remain exact.
Current MiSTer CORENAME remains `X1BTEXT_20261016T155231Z_04`, at native
`PSET(401,160)`/Ok after the final matched control. No new RBF was needed.

Initial syntax experiments are observations, not accepted qualification:
`BASIC_GRAPHICS_20261016T1602/` includes native syntax errors with a trailing
`,7` and LINE's Type mismatch. Its `syntax-error-audit.json` verifies all
complete echoed commands/error/Ok rows with exact native font pixels; there
is no input-loss evidence in those runs. The slower `...1605/` exploration
identifies accepted no-color syntax. Both syntax and cadence differ between
explorations, so no isolated timing-causality inference is made.
The subsequent checker/emitter is frozen before the new seven-case matrix.
No reference timing policy is changed to fit the FPGA.

Native SAVE/LOAD, colors/other graphics commands, wider coordinates/modes,
other BASIC releases and disk formats, native font conversion, licensing and
physical timing remain open. Current RBF timing fails as recorded in
[the source-bound base-text status](BASE_TEXT_COMPATIBILITY_STATUS.md).
The current qualified CSP CLI permits only protected private disk copies;
SAVE/LOAD comparison first needs an explicit writable-new-copy option and
unchanged-original/existing-target/default-policy controls. No disk writes
are enabled by this graphics collection.
