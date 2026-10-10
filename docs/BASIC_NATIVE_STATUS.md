# Native BASIC acceptance: initial disk probe

October 10, 2026. BASIC compatibility and licensing remain open. This probe
uses a locally supplied collection; no download or redistribution permission
is inferred. Private media, RAM dumps and RGB evidence remain ignored.

The existing non-overwriting `scripts/prepare_x1_media.py` stages
`software/Sharp X1 [TOSEC]/Applications/ZZZ-UNK-HuBASIC.zip` into
`software/basic-unpacked/zzz-unk-hubasic-11a5077cf724/`. The archive identifies
no verified BASIC version/model. Its raw sector bytes are wrapped as
40-cylinder, two-sided, 16-sector, 256-byte D88 records without payload changes.
The subsequently observed native screen identifies **SHARP-HuBASIC CZ-8FB01
V1.0**, copyright 1982 SHARP/Hudson. This identifies its own banner, not a
verified dump revision/hash against an independent release or Turbo Z BASIC.

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

The initial eight-second cold/repeat probe completes zero as session 65306:
`output_files/basic-native-fdc-20261010/`, log
`/tmp/x1-basic-native-fdc-20261010.log`. Both children complete with identical
reports and all six output dumps; Main independently verifies actual artifact
and input hashes. The RGB/text shows the banner, `20989 Bytes free` and an
`Ok` prompt. Each executes exactly eight seconds / 256,000,000 SYS edges,
with 936 SD requests, zero disk writes, 494 frames and six PS/2 bytes. This
qualifies repeatable native prompt boot in this profile, not command or model
compatibility. `final-cold.png` is a pixel-exact conversion of the terminal
captured PPM, checked against all 128,000 RGB pixels. It is not generated or
retouched imagery, a hardware screenshot or BASIC command acceptance.
PNG SHA-256:
`bfc710ce122169cec02aae2b98da7e68a887b343db2d676e9f48306d2d843841`;
final cold PPM:
`fed26d19f86ce01de365cb26b7edd9a1246f4637130775c395439f2d06d72aff`.
The retained `interim.png` matched the live PPM when first converted, but a
terminal comparison subsequently rejects 64 differing pixels. It must not
stand in for the final frame; both captures are preserved, and the new terminal
conversion passes the unchanged exact-pixel comparator without tolerance.

A separate twelve-second cold/repeat command probe starts as session 79875:
`output_files/basic-print42-fdc-20261010/`, log
`/tmp/x1-basic-print42-fdc-20261010.log`. The original
`verilator/tests/basic_print_42.keys` sends IPL F, then held-Shift letters,
space/digits/keypad multiply and Enter for `PRINT 6*7` beginning at nine seconds.
It uses the inherited PS/2 mapping rather than guessed locale punctuation.
Neither an echoed command nor collector repeatability establishes arithmetic;
require a separate native result line `42` and return to `Ok`.

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
