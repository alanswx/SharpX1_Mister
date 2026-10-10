# Native BASIC acceptance: initial disk probe

October 10, 2026. BASIC compatibility and licensing remain open. This probe
uses a locally supplied collection; no download or redistribution permission
is inferred. Private media, RAM dumps and RGB evidence remain ignored.

The existing non-overwriting `scripts/prepare_x1_media.py` stages
`software/Sharp X1 [TOSEC]/Applications/ZZZ-UNK-HuBASIC.zip` into
`software/basic-unpacked/zzz-unk-hubasic-11a5077cf724/`. The archive identifies
no verified BASIC version/model. Its raw sector bytes are wrapped as
40-cylinder, two-sided, 16-sector, 256-byte D88 records without payload changes.
Do not relabel this unknown release as CZ-8FB01 or Turbo Z BASIC.

| Asset | SHA-256 |
| --- | --- |
| Supplied ZIP | `11a5077cf7242424f6448879334cdae2bb663e542145b8ab3cf977fa6c4e5386` |
| Raw 2D member | `d7e8ebfca043bb05a07a8ea20f001bf4bb54a0acda662260bd29005918699e5a` |
| Wrapped D88 | `ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a` |
| Selected frozen runner | `c244826e3f9da196276431ceb4e3ce7b7f8a1d0d849b4e8af977c99c27ca76cc` |

The selected runner is the previously frozen fixed-FDC CROSS checkpoint:
shared `rtl/sharpx1.v`, opt-in 1-MHz FDC bridge, SYS 32 MHz, VID 28.571428 MHz.
This is not a new build or ordinary-board/hardware qualification. The original
IPL and real PS/2 event file are hashed before each cold/repeat collection;
no restored state, RAM injection, writable disk output or private asset patch
is used. `probe_basic_native.py` explicitly checks the chosen executable hash;
its observations do not independently establish build provenance.

The initial eight-second cold/repeat probe is running as session 65306:
`output_files/basic-native-fdc-20261010/`, log
`/tmp/x1-basic-native-fdc-20261010.log`. No boot, command or repeat pass is
claimed until its terminal evidence and actual display are inspected.

`make -C verilator test-basic-native-probe` exercises the collector using
temporary synthetic files and a fake executable. Seven test methods/twelve
scenarios cover repeat observations, pre-output runner/media refusal, changed
payload/report/input/runner rejection, disk-write refusal and retained
nonzero/timeout evidence. The direct local unittest run completes zero.
This asset-free target is scheduled in CI; no hosted result is claimed.

## Required acceptance

1. Inspect the native cold frame and disk/CPU evidence; identify the release
   from its own output rather than the archive's unknown name.
2. At a native prompt, send actual PS/2 commands and verify printed arithmetic,
   stored/listed/run programs and representative text/graphics behavior.
3. Check retained-asset warm reset and protected-copy save/load with exact
   readback; do not enable writes to originals.
4. Compare authorized, identified base/Turbo/Turbo Z BASIC releases separately,
   including native raster/font/banking and clock/model requirements.
5. Keep licensing/provenance and source-bound fitted/hardware acceptance
   distinct from simulation or a prompt screenshot.
