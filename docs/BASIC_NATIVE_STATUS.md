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

A separate twelve-second cold/repeat command probe completes zero as session 79875:
`output_files/basic-print42-fdc-20261010/`, log
`/tmp/x1-basic-print42-fdc-20261010.log`. The original
`verilator/tests/basic_print_42.keys` sends IPL F, then held-Shift letters,
space/digits/keypad multiply and Enter for `PRINT 6*7` beginning at nine seconds.
It uses the inherited PS/2 mapping rather than guessed locale punctuation.
Neither an echoed command nor collector repeatability establishes arithmetic;
require a separate native result line `42` and return to `Ok`.
The command cold child now completes: text rows 13/14/15 contain exact
`print 6*7`, ` 42` and `Ok`. Main's independent ANK oracle checks **15,360**
pixels across all three complete 80-column rows, including glyph backgrounds,
with 164 foreground pixels. The final terminal checker qualifies both cold
and repeat: **30,720 exact RGB pixels**, identical reports/all six dumps and
unchanged input/runner hashes. Each runs twelve seconds / 384,000,000 SYS
edges, 36 PS/2 bytes, 936 SD requests, zero disk writes and 741 frames. An
independent read-only reviewer verifies the cold text/RGB and keyboard-source
explanation. This is arithmetic acceptance in this profile, not program
save/load/graphics or general BASIC compatibility.

The first prototype oracle incorrectly required uppercase command echo and
rejects the actual lowercase row. Source inspection explains the case before
changing the expectation: inherited startup sets active-low Caps ON (`FFF7`),
then alphabet conversion XORs case for Caps and Shift. Held Shift therefore
produces lowercase. The checker now requires that exact lowercase echo rather
than accepting arbitrary case variants; the independent arithmetic result and
pixel checks are unchanged. Keypad `7C` emits `*` in both mapping tables.
No RTL, firmware, key stream or private media is changed to obtain this result.
`check_basic_print42.py` requires terminal paired evidence, current asset/
runner/artifact hashes, fixed clocks/profile and all 36 PS/2 bytes before it
can qualify both native command runs. Its synthetic unit gate is separate.
Nine synthetic oracle tests pass locally, including wrong/missing/duplicate
results, uppercase echo, displaced text, missing/corrupt raster and full-row
padding, plus terminal/profile/hash/command/input-manifest rejections. Review
found an empty input map could initially bypass source checks; the final
checker requires a nonempty map and all three actual ROM/disk/key command
paths within it. Restore/RAM injection/writable output are rejected. Main's
fresh `test-basic-print42-oracle` Make target also completes zero (41425).
CI schedules that asset-free unit gate, not private native BASIC execution.

Accepted checker/ANK copies are retained beside native evidence **after** this
exploratory cold/repeat observation; this is not a claim that the newly written
checker was frozen before the initial cold run. Future regressions must freeze
the accepted oracle before collecting new runs. The frozen checker independently
passes both terminal runs in `/tmp/x1-basic-print42-native-acceptance.log`.
Checker SHA-256:
`913aa2364bb2e35e08d283da9092ae1ea336c2d3bed9fb892d706dd026184d8b`;
font source:
`68aa689abd81c1a620980b5318b669b292a72d4877916ec43dc2461d713c831b`;
terminal cold PNG (128,000-pixel exact PPM comparison passes):
`68baad2e45d0dad1ac94dc0c0196fd4100dbd27c74e3115254ac55b0a9907be1`.

The sixteen-second stored-program cold/repeat probe completes with exit zero:
`output_files/basic-list-run-fdc-20261010/`, log
`/tmp/x1-basic-list-run-fdc-20261010.log`. `basic_list_run.keys` enters
`10 PRINT 9`, then `LIST` and `RUN`, without Shift under startup Caps ON.
Both terminal runs separately show input `10 PRINT 9`, `LIST`, a listed
`10 PRINT 9`, `Ok`, `RUN`, result `9`, then `Ok` (rows 13–19). This is not an
echo-only pass. Reports and all six output dumps are identical; all seven input
hashes and the frozen `c244826e...` executable remain unchanged. Each run uses
16 seconds, 512 million SYS edges, 63 actual PS/2 bytes, 988 captured frames,
32-MHz SYS/28,571,428-Hz VID and the separate 1-MHz FDC experiment. There are
zero disk writes and no RAM injection or restored state.

The generalized checker `--sequence program` independently checks every pixel
of the seven complete transcript rows: 35,840 pixels/429 ink pixels per child,
71,680/858 total. Log: `/tmp/x1-basic-program-native-acceptance.log`. The
checker and ANK copies are frozen **after** the exploratory observation, not
claimed as pre-run oracles. The earlier arithmetic checker copy stays intact.
Current checker SHA-256:
`1f11f6f1a811cd73266cd99652353d3d76e3b9a06573bd9fd21b586a02a2c687`;
stored-program evidence JSON:
`4d82797f3dd0b884c58fcff7e0cc3efd866aec87d1dc3bed12b1eab15f8f1076`;
terminal cold PNG:
`9c47e55048db6a6fc21e7b2d4cb098f791813c91b4fe0365fd19c76a8a83e000`.
The PNG is a lossless conversion of actual native RGB; the exact 128,000-pixel
PPM comparison passes with zero mismatches.

`make -C verilator test-basic-print42-oracle` now passes thirteen synthetic
unit methods: the original nine arithmetic tests plus four stored-program
tests. These add missing LIST/listed-line/RUN/wrong-result, complete-row padding,
result-glyph corruption and 16-second/63-event profile rejection coverage.
This bounded CZ-8FB01 result is not general BASIC, other-model or hardware
acceptance. Retained reset, native save/load and representative graphics tests
remain required.

`make -C verilator test-basic-native-probe` exercises the collector using
temporary synthetic files and a fake executable. Eight test methods/fourteen
scenarios cover repeat observations, pre-output runner/media refusal, changed
payload/report/input/runner rejection, disk-write refusal and retained
nonzero/timeout evidence. Changed or disappearing inputs now retain a `failed`
phase and explicit integrity/read-error evidence, never a stale `repeatable`
phase. The prior collector already refused a PASS/returned nonzero on changed
bytes; this repairs its terminal reporting and missing-file evidence. Existing
native results retain their original frozen collector and source hashes.
The strict checker also binds the collector's original working-tree path;
after this intentional collector edit, rerunning that historical check against
the current tree rejects that source hash. Preserve its original evidence/
frozen copy and recorded successful acceptance rather than patching manifests
or substituting current source. Future native runs need the new collector.
The direct local unittest run completes zero; an initial new fixture failure
from macOS `/var` versus `/private/var` spelling was corrected by normalizing
the disposable root, not weakening the integrity comparison.
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
