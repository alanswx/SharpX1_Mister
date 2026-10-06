# Turbo Z full-color output foundation

October 6, 2026. This is the first Z1 increment, not Turbo Z emulation.

## Implemented boundary

The shared `rtl/sharpx1.v` exposes a new combinational `rgb12` output with
conventional `R[11:8]:G[7:4]:B[3:0]` packing. Existing digital rendering
expands each component to zero or fifteen. The historical `rgb` diagnostic
output retains its different `G:R:B` bit order and is not removed.

Both `verilator/sim.v` and `sharpx1.sv` consume the same RGB12 boundary.
MiSTer's eight-bit component outputs repeat each nibble (`n * 17`). The
headless runner captures RGB12 at the existing pixel enable/HS/VS/blank
signals; PPM and optional SDL pixels preserve intermediate component levels.
There is no new clock, enable, RAM, palette state or resampling. Audio and
the digital renderer are unchanged. Palette/multi-mode logic must eventually
feed this shared boundary, not a screenshot-only color override.

The simulator serialization version is now **v12** because the added output
port changes the serialized model layout. Reject v11 and older snapshots;
regenerate from native boot. Historical v11 executables and evidence remain
frozen, not converted. This version change does not itself imply a new
machine capability or requalification of five games.

## Executed checks

- `make -C verilator test-rgb12 HEADLESS_DIR=obj_dir_v12_rgb12` passes:
  all 4096 colors in a generated 32x128 raster, independent component/scaling
  expectations, exact PPM header/payload, deterministic pixel hash, eight
  legacy colors and blank/held-sync handling. This exercises the capture
  adapter with original synthetic inputs, not a native Z palette.
- `lint-wrapper` and `lint-wrapper-turbo-video` exit zero. Existing framework
  warnings remain visible. These use the PLL interface stand-in, not a fit,
  scaler run or physical output validation.
- `test_snapshot.py` passes on the isolated v12 `qualification-fast` runner:
  CPU/RAM/clock continuation, negative v11-header/time/truncation/clock tests,
  joystick persistence/override and SDL dummy-driver checks. Its modified
  invalid header is a negative fixture, never a state conversion.

The fresh full delay-aware baseline regression and unchanged native Xevious
qualification were started separately; their terminal results must be
recorded before advertising them as acceptance of this increment.

Source-bound executables (Verilator 5.044 / macOS Clang):

| Runner | SHA-256 |
|---|---|
| `obj_dir_v12_rgb12/Vtop`, delay-aware base SYS32MHz / VID28,571,428Hz | `3af87e0af9fc188795bb6ae90ea3cb8d7fdc0051d4ec5b4fa1e6adf47528614e` |
| `obj_dir_v12_rgb12_fast/Vtop`, isolated savable base, same clocks, synthesis-style delays | `159062a12920cb398d1bd348b8e901a7b6139d31cfcadd8d038b73235d962a8a` |

Logs: `/tmp/x1-v12-rgb12-build.log`,
`/tmp/x1-v12-rgb12-wrapper-lint.log`,
`/tmp/x1-v12-rgb12-regression.log`, `/tmp/x1-v12-rgb12-xevious.log`.
Generated rasters/states and private input media are ignored, not committed.

## Hosted diagnostic compiler follow-up

The preceding [19-target run on `35fd51d`](https://github.com/alanswx/SharpX1_Mister/actions/runs/37487504759)
failed at its 600-second DMA build limit. All nine SIO targets completed, but
GCC remained inside the generated DMA coroutine compilation even with `-O0`;
there was no DMA simulator execution or RTL assertion failure in that run.
The next 20-target workflow selects Clang and adds the capture test. It
does not remove delays/assertions, shorten transfers or relax acceptance.
[Verilator's compiler option](https://verilator.org/guide/latest/exe_verilator.html#cmdoption-compiler)
tunes generated code but does not select the make compiler; the workflow also
passes `CXX=clang++` through `-MAKEFLAGS`, and prints compiler versions.
Hosted execution remains an independent acceptance gate.

## Still required

Z1 remains open for fitted/scaler/physical full-color validation. No real
machine palette currently generates intermediate levels. Z0/Z2 must resolve
model/decode and manual-based palette transactions; Z3/Z4 must implement
GRAM packing and text priority. Z5–Z9 (FM, HD disks, Kanji/devices, capture,
native/timing acceptance) remain separate gates in [the roadmap](TURBO_Z_PLAN.md).
