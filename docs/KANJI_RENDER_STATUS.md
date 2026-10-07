# Opt-in first-level Kanji rendering experiment

October 6/7, 2026. Work group 3; a first-level dependency, **not full Turbo Z**.
The separate `TURBO_KANJI_RENDER=1` parameter connects the shared physical ROM
display port to the actual character pipeline. CPU-only `TURBO_KANJI=1`, all
board revisions and ordinary simulation defaults remain unchanged. No private
font bytes are committed. The recommended October 6 RBF has not changed and
does not contain this renderer.

## Policy and wiring

Electrical source/chip selection follows the tested [schematic decoder](KANJI_CONTRACT_STATUS.md#executed-first-level-glyph-source-decoder).
PCG takes priority over Kanji. DKAN4 selects absent second-level storage, not
another first-level bank. Missing/unloaded/second-level Kanji is blank rather
than an ANK replacement; existing reverse/color mixing can still color that
blank cell. Rendering does not invent a native CPU register-device signature.

The ASIC's K4Y..K1Y row logic is opaque in the schematic. This experiment
explicitly follows the local X Millennium source, not an electrical row claim:
`vram/maketxtl.c:knj8_nor` steps 0,2,...14 in standard scan;
`vram/maketxth.c:txt16_nor` steps through all sixteen rows in high scan.
The existing inherited `cg_line` phase feeds either `{cg_line[2:0],0}` or
`cg_line[3:0]`. Per-cell height, global expansion and underline combinations
still require separate Kanji qualification. MAME instead treats Kanji as
overriding PCG and guesses away double height; it is not the oracle here.
Neither emulator was newly built/run for this increment.

The new Kanji/attribute metadata registers latch at the existing early text
phase, together with the character/row address. The video ROM takes one local
clock edge; the later CG-load phase consumes it. Existing glyph shifts,
color/reverse, horizontal expansion and the downstream mixer stay in place.
Metadata resets asynchronously with video reset; the loader's retained ROM
and two-stage readiness gate remain unchanged. Actual cells and consecutive
rows, not forced internal glyph registers, are checked below.

`rtl/machine.qip` now includes the address and source decoders. Inherited
video copyright and restrictive distribution notices remain intact. New
extensions/fixtures are original; this does not resolve the root licensing
conflict. Wrapper lint passes with inherited warnings and a PLL stand-in,
not Quartus/physical acceptance of these new FPGA source bytes.

## Executed local gates

```sh
make -C verilator test-machine-kanji-render
make -C verilator test-machine-kanji-render-timing
make -C verilator test-machine-kanji-render-snapshot
```

The asset-free fixture executes an original Z80 ROM, configures the PPI/DAM,
writes all text/attribute/KVRAM through real CPU ports and programs the CRTC.
Its physical font is a generated 128 KiB pattern. The independent pixel oracle
uses integer bank/half/character/row formulas, inspects every RGB pixel and
checks nominal HS/VS periods within two 32 MHz observation quanta (62.5 ns).
Clock profile: 32 MHz system / 42.954540 MHz nominal X3; each invocation is
300 ms / 9,600,000 reference units, not 9,600,000 video edges.

Both fast and delay-aware runners pass the complete ten-case matrix:

| Cases | Actual image/gates |
|---|---|
| Standard scan, 40/80 columns, loaded/missing ROM | 320×200 / 640×200, even Kanji rows, both halves/banks/glyph changes, reverse and absent-level-2 isolation |
| High scan, 40/80 columns, loaded/missing ROM | 320×400 / 640×400, all sixteen Kanji rows and the same addressing/isolation checks |
| Standard/high scan, 80 columns, loaded warm reset | 10 us reset at 120 ms; retain physical font without asset reload, re-execute CPU programming and compare all final pixels |

Each matrix checks **1,536,000 actual pixels**, not an exhaustive attribute or
bank/character cross-product. Final logs:
`/tmp/x1-kanji-render-fast-final.log`,
`/tmp/x1-kanji-render-timing-final.log` (both exit zero).
Synthetic actual PPMs, generated assets and reports are retained privately in
ignored `output_files/kanji-render-xmil-row-{fast,timing}-final/`.
Fast runner SHA-256:
`f8bc8a21baaa94ac1bc75a6a2abfd389b7dd45cb095a0af1bae61c1ffa270dc2`;
delay-aware:
`8cf2b2c4510893aeaa633edb8b32836a6bfb4f29ba5621822d73cedfbded373c`.

The user-authorized inferred model-40 physical candidate also passes the ten
fast cases, including period checks, with SHA-256
`b32559f5d5b9014d5ba316c41293e1336532eb0c66a01d5ac7e1304dabdaa91c`.
Log `/tmp/x1-kanji-render-model40-fast-final.log`; private actual images/reports
in ignored `output_files/kanji-render-model40-private-fast-final/`.
This qualifies bounded candidate-byte rendering under the stated row policy,
not hardware-chip identity, linguistic glyph accuracy or native game boot.
Do not redistribute candidate assets or snapshots.

The real-CPU/INI diagnostic passes in the render-enabled fast model:
`/tmp/x1-kanji-render-cpu-concurrency.log`. This is a profile regression, not
proof that its display cell selects Kanji concurrently with every CPU read.
The prior CPU-only X3 snapshot test also still passes:
`/tmp/x1-kanji-render-cpu-profile-snapshot.log`.
Text-raster/mixer and physical decode tests pass:
`/tmp/x1-kanji-render-mixer-regression.log`.
Running the unchanged RGB fixture against the same-clock CPU-only Kanji
runner fails actual pixels on its first missing-ROM case (exit one), rather
than accepting its ANK fallback. Log
`/tmp/x1-kanji-render-disabled-negative.log`; no production RTL was modified
for that negative control.

The distinct render profile uses snapshot identity bit 44; CPU-only profile
identity remains unchanged. Actual high-scan render snapshot acceptance passes
at 200 ms + 100 ms continuation versus uninterrupted 300 ms: exact final RGB
PPM, report fields, RAM/text/attribute/sub-RAM/CPU dumps, additive HS/VS counts
and bidirectional rejection against the same-clock CPU-only Kanji model.
Log `/tmp/x1-kanji-render-snapshot-after-frame.log`, exit zero. An earlier
125 ms checkpoint failed its retained `frames > 0` requirement because CPU
setup had completed but the first frame had not. The checkpoint was moved to
200 ms, retaining the assertion and total 300 ms duration; original log
`/tmp/x1-kanji-render-snapshot.log` remains preserved.

The first pixel-fixture attempt also failed: ROM at address zero had emitted
jump labels for origin 0x8000. Corrected the original fixture to origin zero,
not any RTL, private asset or captured pixels; preserved
`/tmp/x1-kanji-render-first.log` and subsequent corrected results.
New render targets are added to hosted CI; their hosted result remains pending.

## Still required

- Mixed PCG/ANK/Kanji actual pixels and exits, all colors/blink/width/height,
  global expansion/underline/gap combinations and mid-scan changes.
- Direct observed simultaneous CPU/video ROM selection, reset during a pending
  rendered transaction, stopped-clock/pulse and loader-recovery pixel gates.
- Resolve ASIC raster/enable/phase behavior with primary programming details
  or a hardware trace, not agreement with a single emulator.
- Native Turbo/400-line applications and commercial games; this is synthetic
  CPU programming, not native firmware glyph acceptance.
- Native `0E80..83` protocol, separate Turbo Z second-level/external storage,
  fitted resource/timing and physical video/Main-reset acceptance.

No work group or full goal is complete from these tests.

## Executed mixed-source matrix

The next original fixture, `test_machine_kanji_mixed.py`, adds actual adjacent
ANK, PCG-with-K7-set, first-level Kanji and absent-level-2 cells. It prepares
PCG through the real CPU/window/WAIT path: 48 paired per-plane bytes are
written and individually read back before video programming. No memory or
internal glyph-register injection is used. Eight colors and reverse are
independent of the source type. Synthetic ANK16 and physical Kanji uploads
are original generated patterns; standard ANK uses the inherited CG8 table.

The first ten-case fast matrix passes: 40/80 columns, standard/high scan,
cold/10 us warm reset at 200 ms, and standard/high exits to KVRAM zero. The
exits check first/second-level Kanji becoming ANK and high-scan paired PCG
becoming ordinary vertically repeated PCG. A warm invocation uploads assets
only once; the CPU rewrites PCG during reboot, so it does not prove PCG
retention without writes. Each invocation retains 500 ms / 16,000,000
reference cycles; actual RGB and HS/VS periods are checked.

Four additional fast cases pass separately: standard expanded 40×10 with
underline (320×200), standard 80×20 underline (640×200), high 40×20 underline
(320×400), and high expanded 80×12 (640×384). Palette 0 is red background/gap,
palette 1 green underline; K5 alternates across all four cell types, and
reserved rasters must not acquire reversed glyph ink. These qualify the
existing provisional digital policy, not native `WIDTH`/`KSEN` execution or
ASIC raster behavior.

An initial underline fixture failed on absent-level-2 cells: the CPU emitter's
level-2 jump bypassed its K5 insertion. K5 is now added after all type
branches. The expected pixels/assertions and RTL were not changed to accept
the failure; its log and actual image remain in
`/tmp/x1-kanji-mixed-policy-first.log` and ignored
`output_files/kanji-mixed-policy-first/`. The corrected four-case log is
`/tmp/x1-kanji-mixed-policy-k5-fixed.log` (exit zero).
The unchanged mixed fixture also fails real pixels against the CPU-only
Kanji runner, `/tmp/x1-kanji-mixed-render-disabled-negative.log` (exit one).

The complete **fourteen-case** final fast/delay-aware matrices both pass,
with **2,101,760 actual pixels** checked per matrix. Final logs/output
directories are `/tmp/x1-kanji-mixed-{fast,timing}-final.log` and ignored
`output_files/kanji-mixed-{fast,timing}-final/`. Both processes exit zero;
neither diagnostic-only `--first-only` nor `--policy-only` is used in these
final gates. The corresponding targets are:

```sh
make -C verilator test-machine-kanji-mixed
make -C verilator test-machine-kanji-mixed-timing
```

No RTL, model identity, private asset or RBF change is made in this fixture
increment. Hosted mixed targets are added but their result is not yet known.
Per-cell width/height, blinking, the remaining expansion/underline cross
product, simultaneous CPU/video ROM selection and native/hardware acceptance
remain open.

### Native title probe now accepts the physical candidate

`probe_special_titles.py --kanji-physical PATH` validates exactly 131,072
bytes before creating outputs, records its hash among the protected original
inputs, and forwards the path to the frozen runner for both cold executions.
The asset-free mocked timeout test passes forwarding/hash recording and
rejection of a synthetic 306,176-byte tool-style export before launch/output.
Log `/tmp/x1-kanji-native-probe-timeout-resolved-path.log`, exit zero. Its first
new path assertion failed on macOS `/var` versus resolved `/private/var`;
the fixture now compares the collector's canonical path, retaining strict hash
and command checks. Original failure remains at
`/tmp/x1-kanji-native-probe-timeout-final.log`. Mocked provenance tests are not
game or FPGA verification.

Two fresh native Arcus boots complete successfully/repeat identically in ignored
`output_files/arcus-kanji-render-native-ipl/` with the unchanged supplied
32 KiB Turbo IPL, ANK16 and inferred physical model-40 Kanji candidate, frozen
fast runner `f8bc8a21...a270dc2`, eight seconds each, Disk 1 A / Disk 2 B
(still exploratory). The first completes with 888 disk requests, zero writes,
495 frames, hash `ad3165ae6bcf6eff`, and 167,936 uploaded bytes. Its actual
320×200 final PPM was converted losslessly for inspection as `cold-final.png`:
it reads “IPL is looking for a program from FD0,” **not game boot**. The
earlier `cold-inspection.png` preserves an intermediate initialization screen,
not a final capture. Both final reports and all six dumped artifact hashes
match; direct PPM/CPU byte comparisons also pass. The collector exits zero and
records `repeatable=true`, `unchanged_inputs=true`, `gameplay_verified=false`
in its private `evidence.json`. This is a repeated FD0-search outcome, **not
Arcus boot/playability or native Kanji glyph acceptance**. Diagnostic CPU FDC
data and DMA grant counters are zero; do not infer a causal device failure
without native transaction traces. No source/profile/assets were modified
to bypass IPL startup or disk ordering.
